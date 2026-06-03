# Moyeora Finance System

## Monthly Structure

월별 회비 구조는 아래 경로를 사용합니다.

- `groups/{groupId}/fees/{YYYY-MM}`
  - `amount`: 월 회비 금액
  - `dueDate`: 납부 기한
  - `createdAt`: 생성 시각
- `groups/{groupId}/fees/{YYYY-MM}/records/{uid}`
  - `status`: `paid | unpaid`
  - `paidAt`: 납부 시각
  - `amount`: 개인 납부 금액

앱 진입 시 현재 월 문서가 없으면 자동 생성하며, 활성 멤버의 `records/{uid}`도 기본값(`unpaid`)으로 채웁니다.

## Role Restriction

- 조회: 활성 멤버
- 수정(금액 변경 / 납부 처리 / CSV Export): `owner` 또는 `treasurer`
- 구현 기준:
  - 앱 권한 체크: `PermissionService.canManageFinance()`
  - Firestore Rules: `canManageFinance(groupId)`

## UI Overview

`FinanceScreen`에서 제공:

- 현재 월 요약(기간/납부기한/월 회비)
- 납부 완료/미납 카운트
- 멤버별 납부 상태 목록
- `CSV 다운로드` 버튼(권한 보유자만 노출)

## Future Payment Integration

향후 결제 연동 시 권장 확장:

1. 외부 결제 트랜잭션 ID 필드 추가 (`transactionId`, `provider`)
2. 웹훅 수신 후 `records/{uid}` 상태 자동 동기화
3. 납부 실패/재시도 이력 서브컬렉션 분리
4. 월별 스냅샷 리포트 자동 생성 및 보관
