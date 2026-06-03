import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../project/domain/models/project_model.dart';
import '../../../project/presentation/providers/project_provider.dart';
import '../../../transaction/data/repositories/transaction_repository.dart';
import '../../../transaction/domain/models/transaction_model.dart';

final _allTransactionsProvider = FutureProvider<List<_TxWithProject>>((ref) async {
  final projects = await ref.watch(userProjectsProvider.future);
  final repo = TransactionRepository();
  final results = await Future.wait(
    projects.map((p) async {
      final txns = await repo.getProjectTransactions(p.id);
      return txns.map((t) => _TxWithProject(transaction: t, project: p)).toList();
    }),
  );
  return results.expand((list) => list).toList()
    ..sort((a, b) => b.transaction.date.compareTo(a.transaction.date));
});

class _TxWithProject {
  final TransactionModel transaction;
  final ProjectModel project;
  const _TxWithProject({required this.transaction, required this.project});
}

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(_allTransactionsProvider);
    final formatter = NumberFormat('#,###', 'ko_KR');

    return Scaffold(
      appBar: AppBar(
        title: Builder(builder: (context) {
          final fgColor = Theme.of(context).appBarTheme.foregroundColor ?? Colors.white;
          return TextField(
            controller: _controller,
            autofocus: true,
            style: TextStyle(color: fgColor),
            cursorColor: fgColor,
            decoration: InputDecoration(
              hintText: '전체 가계부에서 검색...',
              hintStyle: TextStyle(color: fgColor.withValues(alpha: 0.5)),
              border: InputBorder.none,
            ),
            onChanged: (v) => setState(() => _query = v.trim()),
          );
        }),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: allAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (all) {
          if (_query.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search, size: 64, color: context.appColors.textHint),
                  const SizedBox(height: 12),
                  Text('검색어를 입력하세요', style: TextStyle(color: context.appColors.textSecondary)),
                ],
              ),
            );
          }

          final q = _query.toLowerCase();
          final results = all
              .where((item) =>
                  item.transaction.description.toLowerCase().contains(q) ||
                  item.project.name.toLowerCase().contains(q))
              .toList();

          if (results.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off, size: 64, color: context.appColors.textHint),
                  const SizedBox(height: 12),
                  Text('\'$_query\' 검색 결과가 없습니다.', style: TextStyle(color: context.appColors.textSecondary)),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '${results.length}건',
                  style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final item = results[i];
                    final tx = item.transaction;
                    final p = item.project;
                    return ListTile(
                      leading: Text(tx.category.emoji, style: const TextStyle(fontSize: 22)),
                      title: Text(tx.description),
                      subtitle: Row(
                        children: [
                          Text(
                            '${p.icon ?? '📁'} ${p.name}',
                            style: TextStyle(fontSize: 12, color: context.appColors.textSecondary),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('M/d').format(tx.date),
                            style: TextStyle(fontSize: 12, color: context.appColors.textHint),
                          ),
                        ],
                      ),
                      trailing: Text(
                        '${tx.isIncome ? '+' : '-'}₩${formatter.format(tx.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: tx.isIncome ? Colors.teal : AppColors.error,
                          fontSize: 14,
                        ),
                      ),
                      onTap: () => context.push(
                        '/projects/${p.id}/transactions?name=${Uri.encodeComponent(p.name)}',
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
