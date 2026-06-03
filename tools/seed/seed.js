
const admin = require('firebase-admin');

const projectId = process.env.FIREBASE_PROJECT_ID || 'moyeora-dev';
const userUid = process.env.USER_UID;

if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  throw new Error('GOOGLE_APPLICATION_CREDENTIALS 환경변수가 필요합니다.');
}

if (!userUid) {
  throw new Error('USER_UID 환경변수가 필요합니다.');
}

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId,
});

const db = admin.firestore();
const now = admin.firestore.FieldValue.serverTimestamp();

const groupId = 'g_demo';
const eventId = 'event_demo_1';
const noticeId = 'notice_demo_1';

async function seed() {
  const groupRef = db.collection('groups').doc(groupId);
  const memberRef = groupRef.collection('members').doc(userUid);
  const eventRef = groupRef.collection('events').doc(eventId);
  const noticeRef = groupRef.collection('notices').doc(noticeId);

  await groupRef.set(
    {
      name: '데모 그룹',
      ownerId: userUid,
      memberCount: 1,
      isDormant: false,
      createdAt: now,
      updatedAt: now,
    },
    { merge: true },
  );

  await memberRef.set(
    {
      uid: userUid,
      role: 'owner',
      status: 'active',
      nickname: 'Owner',
      permissions: [
        'member.manage',
        'role.manage',
        'event.manage',
        'attendance.manage',
        'fee.manage',
        'payment.manage',
        'notice.manage',
        'private.read',
        'settings.manage',
      ],
      joinedAt: now,
      updatedAt: now,
    },
    { merge: true },
  );

  await eventRef.set(
    {
      title: '첫 정기 모임',
      description: 'Moyeora 데모 이벤트',
      startsAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
      ),
      endsAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 3 * 24 * 60 * 60 * 1000 + 2 * 60 * 60 * 1000),
      ),
      responseCloseAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 2 * 24 * 60 * 60 * 1000),
      ),
      status: 'open',
      deletedAt: null,
      createdBy: userUid,
      createdAt: now,
      updatedAt: now,
    },
    { merge: true },
  );

  await noticeRef.set(
    {
      title: '[고정] 데모 공지',
      body: 'Moyeora 시드 데이터로 생성된 공지입니다.',
      isPinned: true,
      createdBy: userUid,
      createdAt: now,
      updatedAt: now,
    },
    { merge: true },
  );

  console.log('Seed complete');
  console.log(`projectId=${projectId}`);
  console.log(`groupId=${groupId}`);
  console.log(`ownerUid=${userUid}`);
}

seed()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Seed failed:', error.message);
    process.exit(1);
  });
