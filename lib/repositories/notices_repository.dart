import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_paths.dart';
import '../dev/firestore_metrics.dart';
import '../dev/perf_timing.dart';

class NoticesRepository {
  NoticesRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> fetchNotices({
    required String groupId,
    int limit = 30,
  }) async {
    final span = PerfSpan('Notices load').start();
    try {
      final snap = await _firestore
          .collection(FirestorePaths.groups)
          .doc(groupId)
          .collection(FirestorePaths.notices)
          .orderBy(FirestorePaths.createdAt, descending: true)
          .limit(limit)
          .get();
      FirestoreMetrics.instance.addReads(snap.docs.length);
      return snap.docs;
    } finally {
      span.end();
      FirestoreMetrics.instance.dump('notices');
    }
  }

  Future<void> markNoticeRead({
    required String groupId,
    required String noticeId,
    required String uid,
  }) async {
    final span = PerfSpan('Notice read mark').start();
    await _firestore
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection(FirestorePaths.notices)
        .doc(noticeId)
        .collection('reads')
        .doc(uid)
        .set({'readAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));

    await _firestore.collection(FirestorePaths.users).doc(uid).set({
      'lastNoticeSeenAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    FirestoreMetrics.instance.addWrites(2);
    span.end();
  }
}
