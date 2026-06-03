# jaywapp-dart-google-sheet

Dart용 Google Sheets API 래퍼 라이브러리.

## 기술 스택

| | |
|--|--|
| 언어 | Dart |
| 외부 의존 | googleapis, google_sign_in |

## 구조

```
lib/
├── google-sheet-manager.dart  # GoogleSheetManager 클래스 (Get / Set / GetActive)
└── google-sheet-range.dart    # 범위 객체 (A1 표기법 처리)
```

## 사용법

```dart
final manager = GoogleSheetManager(client: authenticatedClient);

// 셀 읽기
final values = await manager.get(range: GoogleSheetRange('Sheet1', 'A1', 'C10'));

// 셀 쓰기
await manager.set(range: GoogleSheetRange('Sheet1', 'A1'), values: [['hello']]);
```
