import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_paths.dart';
import '../dev/firestore_metrics.dart';
import '../dev/perf_timing.dart';

class EventsPage {
  const EventsPage({required this.docs, this.lastVisible});

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> docs;
  final QueryDocumentSnapshot<Map<String, dynamic>>? lastVisible;
}

class EventsRepository {
  EventsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<EventsPage> fetchEvents({
    required String groupId,
    int limit = 20,
    QueryDocumentSnapshot<Map<String, dynamic>>? startAfter,
  }) async {
    final span = PerfSpan('Events load').start();
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(FirestorePaths.groups)
          .doc(groupId)
          .collection(FirestorePaths.events)
          .orderBy(FirestorePaths.startAt)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snap = await query.get();
      FirestoreMetrics.instance.addReads(snap.docs.length);
      return EventsPage(
        docs: snap.docs,
        lastVisible: snap.docs.isEmpty ? startAfter : snap.docs.last,
      );
    } finally {
      span.end();
      FirestoreMetrics.instance.dump('events');
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getMyResponse({
    required String groupId,
    required String eventId,
    required String uid,
  }) async {
    final span = PerfSpan('Event my response').start();
    final doc = await _firestore
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection(FirestorePaths.events)
        .doc(eventId)
        .collection('responses')
        .doc(uid)
        .get();
    FirestoreMetrics.instance.addReads(doc.exists ? 1 : 0);
    span.end();
    return doc;
  }
}
