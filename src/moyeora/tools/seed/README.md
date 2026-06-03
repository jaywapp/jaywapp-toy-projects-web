# Moyeora Seed 실행 가이드

`seed.js`는 Firebase Admin SDK를 사용해 개발용 초기 데이터를 생성한다.

생성 항목:
- 그룹 `g_demo`
- 소유자 멤버 문서 (`USER_UID` 기반)
- 샘플 이벤트 1개
- 고정 공지 1개

## 1) 준비
Node.js 18+ 권장.

```bash
cd D:/workspace/moyeora/moyeora_flutter/moyeora/tools/seed
npm init -y
npm install firebase-admin
```

## 2) 환경변수 설정
필수 환경변수:
- `GOOGLE_APPLICATION_CREDENTIALS`: 서비스 계정 JSON 파일 절대 경로
- `FIREBASE_PROJECT_ID`: `moyeora-dev`
- `USER_UID`: owner로 만들 Firebase Auth 사용자 UID

PowerShell 예시:
```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="D:\keys\moyeora-dev-service-account.json"
$env:FIREBASE_PROJECT_ID="moyeora-dev"
$env:USER_UID="YOUR_FIREBASE_AUTH_UID"
```

## 3) 실행
```bash
cd D:/workspace/moyeora/moyeora_flutter/moyeora/tools/seed
node seed.js
```

성공 시 `Seed complete` 로그와 함께 project/group/owner 정보가 출력된다.
