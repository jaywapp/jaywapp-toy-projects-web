import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_paths.dart';
import '../dev/firestore_metrics.dart';
import '../dev/perf_timing.dart';

class FinanceSnapshotData {
  const FinanceSnapshotData({
    required this.myMember,
    required this.activeMembers,
    required this.records,
    required this.fee,
  });

  final Map<String, dynamic>? myMember;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> activeMembers;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> records;
  final Map<String, dynamic>? fee;
}

class FinanceRepository {
  FinanceRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<FinanceSnapshotData> loadFinance({
    required String groupId,
    required String uid,
    required String periodKey,
    int recordsLimit = 30,
  }) async {
    final span = PerfSpan('Finance load').start();
    try {
      final feeRef = _firestore
          .collection(FirestorePaths.groups)
          .doc(groupId)
          .collection('fees')
          .doc(periodKey);

      final results = await Future.wait([
        _firestore
            .collection(FirestorePaths.groups)
            .doc(groupId)
            .collection(FirestorePaths.members)
            .doc(uid)
            .get(),
        _firestore
            .collection(FirestorePaths.groups)
            .doc(groupId)
            .collection(FirestorePaths.members)
            .where(FirestorePaths.status, isEqualTo: 'active')
            .limit(recordsLimit)
            .get(),
        feeRef.collection('records').limit(recordsLimit).get(),
        feeRef.get(),
      ]);

      final myMember = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final active = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final records = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final fee = results[3] as DocumentSnapshot<Map<String, dynamic>>;

      FirestoreMetrics.instance.addReads(
        (myMember.exists ? 1 : 0) +
            active.docs.length +
            records.docs.length +
            (fee.exists ? 1 : 0),
      );

      return FinanceSnapshotData(
        myMember: myMember.data(),
        activeMembers: active.docs,
        records: records.docs,
        fee: fee.data(),
      );
    } finally {
      span.end();
      FirestoreMetrics.instance.dump('finance');
    }
  }
}
