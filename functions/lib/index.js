"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.analyzeExpense = exports.onTransactionConfirmed = exports.generateMonthlyReport = exports.processRecurringExpenses = exports.processRecurringAllocations = void 0;
const https_1 = require("firebase-functions/v2/https");
const generative_ai_1 = require("@google/generative-ai");
const admin = require("firebase-admin");
var recurringAllocations_1 = require("./recurringAllocations");
Object.defineProperty(exports, "processRecurringAllocations", { enumerable: true, get: function () { return recurringAllocations_1.processRecurringAllocations; } });
var recurringExpenses_1 = require("./recurringExpenses");
Object.defineProperty(exports, "processRecurringExpenses", { enumerable: true, get: function () { return recurringExpenses_1.processRecurringExpenses; } });
var monthlyReport_1 = require("./monthlyReport");
Object.defineProperty(exports, "generateMonthlyReport", { enumerable: true, get: function () { return monthlyReport_1.generateMonthlyReport; } });
var notifications_1 = require("./notifications");
Object.defineProperty(exports, "onTransactionConfirmed", { enumerable: true, get: function () { return notifications_1.onTransactionConfirmed; } });
if (!admin.apps.length) {
    admin.initializeApp();
}
function buildPrompt(projectList, today, userInput) {
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
exports.analyzeExpense = (0, https_1.onCall)({ region: "asia-northeast3" }, async (request) => {
    var _a;
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const { userInput, imageBase64, imageMimeType, projects } = request.data;
    if (!projects || projects.length === 0) {
        throw new https_1.HttpsError("invalid-argument", "프로젝트 목록이 없습니다.");
    }
    if (!userInput && !imageBase64) {
        throw new https_1.HttpsError("invalid-argument", "텍스트 또는 이미지가 필요합니다.");
    }
    const uid = request.auth.uid;
    const userDoc = await admin.firestore().collection("users").doc(uid).get();
    const apiKey = (_a = userDoc.data()) === null || _a === void 0 ? void 0 : _a.geminiApiKey;
    if (!apiKey) {
        throw new https_1.HttpsError("failed-precondition", "Gemini API 키가 설정되지 않았습니다. 설정에서 API 키를 입력해주세요.");
    }
    const genAI = new generative_ai_1.GoogleGenerativeAI(apiKey);
    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });
    const today = new Date().toISOString().substring(0, 10);
    const projectList = projects
        .map((p) => `- ${p.name} (id: ${p.id}, 유형: ${p.type})`)
        .join("\n");
    const prompt = buildPrompt(projectList, today, userInput);
    const parts = [{ text: prompt }];
    if (imageBase64 && imageMimeType) {
        parts.unshift({
            inlineData: {
                data: imageBase64,
                mimeType: imageMimeType,
            },
        });
    }
    const result = await model.generateContent({
        contents: [{ role: "user", parts }],
        generationConfig: {
            temperature: 0.1,
            responseMimeType: "application/json",
        },
    });
    const text = result.response.text();
    const data = JSON.parse(text);
    return data;
});
//# sourceMappingURL=index.js.map