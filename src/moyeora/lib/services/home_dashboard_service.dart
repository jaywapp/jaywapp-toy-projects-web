import 'package:cloud_firestore/cloud_firestore.dart';

import '../dev/firestore_metrics.dart';
import '../dev/perf_timing.dart';

class HomeDashboardService {
  HomeDashboardService._();

  static Future<Map<String, String>> loadHomeKpi(
    String groupId,
    String uid,
  ) async {
    final span = PerfSpan('Home KPI').start();
    final now = DateTime.now();
    final db = FirebaseFirestore.instance;
    final periodKey = _currentPeriodKey(now);

    final statsDoc = await db
        .collection('groups')
        .doc(groupId)
        .collection('stats')
        .doc(periodKey)
        .get();
    FirestoreMetrics.instance.addReads(statsDoc.exists ? 1 : 0);

    final upcomingEvents = await db
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .where('isDeleted', isEqualTo: false)
        .where('startAt', isGreaterThan: Timestamp.fromDate(now))
        .orderBy('startAt')
        .limit(10)
        .get();
    FirestoreMetrics.instance.addReads(upcomingEvents.docs.length);

    final feeSummary = await db
        .collection('groups')
        .doc(groupId)
        .collection('fees')
        .doc(periodKey)
        .get();
    FirestoreMetrics.instance.addReads(feeSummary.exists ? 1 : 0);

    final stats = statsDoc.data() ?? const <String, dynamic>{};
    final attendanceRateRaw = stats['attendanceRate'];
    final attendanceRate = attendanceRateRaw is num
        ? '${attendanceRateRaw.toStringAsFixed(1)}%'
        : '-';
    final unpaidCount = _toInt(feeSummary.data()?['unpaidCount'], fallback: 0);

    final result = {
      'attendanceRate': attendanceRate,
      'unpaidCount': '${unpaidCount}명',
      'upcomingCount': '${upcomingEvents.docs.length}건',
    };
    span.end();
    FirestoreMetrics.instance.dump('home-kpi');
    return result;
  }

  static Future<Map<String, String>> loadMyHomeSummary(
    String groupId,
    String uid,
  ) async {
    final db = FirebaseFirestore.instance;
    final now = DateTime.now();
    final periodKey = _currentPeriodKey(now);
    final lbDoc = await db
        .collection('groups')
        .doc(groupId)
        .collection('leaderboards')
        .doc(periodKey)
        .get();
    final attendanceTop =
        (lbDoc.data()?['attendanceTop'] as List<dynamic>? ?? const []);

    final top3 = attendanceTop
        .take(3)
        .map((item) {
          if (item is Map) {
            final nickname = item['nickname']?.toString();
            final uidValue = item['uid']?.toString();
            return nickname ?? uidValue ?? '-';
          }
          return '-';
        })
        .where((name) => name != '-')
        .join(', ');

    var rankText = '-';
    for (var i = 0; i < attendanceTop.length; i++) {
      final item = attendanceTop[i];
      if (item is Map && item['uid'] == uid) {
        rankText = '${i + 1}위';
        break;
      }
    }

    return {'top3': top3.isEmpty ? '-' : top3, 'rank': rankText};
  }

  static Future<Map<String, String>> loadHomeEngagement(
    String groupId,
    String uid,
  ) async {
    final span = PerfSpan('Home engagement').start();
    final db = FirebaseFirestore.instance;
    final periodKey = _currentPeriodKey();

    final lbDoc = await db
        .collection('groups')
        .doc(groupId)
        .collection('leaderboards')
        .doc(periodKey)
        .get();
    FirestoreMetrics.instance.addReads(lbDoc.exists ? 1 : 0);

    final statsDoc = await db
        .collection('groups')
        .doc(groupId)
        .collection('stats')
        .doc(periodKey)
        .get();
    FirestoreMetrics.instance.addReads(statsDoc.exists ? 1 : 0);

    final activityTop =
        (lbDoc.data()?['activityTop'] as List<dynamic>? ?? const []);
    final attendanceTop =
        (lbDoc.data()?['attendanceTop'] as List<dynamic>? ?? const []);

    var activityRank = '-';
    var attendanceRank = '-';
    for (var i = 0; i < activityTop.length; i++) {
      final item = activityTop[i];
      if (item is Map && item['uid'] == uid) {
        activityRank = '${i + 1}위';
        break;
      }
    }
    for (var i = 0; i < attendanceTop.length; i++) {
      final item = attendanceTop[i];
      if (item is Map && item['uid'] == uid) {
        attendanceRank = '${i + 1}위';
        break;
      }
    }

    final noResponseCount = _toInt(
      statsDoc.data()?['weeklyNoResponseCount'],
      fallback: 0,
    );
    final result = {
      'weeklyNoResponse': '${noResponseCount}명',
      'attendanceStreak': attendanceRank,
      'activityRank': activityRank,
    };
    span.end();
    FirestoreMetrics.instance.dump('home-engagement');
    return result;
  }

  static String _currentPeriodKey([DateTime? date]) {
    final now = date ?? DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    return '${now.year}-$month';
  }

  static int _toInt(dynamic value, {required int fallback}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
