import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../data/repositories/settlement_repository.dart';
import '../../domain/models/settlement_model.dart';
import '../../../project/data/repositories/member_repository.dart';

final _settlementRepoProvider = Provider<SettlementRepository>((ref) => SettlementRepository());
final _memberRepoProvider2 = Provider<MemberRepository>((ref) => MemberRepository());

final settlementProvider = FutureProvider.family<SettlementResult, String>((ref, projectId) async {
  return ref.read(_settlementRepoProvider).calculateSettlement(projectId);
});

final _historyProvider = FutureProvider.family<List<CompletedSettlement>, String>((ref, projectId) async {
  return ref.read(_settlementRepoProvider).getSettlementHistory(projectId);
});

class SettlementScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String projectName;
  final List<String> memberIds;

  const SettlementScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.memberIds,
  });

  @override
  ConsumerState<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends ConsumerState<SettlementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _completeSettlement(SettlementResult result) async {
    if (result.settlements.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정산할 내역이 없습니다.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('정산 완료 처리'),
        content: const Text('현재 정산 내역을 완료로 기록하시겠습니까?\n완료 후에도 히스토리에서 확인 가능합니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('완료 처리')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(_settlementRepoProvider).saveSettlement(result);
      ref.invalidate(_historyProvider(widget.projectId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('정산이 완료 처리되었습니다.'), backgroundColor: AppColors.success),
      );
      _tabController.animateTo(1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('처리 실패: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settlementAsync = ref.watch(settlementProvider(widget.projectId));
    final namesAsync = ref.watch(
      FutureProvider((ref) => ref.read(_memberRepoProvider2).getUserNames(widget.memberIds)).future,
    );
    final formatter = NumberFormat('#,###', 'ko_KR');

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.projectName} 정산'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(settlementProvider(widget.projectId)),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '현재 정산'),
            Tab(text: '정산 히스토리'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ── 현재 정산 탭 ──
          settlementAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
            data: (result) => FutureBuilder<Map<String, String>>(
              future: namesAsync,
              builder: (context, namesSnap) {
                final names = namesSnap.data ?? {};
                return Stack(
                  children: [
                    ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                      children: [
                        _buildSummaryCard(context, result, formatter),
                        const SizedBox(height: 16),
                        _buildMemberSpentCard(result, names, formatter),
                        const SizedBox(height: 16),
                        _buildSettlementCard(context, result, names, formatter),
                      ],
                    ),
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: ElevatedButton.icon(
                        onPressed: result.settlements.isEmpty
                            ? null
                            : () => _completeSettlement(result),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('정산 완료 처리'),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          // ── 히스토리 탭 ──
          _HistoryTab(projectId: widget.projectId, formatter: formatter),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, SettlementResult result, NumberFormat formatter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem(context, '총 지출', '₩${formatter.format(result.totalSpent)}'),
            _statItem(context, '멤버 수', '${result.memberSpent.length}명'),
            _statItem(context, '1인 평균', '₩${formatter.format(result.averageSpent.round())}'),
          ],
        ),
      ),
    );
  }

  Widget _statItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.primary)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: context.appColors.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildMemberSpentCard(SettlementResult result, Map<String, String> names, NumberFormat formatter) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('멤버별 지출', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...result.memberSpent.entries.map((e) {
              final diff = e.value - result.averageSpent;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(names[e.key] ?? e.key)),
                    Text('₩${formatter.format(e.value)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Text(
                      '${diff >= 0 ? '+' : ''}₩${formatter.format(diff.round())}',
                      style: TextStyle(fontSize: 12, color: diff >= 0 ? AppColors.success : AppColors.error),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSettlementCard(BuildContext context, SettlementResult result, Map<String, String> names, NumberFormat formatter) {
    if (result.settlements.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(child: Text('정산할 내역이 없습니다.', style: TextStyle(color: context.appColors.textSecondary))),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('정산 내역', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...result.settlements.map((s) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.error.withValues(alpha: 0.15),
                    child: Text((names[s.fromUserId] ?? '?').substring(0, 1),
                        style: const TextStyle(color: AppColors.error, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${names[s.fromUserId] ?? s.fromUserId} → ${names[s.toUserId] ?? s.toUserId}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text('₩${formatter.format(s.amount.round())}',
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

// ── 히스토리 탭 ──────────────────────────────────────────────────────────────

class _HistoryTab extends ConsumerWidget {
  final String projectId;
  final NumberFormat formatter;

  const _HistoryTab({required this.projectId, required this.formatter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(_historyProvider(projectId));

    return historyAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('오류: $e')),
      data: (history) {
        if (history.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history, size: 48, color: context.appColors.textHint),
                const SizedBox(height: 12),
                Text('정산 히스토리가 없습니다.', style: TextStyle(color: context.appColors.textSecondary)),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: history.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, i) {
            final record = history[i];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('yyyy년 M월 d일 HH:mm').format(record.completedAt),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '총 지출: ₩${formatter.format(record.totalSpent)}  ·  ${record.memberSpent.length}명',
                      style: TextStyle(fontSize: 13, color: context.appColors.textSecondary),
                    ),
                    if (record.settlements.isNotEmpty) ...[
                      const Divider(height: 16),
                      ...record.settlements.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${s.fromUserId.substring(0, 6)}... → ${s.toUserId.substring(0, 6)}...  ₩${formatter.format(s.amount.round())}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      )),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
