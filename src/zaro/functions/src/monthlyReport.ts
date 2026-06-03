import { onCall, HttpsError } from "firebase-functions/v2/https";
import { GoogleGenerativeAI } from "@google/generative-ai";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

interface MonthlyReportRequest {
  year: number;
  month: number;
  projectName: string;
  totalBudget: number;
  totalSpent: number;
  transactions: Array<{
    description: string;
    amount: number;
    date: string;
    projectName: string;
  }>;
}

export const generateMonthlyReport = onCall<MonthlyReportRequest>(
  { region: "asia-northeast3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const uid = request.auth.uid;
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const apiKey = userDoc.data()?.geminiApiKey as string | undefined;
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "Gemini API 키가 설정되지 않았습니다. 설정에서 API 키를 입력해주세요.");
    }

    const { year, month, projectName, totalBudget, totalSpent, transactions } = request.data;

    const remaining = totalBudget - totalSpent;
    const usageRate = totalBudget > 0 ? Math.round((totalSpent / totalBudget) * 100) : 0;

    const txList = transactions
      .map((t) => `- ${t.date} | ${t.description} | ₩${t.amount.toLocaleString()}`)
      .join("\n");

    const prompt = `당신은 가계부 분석 전문가입니다. 아래 ${year}년 ${month}월 지출 데이터를 분석하여 한국어로 월별 리포트를 작성해주세요.

[프로젝트] ${projectName}
[예산] ₩${totalBudget.toLocaleString()}
[총 지출] ₩${totalSpent.toLocaleString()} (${usageRate}%)
[잔액] ₩${remaining.toLocaleString()}

[지출 내역]
${txList || "지출 내역 없음"}

다음 항목을 포함하여 자연스러운 문장으로 리포트를 작성해주세요:
1. 이번 달 지출 요약 (예산 대비 평가)
2. 주요 지출 항목 분석
3. 절약 포인트 및 개선 제안
4. 다음 달 예산 관리 조언

리포트는 친근하고 실용적인 어조로 작성하세요. 마크다운 헤더(#)는 사용하지 말고, 줄바꿈과 이모지를 활용해 가독성을 높여주세요.`;

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

    const result = await model.generateContent(prompt);
    const report = result.response.text();

    return { report };
  }
);
