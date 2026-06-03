# Moyeora Stats Upgrade

## Data Sources

통계 화면은 월 키(`periodKey`, 예: `2026-02`) 기준으로 아래 문서를 읽습니다.

- `groups/{groupId}/stats/{periodKey}`
  - `activeMemberCount`
  - `eventCountThisMonth`
  - `attendanceRate` (있을 경우 우선 사용)
- `groups/{groupId}/leaderboards/{periodKey}`
  - `attendanceTop`
  - `activityTop`

## Visual Hierarchy

화면은 시선 흐름을 아래 순서로 설계했습니다.

1. 월간 출석률 차트(핵심 KPI)
2. 내 활동 요약(개인화 지표)
3. Top 3 하이라이트(동기부여 영역)

디자인 원칙:

- 간결한 카드 레이아웃
- 불필요한 장식 최소화
- DodgerBlue(`0xFF1E90FF`) 포인트 컬러
- 라이트/다크 테마 공통 가독성 유지

## Leaderboard Integration

- `attendanceTop`으로 Top 3 카드와 개인 출석 순위/점수를 계산합니다.
- `activityTop`으로 개인 활동 순위/점수를 계산합니다.
- `stats.attendanceRate`가 없을 때는
  - `attendanceTop`, `activeMemberCount`, `eventCountThisMonth`를 이용해
  - 월간 출석률을 추정치로 계산해 차트에 표시합니다.

## Result

- 통계 전용 화면(`lib/screens/stats/stats_screen.dart`) 추가
- 하단 탭에 Stats 진입점 연결
- 차트 라이브러리 `fl_chart` 기반의 경량 시각화 적용
