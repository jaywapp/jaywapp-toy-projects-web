# Moyeora

모임 운영을 위한 Flutter + Firebase 프로젝트입니다.

## 기술 스택
- Flutter (Riverpod, GoRouter)
- Firebase Auth / Firestore / Functions / Messaging
- Cloud Functions (TypeScript, Node 20)

## 앱 실행
1. 의존성 설치
```bash
flutter pub get
```

2. 실행
```bash
flutter run
```

3. 환경 선택 (선택)
```bash
flutter run --dart-define=APP_ENV=dev
flutter run --dart-define=APP_ENV=stage
flutter run --dart-define=APP_ENV=prod
```

## 품질 점검
```bash
flutter analyze
flutter test
```

## Android 내부 테스트 자동 배포 (Fastlane)
Play Console 내부 테스트 트랙 업로드를 `fastlane`으로 자동화할 수 있습니다.

1. 사전 준비
- Firebase/Play 연결된 서비스 계정 JSON 키를 준비합니다.
- 파일 경로 예시: `android/play-service-account.json`
- 앱 패키지명은 `com.jaywapp.moyeora` 기준입니다.

2. Fastlane 설치 (Android 디렉터리)
```bash
cd android
bundle install
```

3. 내부 테스트 트랙 업로드
- 빌드 + 업로드:
```bash
bundle exec fastlane android internal_release release_name:"1.0.0 (1) - 내부 테스트" release_notes:"첫 내부 테스트 배포"
```
- 이미 빌드된 AAB 업로드:
```bash
bundle exec fastlane android internal_upload aab:"../build/app/outputs/bundle/release/app-release.aab" release_name:"1.0.0 (1) - 내부 테스트" release_notes:"첫 내부 테스트 배포"
```

4. 환경변수로 경로/값 오버라이드 (선택)
```bash
PLAY_SERVICE_ACCOUNT_JSON=play-service-account.json
PLAY_PACKAGE_NAME=com.jaywapp.moyeora
AAB_PATH=../build/app/outputs/bundle/release/app-release.aab
RELEASE_NAME=1.0.0 (1) - 내부 테스트
RELEASE_NOTES=첫 내부 테스트 배포
IN_APP_UPDATE_PRIORITY=0
```

### GitHub Actions 연동
자동 + 수동 실행으로 내부 테스트 트랙 배포:
- 워크플로 파일: `.github/workflows/android-internal-release.yml`
- 자동 실행: `main` 브랜치 푸시 시
- 수동 실행: GitHub > Actions > `Android Internal Release` > `Run workflow`

필수 GitHub Secrets:
- `ANDROID_UPLOAD_KEYSTORE_BASE64`: 업로드 키스토어(`.jks`)를 base64로 인코딩한 값
- `ANDROID_UPLOAD_STORE_PASSWORD`: 키스토어 비밀번호
- `ANDROID_UPLOAD_KEY_ALIAS`: 키 alias
- `ANDROID_UPLOAD_KEY_PASSWORD`: 키 비밀번호
- `PLAY_SERVICE_ACCOUNT_JSON`: Google Play API 서비스 계정 JSON 원문

`ANDROID_UPLOAD_KEYSTORE_BASE64` 생성 예시:
```bash
base64 -w 0 D:/keys/moyeora-upload.jks
```
Windows PowerShell 예시:
```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("D:\keys\moyeora-upload.jks"))
```

## Firebase Functions
`functions` 디렉터리에서 실행합니다.

1. 빌드 / 린트 / 테스트
```bash
npm run build
npm run lint
npm run test
```

2. 에뮬레이터 실행
```bash
npm run serve
```

3. 배포
```bash
npm run deploy
```

### 웹 카카오 로그인 설정
- `lib/config/app_keys.dart`의 `kKakaoJavaScriptKey`를 실제 키로 교체합니다.
- 권장: `lib/config/app_keys.dart`의 `kKakaoRestApiKey`도 함께 설정합니다.
- Android Kakao scheme는 `kakao9311d9d4b7a253e9b7469099c3efa983` 기준으로 설정돼 있습니다.
- Android 패키지명은 `com.jaywapp.moyeora` 기준으로 Kakao Developers에 등록해야 합니다.
- iOS URL scheme에도 `kakao9311d9d4b7a253e9b7469099c3efa983`를 등록해야 합니다.
- Kakao Developer 콘솔 Redirect URI에 `https://<your-domain>/kakao_login_callback.html`를 등록합니다.
- Functions 환경 변수에 `KAKAO_REST_API_KEY`를 설정합니다.
- 선택으로 `KAKAO_CLIENT_SECRET`도 설정할 수 있습니다.

로컬/에뮬레이터 예시(`functions/.env`):
```bash
KAKAO_REST_API_KEY=...
KAKAO_CLIENT_SECRET=...
```

## 운영 안전 가드
- `seedDemoData` 함수는 기본적으로 운영 환경에서 차단됩니다.
- 에뮬레이터가 아닌 환경에서 데모 시딩을 허용하려면 `ALLOW_DEMO_SEED=true`를 명시적으로 설정해야 합니다.
- 통계 재계산은 `recomputeGroupPeriodStats` callable을 통해 운영진 권한으로만 수행됩니다.

## 권한 모델 요약
- 그룹 멤버 권한은 `groups/{groupId}/members/{uid}`의 `role`/`permissions`를 기준으로 판정합니다.
- 가입 승인(`approveMember`) 시 서버가 `role: member`, `permissions: []`를 강제하여 초기 권한 상승을 방지합니다.
- 역할 변경은 `setRoleAndClaims`에서 처리하며 Firebase Custom Claims를 함께 갱신합니다.
- 모임장 위임은 `delegateGroupOwner` callable에서만 허용됩니다.

## 의견/투표 기능
- 의견 건의: `groups/{groupId}/suggestions`
- 투표: `groups/{groupId}/polls`
- 투표 응답: `groups/{groupId}/polls/{pollId}/votes/{uid}`

## 오류 추적 로그
- 클라이언트 예외는 `logClientEvent` callable을 통해 `appLogs` 컬렉션에 적재됩니다.
- 전역 핸들러(Flutter/Platform/Zone)가 기본 연결되어 있습니다.

## Spark 모드 운영 가이드
- 기본값은 Spark 친화 모드이며, 서버 의존 기능이 비활성화됩니다.
- 제어 플래그: `ENABLE_SERVER_FEATURES` (`false`가 기본값)

### Spark 기본 모드(`ENABLE_SERVER_FEATURES=false`)
- 비활성화 기능:
  - 웹 카카오 로그인 (`authExchangeKakaoCode` 의존)
  - 모임장 위임 (`delegateGroupOwner` 의존)
  - 원격 클라이언트 오류 로그 적재 (`logClientEvent` 의존)
- 동작 방식:
  - 카카오 로그인 버튼은 비활성 안내로 대체
  - 팀원 권한 메뉴의 모임장 위임 항목 숨김
  - 오류 로그는 로컬 콘솔 출력만 수행

### 서버 기능 활성 모드(`ENABLE_SERVER_FEATURES=true`)
- 사용 예시:
```bash
flutter run --dart-define=ENABLE_SERVER_FEATURES=true
flutter build web --release --dart-define=APP_ENV=prod --dart-define=ENABLE_SERVER_FEATURES=true
```
- 주의:
  - 서버 의존 기능을 실제 사용하려면 관련 Cloud Functions가 배포되어 있어야 합니다.

## 주요 경로
- 앱 진입점: `lib/main.dart`
- 통계 화면: `lib/screens/stats/stats_screen.dart`
- 보안 규칙: `firestore.rules`
- Functions 엔트리: `functions/src/index.ts`
