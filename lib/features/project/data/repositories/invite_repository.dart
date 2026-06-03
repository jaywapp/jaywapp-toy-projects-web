import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/project_model.dart';

class InviteRepository {
  final _db = FirebaseFirestore.instance;

  Future<String> createInviteCode(String projectId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    final code = _generateCode();
    await _db.collection('invites').doc(code).set({
      'projectId': projectId,
      'createdBy': uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(DateTime.now().add(const Duration(hours: 48))),
    });
    return code;
  }

  Future<({String code, DateTime expiresAt})?> getActiveInviteCode(String projectId) async {
    final snapshot = await _db
        .collection('invites')
        .where('projectId', isEqualTo: projectId)
        .get();

    final now = DateTime.now();
    ({String code, DateTime expiresAt})? latest;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (now.isBefore(expiresAt)) {
        if (latest == null || expiresAt.isAfter(latest.expiresAt)) {
          latest = (code: doc.id, expiresAt: expiresAt);
        }
      }
    }
    return latest;
  }

  Future<String?> getProjectIdByCode(String code) async {
    final doc = await _db.collection('invites').doc(code).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    final expiresAt = (data['expiresAt'] as Timestamp).toDate();
    if (DateTime.now().isAfter(expiresAt)) return null;

    return data['projectId'] as String;
  }

  Future<void> joinProject(String projectId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    final projectDoc = await _db.collection('projects').doc(projectId).get();
    if (!projectDoc.exists) throw Exception('프로젝트를 찾을 수 없습니다.');

    final members = List<Map<String, dynamic>>.from(
      (projectDoc.data()!['members'] as List? ?? []).map((m) => Map<String, dynamic>.from(m as Map)),
    );

    final alreadyMember = members.any((m) => m['userId'] == uid);
    if (alreadyMember) return;

    members.add({'userId': uid, 'role': MemberRole.member.name});
    await _db.collection('projects').doc(projectId).update({'members': members});
  }

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    var code = '';
    var seed = rand;
    for (var i = 0; i < 8; i++) {
      code += chars[seed % chars.length];
      seed = (seed ~/ chars.length) + (seed * 31) % 997;
    }
    return code;
  }
}
