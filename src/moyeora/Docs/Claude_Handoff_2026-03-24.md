# Claude Handoff - 2026-03-24

## Repository

- Git root: `D:\workspace\moyeora\moyeora_flutter\moyeora`
- Working branch: `feat/fix-kakao-platform-config`
- PR: `https://github.com/jaywapp/moyeora/pull/54`

## Goal

- `web`, `android`, `iOS`에서 카카오 로그인 동작을 안정화
- 플랫폼 설정 누락과 Functions secret 처리 문제를 정리하는 작업

## Completed Work

### Platform config

- Android manifest placeholder를 실제 카카오 scheme로 수정
- iOS `Info.plist`에 카카오 URL scheme 추가
- 문서/설정 기준을 실제 앱 식별자 기준으로 정리

### Firebase Functions

- Firebase 프로젝트 `moyeora-dev`에 `KAKAO_REST_API_KEY` secret 등록 완료
- Functions 코드에서 `process.env.KAKAO_REST_API_KEY` 대신 `defineSecret("KAKAO_REST_API_KEY")` 사용하도록 수정
- 카카오 인증 Functions에 secret 바인딩 적용
- `.env`와 Secret Manager 중복 충돌 제거 후 재배포 완료

### Deploy status

- `firebase deploy --only functions --project moyeora-dev` 성공
- `authExchangeKakao`, `authExchangeKakaoCode` 포함 전체 Functions 업데이트 완료

## Key Files

- `android/app/build.gradle.kts`
- `ios/Runner/Info.plist`
- `functions/src/index.ts`
- `functions/lib/index.js`
- `functions/lib/index.js.map`

## Kakao App Settings Assumed

- Web domain: `https://moyeora-dev.web.app/`
- Redirect URI: `https://moyeora-dev.web.app/kakao_login_callback.html`
- Android package name: `com.jaywapp.moyeora`
- iOS Bundle ID: `com.jaywapp.moyeora`
- iOS scheme: `kakao9311d9d4b7a253e9b7469099c3efa983`

## Local Key Notes

- 로컬 파일: `D:\workspace\moyeora\.kakao`
- 포함 정보:
  - REST API Key: `db519d9ce8f61cdae46ef20829fef809`
  - JavaScript Key: `2111eec6e72d297be6b4bd9ed7fd85a2`
  - Native App Key: `9311d9d4b7a253e9b7469099c3efa983`
- 운영 런타임에서는 REST API Key를 Functions Secret Manager에서 사용 중

## Important Implementation Detail

- `functions/.env`에 `KAKAO_REST_API_KEY`를 다시 넣으면 Secret Manager와 충돌해 재배포가 실패함
- `.env`는 유지하더라도 해당 이름은 비워 두거나 다른 이름으로만 써야 함
- 실제 배포 실패 메시지 원인: `Secret environment variable overlaps non secret environment variable`

## Remaining Work

1. 실제 플랫폼 검증
- Web: 로그인 후 콜백 복귀와 Firebase 로그인 확인
- Android: 카카오톡 또는 계정 로그인 후 앱 복귀 확인
- iOS: Safari/카카오톡 로그인 후 앱 복귀 확인

2. 운영 안정화
- `firebase-functions` 버전이 오래됐다는 경고가 있으므로 여유 있을 때 업그레이드 검토
- Node.js 20 런타임 deprecation 일정이 표시되므로 Functions 런타임 업그레이드 계획 필요

3. 문서 보강
- Kakao console 등록값과 빌드 주입 방법을 `Docs`나 `README`에 더 명확히 남길 수 있음

## Validation Notes

- `flutter analyze` 통과
- `flutter test` 통과
- `functions`에서 `npm run build` 통과
- Functions 재배포 통과

## Cautions

- 다음 수정 파일들은 자동 생성물이어서 Functions 소스 변경 후 함께 갱신될 수 있음
  - `functions/lib/index.js`
  - `functions/lib/index.js.map`
- 저장소에 linux/windows generated plugin 파일 변경이 있었지만 이번 작업과 무관하므로 건드리지 않았음

