# Firestore 보안 규칙 테스트

`@firebase/rules-unit-testing`을 사용하여 `firestore.rules`의 보안 규칙을 검증합니다.

## 사전 요구사항

- Node.js 18 이상
- Firebase CLI (`npm install -g firebase-tools`)
- Java Runtime (Firebase Emulator 실행에 필요)

## 설치

```bash
cd test/rules
npm install
```

## 테스트 실행

### 1. Firebase Emulator 수동 시작 후 테스트

```bash
# 터미널 1: 에뮬레이터 시작
firebase emulators:start --only firestore

# 터미널 2: 테스트 실행
cd test/rules
npm test
```

### 2. Emulator를 자동으로 시작/종료하며 테스트

```bash
cd test/rules
npm run test:emulator
```

> 프로젝트 루트에서 실행해야 합니다.

## 테스트 항목

| 항목 | 설명 |
|------|------|
| 그룹 문서 읽기 | 활성 멤버 허용 / 비인증/비멤버 차단 |
| 멤버 문서 읽기 | 활성 멤버 간 상호 읽기 허용 / pending 차단 |
| 이벤트 읽기 | 활성 멤버 허용 / 비멤버 차단 |
| 초대 코드 만료 | 인증 사용자 읽기 허용 / 비인증 차단 / 삭제 항상 차단 |
| g_demo 예외 | demo_user_[1-5] 멤버 생성 허용 / 패턴 불일치 차단 |
| 공지 권한 | 읽기 허용 / 일반 멤버 생성 차단 |

## 에뮬레이터 포트

Firestore 에뮬레이터 기본 포트: **8080**

`firebase.json`에서 포트를 변경한 경우 `firestore.test.js`의 `port` 값도 함께 수정하세요.
