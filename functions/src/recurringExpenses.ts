import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

async function getMemberTokens(memberIds: string[]): Promise<string[]> {
  const docs = await Promise.all(
    memberIds.map((uid) => admin.firestore().collection("users").doc(uid).get())
  );
  return docs
    .map((doc) => doc.data()?.fcmToken as string | undefined)
    .filter((token): token is string => !!token);
}

export const processRecurringExpenses = onSchedule(
  { schedule: "0 0 * * *", timeZone: "Asia/Seoul", region: "asia-northeast3" },
  async () => {
    const db = admin.firestore();
    const now = new Date();
    const today = now.getDate();

    const snapshot = await db
      .collection("recurringExpenses")
      .where("isActive", "==", true)
      .where("dayOfMonth", "==", today)
      .get();

    if (snapshot.empty) {
      console.log("No recurring expenses to process today.");
      return;
    }

    const batch = db.batch();
    // 프로젝트별 처리된 항목 추적 { projectId → { count, descriptions[] } }
    const processed = new Map<string, { count: number; descriptions: string[]; memberIds: string[] }>();

    for (const doc of snapshot.docs) {
      const data = doc.data();

      // 이미 이번 달에 생성됐는지 확인
      const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);
      const existing = await db
        .collection("transactions")
        .where("recurringExpenseId", "==", doc.id)
        .where("date", ">=", startOfMonth)
        .limit(1)
        .get();

      if (!existing.empty) continue;

      const txRef = db.collection("transactions").doc();
      batch.set(txRef, {
        projectId: data.projectId,
        userId: data.userId,
        amount: data.amount,
        description: data.description,
        category: data.category || "other",
        type: data.type || "expense",
        recurringExpenseId: doc.id,
        confirmedAt: now,
        date: now,
        createdAt: now,
      });

      // 알림 집계
      if (!processed.has(data.projectId)) {
        // 프로젝트 멤버 조회
        const projectDoc = await db.collection("projects").doc(data.projectId).get();
        const members = (projectDoc.data()?.members ?? []) as Array<{ userId: string }>;
        processed.set(data.projectId, {
          count: 0,
          descriptions: [],
          memberIds: members.map((m) => m.userId),
        });
      }
      const entry = processed.get(data.projectId)!;
      entry.count++;
      entry.descriptions.push(data.description as string);
    }

    await batch.commit();
    console.log(`Processed ${snapshot.size} recurring expenses`);

    // 프로젝트별 처리 결과 알림 발송
    for (const [projectId, info] of processed.entries()) {
      if (info.count === 0) continue;

      const tokens = await getMemberTokens(info.memberIds);
      if (tokens.length === 0) continue;

      const projectDoc = await db.collection("projects").doc(projectId).get();
      const projectName = (projectDoc.data()?.name as string) ?? "프로젝트";
      const body =
        info.count === 1
          ? `'${info.descriptions[0]}' 고정 지출이 자동 처리되었습니다.`
          : `${info.count}건의 고정 지출이 자동 처리되었습니다.`;

      await admin.messaging().sendEachForMulticast({
        tokens,
        notification: { title: `📋 ${projectName} 고정 지출 처리`, body },
        data: { projectId, type: "recurring_processed" },
        android: { priority: "normal", notification: { channelId: "zaro_expenses" } },
        apns: { payload: { aps: { sound: "default" } } },
        webpush: { notification: { icon: "/icons/Icon-192.png" } },
      });
    }
  }
);
