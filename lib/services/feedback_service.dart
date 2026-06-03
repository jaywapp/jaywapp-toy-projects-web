import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FeedbackService {
  FeedbackService._();

  static Future<void> createSuggestion({
    required String groupId,
    required String title,
    required String body,
    required bool isAnonymous,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: '로그인이 필요합니다.',
      );
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    final displayName =
        userData['nickname']?.toString().trim().isNotEmpty == true
        ? userData['nickname'].toString().trim()
        : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : (user.email ?? user.uid));

    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('suggestions')
        .add({
          'title': title.trim(),
          'body': body.trim(),
          'isAnonymous': isAnonymous,
          'createdBy': user.uid,
          'createdByName': displayName,
          'status': 'open',
          'createdAt': now,
          'updatedAt': now,
        });
  }

  static Future<void> createBetaReport({
    required String title,
    required String body,
    required String category,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: '로그인이 필요합니다.',
      );
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    final displayName =
        userData['nickname']?.toString().trim().isNotEmpty == true
        ? userData['nickname'].toString().trim()
        : (user.displayName?.trim().isNotEmpty == true
              ? user.displayName!.trim()
              : (user.email ?? user.uid));

    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance
        .collection('beta_reports')
        .add({
          'title': title.trim(),
          'body': body.trim(),
          'category': category,
          'createdBy': user.uid,
          'createdByName': displayName,
          'status': 'open',
          'createdAt': now,
          'updatedAt': now,
        });
  }

  static Future<void> createPoll({
    required String groupId,
    required String title,
    required List<String> options,
    String? description,
    DateTime? endAt,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: '로그인이 필요합니다.',
      );
    }

    final cleanedOptions = options
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    if (cleanedOptions.length < 2) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: '선택지는 최소 2개 이상이어야 합니다.',
      );
    }

    final resolvedEndAt = endAt ?? DateTime.now().add(const Duration(days: 7));
    if (!resolvedEndAt.isAfter(DateTime.now())) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'invalid-argument',
        message: '종료 일시는 현재 시각 이후여야 합니다.',
      );
    }

    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('polls')
        .add({
          'title': title.trim(),
          'description': description?.trim() ?? '',
          'options': cleanedOptions,
          'status': 'open',
          'endAt': Timestamp.fromDate(resolvedEndAt),
          'createdBy': user.uid,
          'createdAt': now,
          'updatedAt': now,
        });
  }

  static Future<void> votePoll({
    required String groupId,
    required String pollId,
    required int optionIndex,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: '로그인이 필요합니다.',
      );
    }

    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('polls')
        .doc(pollId)
        .collection('votes')
        .doc(user.uid)
        .set({
          'uid': user.uid,
          'optionIndex': optionIndex,
          'votedAt': now,
          'updatedAt': now,
        }, SetOptions(merge: true));
  }

  static Future<void> setPollStatus({
    required String groupId,
    required String pollId,
    required String status,
  }) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('polls')
        .doc(pollId)
        .set({
          'status': status,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
