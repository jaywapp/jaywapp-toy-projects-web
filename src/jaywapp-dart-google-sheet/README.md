# jaywapp-dart-google-sheet

Google Sheets 범위·행 조회와 갱신을 제공하는 로컬 Dart 패키지다. 외부 의존성은 기존 BeMyColleague와 같은 google_sign_in, googleapis, http 범위를 사용한다.

실제 구현은 lib/google_sheet_manager.dart, lib/google_sheet_range.dart, lib/google_http_client.dart에 하나씩 존재한다. 이전 최상위 하이픈 파일명은 같은 구현을 export하는 호환 경로다.

BeMyColleague의 pubspec.yaml은 ../../jaywapp-dart-google-sheet를 path 의존성으로 참조한다. 사라진 원격 서브모듈을 복제할 필요가 없다.

```dart
import 'package:jaywapp_google_sheet/google_sheet_manager.dart';
import 'package:jaywapp_google_sheet/google_sheet_range.dart';

final manager = GoogleSheetManager(googleAccount, spreadsheetId);
final rows = await manager.GetActiveValues('Sheet1');
final range = GoogleSheetRange.Create('Sheet1', 1, 1, 3, 10);
```

검증: BeMyColleague 앱 디렉터리에서 flutter test --no-pub. 외부 계정 없이 빈 계정과 테스트 행으로 매니저 경계를 검증한다. 저장소 루트의 tests/google-sheet-range.test.dart는 순수 Dart 범위 변환을 검증한다.