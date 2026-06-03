import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'config/app_strings.dart';
import 'repositories/events_repository.dart';
import 'repositories/group_repository.dart';
import 'repositories/notices_repository.dart';
import 'services/home_dashboard_service.dart';

final bool kEnableDebugPanel = AppConfig.enableDevTools;

const String kPermissionDeniedMessage = AppStrings.permissionDenied;

const String kMembershipRequiredMessage = AppStrings.membershipRequired;

final selectedGroupIdProvider =
    NotifierProvider<SelectedGroupIdNotifier, String?>(
      SelectedGroupIdNotifier.new,
    );

final debugFirestoreErrorProvider =
    NotifierProvider<DebugFirestoreErrorNotifier, String?>(
      DebugFirestoreErrorNotifier.new,
    );

final currentFcmTokenProvider =
    NotifierProvider<CurrentFcmTokenNotifier, String?>(
      CurrentFcmTokenNotifier.new,
    );

final tokenStoredProvider = NotifierProvider<TokenStoredNotifier, bool?>(
  TokenStoredNotifier.new,
);

final shellTabIndexProvider = NotifierProvider<ShellTabIndexNotifier, int>(
  ShellTabIndexNotifier.new,
);

final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

final onboardingSeenProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance()
      .timeout(const Duration(seconds: 5));
  return prefs.getBool('onboarding_seen') ?? false;
});

enum AppThemeMode { system, light, dark }

final themeModeProvider = NotifierProvider<ThemeModeNotifier, AppThemeMode>(
  ThemeModeNotifier.new,
);

final homeKpiProvider = FutureProvider.autoDispose
    .family<Map<String, String>, (String, String)>((ref, args) {
  final (groupId, uid) = args;
  return HomeDashboardService.loadHomeKpi(groupId, uid);
});

final homeEngagementProvider = FutureProvider.autoDispose
    .family<Map<String, String>, (String, String)>((ref, args) {
  final (groupId, uid) = args;
  return HomeDashboardService.loadHomeEngagement(groupId, uid);
});

final myHomeSummaryProvider = FutureProvider.autoDispose
    .family<Map<String, String>, (String, String)>((ref, args) {
  final (groupId, uid) = args;
  return HomeDashboardService.loadMyHomeSummary(groupId, uid);
});

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepository();
});

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return EventsRepository();
});

final noticesRepositoryProvider = Provider<NoticesRepository>((ref) {
  return NoticesRepository();
});

class SelectedGroupIdNotifier extends Notifier<String?> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'last_selected_group_id';

  @override
  String? build() {
    _loadLastSelectedGroup();
    return null;
  }

  Future<void> _loadLastSelectedGroup() async {
    final groupId = await _storage.read(key: _key);
    if (groupId != null && groupId.isNotEmpty) {
      state = groupId;
    }
  }

  void setGroup(String? groupId) {
    state = groupId;
    if (groupId == null || groupId.isEmpty) {
      _storage.delete(key: _key);
    } else {
      _storage.write(key: _key, value: groupId);
    }
  }
}

class DebugFirestoreErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setError(String? value) {
    state = value;
  }
}

class CurrentFcmTokenNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setToken(String? value) {
    state = value;
  }
}

class TokenStoredNotifier extends Notifier<bool?> {
  @override
  bool? build() => null;

  void setStored(bool? value) {
    state = value;
  }
}

class ShellTabIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setIndex(int index) {
    if (index < 0 || index > 5) return;
    state = index;
  }
}

class ThemeModeNotifier extends Notifier<AppThemeMode> {
  @override
  AppThemeMode build() {
    _load();
    return AppThemeMode.system;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('theme_mode') ?? 'system';
    if (raw == 'light') {
      state = AppThemeMode.light;
    } else if (raw == 'dark') {
      state = AppThemeMode.dark;
    } else {
      state = AppThemeMode.system;
    }
  }

  Future<void> setMode(AppThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
  }
}
