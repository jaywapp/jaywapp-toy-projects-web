# SDK 및 연동 테스트 복구 결과

orchestrator: Codex

| 작업 | owner | model | effort | depends_on | parallel_group | files | verification | status |
|---|---|---|---|---|---|---|---|---|
| 근거 조사 | Codex | gpt-6-astra | high | 없음 | followup | 분석/설계 | 기존 gitlink 및 subtree-split 일치 | completed |
| Kakao 회귀 복구 | Codex | gpt-6-astra | high | 근거 조사 | followup | App.test.js, KakaoMap.js | Jest5개, production build | completed |
| 단일 Sheets 연결 | Codex | gpt-6-astra | high | 근거 조사 | followup | 로컬 Dart 패키지, 앱 import/pubspec | Flutter7개, 커널 번들 빌드 | completed |
| SDK 호환성 조사 | Codex | gpt-6-astra | high | 근거 조사 | followup | 분석/설계 | metadata와3.32.6 pinned test deps 비교 | completed |
| 기존 lock 기반 세 앱 빌드 | Codex | gpt-6-astra | high | SDK 호환성 조사 | followup | zaro/moyeora/baby-recorder | 별도 SDK 실행 필요 | not_completed |
| 검증 변경 게시 | Codex | gpt-6-astra | high | 완료 작업 | followup | 명시적 승인 파일 | staged diff 및 원격 HEAD 확인 | completed |

## 실행 검증

- proto-shop-finder: npm test -- --watchAll=false --runInBand, 5개 통과. 실제 App와 매장 데이터를 실행하고 Kakao SDK만 제어한다. 초기 지도/반경 메뉴, 가까운·넓은 반경 마커, 위치 기능 미지원, 권한 실패, debounce resize를 검증했다. npm run build 통과. 실지도/브라우저 E2E는 미실행이다.
- BeMyColleague: flutter pub get --offline으로 로컬 path package 하나만 추가. flutter test --no-pub --reporter expanded 전체7개 통과. 실제 초기 로그인 화면과 Sheets6개 경계를 포함한다. flutter build bundle --no-pub exit0, build/flutter_assets/kernel_blob.bin 58,745,904 bytes 생성 확인. APK/IPA/장치 로그인·실제 API는 미검증이다.
- 루트: node --test tests/*.test.cjs 9개 통과. Dart tests/google-sheet-range.test.dart 13개 통과. 기존 호환 export도 유지한다.
- SDK: C:/flutter는 변경하지 않았다. 3.32.6이 기존 .metadata와 일치하고 flutter_test의 test_api0.7.4/matcher0.12.17/leak_tracker10.0.9도 기존 lock과 맞는다. 별도 SDK 다운로드는 하지 않았으며 그 SDK의 전체 복원 성공까지 주장하지 않는다. 추적 lockfile 변경 없음.
- 원격 서브모듈 원본은 Repository not found. 실제 반입된 같은 원본을 로컬 패키지로 사용하며 중복 소스·가짜 서비스·원격 저장소 생성·gitlink 업데이트는 하지 않았다.
- 생성 로그·번들·node_modules·새로 해석한 로컬 cache/lock은 커밋에서 제외한다. 세 저장소의 이전 변경 커밋은 각각 d0d9495, 2273234, 35d4d80이며 모두 원격 HEAD 일치를 확인했다.

동일 저장소의 편집·검증·게시를 순차 진행했다. 전체 프로젝트/모든 플랫폼 검증이 완료된 것은 아니다.
