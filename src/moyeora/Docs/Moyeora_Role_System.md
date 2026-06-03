# Moyeora Role System

## 1) Role Definitions

- `owner`
  - 그룹의 최상위 운영 권한
  - 멤버/일정/회계/역할 관리 가능
- `admin`
  - 운영 보조 권한
  - 멤버/일정 관리 가능
- `treasurer`
  - 회계 담당 권한
  - 회계 관리 가능
- `member`
  - 일반 멤버 권한
  - 읽기/응답 중심 사용

멤버 문서 경로:

- `groups/{groupId}/members/{uid}`

권장 필드:

- `role: "owner" | "admin" | "treasurer" | "member"`

기본값:

- 생성자(creator): `owner`
- 일반 참여자: `member`

## 2) Permission Table

| Role | manageMembers | manageEvents | manageFinance | manageRoles | readOnly |
| --- | --- | --- | --- | --- | --- |
| owner | O | O | O | O | X |
| admin | O | O | X | X | X |
| treasurer | X | X | O | X | X |
| member | X | X | X | X | O |

앱 로컬 권한 서비스:

- `lib/services/permission_service.dart`
- 제공 메서드:
  - `canManageMembers()`
  - `canManageEvents()`
  - `canManageFinance()`
  - `canManageRoles()`
  - `isReadOnly()`
  - `canAccessAdminDashboard()`

## 3) UI Gating Policy

- 관리자 메뉴 노출:
  - `canAccessAdminDashboard()`가 true일 때만 표시
- 일정 상세 출석 현황:
  - `canManageMembers()` 또는 `canManageEvents()`일 때만 표시
- Admin Dashboard 탭 보호:
  - Approvals: `canManageMembers()`
  - Fees: `canManageFinance()`
  - Audit: `canManageRoles()`

## 4) Future Extensibility

- 역할 추가 시:
  - `permission_service.dart` 매트릭스에 역할별 capability만 추가
  - UI는 capability 메서드 기반이므로 화면별 분기 최소 변경
- 서버/보안 규칙 확장:
  - Cloud Functions 권한 체크를 role capability 기반으로 동기화
  - Firestore rules의 role 검사 로직도 동일 매트릭스로 맞춤
- 점진적 마이그레이션:
  - 기존 `permissions` 필드가 있어도 fallback 허용 후, 최종적으로 role 중심으로 통합
