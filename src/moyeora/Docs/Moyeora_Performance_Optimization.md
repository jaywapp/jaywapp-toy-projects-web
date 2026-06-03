# Moyeora Performance Optimization

## 측정 기준
- 기준 화면: Home / Events / Notices / Finance
- 지표: 첫 로딩 읽기 수(reads), 실시간 리스너(listens), 첫 콘텐츠 시간(loadMs)
- 측정 수단: `PerfSpan`, `FirestoreMetrics` 디버그 로그

## Hotspots (Before)
1. Home KPI/리텐션에서 이벤트-응답 순회 N+1
2. Events 리스트 아이템별 `responses/{uid}` 스트림
3. Notices 리스트 아이템별 `reads/{uid}` 조회

## 적용 변경
- Home
  - KPI/리텐션 계산을 집계 문서(`stats`, `leaderboards`) 중심으로 전환
  - 공지 unread 계산을 per-item read 조회 방식에서 제거
- Events
  - 리스트 카드에서 per-item response 스트림 제거
  - 응답 쓰기는 유지(리스트 버튼은 optimistic 선택 상태 없이 단순 액션)
- Notices
  - 리스트에서 per-item `reads/{uid}` 조회 제거
  - 읽음 처리는 상세 화면 진입 시만 기록
- 공통
  - 표준 에러 매핑 적용
  - 그룹 전환/로그아웃 캐시 무효화

## Before / After (코드 경로 기준 추정치)
| 화면 | Before | After |
|---|---|---|
| Home | 약 40~60 reads (이벤트 응답 순회 + 공지 reads 순회) | 약 10~15 reads (집계 문서 중심, 공지 N+1 제거) |
| Events | `1 + 이벤트수` listens (리스트 + 아이템별 응답) | `1` listen (리스트만) |
| Notices | `1 + 공지수` reads (리스트 + 아이템별 reads) | `1` query reads (리스트만) |
| Finance | 4중 stream 결합 | 유지(다음 단계 get/pagination 예정) |

## 예상 효과
- Home: 응답/공지 N+1 제거로 읽기 수 대폭 감소
- Events: 이벤트 수 증가 시 리스너 폭증 방지
- Notices: 공지 수 증가 시 선형 read 증가 제거

## 남은 개선 포인트
1. Home/Events/Notices를 `snapshots()`에서 `get()+refresh` 중심으로 추가 전환
2. Finance를 role별 조회 모델(member 2~3 reads, treasurer paginated)로 분리
3. 지표 자동 집계를 위한 디버그 화면(세션별 before/after 캡처) 추가
