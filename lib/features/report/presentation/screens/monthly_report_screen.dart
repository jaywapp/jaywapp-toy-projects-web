import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../project/domain/models/project_model.dart';
import '../../../project/presentation/providers/project_provider.dart';

final _monthlyReportProvider =
    FutureProvider.family<String, _ReportParams>((ref, params) async {
  final firestore = FirebaseFirestore.instance;
  final start = DateTime(params.year, params.month);
  final end = DateTime(params.year, params.month + 1);

  // 대상 프로젝트 ID 목록 (본 프로젝트 + 옵션에 따라 서브 프로젝트)
  final projectIds = [params.project.id];
  if (params.includeSubProjects) {
    final subs = await ref.read(subProjectsProvider(params.project.id).future);
    projectIds.addAll(subs.map((s) => s.id));
  }

  final allTransactions = <Map<String, dynamic>>[];
  for (final pid in projectIds) {
    final snapshot = await firestore
        .collection('transactions')
        .where('projectId', isEqualTo: pid)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: end)
        .get();

    for (final doc in snapshot.docs) {
      if (doc['confirmedAt'] == null) continue;
      final type = doc['type'] as String? ?? 'expense';
      if (type == 'income') continue; // 수입 제외 (지출만 리포트)
      allTransactions.add({
        'description': doc['description'] as String,
        'amount': (doc['amount'] as num).toInt(),
        'date': (doc['date'] as Timestamp).toDate().toIso8601String().substring(0, 10),
        'projectName': params.project.name,
      });
    }
  }

  final totalSpent = allTransactions.fold<int>(0, (s, t) => s + (t['amount'] as int));

  // 잔액 정보
  final balanceSnap = await firestore
      .collection('transactions')
      .where('projectId', isEqualTo: params.project.id)
      .get();
  double totalIncome = 0;
  for (final doc in balanceSnap.docs) {
    if (doc['confirmedAt'] == null) continue;
    if ((doc['type'] as String? ?? 'expense') == 'income') {
      totalIncome += (doc['amount'] as num).toDouble();
    }
  }

  final functions = FirebaseFunctions.instanceFor(region: 'asia-northeast3');
  final callable = functions.httpsCallable('generateMonthlyReport');
  final result = await callable.call({
    'year': params.year,
    'month': params.month,
    'projectName': params.project.name,
    'totalBudget': totalIncome.toInt(),
    'totalSpent': totalSpent,
    'transactions': allTransactions,
  });

  return (result.data as Map)['report'] as String;
});

class _ReportParams {
  final int year;
  final int month;
  final ProjectModel project;
  final bool includeSubProjects;

  const _ReportParams({
    required this.year,
    required this.month,
    required this.project,
    required this.includeSubProjects,
  });

  @override
  bool operator ==(Object other) =>
      other is _ReportParams &&
      year == other.year &&
      month == other.month &&
      project.id == other.project.id &&
      includeSubProjects == other.includeSubProjects;

  @override
  int get hashCode => Object.hash(year, month, project.id, includeSubProjects);
}

class MonthlyReportScreen extends ConsumerStatefulWidget {
  final ProjectModel project;

  const MonthlyReportScreen({super.key, required this.project});

  @override
  ConsumerState<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends ConsumerState<MonthlyReportScreen> {
  late int _year;
  late int _month;
  bool _includeSubProjects = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  @override
  Widget build(BuildContext context) {
    final params = _ReportParams(
      year: _year,
      month: _month,
      project: widget.project,
      includeSubProjects: _includeSubProjects,
    );
    final reportAsync = ref.watch(_monthlyReportProvider(params));

    return Scaffold(
      appBar: AppBar(title: Text('${widget.project.name} 월별 리포트')),
      body: Column(
        children: [
          _buildMonthSelector(),
          _buildSubProjectToggle(),
          Expanded(
            child: reportAsync.when(
              loading: () => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text('AI가 리포트를 작성하고 있어요...', style: TextStyle(color: context.appColors.textSecondary)),
                  ],
                ),
              ),
              error: (e, _) => Center(child: Text('오류: $e', style: const TextStyle(color: AppColors.error))),
              data: (report) => SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              '$_year년 $_month월 AI 리포트',
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                            ),
                          ],
                        ),
                        if (_includeSubProjects) ...[
                          const SizedBox(height: 4),
                          Text('(하위 가계부 포함)', style: TextStyle(fontSize: 12, color: context.appColors.textHint)),
                        ],
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 12),
                        Text(report, style: const TextStyle(height: 1.8, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() {
              if (_month == 1) {
                _year--;
                _month = 12;
              } else {
                _month--;
              }
            }),
          ),
          Text(
            DateFormat('yyyy년 M월').format(DateTime(_year, _month)),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              final now = DateTime.now();
              if (_year < now.year || (_year == now.year && _month < now.month)) {
                setState(() {
                  if (_month == 12) {
                    _year++;
                    _month = 1;
                  } else {
                    _month++;
                  }
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubProjectToggle() {
    return Padding(
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
    );
  }
}
