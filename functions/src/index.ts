import { onCall, HttpsError } from "firebase-functions/v2/https";
import { GoogleGenerativeAI, Part } from "@google/generative-ai";
import * as admin from "firebase-admin";
export { processRecurringAllocations } from "./recurringAllocations";
export { processRecurringExpenses } from "./recurringExpenses";
export { generateMonthlyReport } from "./monthlyReport";
export { onTransactionConfirmed } from "./notifications";

if (!admin.apps.length) {
  admin.initializeApp();
}

interface Project {
  id: string;
  name: string;
  type: string;
}

interface AnalyzeExpenseRequest {
  userInput?: string;
  imageBase64?: string;
  imageMimeType?: string;
  projects: Project[];
  geminiApiKey?: string;
}

interface AnalyzeExpenseResponse {
  amount: number;
  description: string;
  date: string;
  suggestedProjectId: string;
  confidence: number;
  reason: string;
  category: string;
}

function buildPrompt(projectList: string, today: string, userInput?: string): string {
  return `사용자의 지출 정보를 분석하여 프로젝트 분류를 제안하세요.

[사용자 프로젝트 목록]
${projectList}
${userInput ? `\n[사용자 입력]\n${userInput}` : "\n[이미지에서 지출 정보를 추출하세요]"}

[출력 형식 - JSON만 출력, 마크다운 없이]
{
  "amount": 숫자,
  "description": "항목 설명",
  "date": "YYYY-MM-DD",
  "suggestedProjectId": "프로젝트 id",
  "confidence": 0~1 사이 숫자,
  "reason": "분류 이유 한 줄",
  "category": "food|transport|shopping|leisure|health|housing|education|other 중 하나"
}

date는 언급이 없으면 오늘(${today})로 설정하세요.
amount는 원 단위 숫자만 작성하세요.
category는 지출 내용을 분석하여 가장 적합한 카테고리를 선택하세요.`;
}

export const analyzeExpense = onCall<AnalyzeExpenseRequest>(
  { region: "asia-northeast3" },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const { userInput, imageBase64, imageMimeType, projects, geminiApiKey } = request.data;

    if (!projects || projects.length === 0) {
      throw new HttpsError("invalid-argument", "프로젝트 목록이 없습니다.");
    }
    if (!userInput && !imageBase64) {
      throw new HttpsError("invalid-argument", "텍스트 또는 이미지가 필요합니다.");
    }

    const apiKey = geminiApiKey as string | undefined;
    if (!apiKey) {
      throw new HttpsError("failed-precondition", "Gemini API 키가 설정되지 않았습니다. 설정에서 API 키를 입력해주세요.");
    }

    const genAI = new GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });

    const today = new Date().toISOString().substring(0, 10);
    const projectList = projects
      .map((p) => `- ${p.name} (id: ${p.id}, 유형: ${p.type})`)
      .join("\n");

    const prompt = buildPrompt(projectList, today, userInput);

    const parts: Part[] = [{ text: prompt }];
    if (imageBase64 && imageMimeType) {
      parts.unshift({
        inlineData: {
          data: imageBase64,
          mimeType: imageMimeType as "image/jpeg" | "image/png" | "image/webp",
        },
      });
    }

    let result;
    try {
      result = await model.generateContent({
        contents: [{ role: "user", parts }],
        generationConfig: {
          temperature: 0.1,
          responseMimeType: "application/json",
        },
      });
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      if (msg.includes("API_KEY_INVALID") || msg.includes("API key")) {
        throw new HttpsError("failed-precondition", "Gemini API 키가 유효하지 않습니다. 설정에서 올바른 키를 입력해주세요.");
      }
      throw new HttpsError("internal", `Gemini API 오류: ${msg}`);
    }

    const text = result.response.text();
    let data: AnalyzeExpenseResponse;
    try {
      data = JSON.parse(text) as AnalyzeExpenseResponse;
    } catch {
      throw new HttpsError("internal", "AI 응답 파싱 실패. 다시 시도해주세요.");
    }

    return data;
  }
);
