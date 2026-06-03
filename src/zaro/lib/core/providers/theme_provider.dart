import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeKey = 'theme_mode';

/// main()에서 미리 로드한 초기 테마를 전달받아 즉시 적용
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier(ThemeMode.dark);
});

Future<ThemeMode> loadSavedTheme() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_kThemeKey) == 'light' ? ThemeMode.light : ThemeMode.dark;
}

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier(super.initial);

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kThemeKey, next == ThemeMode.light ? 'light' : 'dark');
  }
}
