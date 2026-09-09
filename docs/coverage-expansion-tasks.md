# 검증 범위 확장 결과

orchestrator: Codex

| 작업 | owner | model | effort | depends_on | parallel_group | files | verification | status |
|---|---|---|---|---|---|---|---|---|
| 인벤토리 | Codex | gpt-6-astra | high | 없음 | nested | 아래 경로 | 실제 추적 파일 및 SDK | completed |
| 실행 가능한 빌드·회귀 확장 | Codex | gpt-6-astra | high | 인벤토리 | nested | 아래 변경 | 아래 명령 | completed |
| 전체 앱 통합 검증 | Codex | gpt-6-astra | high | 빌드·회귀 | nested | 저장소 전체 | 아래 남은 항목 | not_completed |

저장소 간 상위 Codex 작업과 병렬이며 동일 앱 편집·검증은 순차 처리했다. 결과는 아래 검증 범위에만 한정된다.

| 앱 | 실제 빌드·테스트 결과 | 남은 검증 |
|---|---|---|
| proto-shop-finder | npm ci --legacy-peer-deps 및 production build 통과. 루트 DataSelector Node 3개 통과 | 기존 App.test.js는 Kakao maps 미제공 오류로 실패. 실제 지도 UI/검색 E2E 미검증 |
| sijang-2-manchan | npm ci / production build 통과. 실제 App·모달 Jest 3개, 데이터 로더 Node 6개 통과 | 실제 공공 API·Kakao 지도 E2E 미검증. more 컨트롤의 기존 div 접근성 제약 유지 |
| moyeora Flutter | Flutter 3.41.9 / Dart3.11.5에서 --no-pub 기존81개 통과 | SDK가 lock의 테스트 패키지13개 변경을 요구. 임시 해석 상태 테스트이며 원본 lock 기준 재현성/전체 앱 빌드는 미검증. 원본 lock 복구 완료 |
| moyeora Functions | npm ci, npm test로 TypeScript build 및 기간 경계4개 통과 | 선언 Node20/실행 Node22.19 차이. 인증/권한/Firestore emulator 통합 미검증 |
| moyeora Firestore rules | 테스트 파일 및 실행 명령 인벤토리 확인 | 에뮬레이터 실행 미검증 |
| zaro Flutter | --offline --enforce-lockfile 실제 실패: 현재 SDK와 기존 lock9개 불일치 | 호환 Flutter SDK에서 복원·기존 테스트·앱 빌드 필요. lock 수정 없음 |
| zaro Functions | npm ci 및 npm run build 통과 | 외부 Gemini·Firebase callable/예약·알림 기능 실행 미검증 |
| baby-recorder | --offline --enforce-lockfile 실제 실패: SDK와 기존 lock9개 불일치 | 호환 SDK에서 전체 테스트/앱 빌드 필요. 실서비스 webhook 실행 안 함 |
| be-my-colleague | 캐시 부재 뒤 온라인 pub 복원. 실제 테스트 컴파일은 누락 lib/submodules/jaywapp-dart-google-sheet 때문에 실패 | 전체 앱 통합·기본 counter 예제 테스트 교체 필요. 원본에 lock 없음. 복원은 symlink 개발자모드 조건 오류도 보고 |
| jaywapp-dart-google-sheet | 실제 Dart range13개 및 실제 manager Flutter6개 통과 | 원본 패키지 구조가 be_my_colleague HTTP client에 의존. 전체 Google 인증/Sheets E2E 미검증 |

제품 변경: 시장 데이터 요청 실패 때 페이지를 유지하고 HTTP/데이터 배열을 검증한다. 동시 more 요청은 순차 처리해 페이지 중복을 막는다. GoogleSheetManager의 FFI Bool predicate를 Dart bool로 고치고, 짧은 행·마지막 열·비양수 인덱스 경계를 바로잡았다.
재현: 루트 `node --test tests/*.test.cjs` 9개, `C:\flutter\bin\cache\dart-sdk\bin\dart.exe tests/google-sheet-range.test.dart` 13개. be-my-colleague/be_my_colleague에서 `flutter test --no-pub test/google_sheet_manager_test.dart` 6개. 시장 앱에서 `npm test -- --watchAll=false --runInBand` 3개. moyeora/functions에서 `npm test` 4개.
원본 lock/불필요한 빌드 생성변경은 복구했다. Functions의 생성된 lib 출력은 커밋에서 제외하고 원본을 복구했다. SDK 캐시/네트워크 복원은 자동 승인 escalation을 거쳤다.

후속 갱신: proto-shop-finder 테스트와 BeMyColleague 누락 연결은 [SDK·연동 테스트 복구 결과](sdk-test-recovery-tasks.md)에서 해결했다. 위 표는 최초 검증 시점 기록이다.
