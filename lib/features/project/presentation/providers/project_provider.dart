import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/repositories/project_repository.dart';
import '../../domain/models/project_model.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository();
});

final userProjectsProvider = FutureProvider<List<ProjectModel>>((ref) async {
  final authState = ref.watch(authStateProvider);
  final uid = authState.valueOrNull?.uid;
  if (uid == null) return [];
  return ref.read(projectRepositoryProvider).getUserProjects(uid);
});

final projectDetailProvider =
    FutureProvider.family<ProjectModel, String>((ref, projectId) async {
  return ref.read(projectRepositoryProvider).getProject(projectId);
});

final subProjectsProvider =
    FutureProvider.family<List<ProjectModel>, String>((ref, parentId) async {
  return ref.read(projectRepositoryProvider).getSubProjects(parentId);
});

final projectBalanceProvider =
    FutureProvider.family<ProjectBalance, String>((ref, projectId) async {
  return ref.read(projectRepositoryProvider).getBalance(projectId);
});

// 하위 호환: 정산에서 사용
final projectSpentProvider =
    FutureProvider.family<double, String>((ref, projectId) async {
  return ref.read(projectRepositoryProvider).getSpentAmount(projectId);
});

class ProjectNotifier extends AsyncNotifier<List<ProjectModel>> {
  @override
  Future<List<ProjectModel>> build() async {
    return ref.watch(userProjectsProvider.future);
  }

  Future<void> createProject({
    required String name,
    String? icon,
    required ProjectType type,
    String? parentProjectId,
    required double initialIncome,
    CurrencyCode currency = CurrencyCode.krw,
  }) async {
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    await ref.read(projectRepositoryProvider).createProject(
          name: name,
          icon: icon,
          type: type,
          parentProjectId: parentProjectId,
          initialIncome: initialIncome,
          creatorId: uid,
          currency: currency,
        );

    ref.invalidate(userProjectsProvider);
    if (parentProjectId != null) {
      ref.invalidate(subProjectsProvider(parentProjectId));
    }
    state = await AsyncValue.guard(() => ref.read(userProjectsProvider.future));
  }

  Future<void> refresh() async {
    ref.invalidate(userProjectsProvider);
    state = await AsyncValue.guard(() => ref.read(userProjectsProvider.future));
  }
}

final projectNotifierProvider =
    AsyncNotifierProvider<ProjectNotifier, List<ProjectModel>>(
  ProjectNotifier.new,
);
