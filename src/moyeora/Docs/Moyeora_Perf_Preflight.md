# Moyeora Perf Preflight

## 1) 추가된 기반
- 관측(Observability)
  - `lib/dev/perf_timing.dart`
  - `lib/dev/firestore_metrics.dart`
  - 디버그에서만 `[PERF]`, `[FS]` 로그 출력
- 에러 표준화
  - `toUserMessage(Object error)` 기반 사용자 메시지 통일
  - `main.dart`의 `_friendlyError`가 공통 매퍼 사용
- 리포지토리 계층
  - `lib/repositories/group_repository.dart`
  - `lib/repositories/events_repository.dart`
  - `lib/repositories/notices_repository.dart`
  - `lib/repositories/finance_repository.dart`
- 캐시
  - `lib/services/app_cache.dart`
  - `group/member/settings/profile` 메모리 캐시(TTL 60초)
  - 그룹 전환/로그아웃 시 invalidate
- 집계 경로 준비
  - `lib/services/aggregation_service.dart`
  - `periodKey=YYYY-MM`, `generatedAt`, `version` 계약 반영
- 환경 분리 스캐폴드
  - `lib/config/app_config.dart`
  - `APP_ENV(dev/stage/prod)`, `enableDevTools`, `showDebugBanner`
  - DEV 메뉴 라벨 `[DEV]` 적용

## 2) 로그 확인 방법
- 성능 시간: `[PERF] Home KPI: 45ms`
- Firestore 카운트: `[FS][home-kpi] reads=.. writes=.. listens=..`
- 주기 로그: 앱 실행 중 20초 간격으로 `[FS][periodic] ...`

## 3) 쿼리/패턴 정리
- Home KPI/리텐션:
  - 기존: 이벤트/응답 순회 기반 N+1
  - 변경: `stats/{periodKey}`, `leaderboards/{periodKey}` 중심 조회
- Notices 리스트:
  - 기존: 공지 아이템마다 `reads/{uid}` 조회
  - 변경: 리스트에서는 per-item read 조회 제거
- Events 리스트:
  - 기존: 이벤트 아이템마다 `responses/{uid}` 스트림
  - 변경: 리스트에서는 per-item 응답 스트림 제거 (상세 화면에서 조회)

## 4) 캐시 규칙/무효화
- TTL: 60초
- 캐시 키:
  - `group:{groupId}`
  - `member:{groupId}:{uid}`
  - `settings:{groupId}:{uid}`
  - `profile:{uid}`
- 무효화:
  - 그룹 선택 시 `group/member/settings` prefix invalidate
  - 로그아웃 시 전체 clear

## 5) Functions-ready 계약
- 대상 문서:
  - `groups/{groupId}/stats/{periodKey}`
  - `groups/{groupId}/leaderboards/{periodKey}`
- 필드:
  - `generatedAt`(timestamp)
  - `version`(int)
- 클라이언트 동작:
  - stale/missing 시 안내 문구 표시
  - `requestRecompute(...)` 스텁 호출(클라이언트 no-op 로그)

## 6) DEV-only 원칙
- DEV 데이터 버튼은 `AppConfig.enableDevTools`로 제한
- 사용자 기능에는 디버그 로그/패널 영향 없음
