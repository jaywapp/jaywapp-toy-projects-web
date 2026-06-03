/// UI 공통 문자열 상수
///
/// 화면 전체에서 반복 사용되는 UI 메시지를 한 곳에서 관리합니다.
/// 동적 보간이 필요한 문자열은 각 호출 지점에서 처리합니다.
class AppStrings {
  AppStrings._();

  // ── 공통 상태 메시지 ──────────────────────────────────────────
  static const String selectGroupFirst = '그룹을 먼저 선택해 주세요.';
  static const String loadingData = '데이터를 불러오는 중...';

  // ── 권한 / 멤버십 ─────────────────────────────────────────────
  static const String permissionDenied = '권한이 없습니다. 관리자에게 문의해 주세요.';
  static const String membershipRequired =
      '활성 멤버만 접근할 수 있습니다. 먼저 그룹 참여를 완료해 주세요.';

  // ── 그룹 ID 누락 (라우터) ────────────────────────────────────
  static const String groupIdRequired = '그룹 ID가 필요합니다.';
}
