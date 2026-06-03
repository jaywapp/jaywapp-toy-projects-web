import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/project_provider.dart';
import '../../domain/models/project_model.dart';

class ProjectListScreen extends ConsumerStatefulWidget {
  const ProjectListScreen({super.key});

  @override
  ConsumerState<ProjectListScreen> createState() => _ProjectListScreenState();
}

class _ProjectListScreenState extends ConsumerState<ProjectListScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(projectNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'ZARO₩',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            color: AppColors.primary,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '전체 검색',
            onPressed: () => context.push('/search'),
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_outlined),
            tooltip: '전체 통계',
            onPressed: () => context.push('/statistics'),
          ),
          IconButton(
            icon: Icon(_showArchived ? Icons.inventory_2 : Icons.inventory_2_outlined),
            tooltip: _showArchived ? '보관 숨기기' : '보관된 가계부 보기',
            onPressed: () => setState(() => _showArchived = !_showArchived),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
            tooltip: '설정',
          ),
          IconButton(
            icon: const Icon(Icons.logout_outlined),
            onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      body: projectsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (projects) {
          final visible = projects.where((p) => _showArchived ? p.isArchived : !p.isArchived).toList();
          return visible.isEmpty ? _buildEmpty(context) : _buildList(context, visible, projects);
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'add_project',
            onPressed: () => context.push('/projects/create'),
            backgroundColor: context.appColors.surface,
            mini: true,
            child: const Icon(Icons.create_new_folder_outlined),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.extended(
            heroTag: 'add_expense',
            onPressed: () => context.push('/ai-input'),
            backgroundColor: AppColors.primary,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('지출 입력'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _showArchived ? Icons.inventory_2_outlined : Icons.folder_open,
            size: 64,
            color: context.appColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            _showArchived ? '보관된 가계부가 없습니다' : '가계부가 없습니다',
            style: TextStyle(color: context.appColors.textSecondary),
          ),
          if (!_showArchived) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.push('/projects/create'),
              child: const Text('첫 가계부 만들기'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context, List<ProjectModel> visible, List<ProjectModel> all) {
    final parents = visible.where((p) => p.type != ProjectType.sub).toList();
    final allSubs = all.where((p) => p.type == ProjectType.sub).toList();

    if (_showArchived) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: parents.map((p) => _ProjectCard(
              project: p,
              subProjects: allSubs.where((s) => s.parentProjectId == p.id).toList(),
            )).toList(),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(projectNotifierProvider.notifier).refresh(),
      child: ReorderableListView(
        padding: const EdgeInsets.all(16),
        onReorder: (oldIndex, newIndex) async {
          if (newIndex > oldIndex) newIndex--;
          final repo = ref.read(projectRepositoryProvider);
          final reordered = [...parents];
          final item = reordered.removeAt(oldIndex);
          reordered.insert(newIndex, item);
          for (var i = 0; i < reordered.length; i++) {
            await repo.updateProjectOrder(reordered[i].id, i);
          }
          ref.read(projectNotifierProvider.notifier).refresh();
        },
        children: parents.map((p) => _ProjectCard(
              key: ValueKey(p.id),
              project: p,
              subProjects: allSubs.where((s) => s.parentProjectId == p.id).toList(),
            )).toList(),
      ),
    );
  }
}

class _ProjectCard extends ConsumerWidget {
  final ProjectModel project;
  final List<ProjectModel> subProjects;

  const _ProjectCard({super.key, required this.project, required this.subProjects});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(projectBalanceProvider(project.id));
    final formatter = NumberFormat('#,###', 'ko_KR');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/projects/${project.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(project.icon ?? '📁', style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      project.name,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ),
                  _buildTypeBadge(project.type),
                ],
              ),
              const SizedBox(height: 12),
              balanceAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => const SizedBox.shrink(),
                data: (balance) {
                  final ratio = balance.income > 0
                      ? (balance.expense / balance.income).clamp(0.0, 1.0)
                      : 0.0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              '지출 ₩${formatter.format(balance.expense)}',
                              style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              '잔액 ₩${formatter.format(balance.balance)}',
                              style: TextStyle(
                                color: balance.balance < 0 ? Colors.red : AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ratio,
                          backgroundColor: context.appColors.surface,
                          color: ratio >= 1.0 ? Colors.red : AppColors.primary,
                          minHeight: 6,
                        ),
                      ),
                    ],
                  );
                },
              ),
              if (subProjects.isNotEmpty) ...[
                const Divider(height: 20),
                ...subProjects.map((s) => _SubProjectRow(subProject: s)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(ProjectType type) {
    final labels = {
      ProjectType.parent: ('상위', AppColors.primaryLight),
      ProjectType.standalone: ('독립', AppColors.primaryDark),
      ProjectType.sub: ('하위', Colors.grey),
    };
    final (label, color) = labels[type]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}

class _SubProjectRow extends ConsumerWidget {
  final ProjectModel subProject;

  const _SubProjectRow({required this.subProject});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(projectBalanceProvider(subProject.id));
    final formatter = NumberFormat('#,###', 'ko_KR');

    return InkWell(
      onTap: () => context.push('/projects/${subProject.id}'),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            const SizedBox(width: 8),
            Container(width: 2, height: 16, color: AppColors.primaryLight.withValues(alpha: 0.4)),
            const SizedBox(width: 10),
            Text(subProject.icon ?? '📁', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(subProject.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            ),
            balanceAsync.when(
              loading: () => const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.5)),
              error: (_, __) => const SizedBox.shrink(),
              data: (balance) => Text(
                '잔액 ${balance.balance < 0 ? '-' : ''}₩${formatter.format(balance.balance.abs())}',
                style: TextStyle(
                  fontSize: 12,
                  color: balance.balance < 0 ? AppColors.error : context.appColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 14, color: context.appColors.textHint),
          ],
        ),
      ),
    );
  }
}
