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
