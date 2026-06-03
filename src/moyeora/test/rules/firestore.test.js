/**
 * Firestore 보안 규칙 단위 테스트
 *
 * 실행 전 Firebase Emulator Suite가 실행 중이어야 합니다:
 *   firebase emulators:start --only firestore
 *
 * 테스트 실행:
 *   cd test/rules && npm install && npm test
 */

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const { readFileSync } = require("fs");
const { resolve } = require("path");
const assert = require("assert");

let testEnv;

const PROJECT_ID = "moyeora-dev";
const RULES_PATH = resolve(__dirname, "../../firestore.rules");

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(RULES_PATH, "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

after(async () => {
  if (testEnv) {
    await testEnv.cleanup();
  }
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// ── 헬퍼 함수 ──────────────────────────────────────────────────────────────

/**
 * 테스트용 그룹과 멤버를 초기화합니다.
 * Admin SDK(권한 없음)로 직접 데이터를 설정합니다.
 */
async function setupGroup(groupId, ownerId) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.collection("groups").doc(groupId).set({
      name: "테스트 모임",
      ownerId,
      status: "active",
      plan: "free",
      planLabel: "무료",
      limits: { memberMax: 10, eventCreateMonthlyMax: 20 },
      memberCount: 1,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
  });
}

async function setupMember(groupId, uid, role, permissions = [], status = "active") {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db
      .collection("groups")
      .doc(groupId)
      .collection("members")
      .doc(uid)
      .set({
        uid,
        role,
        permissions,
        status,
        joinedAt: new Date(),
        updatedAt: new Date(),
      });
  });
}

async function setupInviteCode(code, groupId, expiresAt, status = "active") {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const payload = {
      code,
      groupId,
      status,
      maxUses: 10,
      useCount: 0,
      createdAt: new Date(),
      updatedAt: new Date(),
    };
    if (expiresAt !== undefined) {
      payload.expiresAt = expiresAt;
    }
    await db.collection("inviteCodes").doc(code).set(payload);
    await db
      .collection("groups")
      .doc(groupId)
      .collection("invites")
      .doc(code)
      .set(payload);
  });
}

// ── 그룹 문서 읽기/쓰기 ─────────────────────────────────────────────────────

describe("groups/{groupId} 읽기", () => {
  it("활성 멤버는 그룹 문서를 읽을 수 있다", async () => {
    await setupGroup("g1", "owner1");
    await setupMember("g1", "user1", "member");

    const ctx = testEnv.authenticatedContext("user1");
    const db = ctx.firestore();
    await assertSucceeds(db.collection("groups").doc("g1").get());
  });

  it("비인증 사용자는 그룹 문서를 읽을 수 없다", async () => {
    await setupGroup("g1", "owner1");

    const ctx = testEnv.unauthenticatedContext();
    const db = ctx.firestore();
    await assertFails(db.collection("groups").doc("g1").get());
  });

  it("멤버가 아닌 인증 사용자는 그룹 문서를 읽을 수 없다", async () => {
    await setupGroup("g1", "owner1");

    const ctx = testEnv.authenticatedContext("outsider");
    const db = ctx.firestore();
    await assertFails(db.collection("groups").doc("g1").get());
  });
});

// ── 멤버 문서 읽기/쓰기 ─────────────────────────────────────────────────────

describe("groups/{groupId}/members/{uid} 읽기", () => {
  it("활성 멤버는 다른 멤버 문서를 읽을 수 있다", async () => {
    await setupGroup("g1", "owner1");
    await setupMember("g1", "user1", "member");
    await setupMember("g1", "user2", "member");

    const ctx = testEnv.authenticatedContext("user1");
    const db = ctx.firestore();
    await assertSucceeds(
      db.collection("groups").doc("g1").collection("members").doc("user2").get()
    );
  });

  it("비멤버는 멤버 문서를 읽을 수 없다", async () => {
    await setupGroup("g1", "owner1");
    await setupMember("g1", "user1", "member");

    const ctx = testEnv.authenticatedContext("outsider");
    const db = ctx.firestore();
    await assertFails(
      db.collection("groups").doc("g1").collection("members").doc("user1").get()
    );
  });

  it("pending 상태 멤버는 그룹 문서를 읽을 수 없다", async () => {
    await setupGroup("g1", "owner1");
    await setupMember("g1", "pending_user", "member", [], "pending");

    const ctx = testEnv.authenticatedContext("pending_user");
    const db = ctx.firestore();
    await assertFails(db.collection("groups").doc("g1").get());
  });
});

// ── 이벤트 읽기/쓰기 ────────────────────────────────────────────────────────

describe("groups/{groupId}/events 읽기", () => {
  it("활성 멤버는 이벤트를 읽을 수 있다", async () => {
    await setupGroup("g1", "owner1");
    await setupMember("g1", "user1", "member");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .collection("groups")
        .doc("g1")
        .collection("events")
        .doc("e1")
        .set({ title: "이벤트", startAt: new Date(), isDeleted: false });
    });

    const ctx = testEnv.authenticatedContext("user1");
    const db = ctx.firestore();
    await assertSucceeds(
      db.collection("groups").doc("g1").collection("events").doc("e1").get()
    );
  });

  it("비멤버는 이벤트를 읽을 수 없다", async () => {
    await setupGroup("g1", "owner1");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .collection("groups")
        .doc("g1")
        .collection("events")
        .doc("e1")
        .set({ title: "이벤트", startAt: new Date(), isDeleted: false });
    });

    const ctx = testEnv.authenticatedContext("outsider");
    const db = ctx.firestore();
    await assertFails(
      db.collection("groups").doc("g1").collection("events").doc("e1").get()
    );
  });
});

// ── 초대 코드 만료 테스트 ────────────────────────────────────────────────────

describe("inviteCodes 만료 테스트", () => {
  it("유효한(만료되지 않은) 초대 코드는 읽을 수 있다", async () => {
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await setupInviteCode("VALID123", "g1", expiresAt);

    const ctx = testEnv.authenticatedContext("user1");
    const db = ctx.firestore();
    await assertSucceeds(db.collection("inviteCodes").doc("VALID123").get());
  });

  it("비인증 사용자는 초대 코드를 읽을 수 없다", async () => {
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await setupInviteCode("VALID456", "g1", expiresAt);

    const ctx = testEnv.unauthenticatedContext();
    const db = ctx.firestore();
    await assertFails(db.collection("inviteCodes").doc("VALID456").get());
  });

  it("초대 코드는 직접 삭제할 수 없다", async () => {
    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await setupInviteCode("NODELETE", "g1", expiresAt);
    await setupGroup("g1", "owner1");
    await setupMember("g1", "owner1", "owner");

    const ctx = testEnv.authenticatedContext("owner1");
    const db = ctx.firestore();
    await assertFails(db.collection("inviteCodes").doc("NODELETE").delete());
  });
});

// ── g_demo 예외 동작 테스트 ──────────────────────────────────────────────────

describe("g_demo 예외 동작", () => {
  it("데모 그룹의 활성 멤버는 demo_user_[1-5] 멤버를 생성할 수 있다", async () => {
    await setupGroup("g_demo", "owner1");
    await setupMember("g_demo", "owner1", "owner");

    const ctx = testEnv.authenticatedContext("owner1");
    const db = ctx.firestore();
    await assertSucceeds(
      db
        .collection("groups")
        .doc("g_demo")
        .collection("members")
        .doc("demo_user_1")
        .set({
          uid: "demo_user_1",
          status: "active",
          role: "member",
          permissions: [],
        })
    );
  });

  it("데모 그룹에서도 demo_user_[1-5] 패턴에 맞지 않으면 생성 불가", async () => {
    await setupGroup("g_demo", "owner1");
    await setupMember("g_demo", "owner1", "owner");

    const ctx = testEnv.authenticatedContext("owner1");
    const db = ctx.firestore();
    // demo_user_6은 패턴에 맞지 않음
    await assertFails(
      db
        .collection("groups")
        .doc("g_demo")
        .collection("members")
        .doc("demo_user_6")
        .set({
          uid: "demo_user_6",
          status: "active",
          role: "member",
          permissions: [],
        })
    );
  });

  it("일반 그룹에서는 데모 예외가 적용되지 않는다", async () => {
    await setupGroup("g_normal", "owner1");
    await setupMember("g_normal", "owner1", "owner");

    const ctx = testEnv.authenticatedContext("owner1");
    const db = ctx.firestore();
    // 일반 그룹에서 demo_user_1 생성 시도 → inviteCode 조건이 맞지 않아 실패
    await assertFails(
      db
        .collection("groups")
        .doc("g_normal")
        .collection("members")
        .doc("demo_user_1")
        .set({
          uid: "demo_user_1",
          status: "active",
          role: "member",
          permissions: [],
        })
    );
  });
});

// ── 공지 읽기/쓰기 ──────────────────────────────────────────────────────────

describe("groups/{groupId}/notices 권한", () => {
  it("활성 멤버는 공지를 읽을 수 있다", async () => {
    await setupGroup("g1", "owner1");
    await setupMember("g1", "user1", "member");
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx
        .firestore()
        .collection("groups")
        .doc("g1")
        .collection("notices")
        .doc("n1")
        .set({ title: "공지", body: "내용", pinned: false, createdAt: new Date() });
    });

    const ctx = testEnv.authenticatedContext("user1");
    const db = ctx.firestore();
    await assertSucceeds(
      db.collection("groups").doc("g1").collection("notices").doc("n1").get()
    );
  });

  it("일반 멤버는 공지를 생성할 수 없다", async () => {
    await setupGroup("g1", "owner1");
    await setupMember("g1", "user1", "member");

    const ctx = testEnv.authenticatedContext("user1");
    const db = ctx.firestore();
    await assertFails(
      db
        .collection("groups")
        .doc("g1")
        .collection("notices")
        .add({
          title: "무단 공지",
          body: "내용",
          pinned: false,
          createdAt: new Date(),
          createdBy: "user1",
        })
    );
  });
});
