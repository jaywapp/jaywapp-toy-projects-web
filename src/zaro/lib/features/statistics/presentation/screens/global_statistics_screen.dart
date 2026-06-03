import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../project/domain/models/project_model.dart';
import '../../../project/presentation/providers/project_provider.dart';
import '../../../transaction/data/repositories/transaction_repository.dart';
import '../../../transaction/domain/models/transaction_model.dart';

// ─── Provider ───────────────────────────────────────────────────────────────

final _globalTransactionsProvider = FutureProvider<List<TransactionModel>>((ref) async {
  final projects = await ref.watch(userProjectsProvider.future);
  final repo = TransactionRepository();
  final results = await Future.wait(projects.map((p) => repo.getProjectTransactions(p.id)));
  return results.expand((list) => list).toList();
});

// ─── Screen ─────────────────────────────────────────────────────────────────

enum _DateRange { thisMonth, threeMonths, sixMonths, oneYear, all }

extension _DateRangeLabel on _DateRange {
  String get label => switch (this) {
        _DateRange.thisMonth => '이번달',
        _DateRange.threeMonths => '3개월',
        _DateRange.sixMonths => '6개월',
        _DateRange.oneYear => '1년',
        _DateRange.all => '전체',
      };
}

class GlobalStatisticsScreen extends ConsumerStatefulWidget {
  const GlobalStatisticsScreen({super.key});

  @override
  ConsumerState<GlobalStatisticsScreen> createState() => _GlobalStatisticsScreenState();
}

class _GlobalStatisticsScreenState extends ConsumerState<GlobalStatisticsScreen> {
  int _touchedIndex = -1;
  late DateTime _selectedMonth;
  bool _showIncome = false;
  _DateRange _dateRange = _DateRange.thisMonth;

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _prevMonth() => setState(() {
        _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
      });

  void _nextMonth() {
    final now = DateTime(DateTime.now().year, DateTime.now().month);
    if (_selectedMonth.isBefore(now)) {
      setState(() => _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1));
    }
  }

  List<TransactionModel> _applyDateFilter(List<TransactionModel> all) {
    final now = DateTime.now();
    return switch (_dateRange) {
      _DateRange.thisMonth => all
          .where((t) => t.date.year == _selectedMonth.year && t.date.month == _selectedMonth.month)
          .toList(),
      _DateRange.threeMonths =>
        all.where((t) => t.date.isAfter(DateTime(now.year, now.month - 3, now.day))).toList(),
      _DateRange.sixMonths =>
        all.where((t) => t.date.isAfter(DateTime(now.year, now.month - 6, now.day))).toList(),
      _DateRange.oneYear =>
        all.where((t) => t.date.isAfter(DateTime(now.year - 1, now.month, now.day))).toList(),
      _DateRange.all => all,
    };
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(_globalTransactionsProvider);
    final projectsAsync = ref.watch(userProjectsProvider);
    final formatter = NumberFormat('#,###', 'ko_KR');

    return Scaffold(
      appBar: AppBar(title: const Text('전체 통계')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('지출')),
                ButtonSegment(value: true, label: Text('수입')),
              ],
              selected: {_showIncome},
              onSelectionChanged: (s) => setState(() {
                _showIncome = s.first;
                _touchedIndex = -1;
              }),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primary,
                selectedForegroundColor: Colors.white,
              ),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _DateRange.values
                  .map((r) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(r.label, style: const TextStyle(fontSize: 12)),
                          selected: _dateRange == r,
                          onSelected: (_) => setState(() {
                            _dateRange = r;
                            _touchedIndex = -1;
                          }),
                          showCheckmark: false,
                        ),
                      ))
                  .toList(),
            ),
          ),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (all) {
                final filtered = _applyDateFilter(
                  all.where((t) => t.isIncome == _showIncome).toList(),
                );
                final allFiltered = _applyDateFilter(all);

                final totalIncome = allFiltered.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);
                final totalExpense = allFiltered.where((t) => !t.isIncome).fold(0.0, (s, t) => s + t.amount);

                final categoryTotals = <TransactionCategory, double>{};
                if (!_showIncome) {
                  for (final t in filtered) {
                    categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
                  }
                }

                final monthlyData = _buildMonthlyData(all);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _SummaryCard(
                      income: totalIncome,
                      expense: totalExpense,
                      formatter: formatter,
                    ),
                    const SizedBox(height: 16),
                    if (_dateRange == _DateRange.thisMonth)
                      _MonthSelector(
                        month: _selectedMonth,
                        onPrev: _prevMonth,
                        onNext: _nextMonth,
                      ),
                    const SizedBox(height: 16),
                    if (filtered.isEmpty)
                      _EmptyState(isIncome: _showIncome)
                    else if (_showIncome)
                      _IncomeSummaryCard(transactions: filtered, formatter: formatter)
                    else ...[
                      _CategoryPieChart(
                        categoryTotals: categoryTotals,
                        touchedIndex: _touchedIndex,
                        onTouch: (i) => setState(() => _touchedIndex = i),
                        formatter: formatter,
                      ),
                      const SizedBox(height: 16),
                      _CategoryLegend(categoryTotals: categoryTotals, formatter: formatter),
                    ],
                    const SizedBox(height: 24),
                    if (monthlyData.length >= 2) ...[
                      Text(
                        _showIncome ? '월별 수입 추이' : '월별 지출 추이',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                      ),
                      const SizedBox(height: 16),
                      _MonthlyBarChart(monthlyData: monthlyData, formatter: formatter),
                      const SizedBox(height: 24),
                    ],
                    projectsAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (projects) => _ProjectBreakdown(
                        projects: projects.where((p) => !p.isArchived).toList(),
                        transactions: allFiltered,
                        formatter: formatter,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<_MonthlyAmount> _buildMonthlyData(List<TransactionModel> transactions) {
    final map = <String, double>{};
    for (final t in transactions.where((t) => t.isIncome == _showIncome)) {
      final key = DateFormat('yyyy-MM').format(t.date);
      map[key] = (map[key] ?? 0) + t.amount;
    }
    final keys = map.keys.toList()..sort();
    final recent = keys.length > 6 ? keys.sublist(keys.length - 6) : keys;
    return recent.map((k) {
      final parts = k.split('-');
      return _MonthlyAmount(
        month: DateTime(int.parse(parts[0]), int.parse(parts[1])),
        amount: map[k]!,
      );
    }).toList();
  }
}

// ─── Widgets ────────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double income;
  final double expense;
  final NumberFormat formatter;

  const _SummaryCard({required this.income, required this.expense, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final balance = income - expense;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '전체 잔액',
              style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              '₩${formatter.format(balance)}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: balance < 0 ? Colors.red : AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Item(label: '총 수입', value: '+₩${formatter.format(income)}', color: Colors.teal),
                const SizedBox(width: 24),
                _Item(
                  label: '총 지출',
                  value: '-₩${formatter.format(expense)}',
                  color: context.appColors.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Item({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: context.appColors.textHint, fontSize: 12)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
      ],
    );
  }
}

class _MonthSelector extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthSelector({required this.month, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final now = DateTime(DateTime.now().year, DateTime.now().month);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Text(
          DateFormat('yyyy년 M월').format(month),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        IconButton(
          onPressed: month.isBefore(now) ? onNext : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isIncome;
  const _EmptyState({required this.isIncome});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_outlined, size: 48, color: context.appColors.textHint),
            const SizedBox(height: 12),
            Text(
              isIncome ? '이 기간 수입 내역이 없습니다.' : '이 기간 지출 내역이 없습니다.',
              style: TextStyle(color: context.appColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeSummaryCard extends StatelessWidget {
  final List<TransactionModel> transactions;
  final NumberFormat formatter;

  const _IncomeSummaryCard({required this.transactions, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final total = transactions.fold(0.0, (s, t) => s + t.amount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('수입 합계', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Text(
              '₩${formatter.format(total)}',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.teal),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final Map<TransactionCategory, double> categoryTotals;
  final int touchedIndex;
  final ValueChanged<int> onTouch;
  final NumberFormat formatter;

  const _CategoryPieChart({
    required this.categoryTotals,
    required this.touchedIndex,
    required this.onTouch,
    required this.formatter,
  });

  static const _colors = [
    Color(0xFF6C63FF),
    Color(0xFF48CAE4),
    Color(0xFF52B788),
    Color(0xFFFFB703),
    Color(0xFFE63946),
    Color(0xFFF4845F),
    Color(0xFF9B5DE5),
    Color(0xFF00BBF9),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = categoryTotals.entries.toList();
    final total = entries.fold(0.0, (s, e) => s + e.value);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('카테고리별 지출', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (!event.isInterestedForInteractions || response?.touchedSection == null) {
                        onTouch(-1);
                        return;
                      }
                      onTouch(response!.touchedSection!.touchedSectionIndex);
                    },
                  ),
                  sections: List.generate(entries.length, (i) {
                    final isTouched = i == touchedIndex;
                    final pct = total > 0 ? (entries[i].value / total * 100) : 0.0;
                    return PieChartSectionData(
                      color: _colors[i % _colors.length],
                      value: entries[i].value,
                      title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
                      radius: isTouched ? 70 : 58,
                      titleStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    );
                  }),
                  centerSpaceRadius: 48,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '총 ₩${formatter.format(total)}',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryLegend extends StatelessWidget {
  final Map<TransactionCategory, double> categoryTotals;
  final NumberFormat formatter;

  static const _colors = [
    Color(0xFF6C63FF),
    Color(0xFF48CAE4),
    Color(0xFF52B788),
    Color(0xFFFFB703),
    Color(0xFFE63946),
    Color(0xFFF4845F),
    Color(0xFF9B5DE5),
    Color(0xFF00BBF9),
  ];

  const _CategoryLegend({required this.categoryTotals, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final entries = categoryTotals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: List.generate(entries.length, (i) {
        final cat = entries[i].key;
        final amount = entries[i].value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: _colors[i % _colors.length],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text('${cat.emoji} ${cat.label}', style: const TextStyle(fontSize: 14)),
              const Spacer(),
              Text('₩${formatter.format(amount)}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        );
      }),
    );
  }
}

class _MonthlyBarChart extends StatelessWidget {
  final List<_MonthlyAmount> monthlyData;
  final NumberFormat formatter;

  const _MonthlyBarChart({required this.monthlyData, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final maxAmount = monthlyData.map((m) => m.amount).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxAmount * 1.2,
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    return BarTooltipItem(
                      '₩${formatter.format(rod.toY.toInt())}',
                      const TextStyle(color: Colors.white, fontSize: 12),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= monthlyData.length) return const SizedBox.shrink();
                      return Text(
                        DateFormat('M월').format(monthlyData[i].month),
                        style: TextStyle(fontSize: 11, color: context.appColors.textSecondary),
                      );
                    },
                  ),
                ),
              ),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(monthlyData.length, (i) {
                return BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: monthlyData[i].amount,
                      color: AppColors.primary,
                      width: 20,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ],
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProjectBreakdown extends StatelessWidget {
  final List<ProjectModel> projects;
  final List<TransactionModel> transactions;
  final NumberFormat formatter;

  const _ProjectBreakdown({
    required this.projects,
    required this.transactions,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final parents = projects.where((p) => p.type != ProjectType.sub).toList();
    if (parents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('가계부별 현황', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        const SizedBox(height: 8),
        ...parents.map((p) {
          final projectTxns = transactions.where((t) => t.projectId == p.id);
          final income = projectTxns.where((t) => t.isIncome).fold(0.0, (s, t) => s + t.amount);
          final expense = projectTxns.where((t) => !t.isIncome).fold(0.0, (s, t) => s + t.amount);
          final balance = income - expense;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(p.icon ?? '📁', style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          '수입 ₩${formatter.format(income)}  지출 ₩${formatter.format(expense)}',
                          style: TextStyle(color: context.appColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '₩${formatter.format(balance)}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: balance < 0 ? Colors.red : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _MonthlyAmount {
  final DateTime month;
  final double amount;
  _MonthlyAmount({required this.month, required this.amount});
}
