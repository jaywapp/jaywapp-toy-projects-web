import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/project/presentation/screens/project_list_screen.dart';
import '../../features/project/presentation/screens/project_create_screen.dart';
import '../../features/project/presentation/screens/project_detail_screen.dart';
import '../../features/ai_input/presentation/screens/ai_input_screen.dart';
import '../../features/transaction/presentation/screens/transaction_list_screen.dart';
import '../../features/report/presentation/screens/monthly_report_screen.dart';
import '../../features/settlement/presentation/screens/settlement_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';
import '../../features/project/presentation/screens/join_screen.dart';
import '../../features/statistics/presentation/screens/statistics_screen.dart';
import '../../features/statistics/presentation/screens/global_statistics_screen.dart';
import '../../features/search/presentation/screens/global_search_screen.dart';

class _RouterNotifier extends ChangeNotifier {
  late final ProviderSubscription<Object?> _sub;

  _RouterNotifier(Ref ref) {
    _sub = ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  void close() {
    _sub.close();
    dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _RouterNotifier(ref);
  ref.onDispose(notifier.close);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      if (authState.isLoading) return null;
      final isLoggedIn = authState.valueOrNull != null;
      final isLoginRoute = state.matchedLocation == '/login';

      if (!isLoggedIn && !isLoginRoute) return '/login';
      if (isLoggedIn && isLoginRoute) return '/projects';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/projects',
        builder: (context, state) => const ProjectListScreen(),
      ),
      GoRoute(
        path: '/projects/create',
        builder: (context, state) {
          final parentId = state.uri.queryParameters['parentId'];
          return ProjectCreateScreen(parentProjectId: parentId);
        },
      ),
      GoRoute(
        path: '/projects/:id',
        builder: (context, state) => ProjectDetailScreen(
          projectId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/projects/:id/transactions',
        builder: (context, state) => TransactionListScreen(
          projectId: state.pathParameters['id']!,
          projectName: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: '/projects/:id/report',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return MonthlyReportScreen(project: extra!['project']);
        },
      ),
      GoRoute(
        path: '/projects/:id/settlement',
        builder: (context, state) {
          final memberIds = (state.uri.queryParameters['members'] ?? '')
              .split(',')
              .where((s) => s.isNotEmpty)
              .toList();
          return SettlementScreen(
            projectId: state.pathParameters['id']!,
            projectName: state.uri.queryParameters['name'] ?? '',
            memberIds: memberIds,
          );
        },
      ),
      GoRoute(
        path: '/ai-input',
        builder: (context, state) {
          final projectId = state.uri.queryParameters['projectId'];
          return AiInputScreen(initialProjectId: projectId);
        },
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/projects/:id/statistics',
        builder: (context, state) => StatisticsScreen(
          projectId: state.pathParameters['id']!,
          projectName: state.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: '/statistics',
        builder: (context, state) => const GlobalStatisticsScreen(),
      ),
      GoRoute(
        path: '/search',
        builder: (context, state) => const GlobalSearchScreen(),
      ),
      GoRoute(
        path: '/join',
        builder: (context, state) {
          final code = state.uri.queryParameters['code'] ?? '';
          return JoinScreen(code: code);
        },
      ),
    ],
  );
});
