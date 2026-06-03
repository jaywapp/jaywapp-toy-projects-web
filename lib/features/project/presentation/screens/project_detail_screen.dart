import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../providers/project_provider.dart';
import '../../domain/models/project_model.dart';
import '../../data/repositories/project_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import 'member_manage_screen.dart';
import '../../../allocation/presentation/screens/allocation_screen.dart';
import '../../../allocation/data/repositories/allocation_repository.dart';
import '../../../transaction/data/repositories/recurring_expense_repository.dart';
import '../../../transaction/domain/models/recurring_expense_model.dart';
import '../../../transaction/domain/models/transaction_model.dart';

enum _ProjectAction { edit, budget, categoryBudget, archive, delete }

class ProjectDetailScreen extends ConsumerWidget {
  final String projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projectAsync = ref.watch(projectDetailProvider(projectId));
    final balanceAsync = ref.watch(projectBalanceProvider(projectId));
    final subProjectsAsync = ref.watch(subProjectsProvider(projectId));
    final formatter = NumberFormat('#,###', 'ko_KR');
    final currentUid = ref.watch(authNotifierProvider).value?.id;
    final isViewer = projectAsync.maybeWhen(
      data: (p) {
        final m = p.members.where((m) => m.userId == currentUid).toList();
        return m.isNotEmpty && m.first.role == MemberRole.viewer;
      },
      orElse: () => false,
    );

    return Scaffold(
      appBar: AppBar(
        title: projectAsync.when(
          data: (p) => Text(p.name),
          loading: () => const Text(''),
          error: (_, __) => const Text('오류'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: '멤버 관리',
            onPressed: () => projectAsync.whenData((p) => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => MemberManageScreen(project: p)),
                )),
          ),
          if (!isViewer) ...[
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: '하위 가계부 추가',
              onPressed: () => context.push('/projects/create?parentId=$projectId'),
            ),
            PopupMenuButton<_ProjectAction>(
              onSelected: (action) {
                projectAsync.whenData((p) {
                  if (action == _ProjectAction.edit) {
                    _showEditDialog(context, ref, p);
                  } else if (action == _ProjectAction.budget) {
                    _showBudgetDialog(context, ref, p);
                  } else if (action == _ProjectAction.categoryBudget) {
                    _showCategoryBudgetDialog(context, ref, p);
                  } else if (action == _ProjectAction.archive) {
                    _toggleArchive(context, ref, p);
                  } else if (action == _ProjectAction.delete) {
                    _showDeleteDialog(context, ref, p);
                  }
                });
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: _ProjectAction.edit, child: Row(children: [Icon(Icons.edit_outlined, size: 18), SizedBox(width: 8), Text('가계부 수정')])),
                const PopupMenuItem(value: _ProjectAction.budget, child: Row(children: [Icon(Icons.account_balance_wallet_outlined, size: 18), SizedBox(width: 8), Text('예산 한도 설정')])),
                const PopupMenuItem(value: _ProjectAction.categoryBudget, child: Row(children: [Icon(Icons.pie_chart_outline, size: 18), SizedBox(width: 8), Text('카테고리별 예산')])),
                PopupMenuItem(
                  value: _ProjectAction.archive,
                  child: projectAsync.when(
                    data: (p) => Row(children: [
                      Icon(p.isArchived ? Icons.unarchive_outlined : Icons.inventory_2_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(p.isArchived ? '보관 해제' : '보관하기'),
                    ]),
                    loading: () => const Text('보관하기'),
                    error: (_, __) => const Text('보관하기'),
                  ),
                ),
                const PopupMenuItem(value: _ProjectAction.delete, child: Row(children: [Icon(Icons.delete_outline, size: 18, color: Colors.red), SizedBox(width: 8), Text('가계부 삭제', style: TextStyle(color: Colors.red))])),
              ],
            ),
          ],
        ],
      ),
      body: projectAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (project) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildBalanceCard(context, ref, balanceAsync, project, formatter, isViewer: isViewer),
            const SizedBox(height: 16),
            _buildActionButtons(context, project, isViewer: isViewer),
            if (project.members.length > 1) ...[
              const SizedBox(height: 8),
              _buildSettlementButton(context, project),
            ],
            const SizedBox(height: 24),
            if (project.type != ProjectType.sub) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('하위 가계부', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  subProjectsAsync.when(
                    data: (subs) => subs.isNotEmpty
                        ? TextButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push<bool>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AllocationScreen(fromProject: project),
                                ),
                              );
                              if (result == true) {
                                ref.invalidate(projectBalanceProvider(projectId));
                              }
                            },
                            icon: const Icon(Icons.swap_horiz, size: 16),
                            label: const Text('예산 이전'),
                            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                          )
                        : const SizedBox.shrink(),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              subProjectsAsync.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('오류: $e'),
                data: (subs) => subs.isEmpty
                    ? Text('하위 가계부 없음', style: TextStyle(color: context.appColors.textSecondary))
                    : Column(
                        children: subs.map((s) => _SubProjectTile(project: s)).toList(),
                      ),
              ),
              const SizedBox(height: 24),
              if (!isViewer) ...[
                _RecurringAllocationList(projectId: projectId),
                const SizedBox(height: 24),
                _RecurringIncomeList(projectId: projectId),
                const SizedBox(height: 24),
                _RecurringExpenseList(projectId: projectId),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<ProjectBalance> balanceAsync,
    ProjectModel project,
    NumberFormat formatter, {
    bool isViewer = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: balanceAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('잔액 정보를 불러올 수 없습니다.'),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.currency.format(balance.balance),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            color: balance.balance < 0 ? Colors.red : AppColors.primary,
                          ),
                        ),
                        Text('잔액', style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    if (!isViewer) TextButton.icon(
                      onPressed: () => _showAddIncomeDialog(context, ref, project),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('수입 추가'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    backgroundColor: context.appColors.surface,
                    color: ratio >= 1.0 ? Colors.red : AppColors.primary,
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _budgetItem(context, '수입', '+${project.currency.format(balance.income)}', Colors.teal),
                    _budgetItem(context, '지출', '-${project.currency.format(balance.expense)}', context.appColors.textSecondary),
                    if (project.budgetLimit != null)
                      _budgetItem(
                        context,
                        '예산 한도',
                        project.currency.format(project.budgetLimit!),
                        balance.expense > project.budgetLimit! ? Colors.red : context.appColors.textSecondary,
                      ),
                  ],
                ),
                if (project.budgetLimit != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (balance.expense / project.budgetLimit!).clamp(0.0, 1.0),
                      backgroundColor: context.appColors.surface,
                      color: balance.expense > project.budgetLimit! ? Colors.red : Colors.orange,
                      minHeight: 4,
                    ),
                  ),
                  if (balance.expense > project.budgetLimit!)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '예산 초과! ${project.currency.format(balance.expense - project.budgetLimit!)} 초과',
                        style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAddIncomeDialog(BuildContext context, WidgetRef ref, ProjectModel project) {
    final amountController = TextEditingController();
    final descController = TextEditingController(text: '수입');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('수입 추가'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '금액', prefixText: '₩ '),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: '설명'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(amountController.text) ?? 0;
              if (amount <= 0) return;
              final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
              await ref.read(projectRepositoryProvider).addIncome(
                    projectId: project.id,
                    userId: uid,
                    amount: amount,
                    description: descController.text.trim().isEmpty ? '수입' : descController.text.trim(),
                  );
              ref.invalidate(projectBalanceProvider(project.id));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _toggleArchive(BuildContext context, WidgetRef ref, ProjectModel project) async {
    await ref.read(projectRepositoryProvider).archiveProject(project.id, archive: !project.isArchived);
    ref.invalidate(projectDetailProvider(project.id));
    ref.invalidate(projectNotifierProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(project.isArchived ? '보관이 해제되었습니다.' : '가계부를 보관했습니다.')),
      );
    }
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, ProjectModel project) {
    final nameController = TextEditingController(text: project.name);
    final iconController = TextEditingController(text: project.icon ?? '📁');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('가계부 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '가계부 이름'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: iconController,
              decoration: const InputDecoration(labelText: '아이콘 (이모지)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await ref.read(projectRepositoryProvider).updateProject(
                    project.id,
                    name: name,
                    icon: iconController.text.trim().isEmpty ? null : iconController.text.trim(),
                  );
              ref.invalidate(projectDetailProvider(project.id));
              ref.invalidate(projectNotifierProvider);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showBudgetDialog(BuildContext context, WidgetRef ref, ProjectModel project) {
    final controller = TextEditingController(
      text: project.budgetLimit != null ? project.budgetLimit!.toInt().toString() : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('예산 한도 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '예산 한도 금액', prefixText: '₩ ', hintText: '비워두면 한도 없음'),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          if (project.budgetLimit != null)
            TextButton(
              onPressed: () async {
                await ref.read(projectRepositoryProvider).setBudgetLimit(project.id, null);
                ref.invalidate(projectDetailProvider(project.id));
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('한도 삭제', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              await ref.read(projectRepositoryProvider).setBudgetLimit(project.id, amount);
              ref.invalidate(projectDetailProvider(project.id));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showCategoryBudgetDialog(BuildContext context, WidgetRef ref, ProjectModel project) {
    final controllers = {
      for (final cat in TransactionCategory.values)
        cat: TextEditingController(
          text: project.categoryBudgets[cat]?.toInt().toString() ?? '',
        ),
    };

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('카테고리별 예산'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: TransactionCategory.values.map((cat) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: controllers[cat],
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: '${cat.emoji} ${cat.label}',
                  prefixText: '₩ ',
                  hintText: '비워두면 설정 안 함',
                ),
              ),
            )).toList(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final budgets = <TransactionCategory, double>{};
              for (final cat in TransactionCategory.values) {
                final val = double.tryParse(controllers[cat]!.text);
                if (val != null && val > 0) budgets[cat] = val;
              }
              await ref.read(projectRepositoryProvider).setCategoryBudgets(project.id, budgets);
              ref.invalidate(projectDetailProvider(project.id));
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, ProjectModel project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('가계부 삭제'),
        content: Text('\'${project.name}\' 가계부를 삭제하시겠습니까?\n관련 거래 내역은 유지됩니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () async {
              await ref.read(projectRepositoryProvider).deleteProject(project.id);
              ref.invalidate(projectNotifierProvider);
              if (ctx.mounted) {
                Navigator.pop(ctx);
                context.pop();
              }
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  Widget _budgetItem(BuildContext context, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.appColors.textHint, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, ProjectModel project, {bool isViewer = false}) {
    return Column(
      children: [
        Row(
          children: [
            if (!isViewer) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push('/ai-input?projectId=$projectId'),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('지출 입력'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    side: const BorderSide(color: AppColors.primary),
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/projects/$projectId/transactions?name=${Uri.encodeComponent(project.name)}',
                ),
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('내역'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: BorderSide(color: context.appColors.textSecondary),
                  foregroundColor: context.appColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/projects/$projectId/statistics?name=${Uri.encodeComponent(project.name)}',
                ),
                icon: const Icon(Icons.pie_chart_outline, size: 18),
                label: const Text('통계'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.push(
                  '/projects/$projectId/report',
                  extra: {'project': project},
                ),
                icon: const Icon(Icons.bar_chart_outlined, size: 18),
                label: const Text('AI 리포트'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  side: const BorderSide(color: AppColors.primary),
                  foregroundColor: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSettlementButton(BuildContext context, ProjectModel project) {
    final memberIds = project.members.map((m) => m.userId).join(',');
    return OutlinedButton.icon(
      onPressed: () => context.push(
        '/projects/$projectId/settlement?name=${Uri.encodeComponent(project.name)}&members=$memberIds',
      ),
      icon: const Icon(Icons.calculate_outlined, size: 18),
      label: const Text('정산하기'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        side: const BorderSide(color: AppColors.warning),
        foregroundColor: AppColors.warning,
      ),
    );
  }
}

class _RecurringAllocationList extends ConsumerWidget {
  final String projectId;

  const _RecurringAllocationList({required this.projectId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = AllocationRepository();
    return FutureBuilder(
      future: repo.getRecurringAllocations(projectId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();
        final list = snapshot.data!;
        final formatter = NumberFormat('#,###', 'ko_KR');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('고정 이전', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            ...list.map((a) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.repeat, color: AppColors.primary, size: 20),
                  title: Text(a.description, style: const TextStyle(fontSize: 14)),
                  subtitle: Text('매월 ₩${formatter.format(a.amount)}', style: TextStyle(fontSize: 12, color: context.appColors.textSecondary)),
                  trailing: IconButton(
                    icon: Icon(Icons.cancel_outlined, size: 18, color: context.appColors.textHint),
                    onPressed: () async {
                      await repo.deactivateRecurring(a.id);
                      // ignore: use_build_context_synchronously
                      if (context.mounted) (context as Element).markNeedsBuild();
                    },
                  ),
                )),
          ],
        );
      },
    );
  }
}

class _SubProjectTile extends ConsumerWidget {
  final ProjectModel project;

  const _SubProjectTile({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(projectBalanceProvider(project.id));
    final formatter = NumberFormat('#,###', 'ko_KR');

    return ListTile(
      leading: Text(project.icon ?? '📁', style: const TextStyle(fontSize: 20)),
      title: Text(project.name),
      subtitle: balanceAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => const SizedBox.shrink(),
        data: (balance) => Text(
          '잔액 ₩${formatter.format(balance.balance)}',
          style: TextStyle(
            color: balance.balance < 0 ? Colors.red : context.appColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/projects/${project.id}'),
    );
  }
}

class _RecurringIncomeList extends StatefulWidget {
  final String projectId;

  const _RecurringIncomeList({required this.projectId});

  @override
  State<_RecurringIncomeList> createState() => _RecurringIncomeListState();
}

class _RecurringIncomeListState extends State<_RecurringIncomeList> {
  final _repo = RecurringExpenseRepository();
  late Future<List<RecurringExpense>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _future = _repo.getRecurringExpenses(widget.projectId, type: TransactionType.income);
  }

  Future<void> _showAddDialog() async {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    var selectedDay = 1;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('고정 수입 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: '내용 (예: 월급)'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '금액', prefixText: '₩ '),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedDay,
                  decoration: const InputDecoration(labelText: '매월 입금일'),
                  items: List.generate(28, (i) => i + 1)
                      .map((d) => DropdownMenuItem(value: d, child: Text('$d일')))
                      .toList(),
                  onChanged: (v) => setS(() => selectedDay = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0 || descController.text.trim().isEmpty) return;
                await _repo.createRecurringExpense(
                  projectId: widget.projectId,
                  amount: amount,
                  description: descController.text.trim(),
                  category: TransactionCategory.other,
                  dayOfMonth: selectedDay,
                  type: TransactionType.income,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                setState(_refresh);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'ko_KR');
    return FutureBuilder<List<RecurringExpense>>(
      future: _future,
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        if (list.isEmpty && snapshot.connectionState == ConnectionState.done) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('고정 수입', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                TextButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('추가'),
                  style: TextButton.styleFrom(foregroundColor: Colors.teal),
                ),
              ],
            ),
            if (list.isEmpty && snapshot.connectionState != ConnectionState.done)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: LinearProgressIndicator(),
              )
            else if (list.isNotEmpty)
              ...list.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.arrow_downward_rounded, color: Colors.teal, size: 20),
                    title: Text(e.description, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      '매월 ${e.dayOfMonth}일 · ₩${formatter.format(e.amount)}',
                      style: TextStyle(fontSize: 12, color: context.appColors.textSecondary),
                    ),
                    trailing: IconButton(
                      icon: Icon(Icons.cancel_outlined, size: 18, color: context.appColors.textHint),
                      onPressed: () async {
                        await _repo.deactivate(e.id);
                        setState(_refresh);
                      },
                    ),
                  )),
          ],
        );
      },
    );
  }
}

class _RecurringExpenseList extends StatefulWidget {
  final String projectId;

  const _RecurringExpenseList({required this.projectId});

  @override
  State<_RecurringExpenseList> createState() => _RecurringExpenseListState();
}

class _RecurringExpenseListState extends State<_RecurringExpenseList> {
  final _repo = RecurringExpenseRepository();
  late Future<List<RecurringExpense>> _future;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _future = _repo.getRecurringExpenses(widget.projectId);
  }

  Future<void> _showAddDialog() async {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    var selectedCategory = TransactionCategory.other;
    var selectedDay = 1;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('고정 지출 추가'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: '내용 (예: 넷플릭스)'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '금액', prefixText: '₩ '),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<TransactionCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: '카테고리'),
                  items: TransactionCategory.values
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text('${c.emoji} ${c.label}'),
                          ))
                      .toList(),
                  onChanged: (v) => setS(() => selectedCategory = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedDay,
                  decoration: const InputDecoration(labelText: '매월 결제일'),
                  items: List.generate(28, (i) => i + 1)
                      .map((d) => DropdownMenuItem(value: d, child: Text('$d일')))
                      .toList(),
                  onChanged: (v) => setS(() => selectedDay = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0 || descController.text.trim().isEmpty) return;
                await _repo.createRecurringExpense(
                  projectId: widget.projectId,
                  amount: amount,
                  description: descController.text.trim(),
                  category: selectedCategory,
                  dayOfMonth: selectedDay,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                setState(_refresh);
              },
              child: const Text('추가'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(RecurringExpense expense) async {
    final amountController = TextEditingController(text: expense.amount.toInt().toString());
    final descController = TextEditingController(text: expense.description);
    var selectedCategory = expense.category;
    var selectedDay = expense.dayOfMonth;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('고정 지출 수정'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: '내용'),
                  autofocus: true,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '금액', prefixText: '₩ '),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<TransactionCategory>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: '카테고리'),
                  items: TransactionCategory.values
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text('${c.emoji} ${c.label}'),
                          ))
                      .toList(),
                  onChanged: (v) => setS(() => selectedCategory = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: selectedDay,
                  decoration: const InputDecoration(labelText: '매월 결제일'),
                  items: List.generate(28, (i) => i + 1)
                      .map((d) => DropdownMenuItem(value: d, child: Text('$d일')))
                      .toList(),
                  onChanged: (v) => setS(() => selectedDay = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0 || descController.text.trim().isEmpty) return;
                await _repo.updateRecurringExpense(
                  id: expense.id,
                  amount: amount,
                  description: descController.text.trim(),
                  category: selectedCategory,
                  dayOfMonth: selectedDay,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                setState(_refresh);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat('#,###', 'ko_KR');
    return FutureBuilder<List<RecurringExpense>>(
      future: _future,
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('고정 지출', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                TextButton.icon(
                  onPressed: _showAddDialog,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('추가'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ],
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('등록된 고정 지출이 없습니다.', style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
              )
            else
              ...list.map((e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Text(e.category.emoji, style: const TextStyle(fontSize: 20)),
                    title: Text(e.description, style: const TextStyle(fontSize: 14)),
                    subtitle: Text(
                      '매월 ${e.dayOfMonth}일 · ₩${formatter.format(e.amount)}',
                      style: TextStyle(fontSize: 12, color: context.appColors.textSecondary),
                    ),
                    onTap: () => _showEditDialog(e),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_outlined, size: 18, color: context.appColors.textSecondary),
                          onPressed: () => _showEditDialog(e),
                        ),
                        IconButton(
                          icon: Icon(Icons.cancel_outlined, size: 18, color: context.appColors.textHint),
                          onPressed: () async {
                            await _repo.deactivate(e.id);
                            setState(_refresh);
                          },
                        ),
                      ],
                    ),
                  )),
          ],
        );
      },
    );
  }
}
