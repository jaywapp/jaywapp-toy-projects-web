import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyeora/providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // FlutterSecureStorage는 네이티브 플러그인에 의존하므로
  // 테스트에서는 no-op 핸들러로 mock 처리합니다.
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (MethodCall call) async {
        if (call.method == 'read') return null;
        if (call.method == 'write') return null;
        if (call.method == 'delete') return null;
        return null;
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      null,
    );
  });

  group('SelectedGroupIdNotifier', () {
    test('초기 상태는 null이다', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // build()는 null을 반환하고 비동기로 _loadLastSelectedGroup()를 수행
      final initial = container.read(selectedGroupIdProvider);
      expect(initial, isNull);
    });

    test('setGroup으로 그룹 ID를 설정한다', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedGroupIdProvider.notifier).setGroup('group123');
      await Future<void>.delayed(Duration.zero);

      final state = container.read(selectedGroupIdProvider);
      expect(state, equals('group123'));
    });

    test('setGroup(null)으로 그룹 ID를 초기화한다', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedGroupIdProvider.notifier).setGroup('group123');
      await Future<void>.delayed(Duration.zero);
      container.read(selectedGroupIdProvider.notifier).setGroup(null);
      await Future<void>.delayed(Duration.zero);

      final state = container.read(selectedGroupIdProvider);
      expect(state, isNull);
    });

    test('setGroup("")으로 그룹 ID를 초기화한다', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(selectedGroupIdProvider.notifier).setGroup('group123');
      await Future<void>.delayed(Duration.zero);
      container.read(selectedGroupIdProvider.notifier).setGroup('');
      await Future<void>.delayed(Duration.zero);

      final state = container.read(selectedGroupIdProvider);
      expect(state, equals(''));
    });
  });

  group('ThemeModeNotifier', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('초기 상태는 AppThemeMode.system이다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final mode = container.read(themeModeProvider);
      expect(mode, equals(AppThemeMode.system));
    });

    test('setMode(light)로 라이트 모드로 변경된다', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).setMode(AppThemeMode.light);

      expect(container.read(themeModeProvider), equals(AppThemeMode.light));
    });

    test('setMode(dark)로 다크 모드로 변경된다', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).setMode(AppThemeMode.dark);

      expect(container.read(themeModeProvider), equals(AppThemeMode.dark));
    });

    test('SharedPreferences에 저장된 theme_mode=light 값을 로드한다', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': 'light'});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // _load()가 비동기이므로 잠시 대기
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await container.read(themeModeProvider.notifier).setMode(AppThemeMode.light);

      expect(container.read(themeModeProvider), equals(AppThemeMode.light));
    });

    test('setMode 후 system으로 되돌릴 수 있다', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(themeModeProvider.notifier).setMode(AppThemeMode.dark);
      await container.read(themeModeProvider.notifier).setMode(AppThemeMode.system);

      expect(container.read(themeModeProvider), equals(AppThemeMode.system));
    });
  });

  group('ShellTabIndexNotifier', () {
    test('초기 인덱스는 0이다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(shellTabIndexProvider), equals(0));
    });

    test('setIndex로 인덱스를 변경한다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(shellTabIndexProvider.notifier).setIndex(3);

      expect(container.read(shellTabIndexProvider), equals(3));
    });

    test('0~5 범위 밖의 인덱스는 무시된다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(shellTabIndexProvider.notifier).setIndex(2);
      container.read(shellTabIndexProvider.notifier).setIndex(6);

      expect(container.read(shellTabIndexProvider), equals(2));
    });

    test('음수 인덱스는 무시된다', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(shellTabIndexProvider.notifier).setIndex(1);
      container.read(shellTabIndexProvider.notifier).setIndex(-1);

      expect(container.read(shellTabIndexProvider), equals(1));
    });
  });
}
