"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.dailyBackupJob = exports.dormantGroupAutoDetectionAt02 = exports.leaderboardAndStatsSnapshotAt03 = exports.unpaidMembersReminderAt19 = exports.monthlyFeePeriodAutoCreate = exports.eventAutoCloseAndResultNotifyEvery10m = exports.feeDueReminderD3D1At10 = exports.recurringEventAutoCreateEvery30m = exports.noResponseReminderAt13 = exports.d1EventReminderHourly = exports.onBetaReportCreatedGithubIssue = exports.onSuggestionCreatedGithubIssue = exports.onNoticeCreatedPush = exports.recomputeGroupPeriodStats = exports.seedDemoData = exports.authExchangeKakaoCode = exports.authExchangeKakao = exports.logClientEvent = exports.kickMember = exports.deletePoll = exports.deleteNotice = exports.deleteEvent = exports.deleteGroup = exports.delegateGroupOwner = exports.setRoleAndClaims = exports.approveMember = exports.requestJoinWithInviteCode = exports.revokeInviteCode = exports.createInviteCode = void 0;
const admin = __importStar(require("firebase-admin"));
const firebase_functions_1 = require("firebase-functions");
const params_1 = require("firebase-functions/params");
const https_1 = require("firebase-functions/v2/https");
const firestore_1 = require("firebase-functions/v2/firestore");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const crypto_1 = require("crypto");
const period_1 = require("./period");
admin.initializeApp();
const kakaoRestApiKey = (0, params_1.defineSecret)("KAKAO_REST_API_KEY");
function normalizePermissions(permissions) {
    if (Array.isArray(permissions)) {
        return permissions.filter((p) => typeof p === "string");
    }
    if (permissions && typeof permissions === "object") {
        const result = [];
        for (const [key, value] of Object.entries(permissions)) {
            if (value === true) {
                result.push(key);
            }
            else if (value && typeof value === "object") {
                for (const [childKey, childValue] of Object.entries(value)) {
                    if (childValue === true) {
                        result.push(`${key}.${childKey}`);
                    }
                }
            }
        }
        return result;
    }
    return [];
}
function hasPermissionInMemberData(memberData, permission) {
    if (memberData.role === "owner")
        return true;
    const permissions = normalizePermissions(memberData.permissions);
    return permissions.includes(permission);
}
function isActiveMemberData(memberData) {
    return !!memberData && memberData.status === "active";
}
function canManageMembersOrEvents(memberData) {
    return hasPermissionInMemberData(memberData, "member.manage") ||
        hasPermissionInMemberData(memberData, "event.manage");
}
function hasPermissionFromClaims(authToken, groupId, permission) {
    if (!authToken || typeof authToken !== "object")
        return false;
    const tokenMap = authToken;
    const moyeora = tokenMap.moyeora;
    if (!moyeora || typeof moyeora !== "object")
        return false;
    const groups = moyeora.groups;
    if (!groups || typeof groups !== "object")
        return false;
    const groupClaims = groups[groupId];
    if (!groupClaims || typeof groupClaims !== "object")
        return false;
    const role = groupClaims.role;
    if (role === "owner")
        return true;
    const perms = groupClaims.perms;
    return Array.isArray(perms) && perms.includes(permission);
}
async function hasGroupPermission(groupId, uid, authToken, permission) {
    if (hasPermissionFromClaims(authToken, groupId, permission)) {
        return true;
    }
    const memberDoc = await admin
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("members")
        .doc(uid)
        .get();
    if (!memberDoc.exists)
        return false;
    const data = memberDoc.data() ?? {};
    if (data.status !== "active")
        return false;
    return hasPermissionInMemberData(data, permission);
}
async function upsertGroupClaims(userId, groupId, role, permissions) {
    const userRecord = await admin.auth().getUser(userId);
    const existingClaims = (userRecord.customClaims ?? {});
    const existingMoyeora = (existingClaims.moyeora ?? {});
    const existingGroups = (existingMoyeora.groups ?? {});
    existingGroups[groupId] = { role, perms: permissions };
    await admin.auth().setCustomUserClaims(userId, {
        ...existingClaims,
        moyeora: {
            ...existingMoyeora,
            groups: existingGroups,
        },
    });
}
async function removeGroupClaims(userId, groupId) {
    try {
        const userRecord = await admin.auth().getUser(userId);
        const existingClaims = (userRecord.customClaims ?? {});
        const existingMoyeora = (existingClaims.moyeora ?? {});
        const existingGroups = { ...(existingMoyeora.groups ?? {}) };
        if (!(groupId in existingGroups)) {
            return false;
        }
        delete existingGroups[groupId];
        await admin.auth().setCustomUserClaims(userId, {
            ...existingClaims,
            moyeora: {
                ...existingMoyeora,
                groups: existingGroups,
            },
        });
        return true;
    }
    catch (error) {
        firebase_functions_1.logger.warn("removeGroupClaims failed", { userId, groupId, error });
        return false;
    }
}
async function writeAuditLog(input) {
    try {
        await admin
            .firestore()
            .collection("groups")
            .doc(input.groupId)
            .collection("auditLogs")
            .add({
            at: admin.firestore.FieldValue.serverTimestamp(),
            actorUid: input.actorUid,
            action: input.action,
            targetUid: input.targetUid ?? null,
            targetId: input.targetId ?? null,
            before: input.before ?? null,
            after: input.after ?? null,
            meta: input.meta ?? {},
        });
    }
    catch (error) {
        firebase_functions_1.logger.error("Audit log write failed", {
            groupId: input.groupId,
            action: input.action,
            actorUid: input.actorUid,
            error,
        });
    }
}
async function deleteCollectionDocs(collectionRef, batchSize = 300) {
    let deleted = 0;
    let hasMore = true;
    while (hasMore) {
        const snap = await collectionRef.limit(batchSize).get();
        if (snap.empty) {
            hasMore = false;
            break;
        }
        const batch = admin.firestore().batch();
        for (const doc of snap.docs) {
            batch.delete(doc.ref);
        }
        await batch.commit();
        deleted += snap.size;
        if (snap.size < batchSize) {
            hasMore = false;
        }
    }
    return deleted;
}
async function deleteDocWithSubcollections(docRef, subcollections) {
    let deletedSubDocs = 0;
    for (const sub of subcollections) {
        deletedSubDocs += await deleteCollectionDocs(docRef.collection(sub));
    }
    await docRef.delete();
    return deletedSubDocs;
}
function compactPermissions(permissions) {
    return [...new Set(normalizePermissions(permissions))].sort();
}
const OWNER_PERMISSIONS = [
    "member.manage",
    "event.manage",
    "finance.manage",
    "role.manage",
    "settings.manage",
];
const ADMIN_PERMISSIONS = [
    "member.manage",
    "event.manage",
    "settings.manage",
];
const INVITE_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
const INVITE_CODE_LENGTH = 8;
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;
function isAutomationFeatureEnabled(flagName) {
    // Blaze 운영 기준으로 자동화 기능은 기본 활성화하고,
    // 필요 시 환경변수에 false를 명시해 개별 비활성화할 수 있다.
    return process.env.ENABLE_BLAZE_AUTOMATION_FEATURES !== "false" &&
        process.env[flagName] !== "false";
}
function parseRecurrenceRule(raw) {
    if (raw === "weekly" || raw === "biweekly" || raw === "monthly") {
        return raw;
    }
    return null;
}
function computeNextRecurringStartAt(source, rule) {
    if (rule === "weekly") {
        return new Date(source.getTime() + 7 * 24 * 60 * 60 * 1000);
    }
    if (rule === "biweekly") {
        return new Date(source.getTime() + 14 * 24 * 60 * 60 * 1000);
    }
    const utc = {
        year: source.getUTCFullYear(),
        month: source.getUTCMonth() + 1,
        day: source.getUTCDate(),
        hour: source.getUTCHours(),
        minute: source.getUTCMinutes(),
        second: source.getUTCSeconds(),
        millisecond: source.getUTCMilliseconds(),
    };
    const targetYear = utc.month === 12 ? utc.year + 1 : utc.year;
    const targetMonth = utc.month === 12 ? 1 : utc.month + 1;
    const lastDay = new Date(Date.UTC(targetYear, targetMonth, 0)).getUTCDate();
    const day = Math.min(utc.day, lastDay);
    return new Date(Date.UTC(targetYear, targetMonth - 1, day, utc.hour, utc.minute, utc.second, utc.millisecond));
}
function recurrenceLookAheadMillis(rule) {
    switch (rule) {
        case "weekly":
            return 10 * 24 * 60 * 60 * 1000;
        case "biweekly":
            return 17 * 24 * 60 * 60 * 1000;
        case "monthly":
            return 35 * 24 * 60 * 60 * 1000;
    }
}
function toKstDayKey(date) {
    const kst = new Date(date.getTime() + KST_OFFSET_MS);
    const year = kst.getUTCFullYear();
    const month = `${kst.getUTCMonth() + 1}`.padStart(2, "0");
    const day = `${kst.getUTCDate()}`.padStart(2, "0");
    return `${year}-${month}-${day}`;
}
function daysUntilDueInKst(dueDate, nowDate) {
    const dueKey = toKstDayKey(dueDate);
    const nowKey = toKstDayKey(nowDate);
    const dueUtcMidnight = Date.parse(`${dueKey}T00:00:00Z`);
    const nowUtcMidnight = Date.parse(`${nowKey}T00:00:00Z`);
    return Math.round((dueUtcMidnight - nowUtcMidnight) / (24 * 60 * 60 * 1000));
}
function parseReminderHours(rawValue, fallback) {
    const source = rawValue?.trim();
    const parsed = (source && source.length > 0 ? source.split(",") : [])
        .map((v) => Number(v.trim()))
        .filter((v) => Number.isFinite(v) && v > 0)
        .map((v) => Math.round(v));
    const values = parsed.length > 0 ? parsed : fallback;
    return [...new Set(values)].sort((a, b) => b - a);
}
function normalizeSentHours(rawValue) {
    if (!Array.isArray(rawValue))
        return [];
    return rawValue
        .filter((v) => typeof v === "number" && Number.isFinite(v))
        .map((v) => Math.round(v));
}
function isWithinReminderWindow(hoursUntilTarget, markerHours, windowHours = 1) {
    return hoursUntilTarget <= markerHours &&
        hoursUntilTarget > markerHours - windowHours;
}
function parseGithubIssueLabels(rawValue) {
    const value = rawValue?.trim();
    if (!value)
        return ["feedback"];
    return value
        .split(",")
        .map((label) => label.trim())
        .filter((label) => label.length > 0);
}
function toIsoStringIfTimestamp(raw) {
    if (raw instanceof admin.firestore.Timestamp) {
        return raw.toDate().toISOString();
    }
    return null;
}
async function createGithubIssue(params) {
    const response = await fetch(`https://api.github.com/repos/${params.repo}/issues`, {
        method: "POST",
        headers: {
            "Accept": "application/vnd.github+json",
            "Authorization": `Bearer ${params.token}`,
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "moyeora-functions",
            "Content-Type": "application/json",
        },
        body: JSON.stringify({
            title: params.title,
            body: params.body,
            labels: params.labels,
        }),
    });
    if (!response.ok) {
        const failBody = await response.text();
        throw new Error(`github-issue-create-failed(${response.status}): ${failBody}`);
    }
    const payload = await response.json();
    if (typeof payload.number !== "number" || typeof payload.html_url !== "string") {
        throw new Error("github-issue-create-invalid-response");
    }
    return { number: payload.number, url: payload.html_url };
}
function normalizeInviteCode(raw) {
    return raw
        .toUpperCase()
        .replace(/[^A-Z0-9]/g, "")
        .trim();
}
function generateInviteCode(length = INVITE_CODE_LENGTH) {
    const bytes = (0, crypto_1.randomBytes)(length);
    const chars = [];
    for (let i = 0; i < length; i += 1) {
        chars.push(INVITE_CODE_CHARS[bytes[i] % INVITE_CODE_CHARS.length]);
    }
    return chars.join("");
}
async function getActiveMembers(groupId) {
    const membersSnap = await admin
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("members")
        .where("status", "==", "active")
        .get();
    return membersSnap.docs.map((doc) => ({ uid: doc.id, data: doc.data() }));
}
async function getMemberTokens(groupId, uid) {
    const tokensSnap = await admin
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("members")
        .doc(uid)
        .collection("fcmTokens")
        .get();
    const tokens = new Set();
    for (const doc of tokensSnap.docs) {
        const token = doc.data().token;
        if (typeof token === "string" && token.trim().length > 0) {
            tokens.add(token);
        }
    }
    return [...tokens];
}
async function getNotificationSettings(groupId, uid) {
    const snap = await admin
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("members")
        .doc(uid)
        .collection("notificationSettings")
        .limit(1)
        .get();
    if (snap.empty) {
        return {
            noticeEnabled: true,
            eventReminderEnabled: true,
            noResponseReminderEnabled: true,
            paymentReminderEnabled: true,
        };
    }
    const data = snap.docs[0].data();
    return {
        noticeEnabled: data.noticeEnabled ?? true,
        eventReminderEnabled: data.eventReminderEnabled ?? true,
        noResponseReminderEnabled: data.noResponseReminderEnabled ?? true,
        paymentReminderEnabled: data.paymentReminderEnabled ?? true,
    };
}
async function sendMulticastNotification(tokens, payload) {
    if (tokens.length === 0)
        return;
    try {
        const result = await admin.messaging().sendEachForMulticast({
            tokens,
            notification: {
                title: payload.title,
                body: payload.body,
            },
            data: payload.data,
        });
        if (result.failureCount > 0) {
            firebase_functions_1.logger.warn("Multicast partial failure", {
                successCount: result.successCount,
                failureCount: result.failureCount,
            });
        }
    }
    catch (error) {
        firebase_functions_1.logger.error("Multicast send failed", error);
    }
}
async function getMembersWithoutResponse(groupId, eventId) {
    const activeMembers = await getActiveMembers(groupId);
    const responsesSnap = await admin
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("events")
        .doc(eventId)
        .collection("responses")
        .get();
    const responseMap = new Map();
    for (const doc of responsesSnap.docs) {
        const response = doc.data().response;
        responseMap.set(doc.id, typeof response === "string" ? response : null);
    }
    return activeMembers
        .map((m) => m.uid)
        .filter((uid) => {
        const response = responseMap.get(uid);
        return response == null || response === "maybe";
    });
}
exports.createInviteCode = (0, https_1.onCall)(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const groupId = request.data?.groupId;
    if (!groupId) {
        throw new https_1.HttpsError("invalid-argument", "groupId가 필요합니다.");
    }
    const expiresInDaysRaw = request.data?.expiresInDays;
    const maxUsesRaw = request.data?.maxUses;
    const expiresInDays = typeof expiresInDaysRaw === "number" ? Math.floor(expiresInDaysRaw) : 7;
    const maxUses = typeof maxUsesRaw === "number" ? Math.floor(maxUsesRaw) : 10;
    if (expiresInDays < 1 || expiresInDays > 30) {
        throw new https_1.HttpsError("invalid-argument", "expiresInDays는 1~30일이어야 합니다.");
    }
    if (maxUses < 1 || maxUses > 200) {
        throw new https_1.HttpsError("invalid-argument", "maxUses는 1~200이어야 합니다.");
    }
    const allowed = await hasGroupPermission(groupId, callerUid, request.auth?.token, "member.manage");
    if (!allowed) {
        throw new https_1.HttpsError("permission-denied", "권한이 없습니다.");
    }
    const db = admin.firestore();
    const groupRef = db.collection("groups").doc(groupId);
    let createdCode = null;
    let createdExpiresAt = null;
    let groupNameForLog = groupId;
    for (let attempt = 0; attempt < 8; attempt += 1) {
        const code = generateInviteCode();
        const inviteRef = groupRef.collection("invites").doc(code);
        const inviteCodeRef = db.collection("inviteCodes").doc(code);
        try {
            await db.runTransaction(async (tx) => {
                const [groupSnap, inviteSnap, codeSnap] = await Promise.all([
                    tx.get(groupRef),
                    tx.get(inviteRef),
                    tx.get(inviteCodeRef),
                ]);
                if (!groupSnap.exists) {
                    throw new https_1.HttpsError("not-found", "그룹을 찾을 수 없습니다.");
                }
                if (inviteSnap.exists || codeSnap.exists) {
                    throw new Error("invite-code-conflict");
                }
                const groupData = groupSnap.data() ?? {};
                if (typeof groupData.name === "string" && groupData.name.trim().length > 0) {
                    groupNameForLog = groupData.name;
                }
                const expiresAt = admin.firestore.Timestamp.fromMillis(Date.now() + expiresInDays * 24 * 60 * 60 * 1000);
                const commonPayload = {
                    code,
                    groupId,
                    createdBy: callerUid,
                    status: "active",
                    maxUses,
                    useCount: 0,
                    expiresAt,
                    createdAt: admin.firestore.FieldValue.serverTimestamp(),
                    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                };
                tx.set(inviteRef, commonPayload);
                tx.set(inviteCodeRef, commonPayload);
                tx.set(groupRef, { updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
                createdCode = code;
                createdExpiresAt = expiresAt;
            });
            break;
        }
        catch (error) {
            if (error instanceof https_1.HttpsError) {
                throw error;
            }
            if (error instanceof Error && error.message === "invite-code-conflict") {
                continue;
            }
            firebase_functions_1.logger.error("createInviteCode failed", { groupId, callerUid, error });
            throw new https_1.HttpsError("internal", "초대코드 발급 중 오류가 발생했습니다.");
        }
    }
    if (!createdCode || !createdExpiresAt) {
        throw new https_1.HttpsError("aborted", "초대코드를 발급하지 못했습니다. 잠시 후 다시 시도해 주세요.");
    }
    await writeAuditLog({
        groupId,
        actorUid: callerUid,
        action: "invite.create",
        targetId: createdCode,
        after: {
            code: createdCode,
            status: "active",
            expiresInDays,
            maxUses,
        },
        meta: { source: "callable.createInviteCode", groupName: groupNameForLog },
    });
    return {
        success: true,
        code: createdCode,
        groupId,
        expiresAt: createdExpiresAt,
        maxUses,
        useCount: 0,
    };
});
exports.revokeInviteCode = (0, https_1.onCall)(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const groupId = request.data?.groupId;
    const rawCode = request.data?.code;
    const code = normalizeInviteCode(rawCode ?? "");
    if (!groupId || code.length < 6) {
        throw new https_1.HttpsError("invalid-argument", "groupId와 code가 필요합니다.");
    }
    const allowed = await hasGroupPermission(groupId, callerUid, request.auth?.token, "member.manage");
    if (!allowed) {
        throw new https_1.HttpsError("permission-denied", "권한이 없습니다.");
    }
    const db = admin.firestore();
    const groupRef = db.collection("groups").doc(groupId);
    const inviteRef = groupRef.collection("invites").doc(code);
    const inviteCodeRef = db.collection("inviteCodes").doc(code);
    let beforeStatus = "unknown";
    await db.runTransaction(async (tx) => {
        const [groupSnap, inviteSnap, codeSnap] = await Promise.all([
            tx.get(groupRef),
            tx.get(inviteRef),
            tx.get(inviteCodeRef),
        ]);
        if (!groupSnap.exists) {
            throw new https_1.HttpsError("not-found", "그룹을 찾을 수 없습니다.");
        }
        if (!inviteSnap.exists && !codeSnap.exists) {
            throw new https_1.HttpsError("not-found", "초대코드를 찾을 수 없습니다.");
        }
        const inviteData = inviteSnap.data() ?? codeSnap.data() ?? {};
        if (inviteData.groupId !== groupId) {
            throw new https_1.HttpsError("failed-precondition", "해당 그룹의 초대코드가 아닙니다.");
        }
        beforeStatus = typeof inviteData.status === "string" ? inviteData.status : "unknown";
        const update = {
            status: "revoked",
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            revokedAt: admin.firestore.FieldValue.serverTimestamp(),
            revokedBy: callerUid,
        };
        tx.set(inviteRef, update, { merge: true });
        tx.set(inviteCodeRef, update, { merge: true });
        tx.set(groupRef, { updatedAt: admin.firestore.FieldValue.serverTimestamp() }, { merge: true });
    });
    await writeAuditLog({
        groupId,
        actorUid: callerUid,
        action: "invite.revoke",
        targetId: code,
        before: { status: beforeStatus },
        after: { status: "revoked" },
        meta: { source: "callable.revokeInviteCode" },
    });
    return { success: true, code, status: "revoked" };
});
exports.requestJoinWithInviteCode = (0, https_1.onCall)(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const rawCode = request.data?.code;
    const code = normalizeInviteCode(rawCode ?? "");
    if (code.length < 6) {
        throw new https_1.HttpsError("invalid-argument", "유효한 초대코드를 입력해 주세요.");
    }
    const db = admin.firestore();
    const inviteCodeRef = db.collection("inviteCodes").doc(code);
    const authToken = (request.auth?.token ?? {});
    const result = await db.runTransaction(async (tx) => {
        const inviteCodeSnap = await tx.get(inviteCodeRef);
        if (!inviteCodeSnap.exists) {
            throw new https_1.HttpsError("not-found", "유효하지 않은 초대코드입니다.");
        }
        const inviteCodeData = inviteCodeSnap.data() ?? {};
        const groupId = inviteCodeData.groupId;
        if (typeof groupId !== "string" || groupId.trim().length === 0) {
            throw new https_1.HttpsError("failed-precondition", "초대코드 상태가 올바르지 않습니다.");
        }
        const groupRef = db.collection("groups").doc(groupId);
        const inviteRef = groupRef.collection("invites").doc(code);
        const memberRef = groupRef.collection("members").doc(callerUid);
        const profileRef = db.collection("users").doc(callerUid);
        const membershipRef = profileRef.collection("memberships").doc(groupId);
        const [groupSnap, inviteSnap, memberSnap, profileSnap] = await Promise.all([
            tx.get(groupRef),
            tx.get(inviteRef),
            tx.get(memberRef),
            tx.get(profileRef),
        ]);
        if (!groupSnap.exists) {
            throw new https_1.HttpsError("not-found", "그룹을 찾을 수 없습니다.");
        }
        const groupData = groupSnap.data() ?? {};
        const groupName = typeof groupData.name === "string" ? groupData.name : groupId;
        const inviteData = inviteSnap.data() ?? inviteCodeData;
        const status = inviteData.status;
        if (status !== "active") {
            throw new https_1.HttpsError("failed-precondition", "사용할 수 없는 초대코드입니다.");
        }
        const expiresAt = inviteData.expiresAt;
        if (expiresAt instanceof admin.firestore.Timestamp && expiresAt.toMillis() <= Date.now()) {
            throw new https_1.HttpsError("failed-precondition", "만료된 초대코드입니다.");
        }
        const maxUses = typeof inviteData.maxUses === "number" ? inviteData.maxUses : 0;
        const useCount = typeof inviteData.useCount === "number" ? inviteData.useCount : 0;
        if (maxUses > 0 && useCount >= maxUses) {
            throw new https_1.HttpsError("failed-precondition", "사용 횟수를 초과한 초대코드입니다.");
        }
        const existingMemberData = memberSnap.data() ?? {};
        const existingMemberStatus = typeof existingMemberData.status === "string" ?
            existingMemberData.status :
            null;
        if (existingMemberStatus === "active") {
            return { status: "already_active", groupId, groupName };
        }
        const wasPending = existingMemberStatus === "pending";
        const shouldConsumeInvite = !wasPending;
        const needsMemberCountIncrement = existingMemberStatus !== "active";
        const limits = groupData.limits;
        const memberMax = limits && typeof limits === "object" && typeof limits.memberMax === "number" ?
            limits.memberMax :
            null;
        const currentMemberCount = typeof groupData.memberCount === "number" ?
            groupData.memberCount :
            0;
        if (memberMax !== null && needsMemberCountIncrement && currentMemberCount >= memberMax) {
            throw new https_1.HttpsError("failed-precondition", `멤버 정원(${memberMax}명)을 초과해 가입할 수 없습니다.`);
        }
        const profileData = profileSnap.data() ?? {};
        const displayNameCandidates = [
            profileData.displayName,
            profileData.nickname,
            authToken.name,
        ];
        let displayName = `user_${callerUid.slice(0, 6)}`;
        for (const candidate of displayNameCandidates) {
            if (typeof candidate === "string" && candidate.trim().length > 0) {
                displayName = candidate.trim();
                break;
            }
        }
        const photoUrlCandidate = profileData.photoUrl ?? authToken.picture;
        const photoUrl = typeof photoUrlCandidate === "string" && photoUrlCandidate.trim().length > 0 ?
            photoUrlCandidate.trim() :
            null;
        const nextUseCount = shouldConsumeInvite ? useCount + 1 : useCount;
        const nextStatus = maxUses > 0 && nextUseCount >= maxUses ? "exhausted" : "active";
        const now = admin.firestore.FieldValue.serverTimestamp();
        tx.set(memberRef, {
            uid: callerUid,
            status: "active",
            role: "member",
            permissions: [],
            displayName,
            photoUrl,
            joinedAt: now,
            approvedAt: now,
            updatedAt: now,
            inviteCode: code,
        }, { merge: true });
        tx.set(membershipRef, {
            groupId,
            status: "active",
            joinedAt: now,
            role: "member",
            permissions: [],
            updatedAt: now,
        }, { merge: true });
        if (needsMemberCountIncrement) {
            tx.set(groupRef, {
                memberCount: admin.firestore.FieldValue.increment(1),
                updatedAt: now,
            }, { merge: true });
        }
        if (shouldConsumeInvite) {
            tx.set(inviteRef, {
                code,
                groupId,
                status: nextStatus,
                maxUses,
                useCount: admin.firestore.FieldValue.increment(1),
                lastUsedAt: now,
                updatedAt: now,
            }, { merge: true });
            tx.set(inviteCodeRef, {
                status: nextStatus,
                maxUses,
                useCount: admin.firestore.FieldValue.increment(1),
                lastUsedAt: now,
                updatedAt: now,
            }, { merge: true });
        }
        return { status: "joined", groupId, groupName };
    });
    if (result.status === "joined") {
        try {
            await upsertGroupClaims(callerUid, result.groupId, "member", []);
        }
        catch (error) {
            firebase_functions_1.logger.warn("requestJoinWithInviteCode claims update failed", {
                groupId: result.groupId,
                callerUid,
                error,
            });
        }
        await writeAuditLog({
            groupId: result.groupId,
            actorUid: callerUid,
            action: "member.joinByInvite",
            targetUid: callerUid,
            targetId: result.groupId,
            after: { status: "active", inviteCode: code },
            meta: { source: "callable.requestJoinWithInviteCode" },
        });
    }
    return { success: true, ...result };
});
exports.approveMember = (0, https_1.onCall)(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const groupId = request.data?.groupId;
    const userId = request.data?.userId;
    if (!groupId || !userId) {
        throw new https_1.HttpsError("invalid-argument", "groupId와 userId가 필요합니다.");
    }
    const db = admin.firestore();
    const allowed = await hasGroupPermission(groupId, callerUid, request.auth?.token, "member.manage");
    if (!allowed) {
        throw new https_1.HttpsError("permission-denied", "권한이 없습니다.");
    }
    const groupRef = db.collection("groups").doc(groupId);
    const memberRef = groupRef.collection("members").doc(userId);
    const membershipRef = db.collection("users").doc(userId).collection("memberships").doc(groupId);
    let beforeTarget = null;
    let memberCountIncremented = false;
    const role = "member";
    const permissions = [];
    await db.runTransaction(async (tx) => {
        const [groupSnap, memberSnap] = await Promise.all([
            tx.get(groupRef),
            tx.get(memberRef),
        ]);
        if (!groupSnap.exists) {
            throw new https_1.HttpsError("not-found", "그룹을 찾을 수 없습니다.");
        }
        const groupData = groupSnap.data() ?? {};
        const limits = groupData.limits;
        const memberMax = limits && typeof limits === "object" && typeof limits.memberMax === "number" ?
            limits.memberMax :
            null;
        const currentMemberCount = typeof groupData.memberCount === "number" ?
            groupData.memberCount :
            0;
        beforeTarget = memberSnap.data() ?? null;
        const alreadyActive = beforeTarget?.status === "active";
        if (!alreadyActive && memberMax !== null && currentMemberCount >= memberMax) {
            throw new https_1.HttpsError("failed-precondition", `멤버 정원(${memberMax}명)을 초과해 승인할 수 없습니다.`);
        }
        tx.set(memberRef, {
            status: "active",
            role,
            permissions,
            approvedAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        tx.set(membershipRef, {
            groupId,
            joinedAt: admin.firestore.FieldValue.serverTimestamp(),
            status: "active",
            role,
            permissions,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        if (!alreadyActive) {
            tx.set(groupRef, {
                memberCount: admin.firestore.FieldValue.increment(1),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
            memberCountIncremented = true;
        }
    });
    let claimsUpdated = false;
    try {
        await upsertGroupClaims(userId, groupId, role, permissions);
        claimsUpdated = true;
    }
    catch (error) {
        firebase_functions_1.logger.error("approveMember claims update failed", {
            groupId,
            userId,
            error,
        });
    }
    await writeAuditLog({
        groupId,
        actorUid: callerUid,
        action: "member.approve",
        targetUid: userId,
        targetId: groupId,
        before: beforeTarget ? {
            status: beforeTarget["status"] ?? null,
            role: beforeTarget["role"] ?? null,
            permissions: compactPermissions(beforeTarget["permissions"]),
        } : null,
        after: { status: "active", role, permissions },
        meta: { source: "callable.approveMember", claimsUpdated, memberCountIncremented },
    });
    return { success: true };
});
exports.setRoleAndClaims = (0, https_1.onCall)(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const groupId = request.data?.groupId;
    const userId = request.data?.userId;
    const role = request.data?.role;
    const rawPermissions = request.data?.permissions;
    if (!groupId || !userId || !role) {
        throw new https_1.HttpsError("invalid-argument", "groupId, userId, role이 필요합니다.");
    }
    if (!["member", "admin", "treasurer"].includes(role)) {
        throw new https_1.HttpsError("invalid-argument", "role은 member/admin/treasurer만 허용됩니다. 모임장 위임은 별도 기능을 사용해 주세요.");
    }
    const allowed = await hasGroupPermission(groupId, callerUid, request.auth?.token, "member.manage");
    if (!allowed) {
        throw new https_1.HttpsError("permission-denied", "권한이 없습니다.");
    }
    const permissions = compactPermissions(rawPermissions);
    const db = admin.firestore();
    const targetRef = db.collection("groups").doc(groupId).collection("members").doc(userId);
    const beforeTarget = (await targetRef.get()).data() ?? null;
    await targetRef.set({
        role,
        permissions,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    await db.collection("users").doc(userId).collection("memberships").doc(groupId).set({
        groupId,
        role,
        status: "active",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    const userRecord = await admin.auth().getUser(userId);
    const existingClaims = (userRecord.customClaims ?? {});
    const existingMoyeora = (existingClaims.moyeora ?? {});
    const existingGroups = (existingMoyeora.groups ?? {});
    existingGroups[groupId] = { role, perms: permissions };
    await admin.auth().setCustomUserClaims(userId, {
        ...existingClaims,
        moyeora: {
            ...existingMoyeora,
            groups: existingGroups,
        },
    });
    await writeAuditLog({
        groupId,
        actorUid: callerUid,
        action: "role.update",
        targetUid: userId,
        targetId: groupId,
        before: beforeTarget ? {
            role: beforeTarget.role ?? null,
            permissions: compactPermissions(beforeTarget.permissions),
        } : null,
        after: { role, permissions },
        meta: { source: "callable.setRoleAndClaims", claimsUpdated: true },
    });
    return { success: true, role, permissionsCount: permissions.length };
});
exports.delegateGroupOwner = (0, https_1.onCall)(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const groupId = request.data?.groupId;
    const newOwnerUid = request.data?.newOwnerUid;
    if (!groupId || !newOwnerUid) {
        throw new https_1.HttpsError("invalid-argument", "groupId, newOwnerUid가 필요합니다.");
    }
    if (newOwnerUid === callerUid) {
        throw new https_1.HttpsError("failed-precondition", "자기 자신에게 위임할 수 없습니다.");
    }
    const db = admin.firestore();
    const groupRef = db.collection("groups").doc(groupId);
    const callerMemberRef = groupRef.collection("members").doc(callerUid);
    const newOwnerMemberRef = groupRef.collection("members").doc(newOwnerUid);
    const callerMembershipRef = db.collection("users").doc(callerUid).collection("memberships").doc(groupId);
    const newOwnerMembershipRef = db.collection("users").doc(newOwnerUid).collection("memberships").doc(groupId);
    let beforeOwnerId = null;
    let beforeTargetRole = null;
    await db.runTransaction(async (tx) => {
        const [groupSnap, callerMemberSnap, newOwnerMemberSnap] = await Promise.all([
            tx.get(groupRef),
            tx.get(callerMemberRef),
            tx.get(newOwnerMemberRef),
        ]);
        if (!groupSnap.exists) {
            throw new https_1.HttpsError("not-found", "그룹을 찾을 수 없습니다.");
        }
        const groupData = groupSnap.data() ?? {};
        beforeOwnerId = typeof groupData.ownerId === "string" ? groupData.ownerId : null;
        if (beforeOwnerId !== callerUid) {
            throw new https_1.HttpsError("permission-denied", "현재 모임장만 위임할 수 있습니다.");
        }
        const callerMember = callerMemberSnap.data() ?? {};
        if (callerMember.status !== "active" || callerMember.role !== "owner") {
            throw new https_1.HttpsError("permission-denied", "현재 모임장 권한이 확인되지 않았습니다.");
        }
        if (!newOwnerMemberSnap.exists) {
            throw new https_1.HttpsError("not-found", "위임 대상 멤버를 찾을 수 없습니다.");
        }
        const newOwnerMember = newOwnerMemberSnap.data() ?? {};
        if (newOwnerMember.status !== "active") {
            throw new https_1.HttpsError("failed-precondition", "활성 멤버에게만 위임할 수 있습니다.");
        }
        beforeTargetRole = typeof newOwnerMember.role === "string" ? newOwnerMember.role : null;
        const now = admin.firestore.FieldValue.serverTimestamp();
        tx.set(callerMemberRef, {
            role: "admin",
            permissions: ADMIN_PERMISSIONS,
            updatedAt: now,
        }, { merge: true });
        tx.set(newOwnerMemberRef, {
            role: "owner",
            permissions: OWNER_PERMISSIONS,
            updatedAt: now,
        }, { merge: true });
        tx.set(callerMembershipRef, {
            groupId,
            role: "admin",
            status: "active",
            updatedAt: now,
        }, { merge: true });
        tx.set(newOwnerMembershipRef, {
            groupId,
            role: "owner",
            status: "active",
            updatedAt: now,
        }, { merge: true });
        tx.set(groupRef, {
            ownerId: newOwnerUid,
            updatedAt: now,
        }, { merge: true });
    });
    let callerClaimsUpdated = false;
    let newOwnerClaimsUpdated = false;
    try {
        await upsertGroupClaims(callerUid, groupId, "admin", ADMIN_PERMISSIONS);
        callerClaimsUpdated = true;
    }
    catch (error) {
        firebase_functions_1.logger.error("delegateGroupOwner caller claims update failed", {
            groupId,
            callerUid,
            error,
        });
    }
    try {
        await upsertGroupClaims(newOwnerUid, groupId, "owner", OWNER_PERMISSIONS);
        newOwnerClaimsUpdated = true;
    }
    catch (error) {
        firebase_functions_1.logger.error("delegateGroupOwner target claims update failed", {
            groupId,
            newOwnerUid,
            error,
        });
    }
    await writeAuditLog({
        groupId,
        actorUid: callerUid,
        action: "owner.delegate",
        targetUid: newOwnerUid,
        targetId: groupId,
        before: {
            ownerUid: beforeOwnerId,
            targetRole: beforeTargetRole,
        },
        after: {
            ownerUid: newOwnerUid,
            callerRole: "admin",
            targetRole: "owner",
        },
        meta: {
            source: "callable.delegateGroupOwner",
            callerClaimsUpdated,
            newOwnerClaimsUpdated,
        },
    });
    return {
        success: true,
        groupId,
        ownerUid: newOwnerUid,
        callerClaimsUpdated,
        newOwnerClaimsUpdated,
    };
});
exports.deleteGroup = (0, https_1.onCall)({ timeoutSeconds: 540, memory: "1GiB" }, async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const groupId = request.data?.groupId;
    if (!groupId) {
        throw new https_1.HttpsError("invalid-argument", "groupId가 필요합니다.");
    }
    const db = admin.firestore();
    const groupRef = db.collection("groups").doc(groupId);
    const groupSnap = await groupRef.get();
    if (!groupSnap.exists) {
        throw new https_1.HttpsError("not-found", "그룹을 찾을 수 없습니다.");
    }
    const groupData = groupSnap.data() ?? {};
    const ownerId = typeof groupData.ownerId === "string" ? groupData.ownerId : null;
    const callerMemberSnap = await groupRef.collection("members").doc(callerUid).get();
    const callerMemberData = callerMemberSnap.data() ?? {};
    const callerIsOwnerRole = callerMemberData.status === "active" &&
        callerMemberData.role === "owner";
    if (ownerId !== callerUid && !callerIsOwnerRole) {
        throw new https_1.HttpsError("permission-denied", "모임장만 모임을 삭제할 수 있습니다.");
    }
    const [membersSnap, membershipSnap, inviteCodesSnap] = await Promise.all([
        groupRef.collection("members").get(),
        db.collectionGroup("memberships").where("groupId", "==", groupId).get(),
        db.collection("inviteCodes").where("groupId", "==", groupId).get(),
    ]);
    const memberUids = new Set();
    for (const memberDoc of membersSnap.docs) {
        memberUids.add(memberDoc.id);
    }
    const membershipRefs = new Map();
    for (const membershipDoc of membershipSnap.docs) {
        const parentUserRef = membershipDoc.ref.parent.parent;
        if (parentUserRef) {
            memberUids.add(parentUserRef.id);
        }
        membershipRefs.set(membershipDoc.ref.path, membershipDoc.ref);
    }
    for (const uid of memberUids) {
        const ref = db.collection("users").doc(uid).collection("memberships").doc(groupId);
        membershipRefs.set(ref.path, ref);
    }
    try {
        await Promise.all([
            ...inviteCodesSnap.docs.map((doc) => doc.ref.delete()),
            ...[...membershipRefs.values()].map((ref) => ref.delete()),
        ]);
        await db.recursiveDelete(groupRef);
    }
    catch (error) {
        firebase_functions_1.logger.error("deleteGroup recursive delete failed", {
            groupId,
            callerUid,
            error,
        });
        throw new https_1.HttpsError("internal", "모임 삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.");
    }
    let claimsCleared = 0;
    for (const uid of memberUids) {
        const cleared = await removeGroupClaims(uid, groupId);
        if (cleared) {
            claimsCleared += 1;
        }
    }
    firebase_functions_1.logger.info("group deleted", {
        groupId,
        actorUid: callerUid,
        membersCount: memberUids.size,
        membershipsDeleted: membershipRefs.size,
        inviteCodesDeleted: inviteCodesSnap.size,
        claimsCleared,
    });
    return {
        success: true,
        groupId,
        membersCount: memberUids.size,
        membershipsDeleted: membershipRefs.size,
        inviteCodesDeleted: inviteCodesSnap.size,
        claimsCleared,
    };
});
exports.deleteEvent = (0, https_1.onCall)(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const groupId = request.data?.groupId;
    const eventId = request.data?.eventId;
    if (!groupId || !eventId) {
        throw new https_1.HttpsError("invalid-argument", "groupId와 eventId가 필요합니다.");
    }
    const db = admin.firestore();
    const groupRef = db.collection("groups").doc(groupId);
    const memberRef = groupRef.collection("members").doc(callerUid);
    const eventRef = groupRef.collection("events").doc(eventId);
    const [memberSnap, eventSnap] = await Promise.all([
        memberRef.get(),
        eventRef.get(),
    ]);
    const memberData = memberSnap.data();
    if (!memberSnap.exists || !isActiveMemberData(memberData)) {
        throw new https_1.HttpsError("permission-denied", "권한이 없습니다.");
    }
    if (!eventSnap.exists) {
        throw new https_1.HttpsError("not-found", "일정을 찾을 수 없습니다.");
    }
    const eventData = eventSnap.data() ?? {};
    const createdBy = typeof eventData.createdBy === "string" ? eventData.createdBy : null;
    const canDelete = canManageMembersOrEvents(memberData) || createdBy === callerUid;
    if (!canDelete) {
        throw new https_1.HttpsError("permission-denied", "권한이 없습니다.");
    }
    let cancellationNotifiedMembers = 0;
    if (isAutomationFeatureEnabled("ENABLE_EVENT_CANCEL_ALERT")) {
        try {
            const [groupSnap, goingResponsesSnap] = await Promise.all([
                groupRef.get(),
                eventRef.collection("responses").where("response", "==", "going").get(),
            ]);
            const groupName = groupSnap.data()?.name ?? "Moyeora";
            const eventTitle = typeof eventData.title === "string" ? eventData.title : "일정";
            const targetUids = [...new Set(goingResponsesSnap.docs.map((doc) => doc.id))];
            const notified = await Promise.all(targetUids.map(async (uid) => {
                const settings = await getNotificationSettings(groupId, uid);
                if (!settings.eventReminderEnabled)
                    return 0;
                const tokens = await getMemberTokens(groupId, uid);
                if (tokens.length == 0)
                    return 0;
                await sendMulticastNotification(tokens, {
                    title: `${groupName} 일정 취소`,
                    body: `${eventTitle} 일정이 취소되었습니다.`,
                    data: { type: "event", groupId, eventId, canceled: "true" },
                });
                return 1;
            }));
            cancellationNotifiedMembers = notified.filter((value) => value === 1).length;
        }
        catch (error) {
            firebase_functions_1.logger.warn("deleteEvent cancellation notify failed", {
                groupId,
                eventId,
                error,
            });
        }
    }
    let deletedSubDocs = 0;
    try {
        deletedSubDocs = await deleteDocWithSubcollections(eventRef, [
            "responses",
            "attendances",
            "comments",
        ]);
    }
    catch (error) {
        firebase_functions_1.logger.error("deleteEvent failed", {
            groupId,
            eventId,
            callerUid,
            error,
        });
        throw new https_1.HttpsError("internal", "일정 삭제 처리 중 오류가 발생했습니다.");
    }
    await writeAuditLog({
        groupId,
        actorUid: callerUid,
        action: "event.delete",
        targetId: eventId,
        before: {
            title: typeof eventData.title === "string" ? eventData.title : null,
            startAt: eventData.startAt ?? null,
            createdBy,
        },
        after: { deleted: true },
        meta: {
            source: "callable.deleteEvent",
            deletedSubDocs,
            cancellationNotifiedMembers,
        },
    });
    return { success: true, eventId };
});
exports.deleteNotice = (0, https_1.onCall)(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const groupId = request.data?.groupId;
    const noticeId = request.data?.noticeId;
    if (!groupId || !noticeId) {
        throw new https_1.HttpsError("invalid-argument", "groupId와 noticeId가 필요합니다.");
    }
    const db = admin.firestore();
    const groupRef = db.collection("groups").doc(groupId);
    const memberRef = groupRef.collection("members").doc(callerUid);
    const noticeRef = groupRef.collection("notices").doc(noticeId);
    const [memberSnap, noticeSnap] = await Promise.all([
        memberRef.get(),
        noticeRef.get(),
    ]);
    const memberData = memberSnap.data();
    if (!memberSnap.exists || !isActiveMemberData(memberData)) {
        throw new https_1.HttpsError("permission-denied", "권한이 없습니다.");
    }
    if (!noticeSnap.exists) {
        throw new https_1.HttpsError("not-found", "공지를 찾을 수 없습니다.");
    }
    const noticeData = noticeSnap.data() ?? {};
    const createdBy = typeof noticeData.createdBy === "string" ? noticeData.createdBy : null;
    const canDelete = canManageMembersOrEvents(memberData) || createdBy === callerUid;
    if (!canDelete) {
        throw new https_1.HttpsError("permission-denied", "권한이 없습니다.");
    }
    let deletedSubDocs = 0;
    try {
        deletedSubDocs = await deleteDocWithSubcollections(noticeRef, ["reads"]);
    }
    catch (error) {
        firebase_functions_1.logger.error("deleteNotice failed", {
            groupId,
            noticeId,
            callerUid,
            error,
        });
        throw new https_1.HttpsError("internal", "공지 삭제 처리 중 오류가 발생했습니다.");
    }
    await writeAuditLog({
        groupId,
        actorUid: callerUid,
        action: "notice.delete",
        targetId: noticeId,
        before: {
            title: typeof noticeData.title === "string" ? noticeData.title : null,
            pinned: noticeData.pinned === true,
            createdBy,
        },
        after: { deleted: true },
        meta: {
            source: "callable.deleteNotice",
            deletedSubDocs,
        },
    });
    return { success: true, noticeId };
});
exports.deletePoll = (0, https_1.onCall)(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const groupId = request.data?.groupId;
    const pollId = request.data?.pollId;
    if (!groupId || !pollId) {
        throw new https_1.HttpsError("invalid-argument", "groupId와 pollId가 필요합니다.");
    }
    const db = admin.firestore();
    const groupRef = db.collection("groups").doc(groupId);
    const memberRef = groupRef.collection("members").doc(callerUid);
    const pollRef = groupRef.collection("polls").doc(pollId);
    const [memberSnap, pollSnap] = await Promise.all([
        memberRef.get(),
        pollRef.get(),
    ]);
    const memberData = memberSnap.data();
    if (!memberSnap.exists || !isActiveMemberData(memberData)) {
        throw new https_1.HttpsError("permission-denied", "권한이 없습니다.");
    }
    if (!pollSnap.exists) {
        throw new https_1.HttpsError("not-found", "투표를 찾을 수 없습니다.");
    }
    const pollData = pollSnap.data() ?? {};
    const createdBy = typeof pollData.createdBy === "string" ? pollData.createdBy : null;
    const canDelete = canManageMembersOrEvents(memberData) || createdBy === callerUid;
    if (!canDelete) {
        throw new https_1.HttpsError("permission-denied", "권한이 없습니다.");
    }
    let deletedSubDocs = 0;
    try {
        deletedSubDocs = await deleteDocWithSubcollections(pollRef, ["votes"]);
    }
    catch (error) {
        firebase_functions_1.logger.error("deletePoll failed", {
            groupId,
            pollId,
            callerUid,
            error,
        });
        throw new https_1.HttpsError("internal", "투표 삭제 처리 중 오류가 발생했습니다.");
    }
    await writeAuditLog({
        groupId,
        actorUid: callerUid,
        action: "poll.delete",
        targetId: pollId,
        before: {
            title: typeof pollData.title === "string" ? pollData.title : null,
            status: typeof pollData.status === "string" ? pollData.status : null,
            createdBy,
        },
        after: { deleted: true },
        meta: {
            source: "callable.deletePoll",
            deletedSubDocs,
        },
    });
    return { success: true, pollId };
});
exports.kickMember = (0, https_1.onCall)(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const groupId = request.data?.groupId;
    const userId = request.data?.userId;
    if (!groupId || !userId) {
        throw new https_1.HttpsError("invalid-argument", "groupId와 userId가 필요합니다.");
    }
    if (callerUid === userId) {
        throw new https_1.HttpsError("failed-precondition", "자기 자신은 강퇴할 수 없습니다.");
    }
    const db = admin.firestore();
    const groupRef = db.collection("groups").doc(groupId);
    const callerMemberRef = groupRef.collection("members").doc(callerUid);
    const targetMemberRef = groupRef.collection("members").doc(userId);
    const targetMembershipRef = db.collection("users").doc(userId).collection("memberships").doc(groupId);
    let beforeTargetRole = null;
    let beforeTargetStatus = null;
    let nextMemberCount = null;
    await db.runTransaction(async (tx) => {
        const [groupSnap, callerMemberSnap, targetMemberSnap] = await Promise.all([
            tx.get(groupRef),
            tx.get(callerMemberRef),
            tx.get(targetMemberRef),
        ]);
        if (!groupSnap.exists) {
            throw new https_1.HttpsError("not-found", "그룹을 찾을 수 없습니다.");
        }
        const callerMemberData = callerMemberSnap.data();
        if (!callerMemberSnap.exists || !isActiveMemberData(callerMemberData)) {
            throw new https_1.HttpsError("permission-denied", "권한이 없습니다.");
        }
        if (!hasPermissionInMemberData(callerMemberData, "member.manage")) {
            throw new https_1.HttpsError("permission-denied", "권한이 없습니다.");
        }
        if (!targetMemberSnap.exists) {
            throw new https_1.HttpsError("not-found", "대상 멤버를 찾을 수 없습니다.");
        }
        const targetMemberData = targetMemberSnap.data() ?? {};
        if (targetMemberData.status !== "active") {
            throw new https_1.HttpsError("failed-precondition", "활성 상태 멤버만 강퇴할 수 있습니다.");
        }
        const callerRole = typeof callerMemberData.role === "string" ? callerMemberData.role : "member";
        const targetRole = typeof targetMemberData.role === "string" ? targetMemberData.role : "member";
        if (targetRole === "owner") {
            throw new https_1.HttpsError("permission-denied", "모임장은 강퇴할 수 없습니다.");
        }
        if (callerRole !== "owner" && targetRole !== "member") {
            throw new https_1.HttpsError("permission-denied", "모임장만 운영진을 강퇴할 수 있습니다.");
        }
        beforeTargetRole = targetRole;
        beforeTargetStatus = targetMemberData.status;
        const groupData = groupSnap.data() ?? {};
        const currentMemberCount = typeof groupData.memberCount === "number" ? groupData.memberCount : 0;
        nextMemberCount = currentMemberCount > 0 ? currentMemberCount - 1 : 0;
        const now = admin.firestore.FieldValue.serverTimestamp();
        tx.set(targetMemberRef, {
            status: "kicked",
            kickedBy: callerUid,
            kickedAt: now,
            updatedAt: now,
        }, { merge: true });
        tx.set(targetMembershipRef, {
            groupId,
            status: "kicked",
            leftAt: now,
            updatedAt: now,
        }, { merge: true });
        tx.set(groupRef, {
            memberCount: nextMemberCount,
            updatedAt: now,
        }, { merge: true });
    });
    const claimsCleared = await removeGroupClaims(userId, groupId);
    await writeAuditLog({
        groupId,
        actorUid: callerUid,
        action: "member.kick",
        targetUid: userId,
        targetId: groupId,
        before: {
            status: beforeTargetStatus,
            role: beforeTargetRole,
        },
        after: {
            status: "kicked",
            role: beforeTargetRole,
        },
        meta: {
            source: "callable.kickMember",
            claimsCleared,
            memberCount: nextMemberCount,
        },
    });
    return { success: true, userId, claimsCleared };
});
exports.logClientEvent = (0, https_1.onCall)(async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const levelRaw = request.data?.level;
    const level = ["debug", "info", "warn", "error"].includes(levelRaw ?? "") ?
        levelRaw :
        "info";
    const messageRaw = request.data?.message;
    const message = messageRaw?.trim() ?? "";
    if (message.length === 0) {
        throw new https_1.HttpsError("invalid-argument", "message가 필요합니다.");
    }
    const groupIdRaw = request.data?.groupId;
    const groupId = typeof groupIdRaw === "string" && groupIdRaw.trim().length > 0 ? groupIdRaw.trim() : null;
    const stackRaw = request.data?.stack;
    const stack = typeof stackRaw === "string" && stackRaw.trim().length > 0 ? stackRaw : null;
    const contextRaw = request.data?.context;
    const context = contextRaw && typeof contextRaw === "object" ? contextRaw : {};
    const platformRaw = request.data?.platform;
    const platform = typeof platformRaw === "string" ? platformRaw : "unknown";
    if (groupId) {
        const memberSnap = await admin
            .firestore()
            .collection("groups")
            .doc(groupId)
            .collection("members")
            .doc(uid)
            .get();
        const memberData = memberSnap.data() ?? {};
        if (!memberSnap.exists || memberData.status !== "active") {
            throw new https_1.HttpsError("permission-denied", "해당 그룹 로그를 기록할 권한이 없습니다.");
        }
    }
    await admin.firestore().collection("appLogs").add({
        at: admin.firestore.FieldValue.serverTimestamp(),
        uid,
        groupId,
        level,
        message: message.slice(0, 4000),
        stack: stack ? stack.slice(0, 16000) : null,
        context,
        platform,
        source: "client",
    });
    const payload = {
        uid,
        groupId,
        level,
        message: message.slice(0, 1000),
        context,
        stack: stack ? stack.slice(0, 2000) : null,
    };
    if (level === "error") {
        firebase_functions_1.logger.error("client-log", payload);
    }
    else if (level === "warn") {
        firebase_functions_1.logger.warn("client-log", payload);
    }
    else {
        firebase_functions_1.logger.info("client-log", payload);
    }
    return { success: true };
});
async function exchangeKakaoAccessToken(accessToken) {
    const fetchImpl = globalThis.fetch;
    if (!fetchImpl) {
        firebase_functions_1.logger.error("fetch is unavailable in functions runtime");
        throw new https_1.HttpsError("internal", "서버 설정 오류");
    }
    let kakaoMe;
    try {
        const response = await fetchImpl("https://kapi.kakao.com/v2/user/me", {
            method: "GET",
            headers: {
                "Authorization": `Bearer ${accessToken}`,
                "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
            },
        });
        if (!response.ok) {
            firebase_functions_1.logger.warn("Kakao me API failed", { status: response.status });
            throw new https_1.HttpsError("unauthenticated", "카카오 토큰 검증 실패");
        }
        kakaoMe = await response.json();
    }
    catch (error) {
        firebase_functions_1.logger.error("Kakao token exchange failed", error);
        if (error instanceof https_1.HttpsError)
            throw error;
        throw new https_1.HttpsError("unauthenticated", "카카오 인증 실패");
    }
    const kakaoIdRaw = kakaoMe.id;
    if (kakaoIdRaw == null) {
        throw new https_1.HttpsError("unauthenticated", "카카오 사용자 식별 실패");
    }
    const kakaoId = String(kakaoIdRaw);
    const sanitizedId = kakaoId.replace(/[^a-zA-Z0-9_-]/g, "");
    const uid = `kakao:${sanitizedId}`;
    const displayName = kakaoMe.properties?.nickname ??
        kakaoMe.kakao_account?.profile?.nickname ??
        null;
    const profileImageUrl = kakaoMe.kakao_account?.profile?.profile_image_url ?? null;
    try {
        await admin.auth().getUser(uid);
        if (displayName && displayName.trim().length > 0) {
            await admin.auth().updateUser(uid, { displayName });
        }
    }
    catch (error) {
        const authError = error;
        if (authError.code === "auth/user-not-found") {
            await admin.auth().createUser({
                uid,
                displayName: displayName ?? undefined,
            });
        }
        else {
            firebase_functions_1.logger.error("Firebase user sync failed", error);
            throw new https_1.HttpsError("internal", "사용자 동기화 실패");
        }
    }
    const customToken = await admin.auth().createCustomToken(uid, {
        provider: "kakao",
        kakaoId,
    });
    return {
        customToken,
        kakaoId,
        kakaoProfile: {
            nickname: displayName,
            profileImageUrl,
        },
    };
}
async function exchangeKakaoAuthCodeToAccessToken(code, redirectUri) {
    const fetchImpl = globalThis.fetch;
    if (!fetchImpl) {
        firebase_functions_1.logger.error("fetch is unavailable in functions runtime");
        throw new https_1.HttpsError("internal", "서버 설정 오류");
    }
    const restApiKey = kakaoRestApiKey.value();
    if (!restApiKey || restApiKey.trim().length === 0) {
        firebase_functions_1.logger.error("KAKAO_REST_API_KEY is missing");
        throw new https_1.HttpsError("failed-precondition", "카카오 서버 설정이 필요합니다.");
    }
    const clientSecret = process.env.KAKAO_CLIENT_SECRET;
    const body = new URLSearchParams({
        grant_type: "authorization_code",
        client_id: restApiKey.trim(),
        redirect_uri: redirectUri,
        code,
    });
    if (clientSecret && clientSecret.trim().length > 0) {
        body.set("client_secret", clientSecret.trim());
    }
    let tokenResponse;
    try {
        tokenResponse = await fetchImpl("https://kauth.kakao.com/oauth/token", {
            method: "POST",
            headers: {
                "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
            },
            body: body.toString(),
        });
    }
    catch (error) {
        firebase_functions_1.logger.error("Kakao auth code exchange failed", error);
        throw new https_1.HttpsError("internal", "카카오 토큰 교환에 실패했습니다.");
    }
    if (!tokenResponse.ok) {
        const failureBody = await tokenResponse.text();
        firebase_functions_1.logger.warn("Kakao token endpoint failed", {
            status: tokenResponse.status,
            body: failureBody,
        });
        throw new https_1.HttpsError("unauthenticated", "카카오 인증 코드가 유효하지 않습니다.");
    }
    const tokenData = await tokenResponse.json();
    const accessToken = tokenData.access_token;
    if (!accessToken || accessToken.trim().length === 0) {
        throw new https_1.HttpsError("internal", "카카오 액세스 토큰 응답이 비어 있습니다.");
    }
    return accessToken;
}
exports.authExchangeKakao = (0, https_1.onCall)({ secrets: [kakaoRestApiKey] }, async (request) => {
    const accessToken = request.data?.accessToken;
    if (!accessToken || accessToken.trim().length === 0) {
        throw new https_1.HttpsError("invalid-argument", "accessToken이 필요합니다.");
    }
    return exchangeKakaoAccessToken(accessToken.trim());
});
exports.authExchangeKakaoCode = (0, https_1.onCall)({ secrets: [kakaoRestApiKey] }, async (request) => {
    const code = request.data?.code;
    const redirectUri = request.data?.redirectUri;
    if (!code || code.trim().length === 0 || !redirectUri || redirectUri.trim().length === 0) {
        throw new https_1.HttpsError("invalid-argument", "code와 redirectUri가 필요합니다.");
    }
    const accessToken = await exchangeKakaoAuthCodeToAccessToken(code.trim(), redirectUri.trim());
    return exchangeKakaoAccessToken(accessToken);
});
exports.seedDemoData = (0, https_1.onCall)(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const groupId = request.data?.groupId;
    if (!groupId) {
        throw new https_1.HttpsError("invalid-argument", "groupId가 필요합니다.");
    }
    if (groupId !== "g_demo") {
        throw new https_1.HttpsError("permission-denied", "g_demo 그룹에서만 실행할 수 있습니다.");
    }
    if (process.env.FUNCTIONS_EMULATOR !== "true" &&
        process.env.ALLOW_DEMO_SEED !== "true") {
        throw new https_1.HttpsError("failed-precondition", "운영 환경에서 데모 시딩이 차단되어 있습니다.");
    }
    const allowed = await hasGroupPermission(groupId, callerUid, request.auth?.token, "member.manage");
    if (!allowed) {
        throw new https_1.HttpsError("permission-denied", "운영진 권한이 필요합니다.");
    }
    const eventsRef = admin
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("events");
    const noticesRef = admin
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("notices");
    const existing = await eventsRef.limit(1).get();
    if (!existing.empty) {
        return { success: true, seeded: false, reason: "already-exists" };
    }
    const now = Date.now();
    const event1Ref = eventsRef.doc();
    const event2Ref = eventsRef.doc();
    const event3Ref = eventsRef.doc();
    await event1Ref.set({
        title: "주말 정기 모임",
        startAt: admin.firestore.Timestamp.fromMillis(now + 3 * 24 * 60 * 60 * 1000),
        isDeleted: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await event2Ref.set({
        title: "운영진 회의",
        startAt: admin.firestore.Timestamp.fromMillis(now + 24 * 60 * 60 * 1000),
        isDeleted: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await event3Ref.set({
        title: "친선 경기",
        startAt: admin.firestore.Timestamp.fromMillis(now - 2 * 24 * 60 * 60 * 1000),
        isDeleted: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await event1Ref.collection("responses").doc(callerUid).set({
        response: "going",
        respondedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await noticesRef.doc().set({
        title: "3월 회비 안내",
        body: "이번 달 회비 입금 일정을 확인해 주세요.",
        pinned: true,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await noticesRef.doc().set({
        title: "이번 주 일정 변경",
        body: "이번 주 훈련 일정을 조정했습니다.",
        pinned: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await noticesRef.doc().set({
        title: "운영 정책 공지",
        body: "운영 정책을 업데이트했습니다.",
        pinned: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { success: true, seeded: true };
});
function nicknameFromMemberData(data) {
    const publicProfile = data.public;
    if (publicProfile && typeof publicProfile === "object") {
        const nickname = publicProfile.nickname;
        if (typeof nickname === "string" && nickname.trim().length > 0) {
            return nickname.trim();
        }
    }
    return null;
}
async function recomputeGroupPeriodStatsCore(groupId, periodKey) {
    const { start, end } = (0, period_1.getPeriodRange)(periodKey);
    const activeMembers = await getActiveMembers(groupId);
    const nicknameByUid = new Map();
    for (const member of activeMembers) {
        const nickname = nicknameFromMemberData(member.data);
        if (nickname) {
            nicknameByUid.set(member.uid, nickname);
        }
    }
    const eventsSnap = await admin
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("events")
        .where("startAt", ">=", admin.firestore.Timestamp.fromDate(start))
        .where("startAt", "<", admin.firestore.Timestamp.fromDate(end))
        .get();
    const attendanceScore = new Map();
    const activityScore = new Map();
    let eventCountThisMonth = 0;
    for (const member of activeMembers) {
        attendanceScore.set(member.uid, 0);
        activityScore.set(member.uid, 0);
    }
    for (const eventDoc of eventsSnap.docs) {
        if (eventDoc.data().isDeleted === true)
            continue;
        eventCountThisMonth += 1;
        const attendances = await eventDoc.ref.collection("attendances").get();
        for (const attendance of attendances.docs) {
            const uid = attendance.id;
            const status = attendance.data().status;
            const point = status === "present" ? 3 : (status === "late" ? 1 : 0);
            attendanceScore.set(uid, (attendanceScore.get(uid) ?? 0) + point);
            activityScore.set(uid, (activityScore.get(uid) ?? 0) + point);
        }
        const responses = await eventDoc.ref.collection("responses").get();
        for (const response of responses.docs) {
            const uid = response.id;
            activityScore.set(uid, (activityScore.get(uid) ?? 0) + 1);
        }
    }
    const attendanceTop = [...attendanceScore.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 10)
        .map(([uid, score]) => ({
        uid,
        score,
        nickname: nicknameByUid.get(uid) ?? uid,
    }));
    const activityTop = [...activityScore.entries()]
        .sort((a, b) => b[1] - a[1])
        .slice(0, 10)
        .map(([uid, score]) => ({
        uid,
        score,
        nickname: nicknameByUid.get(uid) ?? uid,
    }));
    const paymentsSnap = await admin
        .firestore()
        .collection("groups")
        .doc(groupId)
        .collection("feePeriods")
        .doc(periodKey)
        .collection("payments")
        .get();
    const paidUids = new Set(paymentsSnap.docs.map((d) => d.id));
    const unpaidCount = activeMembers.filter((m) => !paidUids.has(m.uid)).length;
    await safeBatchWrite((batch) => {
        const leaderboardRef = admin
            .firestore()
            .collection("groups")
            .doc(groupId)
            .collection("leaderboards")
            .doc(periodKey);
        const statsRef = admin
            .firestore()
            .collection("groups")
            .doc(groupId)
            .collection("stats")
            .doc(periodKey);
        batch.set(leaderboardRef, {
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
            periodKey,
            version: admin.firestore.FieldValue.increment(1),
            attendanceTop,
            activityTop,
        }, { merge: true });
        batch.set(statsRef, {
            periodKey,
            version: admin.firestore.FieldValue.increment(1),
            unpaidCount,
            activeMemberCount: activeMembers.length,
            eventCountThisMonth,
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    });
    return {
        periodKey,
        activeMemberCount: activeMembers.length,
        eventCountThisMonth,
        unpaidCount,
        attendanceTopCount: attendanceTop.length,
        activityTopCount: activityTop.length,
    };
}
exports.recomputeGroupPeriodStats = (0, https_1.onCall)(async (request) => {
    const callerUid = request.auth?.uid;
    if (!callerUid) {
        throw new https_1.HttpsError("unauthenticated", "로그인이 필요합니다.");
    }
    const groupId = request.data?.groupId;
    const periodKey = request.data?.periodKey;
    if (!groupId || !periodKey) {
        throw new https_1.HttpsError("invalid-argument", "groupId와 periodKey가 필요합니다.");
    }
    if (!(0, period_1.isValidPeriodKey)(periodKey)) {
        throw new https_1.HttpsError("invalid-argument", "periodKey 형식은 YYYY-MM 이어야 합니다.");
    }
    const [canManageMembers, canManageFinance, canManageSettings] = await Promise.all([
        hasGroupPermission(groupId, callerUid, request.auth?.token, "member.manage"),
        hasGroupPermission(groupId, callerUid, request.auth?.token, "finance.manage"),
        hasGroupPermission(groupId, callerUid, request.auth?.token, "settings.manage"),
    ]);
    if (!canManageMembers && !canManageFinance && !canManageSettings) {
        throw new https_1.HttpsError("permission-denied", "운영진 권한이 필요합니다.");
    }
    const summary = await recomputeGroupPeriodStatsCore(groupId, periodKey);
    await writeAuditLog({
        groupId,
        actorUid: callerUid,
        action: "stats.recompute",
        targetId: periodKey,
        before: null,
        after: summary,
        meta: { source: "callable.recomputeGroupPeriodStats" },
    });
    return { success: true, ...summary };
});
exports.onNoticeCreatedPush = (0, firestore_1.onDocumentCreated)("groups/{groupId}/notices/{noticeId}", async (event) => {
    const groupId = event.params.groupId;
    const noticeId = event.params.noticeId;
    const notice = event.data?.data();
    if (!notice)
        return;
    const groupDoc = await admin.firestore().collection("groups").doc(groupId).get();
    const groupName = groupDoc.data()?.name ?? "Moyeora";
    const noticeTitle = notice.title ?? "새 공지";
    const activeMembers = await getActiveMembers(groupId);
    for (const member of activeMembers) {
        const settings = await getNotificationSettings(groupId, member.uid);
        if (!settings.noticeEnabled)
            continue;
        const tokens = await getMemberTokens(groupId, member.uid);
        await sendMulticastNotification(tokens, {
            title: groupName,
            body: noticeTitle,
            data: { type: "notice", groupId, noticeId },
        });
    }
});
exports.onSuggestionCreatedGithubIssue = (0, firestore_1.onDocumentCreated)("groups/{groupId}/suggestions/{suggestionId}", async (event) => {
    const suggestion = event.data?.data();
    if (!suggestion)
        return;
    const repo = (process.env.GITHUB_ISSUES_REPO ?? "").trim();
    const token = (process.env.GITHUB_ISSUES_TOKEN ?? "").trim();
    if (!repo || !token) {
        firebase_functions_1.logger.info("onSuggestionCreatedGithubIssue skipped (missing config)", {
            groupId: event.params.groupId,
            suggestionId: event.params.suggestionId,
            hasRepo: repo.length > 0,
            hasToken: token.length > 0,
        });
        return;
    }
    const groupId = event.params.groupId;
    const suggestionId = event.params.suggestionId;
    const groupDoc = await admin.firestore().collection("groups").doc(groupId).get();
    const groupName = groupDoc.data()?.name ?? groupId;
    const titleRaw = typeof suggestion.title === "string" ? suggestion.title.trim() : "";
    const bodyRaw = typeof suggestion.body === "string" ? suggestion.body.trim() : "";
    const isAnonymous = suggestion.isAnonymous === true;
    const createdBy = typeof suggestion.createdBy === "string" ? suggestion.createdBy : "unknown";
    const createdByName = typeof suggestion.createdByName === "string" ? suggestion.createdByName : "";
    const createdAt = toIsoStringIfTimestamp(suggestion.createdAt) ?? new Date().toISOString();
    const displayName = isAnonymous ? "익명 제보자" : (createdByName || createdBy);
    const issueTitle = `[제보][${groupName}] ${titleRaw || "제목 없음"}`.slice(0, 240);
    const labels = parseGithubIssueLabels(process.env.GITHUB_ISSUES_LABELS);
    const issueBody = [
        "## 모임 제보",
        "",
        `- 그룹: ${groupName} (\`${groupId}\`)`,
        `- 제보 ID: \`${suggestionId}\``,
        `- 작성자: ${displayName}`,
        `- 익명 여부: ${isAnonymous ? "예" : "아니오"}`,
        `- 등록 시각(UTC): ${createdAt}`,
        "",
        "## 내용",
        "",
        bodyRaw || "(본문 없음)",
        "",
        "---",
        "",
        "_이 이슈는 moyeora 앱 제보 기능에서 자동 생성되었습니다._",
    ].join("\n");
    try {
        const created = await createGithubIssue({
            repo,
            token,
            title: issueTitle,
            body: issueBody,
            labels,
        });
        await event.data?.ref.set({
            githubIssue: {
                status: "created",
                repo,
                number: created.number,
                url: created.url,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    catch (error) {
        firebase_functions_1.logger.error("onSuggestionCreatedGithubIssue failed", {
            groupId,
            suggestionId,
            error,
        });
        await event.data?.ref.set({
            githubIssue: {
                status: "failed",
                repo,
                error: error instanceof Error ? error.message : String(error),
                failedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
});
exports.onBetaReportCreatedGithubIssue = (0, firestore_1.onDocumentCreated)("beta_reports/{reportId}", async (event) => {
    const report = event.data?.data();
    if (!report)
        return;
    const repo = (process.env.GITHUB_ISSUES_REPO ?? "").trim();
    const token = (process.env.GITHUB_ISSUES_TOKEN ?? "").trim();
    if (!repo || !token) {
        firebase_functions_1.logger.info("onBetaReportCreatedGithubIssue skipped (missing config)", {
            reportId: event.params.reportId,
            hasRepo: repo.length > 0,
            hasToken: token.length > 0,
        });
        return;
    }
    const reportId = event.params.reportId;
    const titleRaw = typeof report.title === "string" ? report.title.trim() : "";
    const bodyRaw = typeof report.body === "string" ? report.body.trim() : "";
    const category = typeof report.category === "string" ? report.category : "other";
    const createdBy = typeof report.createdBy === "string" ? report.createdBy : "unknown";
    const createdByName = typeof report.createdByName === "string" ? report.createdByName : "";
    const createdAt = toIsoStringIfTimestamp(report.createdAt) ?? new Date().toISOString();
    const displayName = createdByName || createdBy;
    const categoryMap = {
        bug: "오류/버그",
        improvement: "기능 개선",
        feature: "신규 기능",
        other: "기타",
    };
    const categoryLabel = categoryMap[category] ?? category;
    const issueTitle = `[베타제보][${categoryLabel}] ${titleRaw || "제목 없음"}`.slice(0, 240);
    const labels = parseGithubIssueLabels(process.env.GITHUB_ISSUES_LABELS)
        .concat(["beta-report"]);
    const issueBody = [
        "## 베타 제보",
        "",
        `- 분류: ${categoryLabel}`,
        `- 제보 ID: \`${reportId}\``,
        `- 작성자: ${displayName}`,
        `- 등록 시각(UTC): ${createdAt}`,
        "",
        "## 내용",
        "",
        bodyRaw || "(본문 없음)",
        "",
        "---",
        "",
        "_이 이슈는 moyeora 앱 베타 제보 기능에서 자동 생성되었습니다._",
    ].join("\n");
    try {
        const created = await createGithubIssue({
            repo,
            token,
            title: issueTitle,
            body: issueBody,
            labels,
        });
        await event.data?.ref.set({
            githubIssue: {
                status: "created",
                repo,
                number: created.number,
                url: created.url,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
    catch (error) {
        firebase_functions_1.logger.error("onBetaReportCreatedGithubIssue failed", {
            reportId,
            error,
        });
        await event.data?.ref.set({
            githubIssue: {
                status: "failed",
                repo,
                error: error instanceof Error ? error.message : String(error),
                failedAt: admin.firestore.FieldValue.serverTimestamp(),
            },
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }
});
exports.d1EventReminderHourly = (0, scheduler_1.onSchedule)("every 30 minutes", async () => {
    if (!isAutomationFeatureEnabled("ENABLE_EVENT_REMINDER")) {
        return;
    }
    const reminderHours = parseReminderHours(process.env.EVENT_REMINDER_HOURS, [24]);
    if (reminderHours.length === 0) {
        return;
    }
    const now = admin.firestore.Timestamp.now();
    const nowMillis = now.toMillis();
    const maxHours = reminderHours[0];
    const upperBound = admin.firestore.Timestamp.fromMillis(nowMillis + (maxHours + 1) * 60 * 60 * 1000);
    const groupsSnap = await admin.firestore().collection("groups").get();
    for (const groupDoc of groupsSnap.docs) {
        const groupId = groupDoc.id;
        const groupName = groupDoc.data()?.name ?? "Moyeora";
        const activeMembers = await getActiveMembers(groupId);
        if (activeMembers.length === 0)
            continue;
        const eventsSnap = await admin
            .firestore()
            .collection("groups")
            .doc(groupId)
            .collection("events")
            .where("startAt", ">", now)
            .where("startAt", "<=", upperBound)
            .get();
        for (const eventDoc of eventsSnap.docs) {
            const eventData = eventDoc.data();
            if (eventData.isDeleted === true)
                continue;
            const startAt = eventData.startAt;
            if (!startAt)
                continue;
            const hoursUntilStart = (startAt.toMillis() - nowMillis) / (60 * 60 * 1000);
            const sentHours = normalizeSentHours(eventData.automationReminderSentHours);
            const pendingHours = reminderHours.filter((hours) => !sentHours.includes(hours) &&
                isWithinReminderWindow(hoursUntilStart, hours, 1));
            if (pendingHours.length === 0)
                continue;
            const nearestHour = pendingHours[pendingHours.length - 1];
            const eventTitle = eventData.title ?? "일정";
            const body = `${eventTitle} · ${nearestHour}시간 전 알림`;
            let sentCount = 0;
            for (const member of activeMembers) {
                const settings = await getNotificationSettings(groupId, member.uid);
                if (!settings.eventReminderEnabled)
                    continue;
                const tokens = await getMemberTokens(groupId, member.uid);
                if (tokens.length === 0)
                    continue;
                await sendMulticastNotification(tokens, {
                    title: `${groupName} 일정 리마인더`,
                    body,
                    data: {
                        type: "event",
                        groupId,
                        eventId: eventDoc.id,
                        reminderType: "event.start",
                        hoursBefore: String(nearestHour),
                    },
                });
                sentCount += 1;
            }
            if (sentCount > 0) {
                await eventDoc.ref.set({
                    automationReminderSentHours: admin.firestore.FieldValue.arrayUnion(...pendingHours),
                    automationReminderUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
        }
    }
});
exports.noResponseReminderAt13 = (0, scheduler_1.onSchedule)("every 30 minutes", async () => {
    if (!isAutomationFeatureEnabled("ENABLE_NO_RESPONSE_REMINDER")) {
        return;
    }
    const reminderHours = parseReminderHours(process.env.NO_RESPONSE_REMINDER_HOURS, [24, 6]);
    if (reminderHours.length === 0) {
        return;
    }
    const now = admin.firestore.Timestamp.now();
    const nowMillis = now.toMillis();
    const maxHours = reminderHours[0];
    const upperBound = admin.firestore.Timestamp.fromMillis(nowMillis + (maxHours + 1) * 60 * 60 * 1000);
    const groupsSnap = await admin.firestore().collection("groups").get();
    for (const groupDoc of groupsSnap.docs) {
        const groupId = groupDoc.id;
        const groupName = groupDoc.data()?.name ?? "Moyeora";
        const eventsSnap = await admin
            .firestore()
            .collection("groups")
            .doc(groupId)
            .collection("events")
            .where("startAt", ">", now)
            .where("startAt", "<=", upperBound)
            .get();
        for (const eventDoc of eventsSnap.docs) {
            const eventData = eventDoc.data();
            if (eventData.isDeleted === true)
                continue;
            const startAt = eventData.startAt;
            if (!startAt)
                continue;
            const responseCloseHours = Number(eventData.responseCloseHours ?? 24);
            const closeMillis = startAt.toMillis() - responseCloseHours * 60 * 60 * 1000;
            if (nowMillis >= closeMillis)
                continue;
            const hoursUntilStart = (startAt.toMillis() - nowMillis) / (60 * 60 * 1000);
            const sentHours = normalizeSentHours(eventData.automationNoResponseReminderSentHours);
            const pendingHours = reminderHours.filter((hours) => !sentHours.includes(hours) &&
                isWithinReminderWindow(hoursUntilStart, hours, 1));
            if (pendingHours.length === 0)
                continue;
            const nearestHour = pendingHours[pendingHours.length - 1];
            const noResponseUids = await getMembersWithoutResponse(groupId, eventDoc.id);
            if (noResponseUids.length === 0)
                continue;
            const eventTitle = eventData.title ?? "일정";
            let sentCount = 0;
            for (const uid of noResponseUids) {
                const settings = await getNotificationSettings(groupId, uid);
                if (!settings.noResponseReminderEnabled)
                    continue;
                const tokens = await getMemberTokens(groupId, uid);
                if (tokens.length === 0)
                    continue;
                await sendMulticastNotification(tokens, {
                    title: `${groupName} 응답 요청`,
                    body: `${eventTitle} · ${nearestHour}시간 전`,
                    data: {
                        type: "event",
                        groupId,
                        eventId: eventDoc.id,
                        reminderType: "event.noResponse",
                        hoursBefore: String(nearestHour),
                    },
                });
                sentCount += 1;
            }
            if (sentCount > 0) {
                await eventDoc.ref.set({
                    automationNoResponseReminderSentHours: admin.firestore.FieldValue.arrayUnion(...pendingHours),
                    automationNoResponseReminderUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
                }, { merge: true });
            }
        }
    }
});
exports.recurringEventAutoCreateEvery30m = (0, scheduler_1.onSchedule)("every 30 minutes", async () => {
    if (!isAutomationFeatureEnabled("ENABLE_RECURRING_EVENTS")) {
        return;
    }
    const db = admin.firestore();
    const nowMillis = Date.now();
    const groups = await getActiveGroups();
    for (const group of groups) {
        const groupId = group.id;
        const groupRef = db.collection("groups").doc(groupId);
        const recurringSnap = await groupRef
            .collection("events")
            .where("recurrenceEnabled", "==", true)
            .get();
        for (const rootDoc of recurringSnap.docs) {
            try {
                let createdEventId = null;
                let createdStartAt = null;
                let recurrenceRule = null;
                const rootRef = rootDoc.ref;
                const rootEventId = rootDoc.id;
                await db.runTransaction(async (tx) => {
                    const freshRoot = await tx.get(rootRef);
                    if (!freshRoot.exists)
                        return;
                    const data = freshRoot.data() ?? {};
                    if (data.isDeleted === true)
                        return;
                    if (data.recurrenceEnabled !== true)
                        return;
                    const rule = parseRecurrenceRule(data.recurrenceRule);
                    if (!rule)
                        return;
                    recurrenceRule = rule;
                    const nextStartRaw = data.recurrenceNextStartAt;
                    if (!(nextStartRaw instanceof admin.firestore.Timestamp))
                        return;
                    const lookAheadMillis = recurrenceLookAheadMillis(rule);
                    if (nextStartRaw.toMillis() > nowMillis + lookAheadMillis)
                        return;
                    const rootEventKey = typeof data.recurrenceRootEventId === "string" &&
                        data.recurrenceRootEventId.trim().length > 0 ?
                        data.recurrenceRootEventId.trim() :
                        rootEventId;
                    const generatedEventId = `recur_${rootEventKey}_${nextStartRaw.toMillis()}`;
                    const generatedRef = rootRef.parent.doc(generatedEventId);
                    const generatedSnap = await tx.get(generatedRef);
                    if (!generatedSnap.exists) {
                        const payload = {
                            title: typeof data.title === "string" ? data.title : "정기 모임",
                            startAt: nextStartRaw,
                            status: "open",
                            isDeleted: false,
                            createdBy: typeof data.createdBy === "string" ? data.createdBy : "system",
                            createdAt: admin.firestore.FieldValue.serverTimestamp(),
                            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                            autoGenerated: true,
                            recurrenceEnabled: false,
                            recurrenceRule: rule,
                            recurrenceRootEventId: rootEventKey,
                        };
                        if (typeof data.locationName === "string" && data.locationName.trim().length > 0) {
                            payload.locationName = data.locationName;
                            payload.location = data.locationName;
                        }
                        else if (typeof data.location === "string" && data.location.trim().length > 0) {
                            payload.location = data.location;
                        }
                        if (typeof data.address === "string" && data.address.trim().length > 0) {
                            payload.address = data.address;
                        }
                        if (typeof data.description === "string" && data.description.trim().length > 0) {
                            payload.description = data.description;
                        }
                        tx.set(generatedRef, payload, { merge: false });
                        createdEventId = generatedEventId;
                        createdStartAt = nextStartRaw;
                    }
                    const nextStartDate = computeNextRecurringStartAt(nextStartRaw.toDate(), rule);
                    tx.set(rootRef, {
                        recurrenceNextStartAt: admin.firestore.Timestamp.fromDate(nextStartDate),
                        recurrenceGeneratedCount: admin.firestore.FieldValue.increment(1),
                        recurrenceLastGeneratedAt: admin.firestore.FieldValue.serverTimestamp(),
                        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    }, { merge: true });
                });
                if (createdEventId && createdStartAt && recurrenceRule) {
                    await writeAuditLog({
                        groupId,
                        actorUid: "system",
                        action: "event.recurrence.generate",
                        targetId: createdEventId,
                        before: null,
                        after: {
                            rootEventId,
                            recurrenceRule,
                            startAt: createdStartAt,
                        },
                        meta: { source: "schedule.recurringEventAutoCreateEvery30m" },
                    });
                }
            }
            catch (error) {
                firebase_functions_1.logger.error("recurringEventAutoCreateEvery30m failed", {
                    groupId,
                    rootEventId: rootDoc.id,
                    error,
                });
            }
        }
    }
});
exports.feeDueReminderD3D1At10 = (0, scheduler_1.onSchedule)({ schedule: "0 10 * * *", timeZone: "Asia/Seoul" }, async () => {
    if (!isAutomationFeatureEnabled("ENABLE_FEE_DUE_REMINDER")) {
        return;
    }
    const db = admin.firestore();
    const now = new Date();
    const nowTs = admin.firestore.Timestamp.fromDate(now);
    const untilTs = admin.firestore.Timestamp.fromMillis(now.getTime() + 4 * 24 * 60 * 60 * 1000);
    const groups = await getActiveGroups();
    for (const group of groups) {
        const groupId = group.id;
        const groupRef = db.collection("groups").doc(groupId);
        try {
            const feesSnap = await groupRef
                .collection("fees")
                .where("dueDate", ">=", nowTs)
                .where("dueDate", "<=", untilTs)
                .get();
            for (const feeDoc of feesSnap.docs) {
                const feeData = feeDoc.data();
                const dueDateRaw = feeData.dueDate;
                if (!(dueDateRaw instanceof admin.firestore.Timestamp))
                    continue;
                const dDay = daysUntilDueInKst(dueDateRaw.toDate(), now);
                if (dDay !== 3 && dDay !== 1)
                    continue;
                const activeMembers = await getActiveMembers(groupId);
                for (const member of activeMembers) {
                    const recordRef = feeDoc.ref.collection("records").doc(member.uid);
                    const recordSnap = await recordRef.get();
                    const recordData = recordSnap.data() ?? {};
                    const status = typeof recordData.status === "string" ? recordData.status : "unpaid";
                    if (status === "paid")
                        continue;
                    const sentDays = Array.isArray(recordData.reminderSentDays) ?
                        recordData.reminderSentDays.filter((v) => typeof v === "number") :
                        [];
                    if (sentDays.includes(dDay))
                        continue;
                    const settings = await getNotificationSettings(groupId, member.uid);
                    if (!settings.paymentReminderEnabled)
                        continue;
                    await sendNotificationToUser(groupId, member.uid, {
                        title: "회비 납부 알림",
                        body: `${feeDoc.id} 회비 납부기한 D-${dDay} 입니다.`,
                        data: { type: "fee", groupId, periodKey: feeDoc.id, dDay: `${dDay}` },
                    });
                    await recordRef.set({
                        status: "unpaid",
                        reminderSentDays: admin.firestore.FieldValue.arrayUnion(dDay),
                        reminderUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
                    }, { merge: true });
                }
            }
        }
        catch (error) {
            firebase_functions_1.logger.error("feeDueReminderD3D1At10 failed", { groupId, error });
        }
    }
});
exports.eventAutoCloseAndResultNotifyEvery10m = (0, scheduler_1.onSchedule)("every 10 minutes", async () => {
    if (!isAutomationFeatureEnabled("ENABLE_EVENT_AUTO_CLOSE")) {
        return;
    }
    const db = admin.firestore();
    const nowTs = admin.firestore.Timestamp.now();
    const nowMillis = nowTs.toMillis();
    const windowStart = admin.firestore.Timestamp.fromMillis(nowMillis - 14 * 24 * 60 * 60 * 1000);
    const groups = await getActiveGroups();
    for (const group of groups) {
        const groupId = group.id;
        const groupRef = db.collection("groups").doc(groupId);
        try {
            const targetEvents = await groupRef
                .collection("events")
                .where("startAt", ">=", windowStart)
                .where("startAt", "<=", nowTs)
                .get();
            for (const eventDoc of targetEvents.docs) {
                let shouldNotify = false;
                let eventTitle = "일정";
                try {
                    await db.runTransaction(async (tx) => {
                        const freshEvent = await tx.get(eventDoc.ref);
                        if (!freshEvent.exists)
                            return;
                        const data = freshEvent.data() ?? {};
                        if (data.isDeleted === true)
                            return;
                        const closedByStatus = data.status === "closed";
                        const closedAt = data.responseClosedAt;
                        const closedByTime = closedAt instanceof admin.firestore.Timestamp &&
                            closedAt.toMillis() <= nowMillis;
                        if (closedByStatus || closedByTime)
                            return;
                        eventTitle = typeof data.title === "string" &&
                            data.title.trim().length > 0 ? data.title.trim() : "일정";
                        shouldNotify = !data.resultNotifiedAt;
                        tx.set(eventDoc.ref, {
                            status: "closed",
                            responseClosedAt: admin.firestore.FieldValue.serverTimestamp(),
                            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
                            ...(shouldNotify ? { resultNotifiedAt: admin.firestore.FieldValue.serverTimestamp() } : {}),
                        }, { merge: true });
                    });
                    if (!shouldNotify)
                        continue;
                    const responsesSnap = await eventDoc.ref.collection("responses").get();
                    const goingCount = responsesSnap.docs.filter((responseDoc) => responseDoc.data().response === "going").length;
                    const activeMembers = await getActiveMembers(groupId);
                    for (const member of activeMembers) {
                        const settings = await getNotificationSettings(groupId, member.uid);
                        if (!settings.eventReminderEnabled)
                            continue;
                        await sendNotificationToUser(groupId, member.uid, {
                            title: "일정 응답 마감",
                            body: `${eventTitle} 참석 확정 ${goingCount}명`,
                            data: {
                                type: "event",
                                subType: "result",
                                groupId,
                                eventId: eventDoc.id,
                            },
                        });
                    }
                    await writeAuditLog({
                        groupId,
                        actorUid: "system",
                        action: "event.response.close",
                        targetId: eventDoc.id,
                        before: null,
                        after: {
                            status: "closed",
                            goingCount,
                        },
                        meta: { source: "schedule.eventAutoCloseAndResultNotifyEvery10m" },
                    });
                }
                catch (error) {
                    firebase_functions_1.logger.error("eventAutoCloseAndResultNotifyEvery10m event failed", {
                        groupId,
                        eventId: eventDoc.id,
                        error,
                    });
                }
            }
        }
        catch (error) {
            firebase_functions_1.logger.error("eventAutoCloseAndResultNotifyEvery10m group failed", {
                groupId,
                error,
            });
        }
    }
});
function getCurrentPeriodKey(date = new Date()) {
    const year = date.getFullYear();
    const month = `${date.getMonth() + 1}`.padStart(2, "0");
    return `${year}-${month}`;
}
async function getActiveGroups() {
    const groupsSnap = await admin.firestore().collection("groups").get();
    return groupsSnap.docs.filter((doc) => doc.data().status !== "dormant");
}
async function safeBatchWrite(writer) {
    const batch = admin.firestore().batch();
    await writer(batch);
    await batch.commit();
}
async function sendNotificationToUser(groupId, uid, payload) {
    const tokens = await getMemberTokens(groupId, uid);
    await sendMulticastNotification(tokens, payload);
}
exports.monthlyFeePeriodAutoCreate = (0, scheduler_1.onSchedule)({ schedule: "5 0 1 * *", timeZone: "Asia/Seoul" }, async () => {
    const periodKey = getCurrentPeriodKey();
    const groups = await getActiveGroups();
    for (const group of groups) {
        const groupId = group.id;
        try {
            const periodRef = admin
                .firestore()
                .collection("groups")
                .doc(groupId)
                .collection("feePeriods")
                .doc(periodKey);
            const existing = await periodRef.get();
            if (existing.exists)
                continue;
            const policySnap = await admin
                .firestore()
                .collection("groups")
                .doc(groupId)
                .collection("feePolicies")
                .limit(1)
                .get();
            const policyAmountSnapshot = policySnap.empty ? null : policySnap.docs[0].data().amount ?? null;
            await periodRef.set({
                periodKey,
                openedAt: admin.firestore.FieldValue.serverTimestamp(),
                policyAmountSnapshot,
            }, { merge: true });
            await writeAuditLog({
                groupId,
                actorUid: "system",
                action: "feePeriod.create",
                targetId: periodKey,
                before: null,
                after: { periodKey, policyAmountSnapshot },
                meta: { source: "schedule.monthlyFeePeriodAutoCreate" },
            });
        }
        catch (error) {
            firebase_functions_1.logger.error("monthlyFeePeriodAutoCreate failed for group", { groupId, error });
        }
    }
});
exports.unpaidMembersReminderAt19 = (0, scheduler_1.onSchedule)({ schedule: "0 19 * * *", timeZone: "Asia/Seoul" }, async () => {
    const periodKey = getCurrentPeriodKey();
    const groups = await getActiveGroups();
    for (const group of groups) {
        const groupId = group.id;
        try {
            const activeMembers = await getActiveMembers(groupId);
            for (const member of activeMembers) {
                const paymentDoc = await admin
                    .firestore()
                    .collection("groups")
                    .doc(groupId)
                    .collection("feePeriods")
                    .doc(periodKey)
                    .collection("payments")
                    .doc(member.uid)
                    .get();
                if (paymentDoc.exists)
                    continue;
                const settingsSnap = await admin
                    .firestore()
                    .collection("groups")
                    .doc(groupId)
                    .collection("members")
                    .doc(member.uid)
                    .collection("notificationSettings")
                    .limit(1)
                    .get();
                const paymentReminderEnabled = settingsSnap.empty ?
                    true :
                    (settingsSnap.docs[0].data().paymentReminderEnabled ?? true);
                if (!paymentReminderEnabled)
                    continue;
                await sendNotificationToUser(groupId, member.uid, {
                    title: "회비 미납 안내",
                    body: `${periodKey} 회비가 아직 입금되지 않았습니다.`,
                    data: { type: "fee", groupId, periodKey },
                });
            }
        }
        catch (error) {
            firebase_functions_1.logger.error("unpaidMembersReminderAt19 failed for group", { groupId, error });
        }
    }
});
exports.leaderboardAndStatsSnapshotAt03 = (0, scheduler_1.onSchedule)({ schedule: "0 3 * * *", timeZone: "Asia/Seoul" }, async () => {
    const now = new Date();
    const periodKey = getCurrentPeriodKey(now);
    const groups = await getActiveGroups();
    for (const group of groups) {
        const groupId = group.id;
        try {
            await recomputeGroupPeriodStatsCore(groupId, periodKey);
        }
        catch (error) {
            firebase_functions_1.logger.error("leaderboardAndStatsSnapshotAt03 failed for group", { groupId, error });
        }
    }
});
exports.dormantGroupAutoDetectionAt02 = (0, scheduler_1.onSchedule)({ schedule: "0 2 * * *", timeZone: "Asia/Seoul" }, async () => {
    const now = Date.now();
    const groupsSnap = await admin.firestore().collection("groups").get();
    for (const groupDoc of groupsSnap.docs) {
        const groupId = groupDoc.id;
        try {
            const groupData = groupDoc.data();
            const createdAt = groupData.createdAt;
            if (!createdAt)
                continue;
            const elapsedDays = (now - createdAt.toMillis()) / (24 * 60 * 60 * 1000);
            if (elapsedDays < 14)
                continue;
            const activeMembers = await getActiveMembers(groupId);
            if (activeMembers.length < 5 && groupData.status !== "dormant") {
                const beforeStatus = groupData.status ?? null;
                await groupDoc.ref.set({ status: "dormant" }, { merge: true });
                await writeAuditLog({
                    groupId,
                    actorUid: "system",
                    action: "group.status.dormant",
                    targetId: groupId,
                    before: { status: beforeStatus },
                    after: { status: "dormant", activeMemberCount: activeMembers.length },
                    meta: { source: "schedule.dormantGroupAutoDetectionAt02" },
                });
                firebase_functions_1.logger.info("Group transitioned to dormant", { groupId });
            }
        }
        catch (error) {
            firebase_functions_1.logger.error("dormantGroupAutoDetectionAt02 failed for group", { groupId, error });
        }
    }
});
/**
 * Firestore 일일 백업 스케줄 함수.
 *
 * - 실행 시각: 매일 KST 03:00 (UTC 18:00)
 * - 대상: Firestore 전체 Export
 * - 저장 위치: Cloud Storage `BACKUP_BUCKET` 환경변수에 지정된 버킷
 * - ENABLE_SERVER_FEATURES 환경변수가 "false"이면 실행을 건너뜁니다.
 *
 * 필요 권한:
 *   - Cloud Functions 서비스 계정에 `roles/datastore.importExportAdmin` 부여
 *   - Cloud Functions 서비스 계정에 해당 GCS 버킷 `roles/storage.objectAdmin` 부여
 */
exports.dailyBackupJob = (0, scheduler_1.onSchedule)({ schedule: "0 18 * * *", timeZone: "UTC" }, async () => {
    // ENABLE_SERVER_FEATURES 조건부 실행
    if (process.env.ENABLE_SERVER_FEATURES === "false") {
        firebase_functions_1.logger.info("dailyBackupJob skipped: ENABLE_SERVER_FEATURES=false");
        return;
    }
    const bucket = (process.env.BACKUP_BUCKET ?? "").trim();
    if (!bucket) {
        firebase_functions_1.logger.error("dailyBackupJob aborted: BACKUP_BUCKET environment variable is not set");
        return;
    }
    const projectId = process.env.GCLOUD_PROJECT ?? admin.instanceId().app.options.projectId;
    if (!projectId) {
        firebase_functions_1.logger.error("dailyBackupJob aborted: could not determine project ID");
        return;
    }
    // 백업 경로: gs://<BACKUP_BUCKET>/firestore-backup/YYYY-MM-DD
    const date = new Date().toISOString().split("T")[0];
    const outputUriPrefix = `gs://${bucket}/firestore-backup/${date}`;
    try {
        // Firestore Admin REST API를 사용하여 Export 요청
        const accessToken = await admin.app().options.credential?.getAccessToken();
        if (!accessToken) {
            firebase_functions_1.logger.error("dailyBackupJob aborted: failed to obtain access token");
            return;
        }
        const url = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default):exportDocuments`;
        const response = await fetch(url, {
            method: "POST",
            headers: {
                "Authorization": `Bearer ${accessToken.access_token}`,
                "Content-Type": "application/json",
            },
            body: JSON.stringify({ outputUriPrefix }),
        });
        if (!response.ok) {
            const body = await response.text();
            firebase_functions_1.logger.error("dailyBackupJob: Firestore export request failed", {
                status: response.status,
                body,
            });
            return;
        }
        const operation = await response.json();
        firebase_functions_1.logger.info("dailyBackupJob: Firestore export started", {
            operation: operation.name,
            outputUriPrefix,
        });
    }
    catch (error) {
        firebase_functions_1.logger.error("dailyBackupJob: unexpected error", { error });
    }
});
//# sourceMappingURL=index.js.map