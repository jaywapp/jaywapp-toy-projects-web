# Moyeora 프로젝트 문제점 정리 (2026-02-13)

## 점검 범위
- Flutter 앱: `lib`, `test`, `pubspec.yaml`, `analysis_options.yaml`
- Firebase Functions: `functions/src`, `functions/package.json`
- Firestore 보안 규칙: `firestore.rules`

## 실행 결과
- `flutter analyze`: 통과 (No issues found)
- `flutter test`: 통과 (테스트 1개만 존재)
- `npm run build` (`functions`): 통과
- `npm run lint` (`functions`): 실패 (lint 1건)

## 우선순위 요약
| 심각도 | 이슈 | 근거 |
|---|---|---|
| Critical | 멤버 승인 흐름에서 권한 상승 가능 | `firestore.rules:50`, `firestore.rules:53`, `functions/src/index.ts:277`, `functions/src/index.ts:290`, `firestore.rules:18` |
| High | 데모 시드 함수가 운영 환경에서도 호출 가능 | `functions/src/index.ts:472`, `functions/src/index.ts:491`, `functions/src/index.ts:516` |
| Medium | `main.dart` 단일 파일 비대화 (3901라인) | `lib/main.dart` |
| Medium | 통계 재계산 서비스가 TODO 상태 | `lib/services/aggregation_service.dart:10` |
| Medium | 테스트 커버리지 부족 | `test/widget_test.dart:6`, `functions/package.json:3` |
| Low | Functions lint 파이프라인 실패 | `functions/src/index.ts:411` |
| Low | README가 기본 템플릿 상태 | `README.md:3`, `README.md:7` |

## 상세 이슈

### 1) [Critical] 멤버 승인 플로우 권한 상승 취약점
1. 가입 신청 생성 규칙에서 `status == 'pending'`만 강제하고, `role`/`permissions` 필드 화이트리스트 제한이 없습니다. (`firestore.rules:50`~`firestore.rules:59`)
2. `approveMember`는 `merge` 업데이트로 상태만 바꿉니다. (`functions/src/index.ts:277`~`functions/src/index.ts:283`)
3. 승인 후 membership의 role을 기존 신청 문서 값에서 그대로 가져옵니다. (`functions/src/index.ts:290`)
4. 실제 권한 판정은 멤버 문서의 `role`/`permissions`를 신뢰합니다. (`firestore.rules:18`~`firestore.rules:25`)
5. 영향: 신청자가 사전에 높은 권한 값을 써두면 승인 즉시 권한 상승이 발생할 수 있습니다.
6. 권장 조치:
1. 가입 신청 시 허용 필드를 화이트리스트로 제한.
2. 승인 시 서버에서 `role: member`, `permissions: []` 강제 초기화.
3. 승인 경로에서 custom claims까지 일관 갱신.

### 2) [High] 데모 데이터 주입 함수 운영 노출
1. `seedDemoData` callable 함수가 존재합니다. (`functions/src/index.ts:472`)
2. 호출 조건이 사실상 활성 멤버 여부뿐입니다. (`functions/src/index.ts:491`)
3. 함수가 실제 공지/일정 데이터를 생성합니다. (`functions/src/index.ts:516` 이후)
4. 영향: 운영 그룹 데이터가 데모 데이터로 오염될 수 있습니다.
5. 권장 조치:
1. `groupId == "g_demo"` 또는 관리자 권한으로 강하게 제한.
2. 프로젝트 ID/환경 변수 기반으로 운영 환경 실행 차단.
3. 함수명을 dev 전용임이 드러나게 변경.

### 3) [Medium] `main.dart` 모놀리식 구조
1. `lib/main.dart`가 3901라인이고 인증/라우팅/화면/관리자/디버그 로직이 혼재합니다.
2. 하나의 파일에 클래스가 다수 존재합니다. (`lib/main.dart:370`, `lib/main.dart:973`, `lib/main.dart:1250`, `lib/main.dart:2954`)
3. 영향: 병합 충돌 증가, 리뷰 난이도 상승, 회귀 범위 확대.
4. 권장 조치:
1. 기능 단위(`auth`, `group`, `events`, `admin`, `settings`)로 분리.
2. 라우팅/뷰/서비스 책임 분리.

### 4) [Medium] 통계 재계산 경로 미구현
1. `AggregationService.requestRecompute`가 TODO만 있고 실제 호출이 없습니다. (`lib/services/aggregation_service.dart:10`)
2. 영향: 통계/리더보드 재계산 트리거가 기대대로 동작하지 않을 수 있습니다.
3. 권장 조치: 실제 callable 연동 또는 미사용 코드 제거.

### 5) [Medium] 테스트 커버리지 부족
1. Flutter 테스트는 앱 생성 여부만 확인하는 스모크 테스트 1개입니다. (`test/widget_test.dart:6`)
2. Functions `package.json`에 test 스크립트가 없습니다. (`functions/package.json:3`~`functions/package.json:9`)
3. 영향: 권한/스케줄/알림/회비 로직의 회귀를 사전 탐지하기 어렵습니다.
4. 권장 조치:
1. Firestore Rules 에뮬레이터 테스트 추가.
2. Functions 핵심 경로(승인/권한/스케줄) 테스트 추가.
3. Flutter 위젯/리포지토리 회귀 테스트 최소 세트 구성.

### 6) [Low] Functions lint 실패 상태
1. `npm run lint`가 1건 오류로 실패합니다.
2. 위치: `functions/src/index.ts:411` (`quote-props` 규칙 위반)
3. 영향: CI 품질 게이트 신뢰도 저하.
4. 권장 조치: lint 오류 수정 및 CI 강제.

### 7) [Low] README 미정비
1. README가 기본 템플릿 문구 상태입니다. (`README.md:3`, `README.md:7`)
2. 영향: 온보딩 및 운영 배포 과정에서 시행착오 증가.
3. 권장 조치:
1. 실행/환경 설정(Firebase, APP_ENV) 문서화.
2. 배포 절차(앱 + Functions) 문서화.
3. 데이터 모델/권한 모델 요약 추가.

## 즉시 조치 권장 Top 3
1. 승인 플로우 권한 상승 취약점 차단 (rules + 서버 강제 초기화).
2. `seedDemoData` 운영 환경 차단.
3. Rules/Functions 보안 핵심 경로 테스트부터 우선 추가.
