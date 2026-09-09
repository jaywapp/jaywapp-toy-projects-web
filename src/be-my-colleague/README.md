# be-my-colleague

동호회·클럽 멤버 관리, 회비 추적, 일정 관리를 위한 Flutter 크로스플랫폼 앱.

## 기술 스택

| | |
|--|--|
| 언어 / 프레임워크 | Dart / Flutter (SDK ^3.5.3) |
| 인증 | Google Sign-In |
| 데이터 | Google Sheets API (googleapis ^13.2.0) |
| 지도 | flutter_naver_map |
| UI | Material Design 3 |
| 플랫폼 | Android, iOS, macOS, Windows, Linux |

## 구조

```
lib/
├── main.dart             # 앱 진입점 (LoginScreen)
├── Service/              # GoogleHttpClient, MapService, GoogleSheetManager
├── model/                # Account, Club, Member, Due, Schedule
└── screens/              # home, members, dues, schedule, more
```

## 기능

- Google 계정 로그인
- 클럽/멤버 관리
- 회비 납부 현황 추적
- 일정 관리
- 네이버 지도 연동

## 로컬 의존성과 검증

Sheets 매니저는 같은 모노레포의 ../../jaywapp-dart-google-sheet path 패키지에서 가져온다. 기존 원격 서브모듈 초기화는 필요하지 않다. be_my_colleague에서 flutter pub get 후 flutter test를 실행한다. 실제 로그인 전 첫 화면과 계정 없는 Sheets 경계는 외부 접속 없이 검증한다.
