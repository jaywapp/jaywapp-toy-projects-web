import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../project/presentation/providers/project_provider.dart';
import '../../../transaction/data/repositories/transaction_repository.dart';
import '../../../transaction/domain/models/transaction_model.dart';

class _StatisticsParams {
  final String projectId;
  final bool includeSubProjects;

  const _StatisticsParams({required this.projectId, required this.includeSubProjects});

  @override
  bool operator ==(Object other) =>
      other is _StatisticsParams &&
      projectId == other.projectId &&
      includeSubProjects == other.includeSubProjects;

  @override
  int get hashCode => Object.hash(projectId, includeSubProjects);
}

final _statisticsProvider = FutureProvider.family<List<TransactionModel>, _StatisticsParams>(
  (ref, params) async {
    final repo = TransactionRepository();
    final projectIds = [params.projectId];
    if (params.includeSubProjects) {
      final subs = await ref.read(subProjectsProvider(params.projectId).future);
      projectIds.addAll(subs.map((s) => s.id));
    }
    final results = await Future.wait(projectIds.map(repo.getProjectTransactions));
    return results.expand((list) => list).toList();
  },
);

class StatisticsScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String projectName;

  const StatisticsScreen({super.key, required this.projectId, required this.projectName});

  @override
  ConsumerState<StatisticsScreen> createState() => _StatisticsScreenState();
}

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

class _StatisticsScreenState extends ConsumerState<StatisticsScreen> {
  int _touchedIndex = -1;
  late DateTime _selectedMonth;
  bool _includeSubProjects = false;
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
      _DateRange.threeMonths => all
          .where((t) => t.date.isAfter(DateTime(now.year, now.month - 3, now.day)))
          .toList(),
      _DateRange.sixMonths => all
          .where((t) => t.date.isAfter(DateTime(now.year, now.month - 6, now.day)))
          .toList(),
      _DateRange.oneYear => all
          .where((t) => t.date.isAfter(DateTime(now.year - 1, now.month, now.day)))
          .toList(),
      _DateRange.all => all,
    };
  }

  @override
  Widget build(BuildContext context) {
    final params = _StatisticsParams(
      projectId: widget.projectId,
      includeSubProjects: _includeSubProjects,
    );
    final async = ref.watch(_statisticsProvider(params));
    final projectAsync = ref.watch(projectDetailProvider(widget.projectId));
    final formatter = NumberFormat('#,###', 'ko_KR');

    return Scaffold(
      appBar: AppBar(title: Text('${widget.projectName} 통계')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                const Text('하위 가계부 포함', style: TextStyle(fontSize: 14)),
                const Spacer(),
                Switch(
                  value: _includeSubProjects,
                  onChanged: (v) => setState(() => _includeSubProjects = v),
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
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
              children: _DateRange.values.map((r) => Padding(
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
              )).toList(),
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('오류: $e')),
              data: (transactions) {
                final filtered = _applyDateFilter(
                  transactions.where((t) => t.isIncome == _showIncome).toList(),
                );

                final categoryTotals = <TransactionCategory, double>{};
                if (!_showIncome) {
                  for (final t in filtered) {
                    categoryTotals[t.category] = (categoryTotals[t.category] ?? 0) + t.amount;
                  }
                }

                final monthlyData = _buildMonthlyData(transactions);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_dateRange == _DateRange.thisMonth)
                      _MonthSelector(
                        month: _selectedMonth,
                        onPrev: _prevMonth,
                        onNext: _nextMonth,
                      ),
                    const SizedBox(height: 16),
                    if (filtered.isEmpty)
                      _EmptyMonth(isIncome: _showIncome)
                    else if (_showIncome)
                      _IncomeSummary(transactions: filtered, formatter: formatter)
                    else ...[
                      _CategoryPieChart(
                        categoryTotals: categoryTotals,
                        touchedIndex: _touchedIndex,
                        onTouch: (i) => setState(() => _touchedIndex = i),
                        formatter: formatter,
                      ),
                      const SizedBox(height: 24),
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
                    ],
                    if (!_showIncome)
                      projectAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                        data: (project) {
                          if (project.categoryBudgets.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 24),
                              _CategoryBudgetChart(
                                categoryBudgets: project.categoryBudgets,
                                categoryTotals: categoryTotals,
                                formatter: formatter,
                              ),
                            ],
                          );
                        },
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

class _EmptyMonth extends StatelessWidget {
  final bool isIncome;
  const _EmptyMonth({this.isIncome = false});

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
              isIncome ? '이달 수입 내역이 없습니다.' : '이달 지출 내역이 없습니다.',
              style: TextStyle(color: context.appColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _IncomeSummary extends StatelessWidget {
  final List<TransactionModel> transactions;
  final NumberFormat formatter;

  const _IncomeSummary({required this.transactions, required this.formatter});

  @override
  Widget build(BuildContext context) {
    final total = transactions.fold(0.0, (s, t) => s + t.amount);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('이달 수입', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 12),
            Text(
              '₩${formatter.format(total)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.teal,
              ),
            ),
            const SizedBox(height: 16),
            ...transactions.map((t) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Text('💰', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(t.description, style: const TextStyle(fontSize: 14)),
                      ),
                      Text(
                        '+₩${formatter.format(t.amount)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.teal,
                        ),
                      ),
                    ],
                  ),
                )),
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
    final entries = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: List.generate(entries.length, (i) {
        final cat = entries[i].key;
        final amount = entries[i].value;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 12, height: 12,
                decoration: BoxDecoration(
                  color: _colors[i % _colors.length],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Text('${cat.emoji} ${cat.label}', style: const TextStyle(fontSize: 14)),
              const Spacer(),
              Text(
                '₩${formatter.format(amount)}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
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

class _MonthlyAmount {
  final DateTime month;
  final double amount;
  _MonthlyAmount({required this.month, required this.amount});
}

class _CategoryBudgetChart extends StatelessWidget {
  final Map<TransactionCategory, double> categoryBudgets;
  final Map<TransactionCategory, double> categoryTotals;
  final NumberFormat formatter;

  const _CategoryBudgetChart({
    required this.categoryBudgets,
    required this.categoryTotals,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final categories = categoryBudgets.keys.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('카테고리별 예산 대비 실적', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 16),
            ...categories.map((cat) {
              final budget = categoryBudgets[cat]!;
              final actual = categoryTotals[cat] ?? 0.0;
              final ratio = (actual / budget).clamp(0.0, 1.0);
              final isOver = actual > budget;

              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('${cat.emoji} ${cat.label}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        const Spacer(),
                        Text(
                          '₩${formatter.format(actual)} / ₩${formatter.format(budget)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOver ? Colors.red : context.appColors.textSecondary,
                            fontWeight: isOver ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: context.appColors.surface,
                        color: isOver ? Colors.red : (ratio > 0.8 ? Colors.orange : AppColors.primary),
                        minHeight: 8,
                      ),
                    ),
                    if (isOver)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '₩${formatter.format(actual - budget)} 초과',
                          style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
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
}
