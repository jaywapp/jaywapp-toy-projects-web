# Moyeora Account Link Strategy

## Why Linking Is Needed

동일 사용자가 Google, Email, Kakao를 혼용할 때 계정이 분리되면 다음 문제가 발생합니다.

- 프로필/멤버십 데이터 중복
- 그룹 권한 불일치
- 알림 토큰 분산

따라서 로그인 충돌(`account-exists-with-different-credential`) 시 계정 연결 플로우를 제공해 단일 사용자 계정으로 통합합니다.

## Linking Flows

1. Google 로그인 충돌 감지
  - FirebaseAuth 예외 코드: `account-exists-with-different-credential`
  - 기존 이메일+비밀번호 인증 후 `currentUser.linkWithCredential(pendingCredential)` 수행
2. 프로필 화면 수동 연결
  - `Google 연결`
  - `이메일 연결`
  - 성공 시 연결 provider 목록 동기화

## Merge Rules

연결/재로그인 시 프로필 병합 규칙:

- 닉네임: `profileSource == "user"`이면 사용자 입력값 유지
- 사진: `photoEditedByUser == true`이면 사용자 입력값 유지
- 외부 provider 값은 사용자 수정 이력이 없을 때만 반영

## Edge Cases

1. 동일 이메일로 다른 provider 가입
  - 연결 다이얼로그 유도
2. 사용자가 연결 중 취소
  - 기존 계정 상태 유지
3. 이미 연결된 provider 재연결 시도
  - FirebaseAuth 에러 코드 노출 및 안내
4. Kakao 충돌 케이스
  - 현재는 프로필 내 수동 계정 연결 경로로 통합 유도

## Future-Proofing

- provider별 연결 상태(`linkedProviders`)를 Firestore에 동기화
- 추후 Kakao credential 표준 연동 시 동일 linking 인터페이스에 확장 가능
