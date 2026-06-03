import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/project_model.dart';

class MemberRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String?> findUserIdByEmail(String email) async {
    final snapshot = await _firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  Future<void> inviteMember({
    required String projectId,
    required String inviteeUserId,
    MemberRole role = MemberRole.member,
  }) async {
    final ref = _firestore.collection('projects').doc(projectId);
    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw Exception('프로젝트를 찾을 수 없습니다.');

      final members = List<Map<String, dynamic>>.from(
        (doc.data()!['members'] as List).map((m) => Map<String, dynamic>.from(m as Map)),
      );

      final alreadyMember = members.any((m) => m['userId'] == inviteeUserId);
      if (alreadyMember) throw Exception('이미 멤버입니다.');

      members.add({'userId': inviteeUserId, 'role': role.name});
      tx.update(ref, {'members': members});
    });
  }

  Future<void> removeMember({
    required String projectId,
    required String userId,
  }) async {
    final ref = _firestore.collection('projects').doc(projectId);
    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw Exception('프로젝트를 찾을 수 없습니다.');

      final members = List<Map<String, dynamic>>.from(
        (doc.data()!['members'] as List).map((m) => Map<String, dynamic>.from(m as Map)),
      );

      final updated = members.where((m) => m['userId'] != userId).toList();
      tx.update(ref, {'members': updated});
    });
  }

  Future<void> updateMemberRole({
    required String projectId,
    required String userId,
    required MemberRole role,
  }) async {
    final ref = _firestore.collection('projects').doc(projectId);
    await _firestore.runTransaction((tx) async {
      final doc = await tx.get(ref);
      if (!doc.exists) throw Exception('프로젝트를 찾을 수 없습니다.');

      final members = List<Map<String, dynamic>>.from(
        (doc.data()!['members'] as List).map((m) => Map<String, dynamic>.from(m as Map)),
      );

      final idx = members.indexWhere((m) => m['userId'] == userId);
      if (idx == -1) throw Exception('멤버를 찾을 수 없습니다.');
      members[idx]['role'] = role.name;
      tx.update(ref, {'members': members});
    });
  }

  Future<Map<String, String>> getUserNames(List<String> userIds) async {
    if (userIds.isEmpty) return {};
    final snapshots = await Future.wait(
      userIds.map((id) => _firestore.collection('users').doc(id).get()),
    );
    return {
      for (final doc in snapshots)
        if (doc.exists) doc.id: (doc.data()!['name'] as String? ?? '알 수 없음'),
    };
  }
}
