import { onSchedule } from "firebase-functions/v2/scheduler";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

export const processRecurringAllocations = onSchedule(
  { schedule: "0 9 1 * *", timeZone: "Asia/Seoul", region: "asia-northeast3" },
  async () => {
    const db = admin.firestore();
    const now = new Date();

    const snapshot = await db
      .collection("recurringAllocations")
      .where("isActive", "==", true)
      .where("frequency", "==", "monthly")
      .where("nextExecutionDate", "<=", now)
      .get();

    const batch = db.batch();

    for (const doc of snapshot.docs) {
      const data = doc.data();
      const fromRef = db.collection("transactions").doc();
      const toRef = db.collection("transactions").doc();
      const desc = data.description || "고정 예산 이전";

      // 상위 지출
      batch.set(fromRef, {
        projectId: data.fromProjectId,
        userId: data.createdByUserId,
        amount: data.amount,
        description: desc,
        type: "expense",
        linkedTransactionId: toRef.id,
        confirmedAt: now,
        date: now,
        createdAt: now,
      });

      // 하위 수입
      batch.set(toRef, {
        projectId: data.toProjectId,
        userId: data.createdByUserId,
        amount: data.amount,
        description: desc,
        type: "income",
        linkedTransactionId: fromRef.id,
        confirmedAt: now,
        date: now,
        createdAt: now,
      });

      // 다음 실행일 업데이트 (다음 달)
      const next = new Date(now.getFullYear(), now.getMonth() + 1, now.getDate());
      batch.update(doc.ref, { nextExecutionDate: next });
    }

    await batch.commit();
    console.log(`Processed ${snapshot.size} recurring allocations`);
  }
);
