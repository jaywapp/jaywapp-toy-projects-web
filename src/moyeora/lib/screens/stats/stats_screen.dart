import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../dev/firestore_metrics.dart';
import '../../dev/perf_timing.dart';
import '../../services/aggregation_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.groupId, required this.uid});

  final String groupId;
  final String uid;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _refreshTick = 0;

  Future<QuerySnapshot<Map<String, dynamic>>> _loadRecentByDocId({
    required CollectionReference<Map<String, dynamic>> collection,
    int limit = 6,
  }) async {
    try {
      return await collection
          .orderBy(FieldPath.documentId, descending: true)
          .limit(limit)
          .get();
    } on FirebaseException catch (e) {
      if (e.code != 'failed-precondition') rethrow;
      // Fallback when composite index is missing in target project.
      return collection.get();
    }
  }

  Future<_StatsBundle> _load() async {
    final span = PerfSpan('통계 로드').start();
    final periodKey = currentPeriodKey();
    final db = FirebaseFirestore.instance;
    final groupRef = db.collection('groups').doc(widget.groupId);
    final results = await Future.wait([
      groupRef.collection('stats').doc(periodKey).get(),
      groupRef.collection('leaderboards').doc(periodKey).get(),
      _loadRecentByDocId(collection: groupRef.collection('stats'), limit: 6),
      _loadRecentByDocId(
        collection: groupRef.collection('leaderboards'),
        limit: 6,
      ),
    ]);
    final statsDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final leaderboardDoc = results[1] as DocumentSnapshot<Map<String, dynamic>>;
    final statsHistorySnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
    final leaderboardHistorySnap =
        results[3] as QuerySnapshot<Map<String, dynamic>>;
    FirestoreMetrics.instance.addReads(
      (statsDoc.exists ? 1 : 0) +
          (leaderboardDoc.exists ? 1 : 0) +
          statsHistorySnap.size +
          leaderboardHistorySnap.size,
    );
    span.end();
    FirestoreMetrics.instance.dump('stats');
    final statsHistory = statsHistorySnap.docs
        .map((doc) => MapEntry(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (statsHistory.length > 6) {
      statsHistory.removeRange(0, statsHistory.length - 6);
    }
    final leaderboardHistory = leaderboardHistorySnap.docs
        .map((doc) => MapEntry(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    if (leaderboardHistory.length > 6) {
      leaderboardHistory.removeRange(0, leaderboardHistory.length - 6);
    }
    return _StatsBundle(
      stats: statsDoc.data(),
      leaderboard: leaderboardDoc.data(),
      periodKey: periodKey,
      statsHistory: statsHistory,
      leaderboardHistory: leaderboardHistory,
    );
  }

  Future<void> _refresh() async {
    setState(() => _refreshTick++);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            ExcludeSemantics(child: Icon(Icons.stacked_bar_chart_outlined, size: 18)),
            SizedBox(width: 6),
            Text('통계'),
          ],
        ),
      ),
      body: FutureBuilder<_StatsBundle>(
        key: ValueKey('${widget.groupId}:${widget.uid}:$_refreshTick'),
        future: _load(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('통계 로딩 실패: ${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final stats = data.stats ?? const <String, dynamic>{};
          final lb = data.leaderboard ?? const <String, dynamic>{};
          final attendanceTop = _toRankRows(lb['attendanceTop']);
          final activityTop = _toRankRows(lb['activityTop']);

          final generatedAtRaw = stats['generatedAt'] ?? lb['generatedAt'];
          final generatedAt = generatedAtRaw is Timestamp
              ? generatedAtRaw.toDate()
              : null;
          final versionRaw = stats['version'] ?? lb['version'];
          final version = versionRaw is num ? versionRaw.toInt() : null;
          final stale =
              generatedAt == null ||
              DateTime.now().difference(generatedAt).inHours > 24;

          if (stale) {
            AggregationService.requestRecompute(
              groupId: widget.groupId,
              periodKey: data.periodKey,
            );
          }

          final activeMemberCount = _asInt(stats['activeMemberCount']);
          final eventCountThisMonth = _asInt(stats['eventCountThisMonth']);
          final attendanceRate = _extractAttendanceRate(
            stats: stats,
            attendanceTop: attendanceTop,
            activeMemberCount: activeMemberCount,
            eventCountThisMonth: eventCountThisMonth,
          );

          final myAttendanceRank = _rankOf(attendanceTop, widget.uid);
          final myActivityRank = _rankOf(activityTop, widget.uid);
          final myAttendanceScore = _scoreOf(attendanceTop, widget.uid);
          final myActivityScore = _scoreOf(activityTop, widget.uid);
          final rateTrend = _buildAttendanceRateTrend(
            statsHistory: data.statsHistory,
            fallbackPeriodKey: data.periodKey,
            fallbackRate: attendanceRate,
          );
          final barItems = _buildBarItems(rateTrend);
          final myAttendanceTrend = _buildMyAttendanceScoreTrend(
            leaderboardHistory: data.leaderboardHistory,
            uid: widget.uid,
          );

          final colorScheme = Theme.of(context).colorScheme;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (stale)
                  AppCard(
                    child: Row(
                      children: [
                        ExcludeSemantics(child: Icon(Icons.sync, size: 16, color: colorScheme.primary)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '통계 집계 중입니다. 잠시 후 최신 데이터가 반영됩니다.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SectionHeader(title: '월간 출석률', icon: Icons.show_chart),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            attendanceRate.toStringAsFixed(1),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primary,
                                  fontSize: 36,
                                ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4, left: 2),
                            child: Text(
                              '%',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            data.periodKey.replaceAll('-', '.'),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: attendanceRate / 100,
                          minHeight: 6,
                          backgroundColor: colorScheme.outlineVariant
                              .withValues(alpha: 0.3),
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 160,
                        child: BarChart(
                          BarChartData(
                            maxY: 100,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: 25,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.3,
                                ),
                                strokeWidth: 1,
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 32,
                                  interval: 25,
                                  getTitlesWidget: (value, meta) => Text(
                                    '${value.toInt()}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    final i = value.toInt();
                                    if (i < 0 || i >= barItems.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(
                                        barItems[i].label,
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                            barGroups: [
                              for (var i = 0; i < barItems.length; i++)
                                BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: barItems[i].value,
                                      color: AppTheme.primary,
                                      width: 24,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const SectionHeader(
                  title: '내 출석 점수 추이',
                  icon: Icons.multiline_chart_outlined,
                ),
                AppCard(
                  child: myAttendanceTrend.length < 2
                      ? Center(
                          child: Text(
                            '추이를 표시할 데이터가 아직 부족합니다.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        )
                      : SizedBox(
                          height: 180,
                          child: LineChart(
                            LineChartData(
                              minY: 0,
                              maxY: _lineMaxY(myAttendanceTrend),
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: false,
                                horizontalInterval: _lineInterval(
                                  myAttendanceTrend,
                                ),
                                getDrawingHorizontalLine: (value) => FlLine(
                                  color: colorScheme.outlineVariant.withValues(
                                    alpha: 0.3,
                                  ),
                                  strokeWidth: 1,
                                ),
                              ),
                              borderData: FlBorderData(show: false),
                              titlesData: FlTitlesData(
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 34,
                                    interval: _lineInterval(myAttendanceTrend),
                                    getTitlesWidget: (value, meta) => Text(
                                      value.toInt().toString(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color:
                                                colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      final i = value.toInt();
                                      if (i < 0 ||
                                          i >= myAttendanceTrend.length) {
                                        return const SizedBox.shrink();
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Text(
                                          _periodLabel(
                                            myAttendanceTrend[i].periodKey,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: [
                                    for (
                                      var i = 0;
                                      i < myAttendanceTrend.length;
                                      i++
                                    )
                                      FlSpot(
                                        i.toDouble(),
                                        myAttendanceTrend[i].value,
                                      ),
                                  ],
                                  isCurved: true,
                                  barWidth: 3,
                                  color: AppTheme.primary,
                                  dotData: FlDotData(
                                    show: true,
                                    getDotPainter:
                                        (spot, percent, bar, index) =>
                                            FlDotCirclePainter(
                                              radius: 3.2,
                                              color: AppTheme.primary,
                                              strokeColor:
                                                  colorScheme.surface,
                                              strokeWidth: 1.2,
                                            ),
                                  ),
                                  belowBarData: BarAreaData(
                                    show: true,
                                    color: AppTheme.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 8),
                const SectionHeader(title: '내 활동', icon: Icons.person_outline),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.emoji_events_outlined,
                        label: '출석 순위',
                        value: myAttendanceRank == null
                            ? '-'
                            : '${myAttendanceRank}위',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.trending_up,
                        label: '활동 순위',
                        value: myActivityRank == null
                            ? '-'
                            : '${myActivityRank}위',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.check_circle_outline,
                        label: '출석 점수',
                        value: '$myAttendanceScore',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricTile(
                        icon: Icons.local_fire_department_outlined,
                        label: '활동 점수',
                        value: '$myActivityScore',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const SectionHeader(
                  title: '출석 상위',
                  icon: Icons.military_tech_outlined,
                ),
                ..._buildTop3Cards(context, attendanceTop),
                if (version != null || generatedAt != null) ...[
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'v${version ?? '-'}  |  ${generatedAt != null ? formatDate(generatedAt) : '-'} 기준',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatsBundle {
  const _StatsBundle({
    required this.stats,
    required this.leaderboard,
    required this.periodKey,
    required this.statsHistory,
    required this.leaderboardHistory,
  });

  final Map<String, dynamic>? stats;
  final Map<String, dynamic>? leaderboard;
  final String periodKey;
  final List<MapEntry<String, Map<String, dynamic>>> statsHistory;
  final List<MapEntry<String, Map<String, dynamic>>> leaderboardHistory;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow {
  const _RankRow({
    required this.uid,
    required this.nickname,
    required this.score,
  });

  final String uid;
  final String nickname;
  final int score;
}

class _BarItem {
  const _BarItem({required this.label, required this.value});

  final String label;
  final double value;
}

class _TrendPoint {
  const _TrendPoint({required this.periodKey, required this.value});

  final String periodKey;
  final double value;
}

List<Widget> _buildTop3Cards(BuildContext context, List<_RankRow> rows) {
  final top3 = rows.take(3).toList();
  if (top3.isEmpty) {
    return [
      AppCard(
        child: Center(
          child: Text(
            '아직 순위 데이터가 없습니다.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    ];
  }
  const medals = ['🥇', '🥈', '🥉'];
  final maxScore = top3.first.score;
  return [
    for (var i = 0; i < top3.length; i++)
      AppCard(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(medals[i], style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    top3[i].nickname,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: maxScore > 0 ? top3[i].score / maxScore : 0,
                      minHeight: 4,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.outlineVariant.withValues(alpha: 0.3),
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${top3[i].score}점',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppTheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
  ];
}

List<_RankRow> _toRankRows(dynamic raw) {
  if (raw is! List) return const <_RankRow>[];
  final rows = <_RankRow>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final uid = item['uid']?.toString();
    if (uid == null || uid.isEmpty) continue;
    rows.add(
      _RankRow(
        uid: uid,
        nickname: item['nickname']?.toString() ?? uid,
        score: _asInt(item['score']),
      ),
    );
  }
  return rows;
}

int _asInt(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

double _extractAttendanceRate({
  required Map<String, dynamic> stats,
  required List<_RankRow> attendanceTop,
  required int activeMemberCount,
  required int eventCountThisMonth,
}) {
  final raw = stats['attendanceRate'];
  if (raw is num) return raw.clamp(0, 100).toDouble();
  if (raw is String) {
    final cleaned = raw.replaceAll('%', '').trim();
    final parsed = double.tryParse(cleaned);
    if (parsed != null) return parsed.clamp(0, 100);
  }

  if (activeMemberCount > 0 &&
      eventCountThisMonth > 0 &&
      attendanceTop.isNotEmpty) {
    final attended = attendanceTop.fold<int>(
      0,
      (accumulated, row) => accumulated + row.score,
    );
    final estimated =
        (attended / (activeMemberCount * eventCountThisMonth)) * 100;
    return estimated.clamp(0, 100);
  }

  return 0;
}

List<_TrendPoint> _buildAttendanceRateTrend({
  required List<MapEntry<String, Map<String, dynamic>>> statsHistory,
  required String fallbackPeriodKey,
  required double fallbackRate,
}) {
  final rows = <_TrendPoint>[
    for (final entry in statsHistory)
      if (_tryParseRate(entry.value['attendanceRate']) case final rate?)
        _TrendPoint(periodKey: entry.key, value: rate),
  ];
  final hasFallback = rows.any((row) => row.periodKey == fallbackPeriodKey);
  if (!hasFallback) {
    rows.add(
      _TrendPoint(
        periodKey: fallbackPeriodKey,
        value: fallbackRate.clamp(0, 100).toDouble(),
      ),
    );
  }
  rows.sort((a, b) => a.periodKey.compareTo(b.periodKey));
  if (rows.length > 6) {
    return rows.sublist(rows.length - 6);
  }
  return rows;
}

List<_BarItem> _buildBarItems(List<_TrendPoint> trend) {
  if (trend.isEmpty) return const <_BarItem>[];
  return <_BarItem>[
    for (final item in trend)
      _BarItem(label: _periodLabel(item.periodKey), value: item.value),
  ];
}

List<_TrendPoint> _buildMyAttendanceScoreTrend({
  required List<MapEntry<String, Map<String, dynamic>>> leaderboardHistory,
  required String uid,
}) {
  final rows = <_TrendPoint>[];
  for (final entry in leaderboardHistory) {
    final attendanceTop = _toRankRows(entry.value['attendanceTop']);
    final rank = _rankOf(attendanceTop, uid);
    if (rank == null) continue;
    rows.add(
      _TrendPoint(
        periodKey: entry.key,
        value: _scoreOf(attendanceTop, uid).toDouble(),
      ),
    );
  }
  rows.sort((a, b) => a.periodKey.compareTo(b.periodKey));
  if (rows.length > 6) {
    return rows.sublist(rows.length - 6);
  }
  return rows;
}

double _lineMaxY(List<_TrendPoint> rows) {
  if (rows.isEmpty) return 10;
  final maxValue = rows.fold<double>(
    0,
    (accumulated, item) => item.value > accumulated ? item.value : accumulated,
  );
  if (maxValue <= 10) return 10;
  if (maxValue <= 20) return 20;
  if (maxValue <= 50) return 50;
  if (maxValue <= 100) return 100;
  return (maxValue * 1.2).ceilToDouble();
}

double _lineInterval(List<_TrendPoint> rows) {
  final maxY = _lineMaxY(rows);
  if (maxY <= 20) return 5;
  if (maxY <= 50) return 10;
  if (maxY <= 100) return 20;
  return (maxY / 5).ceilToDouble();
}

double? _tryParseRate(dynamic raw) {
  if (raw is num) return raw.clamp(0, 100).toDouble();
  if (raw is String) {
    final cleaned = raw.replaceAll('%', '').trim();
    final parsed = double.tryParse(cleaned);
    if (parsed != null) return parsed.clamp(0, 100);
  }
  return null;
}

String _periodLabel(String periodKey) {
  final parts = periodKey.split('-');
  if (parts.length != 2) return periodKey;
  final month = int.tryParse(parts[1]);
  if (month == null) return periodKey;
  return '${month}월';
}

int? _rankOf(List<_RankRow> rows, String uid) {
  for (var i = 0; i < rows.length; i++) {
    if (rows[i].uid == uid) return i + 1;
  }
  return null;
}

int _scoreOf(List<_RankRow> rows, String uid) {
  for (final row in rows) {
    if (row.uid == uid) return row.score;
  }
  return 0;
}

