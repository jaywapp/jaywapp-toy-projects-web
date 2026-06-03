import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

async function getAllMemberTokens(memberIds: string[]): Promise<string[]> {
  const docs = await Promise.all(
    memberIds.map((uid) => admin.firestore().collection("users").doc(uid).get())
  );
  return docs
    .map((doc) => doc.data()?.fcmToken as string | undefined)
    .filter((token): token is string => !!token);
}

async function sendPush(
  tokens: string[],
  title: string,
  body: string,
  data: Record<string, string>
): Promise<void> {
  if (tokens.length === 0) return;
  await admin.messaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
    android: {
      priority: "high",
      notification: { channelId: "zaro_expenses" },
    },
    apns: {
      payload: { aps: { sound: "default" } },
    },
  });
}

export const onTransactionConfirmed = onDocumentUpdated(
  { document: "transactions/{transactionId}", region: "asia-northeast3" },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();

    if (!before || !after) return;

    // confirmedAt이 null → non-null 로 변경될 때만 처리
    if (before.confirmedAt !== null && before.confirmedAt !== undefined) return;
    if (!after.confirmedAt) return;

    const projectId = after.projectId as string;
    const userId = after.userId as string;
    const amount = after.amount as number;
    const description = after.description as string;
    const type = (after.type as string) ?? "expense";

    if (type === "income") return;

    // 프로젝트 정보 조회
    const projectDoc = await admin.firestore().collection("projects").doc(projectId).get();
    if (!projectDoc.exists) return;

    const members = (projectDoc.data()?.members ?? []) as Array<{ userId: string }>;
    const allMemberIds = members.map((m) => m.userId);
    const otherMemberIds = allMemberIds.filter((id) => id !== userId);

    const projectName = (projectDoc.data()?.name as string) ?? "프로젝트";

    // ① 다른 멤버에게 지출 알림
    if (otherMemberIds.length > 0) {
      const senderDoc = await admin.firestore().collection("users").doc(userId).get();
      const senderName = (senderDoc.data()?.name as string) ?? "멤버";
      const tokens = await getAllMemberTokens(otherMemberIds);
      const formattedAmount = amount.toLocaleString("ko-KR");

      await sendPush(
        tokens,
        `${projectName} 새 지출 알림`,
        `${senderName}이 '${description}' ₩${formattedAmount} 지출`,
        { projectId, type: "transaction_confirmed" }
      );
    }

    // ② 예산 초과 알림 (80% / 100% 임계값 돌파 시)
    const txSnapshot = await admin.firestore()
      .collection("transactions")
      .where("projectId", "==", projectId)
      .get();

    let totalIncome = 0;
    let totalExpense = 0;

    for (const doc of txSnapshot.docs) {
      const data = doc.data();
      if (!data.confirmedAt) continue;
      const txType = (data.type as string) ?? "expense";
      const txAmount = (data.amount as number) ?? 0;
      if (txType === "income") {
        totalIncome += txAmount;
      } else {
        totalExpense += txAmount;
      }
    }

    if (totalIncome <= 0) return;

    const prevExpense = totalExpense - amount;
    const prevRatio = prevExpense / totalIncome;
    const currRatio = totalExpense / totalIncome;

    const allTokens = await getAllMemberTokens(allMemberIds);
    const pct = Math.round(currRatio * 100);

    // ③ 수입 대비 예산 경고
    if (totalIncome > 0) {
      if (prevRatio < 1.0 && currRatio >= 1.0) {
        await sendPush(
          allTokens,
          `⚠️ ${projectName} 예산 초과!`,
          `지출이 수입을 초과했습니다 (${pct}% 사용)`,
          { projectId, type: "budget_exceeded" }
        );
      } else if (prevRatio < 0.8 && currRatio >= 0.8) {
        await sendPush(
          allTokens,
          `🔔 ${projectName} 예산 80% 도달`,
          `지출이 수입의 ${pct}%에 도달했습니다`,
          { projectId, type: "budget_warning" }
        );
      }
    }

    // ④ 예산 한도(budgetLimit) 초과 알림
    const budgetLimit = projectDoc.data()?.budgetLimit as number | undefined;
    if (budgetLimit && budgetLimit > 0) {
      const prevBudgetRatio = prevExpense / budgetLimit;
      const currBudgetRatio = totalExpense / budgetLimit;
      const budgetPct = Math.round(currBudgetRatio * 100);
      if (prevBudgetRatio < 1.0 && currBudgetRatio >= 1.0) {
        await sendPush(
          allTokens,
          `🚨 ${projectName} 예산 한도 초과!`,
          `설정한 예산 한도를 초과했습니다 (${budgetPct}% 사용)`,
          { projectId, type: "budget_limit_exceeded" }
        );
      } else if (prevBudgetRatio < 0.8 && currBudgetRatio >= 0.8) {
        await sendPush(
          allTokens,
          `🔔 ${projectName} 예산 한도 80% 도달`,
          `예산 한도의 ${budgetPct}%를 사용했습니다`,
          { projectId, type: "budget_limit_warning" }
        );
      }
    }
  }
);
