import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart'
    show KakaoSdk;

import 'config/app_config.dart';
import 'config/app_keys.dart';
import 'config/app_strings.dart';
import 'dev/firestore_metrics.dart';
import 'firebase_options.dart';
import 'providers.dart';
import 'screens/auth/login_screen.dart';
import 'screens/events/event_detail_screen.dart';
import 'screens/finance/finance_screen.dart';
import 'screens/groups/group_audit_logs_screen.dart';
import 'screens/groups/feedback_hub_screen.dart';
import 'screens/groups/group_members_screen.dart';
import 'screens/groups/group_suggestions_screen.dart';
import 'screens/groups/group_switcher_screen.dart';
import 'screens/invite/invite_manage_screen.dart';
import 'screens/invite/join_invite_screen.dart';
import 'screens/notices/notices_screen.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/search/integrated_search_screen.dart';
import 'screens/settings/beta_report_screen.dart';
import 'screens/settings/notification_settings_screen.dart';
import 'screens/shell/app_shell.dart';
import 'services/app_logger.dart';
import 'services/profile_policy.dart';
import 'services/user_profile_service.dart';
import 'theme/app_theme.dart';
import 'widgets/transition_page.dart';

Future<void> main() async {
  AppLogger.installGlobalHandlers();
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && kKakaoNativeAppKey != 'REPLACE_ME') {
    KakaoSdk.init(nativeAppKey: kKakaoNativeAppKey);
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runZonedGuarded(
    () {
      if (AppConfig.enableDevTools) {
        FirestoreMetrics.instance.startPeriodicDump();
      }
      runApp(const ProviderScope(child: MoyeoraApp()));
    },
    (error, stack) {
      unawaited(
        AppLogger.error('uncaught_zone_error', error: error, stack: stack),
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        pageBuilder: (context, state) =>
            buildTransitionPage(state, const RootGate()),
        routes: [
          GoRoute(
            path: 'notice/:noticeId',
            pageBuilder: (context, state) {
              return buildTransitionPage(
                state,
                NoticeDetailScreen(noticeId: state.pathParameters['noticeId']!),
              );
            },
          ),
          GoRoute(
            path: 'event/:eventId',
            pageBuilder: (context, state) => buildTransitionPage(
              state,
              EventDetailScreen(eventId: state.pathParameters['eventId']!),
            ),
          ),
          GoRoute(
            path: 'search',
            pageBuilder: (context, state) => buildTransitionPage(
              state,
              IntegratedSearchScreen(
                initialGroupId: state.uri.queryParameters['groupId'],
              ),
            ),
          ),
          GoRoute(
            path: 'notification-settings',
            pageBuilder: (context, state) =>
                buildTransitionPage(state, const NotificationSettingsScreen()),
          ),
          GoRoute(
            path: 'beta-report',
            pageBuilder: (context, state) =>
                buildTransitionPage(state, const BetaReportScreen()),
          ),
          GoRoute(
            path: 'profile',
            pageBuilder: (context, state) =>
                buildTransitionPage(state, const ProfileScreen()),
          ),
          GoRoute(
            path: 'join-invite',
            pageBuilder: (context, state) => buildTransitionPage(
              state,
              JoinInviteScreen(initialCode: state.uri.queryParameters['code']),
            ),
          ),
          GoRoute(
            path: 'invite',
            pageBuilder: (context, state) {
              final groupId = state.uri.queryParameters['groupId'];
              if (groupId == null || groupId.isEmpty) {
                return buildTransitionPage(
                  state,
                  const Scaffold(body: Center(child: Text(AppStrings.groupIdRequired))),
                );
              }
              return buildTransitionPage(
                state,
                InviteManageScreen(groupId: groupId),
              );
            },
          ),
          GoRoute(
            path: 'members',
            pageBuilder: (context, state) {
              final groupId = state.uri.queryParameters['groupId'];
              if (groupId == null || groupId.isEmpty) {
                return buildTransitionPage(
                  state,
                  const Scaffold(body: Center(child: Text(AppStrings.groupIdRequired))),
                );
              }
              return buildTransitionPage(
                state,
                GroupMembersScreen(groupId: groupId),
              );
            },
          ),
          GoRoute(
            path: 'audit-logs',
            redirect: (context, state) {
              final groupId = state.uri.queryParameters['groupId'];
              if (groupId == null || groupId.isEmpty) {
                return '/operation-logs';
              }
              return '/operation-logs?groupId=$groupId';
            },
          ),
          GoRoute(
            path: 'operation-logs',
            pageBuilder: (context, state) {
              final groupId = state.uri.queryParameters['groupId'];
              if (groupId == null || groupId.isEmpty) {
                return buildTransitionPage(
                  state,
                  const Scaffold(body: Center(child: Text(AppStrings.groupIdRequired))),
                );
              }
              return buildTransitionPage(
                state,
                GroupAuditLogsScreen(groupId: groupId),
              );
            },
          ),
          GoRoute(
            path: 'finance',
            pageBuilder: (context, state) {
              final groupId = state.uri.queryParameters['groupId'];
              if (groupId == null || groupId.isEmpty) {
                return buildTransitionPage(
                  state,
                  const Scaffold(body: Center(child: Text(AppStrings.groupIdRequired))),
                );
              }
              return buildTransitionPage(
                state,
                FinanceScreen(groupId: groupId),
              );
            },
          ),
          GoRoute(
            path: 'feedback',
            pageBuilder: (context, state) {
              final groupId = state.uri.queryParameters['groupId'];
              if (groupId == null || groupId.isEmpty) {
                return buildTransitionPage(
                  state,
                  const Scaffold(body: Center(child: Text(AppStrings.groupIdRequired))),
                );
              }
              return buildTransitionPage(
                state,
                FeedbackHubScreen(groupId: groupId),
              );
            },
          ),
          GoRoute(
            path: 'suggestions',
            pageBuilder: (context, state) {
              final groupId = state.uri.queryParameters['groupId'];
              if (groupId == null || groupId.isEmpty) {
                return buildTransitionPage(
                  state,
                  const Scaffold(body: Center(child: Text(AppStrings.groupIdRequired))),
                );
              }
              return buildTransitionPage(
                state,
                GroupSuggestionsScreen(groupId: groupId),
              );
            },
          ),
        ],
      ),
    ],
  );
});

class MoyeoraApp extends ConsumerWidget {
  const MoyeoraApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appThemeMode = ref.watch(themeModeProvider);
    final themeMode = switch (appThemeMode) {
      AppThemeMode.light => ThemeMode.light,
      AppThemeMode.dark => ThemeMode.dark,
      AppThemeMode.system => ThemeMode.system,
    };
    return MaterialApp.router(
      title: 'Moyeora',
      debugShowCheckedModeBanner: AppConfig.showDebugBanner,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final selectedGroupId = ref.watch(selectedGroupIdProvider);
    final onboarding = ref.watch(onboardingSeenProvider);

    return auth.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text("인증 상태 오류: $error"))),
      data: (user) {
        return onboarding.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, st) =>
              Scaffold(body: Center(child: Text("온보딩 상태 오류: $e"))),
          data: (seen) {
            if (!seen) return const OnboardingScreen();
            if (user == null) return const LoginScreen();
            final profileStream = FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots()
                .timeout(
                  const Duration(seconds: 10),
                  onTimeout: (sink) => sink.close(),
                );
            FirestoreMetrics.instance.addListens();
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: profileStream,
              builder: (context, profileSnap) {
                if (profileSnap.hasError) {
                  return Scaffold(
                    body: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('프로필을 불러오지 못했습니다.'),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context.go('/'),
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (!profileSnap.hasData) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final profile = profileSnap.data!.data();
                if (profile == null) {
                  UserProfileService.ensurePasswordProfile(uid: user.uid);
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                final nickname = (profile['nickname']?.toString() ?? '').trim();
                if (!ProfilePolicy.isValidRealName(nickname)) {
                  return const ProfileScreen(
                    forceSetup: true,
                    forceMessage: "실명 프로필 설정을 완료해야 계속할 수 있습니다.",
                  );
                }
                if (selectedGroupId == null) {
                  return const GroupSwitcherScreen();
                }
                return const AppShell();
              },
            );
          },
        );
      },
    );
  }
}
