import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/firebase_config.dart';
import 'app_logger.dart';
import 'functions_caller.dart';

enum InviteJoinStatus { joined, pending, alreadyPending, alreadyActive }

class InviteJoinResult {
  const InviteJoinResult({
    required this.status,
    required this.groupId,
    required this.groupName,
  });

  final InviteJoinStatus status;
  final String groupId;
  final String? groupName;
}

class CreatedInviteCode {
  const CreatedInviteCode({
    required this.code,
    required this.groupId,
    required this.expiresAt,
    required this.maxUses,
    required this.useCount,
  });

  final String code;
  final String groupId;
  final DateTime? expiresAt;
  final int maxUses;
  final int useCount;
}

class InviteService {
  InviteService._();

  static const String _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static final Random _random = Random.secure();

  static String normalizeCode(String raw) {
    final upper = raw.toUpperCase();
    final buffer = StringBuffer();
    for (final rune in upper.runes) {
      final isDigit = rune >= 48 && rune <= 57;
      final isAlpha = rune >= 65 && rune <= 90;
      if (isDigit || isAlpha) {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  static Future<CreatedInviteCode> createInvite({
    required String groupId,
    int expiresInDays = 7,
    int maxUses = 10,
  }) async {
    RangeError.checkValueInInterval(expiresInDays, 1, 365, 'expiresInDays');
    RangeError.checkValueInInterval(maxUses, 1, 100, 'maxUses');

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: '로그인이 필요합니다.',
      );
    }

    final db = FirebaseFirestore.instance;
    for (var attempt = 0; attempt < 8; attempt += 1) {
      final code = _generateCode();
      final groupRef = db.collection('groups').doc(groupId);
      final inviteRef = groupRef.collection('invites').doc(code);
      final inviteCodeRef = db.collection('inviteCodes').doc(code);
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(Duration(days: expiresInDays)),
      );

      try {
        await db.runTransaction((tx) async {
          final groupSnap = await tx.get(groupRef);
          if (!groupSnap.exists) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'not-found',
              message: '그룹을 찾을 수 없습니다.',
            );
          }
          final groupName = groupSnap.data()?['name']?.toString().trim();

          final codeSnap = await tx.get(inviteCodeRef);
          if (codeSnap.exists) {
            throw FirebaseException(
              plugin: 'cloud_firestore',
              code: 'already-exists',
              message: '이미 사용 중인 코드입니다.',
            );
          }

          final payload = <String, dynamic>{
            'code': code,
            'groupId': groupId,
            if (groupName != null && groupName.isNotEmpty)
              'groupName': groupName,
            'createdBy': user.uid,
            'status': 'active',
            'maxUses': maxUses,
            'useCount': 0,
            'expiresAt': expiresAt,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          tx.set(inviteRef, payload);
          tx.set(inviteCodeRef, payload);
        });

        return CreatedInviteCode(
          code: code,
          groupId: groupId,
          expiresAt: expiresAt.toDate(),
          maxUses: maxUses,
          useCount: 0,
        );
      } on FirebaseException catch (e) {
        if (e.code == 'already-exists') {
          unawaited(AppLogger.warn(
            'invite_code_collision',
            groupId: groupId,
            context: {'attempt': attempt, 'code': code},
          ));
          continue;
        }
        rethrow;
      }
    }

    unawaited(AppLogger.warn(
      'invite_code_all_attempts_failed',
      groupId: groupId,
      context: {'maxAttempts': 8},
    ));
    throw FirebaseException(
      plugin: 'cloud_firestore',
      code: 'aborted',
      message: '초대코드 발급에 실패했습니다. 잠시 후 다시 시도해 주세요.',
    );
  }

  static Future<void> revokeInvite({
    required String groupId,
    required String code,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: '로그인이 필요합니다.',
      );
    }

    final normalized = normalizeCode(code);
    final db = FirebaseFirestore.instance;
    final groupInviteRef = db
        .collection('groups')
        .doc(groupId)
        .collection('invites')
        .doc(normalized);
    final globalInviteRef = db.collection('inviteCodes').doc(normalized);

    final batch = db.batch();
    final updatePayload = <String, dynamic>{
      'status': 'revoked',
      'revokedBy': user.uid,
      'revokedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    batch.set(groupInviteRef, updatePayload, SetOptions(merge: true));
    batch.set(globalInviteRef, updatePayload, SetOptions(merge: true));
    await batch.commit();
  }

  static Future<InviteJoinResult> requestJoinWithCode({
    required String code,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unauthenticated',
        message: '로그인이 필요합니다.',
      );
    }

    final normalized = normalizeCode(code);
    try {
      final result = await FunctionsCaller.callWithRetry(
        () => FirebaseFunctions.instanceFor(
          region: FirebaseConfig.functionsRegion,
        ).httpsCallable('requestJoinWithInviteCode').call(<String, dynamic>{
          'code': normalized,
        }),
      );
      final response = result;
      final raw = response.data;
      if (raw is! Map) {
        throw FirebaseException(
          plugin: 'cloud_functions',
          code: 'internal',
          message: '응답 형식이 올바르지 않습니다.',
        );
      }
      final data = Map<String, dynamic>.from(raw);
      final statusRaw =
          data['status']?.toString().trim().toLowerCase() ?? 'joined';
      final status = switch (statusRaw) {
        'joined' => InviteJoinStatus.joined,
        'already_active' => InviteJoinStatus.alreadyActive,
        'already_pending' => InviteJoinStatus.alreadyPending,
        'pending' => InviteJoinStatus.pending,
        _ => throw FirebaseException(
            plugin: 'cloud_functions',
            code: 'internal',
            message: '알 수 없는 가입 상태입니다: $statusRaw',
          ),
      };
      final groupId = data['groupId']?.toString().trim() ?? '';
      if (groupId.isEmpty) {
        throw FirebaseException(
          plugin: 'cloud_functions',
          code: 'internal',
          message: '응답에 groupId가 없습니다.',
        );
      }
      final groupName = data['groupName']?.toString().trim();
      return InviteJoinResult(
        status: status,
        groupId: groupId,
        groupName: (groupName != null && groupName.isNotEmpty)
            ? groupName
            : null,
      );
    } on FirebaseFunctionsException catch (e) {
      if (_shouldFallbackToClientJoin(e)) {
        return _requestJoinWithCodeByClient(code: normalized, user: user);
      }
      throw FirebaseException(
        plugin: 'cloud_functions',
        code: e.code,
        message: e.message,
      );
    }
  }

  static bool _shouldFallbackToClientJoin(FirebaseFunctionsException e) {
    return e.code == 'internal' ||
        e.code == 'unavailable' ||
        e.code == 'not-found';
  }

  static Future<InviteJoinResult> _requestJoinWithCodeByClient({
    required String code,
    required User user,
  }) async {
    final db = FirebaseFirestore.instance;
    final inviteCodeRef = db.collection('inviteCodes').doc(code);
    final profileRef = db.collection('users').doc(user.uid);

    final result = await db.runTransaction<InviteJoinResult>((tx) async {
      final inviteSnap = await tx.get(inviteCodeRef);
      if (!inviteSnap.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: '유효하지 않은 초대코드입니다.',
        );
      }

      final inviteData = inviteSnap.data() ?? <String, dynamic>{};
      final groupId = inviteData['groupId']?.toString() ?? '';
      final groupName = inviteData['groupName']?.toString().trim();
      if (groupId.isEmpty) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: '초대코드 상태가 올바르지 않습니다.',
        );
      }

      final status = inviteData['status']?.toString() ?? 'active';
      if (status != 'active') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: '사용할 수 없는 초대코드입니다.',
        );
      }

      final expiresAt = inviteData['expiresAt'];
      if (expiresAt is Timestamp &&
          expiresAt.toDate().isBefore(DateTime.now())) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: '만료된 초대코드입니다.',
        );
      }

      final groupRef = db.collection('groups').doc(groupId);
      final memberRef = groupRef.collection('members').doc(user.uid);
      final membershipRef = db
          .collection('users')
          .doc(user.uid)
          .collection('memberships')
          .doc(groupId);
      final membershipSnap = await tx.get(membershipRef);
      if (membershipSnap.exists) {
        final membershipStatus = membershipSnap.data()?['status']?.toString();
        if (membershipStatus == 'active') {
          return InviteJoinResult(
            status: InviteJoinStatus.alreadyActive,
            groupId: groupId,
            groupName: groupName,
          );
        }
        if (membershipStatus == 'pending') {
          return InviteJoinResult(
            status: InviteJoinStatus.alreadyPending,
            groupId: groupId,
            groupName: groupName,
          );
        }
      }

      final profileSnap = await tx.get(profileRef);
      final profile = profileSnap.data() ?? <String, dynamic>{};
      final displayName =
          (profile['displayName']?.toString().trim().isNotEmpty ?? false)
          ? profile['displayName'].toString().trim()
          : (profile['nickname']?.toString().trim().isNotEmpty ?? false)
          ? profile['nickname'].toString().trim()
          : (user.displayName?.trim().isNotEmpty ?? false)
          ? user.displayName!.trim()
          : 'user_${user.uid.substring(0, 6)}';
      final photoUrl =
          (profile['photoUrl']?.toString().trim().isNotEmpty ?? false)
          ? profile['photoUrl'].toString().trim()
          : user.photoURL;

      final memberPayload = <String, dynamic>{
        'uid': user.uid,
        'status': 'pending',
        'displayName': displayName,
        'requestedAt': FieldValue.serverTimestamp(),
        'inviteCode': code,
      };
      if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        memberPayload['photoUrl'] = photoUrl.trim();
      }

      tx.set(memberRef, memberPayload);
      tx.set(membershipRef, <String, dynamic>{
        'groupId': groupId,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return InviteJoinResult(
        status: InviteJoinStatus.pending,
        groupId: groupId,
        groupName: (groupName != null && groupName.isNotEmpty)
            ? groupName
            : null,
      );
    });

    return result;
  }

  static String _generateCode([int length = 8]) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i += 1) {
      final index = _random.nextInt(_alphabet.length);
      buffer.write(_alphabet[index]);
    }
    return buffer.toString();
  }
}
