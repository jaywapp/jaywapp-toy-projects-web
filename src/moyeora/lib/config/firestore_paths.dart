/// Firestore 컬렉션/문서/필드 경로 상수.
/// 경로 변경 시 이 파일 한 곳만 수정하면 전체 코드에 반영됩니다.
class FirestorePaths {
  FirestorePaths._();

  // ── 최상위 컬렉션 ──
  static const groups = 'groups';
  static const users = 'users';
  static const inviteCodes = 'inviteCodes';

  // ── groups 서브컬렉션 ──
  static const members = 'members';
  static const events = 'events';
  static const notices = 'notices';
  static const polls = 'polls';
  static const invites = 'invites';
  static const fcmTokens = 'fcmTokens';

  // ── members 서브컬렉션 ──
  static const notificationSettings = 'notificationSettings';
  static const notificationSettingsDefault = 'default';

  // ── 공통 필드 ──
  static const isDeleted = 'isDeleted';
  static const startAt = 'startAt';
  static const createdAt = 'createdAt';
  static const updatedAt = 'updatedAt';
  static const status = 'status';
  static const name = 'name';
  static const token = 'token';
  static const platform = 'platform';
}
