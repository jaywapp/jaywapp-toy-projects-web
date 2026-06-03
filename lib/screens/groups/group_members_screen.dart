import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../config/firebase_config.dart';
import '../../services/functions_caller.dart';
import '../../services/profile_policy.dart';
import '../../services/permission_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';

enum _MembersSortOption { name, joinedAt }

class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  _MembersSortOption _sortOption = _MembersSortOption.name;
  final Set<String> _approving = <String>{};

  String get _sortLabel =>
      _sortOption == _MembersSortOption.name ? '이름순' : '가입일순';

  void _toggleSort() {
    setState(() {
      _sortOption = _sortOption == _MembersSortOption.name
          ? _MembersSortOption.joinedAt
          : _MembersSortOption.name;
    });
  }

  Future<void> _approvePending({
    required BuildContext context,
    required String userId,
  }) async {
    if (_approving.contains(userId)) return;
    setState(() => _approving.add(userId));
    try {
      if (AppConfig.enableServerDependentFeatures) {
        await _approvePendingByCallable(userId: userId);
      } else {
        await _approvePendingByClient(userId: userId);
      }
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message:
            '\uC2B9\uC778\uC774 \uC644\uB8CC\uB418\uC5C8\uC2B5\uB2C8\uB2E4.',
        type: AppSnackType.success,
      );
    } on FirebaseFunctionsException catch (e) {
      if (AppConfig.enableServerDependentFeatures &&
          _shouldFallbackClientApprove(e)) {
        try {
          await _approvePendingByClient(userId: userId);
          if (!context.mounted) return;
          AppSnackbar.show(
            context,
            message: '승인이 완료되었습니다.',
            type: AppSnackType.success,
          );
          return;
        } on FirebaseException catch (clientError) {
          if (!context.mounted) return;
          AppSnackbar.show(
            context,
            message: _toApprovalErrorMessage(clientError.code),
            type: AppSnackType.error,
          );
          return;
        } catch (_) {
          if (!context.mounted) return;
          AppSnackbar.show(
            context,
            message: '가입 승인 처리 중 오류가 발생했습니다.',
            type: AppSnackType.error,
          );
          return;
        }
      }
      if (!context.mounted) return;
      final message = _toApprovalErrorMessage(e.code);
      AppSnackbar.show(context, message: message, type: AppSnackType.error);
    } on FirebaseException catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: _toApprovalErrorMessage(e.code),
        type: AppSnackType.error,
      );
    } catch (_) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message:
            '\uAC00\uC785 \uC2B9\uC778 \uCC98\uB9AC \uC911 \uC624\uB958\uAC00 \uBC1C\uC0DD\uD588\uC2B5\uB2C8\uB2E4.',
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _approving.remove(userId));
      }
    }
  }

  Future<void> _approvePendingByCallable({required String userId}) async {
    await FunctionsCaller.callWithRetry(
      () => FirebaseFunctions.instanceFor(
        region: FirebaseConfig.functionsRegion,
      ).httpsCallable('approveMember').call(<String, dynamic>{
        'groupId': widget.groupId,
        'userId': userId,
      }),
    );
  }

  Future<void> _approvePendingByClient({required String userId}) async {
    final db = FirebaseFirestore.instance;
    final groupRef = db.collection('groups').doc(widget.groupId);
    final memberRef = groupRef.collection('members').doc(userId);
    final membershipRef = db
        .collection('users')
        .doc(userId)
        .collection('memberships')
        .doc(widget.groupId);

    await db.runTransaction((tx) async {
      final memberSnap = await tx.get(memberRef);
      if (!memberSnap.exists) {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'not-found',
          message: '승인 대상을 찾을 수 없습니다.',
        );
      }

      final status = memberSnap.data()?['status']?.toString() ?? '';
      if (status == 'active') {
        return;
      }
      if (status != 'pending') {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'failed-precondition',
          message: '현재 상태에서는 승인할 수 없습니다.',
        );
      }

      final now = FieldValue.serverTimestamp();
      tx.set(memberRef, {
        'status': 'active',
        'role': PermissionService.member,
        'permissions': const <String>[],
        'approvedAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));
      tx.set(membershipRef, {
        'groupId': widget.groupId,
        'status': 'active',
        'joinedAt': now,
        'role': PermissionService.member,
        'permissions': const <String>[],
        'updatedAt': now,
      }, SetOptions(merge: true));
    });
  }

  bool _shouldFallbackClientApprove(FirebaseFunctionsException e) {
    return e.code == 'internal' ||
        e.code == 'unavailable' ||
        e.code == 'not-found';
  }

  String _toApprovalErrorMessage(String code) {
    return switch (code) {
      'permission-denied' => '권한이 없습니다.',
      'failed-precondition' => '현재 상태에서는 승인할 수 없습니다.',
      'not-found' => '승인 대상을 찾을 수 없습니다.',
      'unavailable' => '서버 연결이 불안정합니다. 잠시 후 다시 시도해 주세요.',
      'internal' => '가입 승인 처리 중 오류가 발생했습니다.',
      _ => '승인 실패: $code',
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }

    final groupRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId);
    final activeMembersStream = groupRef
        .collection('members')
        .where('status', isEqualTo: 'active')
        .snapshots();
    final pendingMembersStream = groupRef
        .collection('members')
        .where('status', isEqualTo: 'pending')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            ExcludeSemantics(child: Icon(Icons.groups_2_outlined, size: 18)),
            SizedBox(width: 6),
            Text('팀원'),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: groupRef.snapshots(),
        builder: (context, groupSnap) {
          if (groupSnap.hasError) {
            return Center(child: Text('모임 정보를 불러오지 못했습니다: ${groupSnap.error}'));
          }
          if (!groupSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final groupData = groupSnap.data!.data() ?? <String, dynamic>{};
          final groupName = groupData['name']?.toString() ?? widget.groupId;
          final emblemUrl = groupData['emblemUrl']?.toString();

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: activeMembersStream,
            builder: (context, membersSnap) {
              if (membersSnap.hasError) {
                return Center(
                  child: Text('팀원 목록을 불러오지 못했습니다: ${membersSnap.error}'),
                );
              }
              if (!membersSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final members = membersSnap.data!.docs.toList();
              if (members.isEmpty) {
                return const EmptyState(
                  icon: Icons.group_off_outlined,
                  title: '활성 팀원이 없습니다',
                  description: '아직 참여가 승인된 팀원이 없습니다.',
                );
              }

              final uidList = members.map((m) => m.id).toList(growable: false);
              return FutureBuilder<Map<String, _MemberProfile>>(
                future: _loadMemberProfiles(uidList),
                builder: (context, profileSnap) {
                  final profiles =
                      profileSnap.data ?? const <String, _MemberProfile>{};
                  final sortedMembers = [...members]
                    ..sort((a, b) => _compareMembers(a, b, profiles));
                  Map<String, dynamic>? myMemberData;
                  for (final m in members) {
                    if (m.id == user.uid) {
                      myMemberData = m.data();
                      break;
                    }
                  }
                  final myPermission = PermissionService.fromMemberData(
                    myMemberData,
                  );
                  final canGrantRole = myPermission.isOwner;
                  final canKickMembers =
                      AppConfig.enableServerDependentFeatures &&
                      myPermission.canManageMembers();
                  final canApproveMembers =
                      myPermission.canManageMembers() ||
                      myPermission.isTreasurer;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      if (canApproveMembers)
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: pendingMembersStream,
                          builder: (context, pendingSnap) {
                            if (pendingSnap.hasError) {
                              return AppCard(
                                child: ListTile(
                                  title: const Text(
                                    '\uAC00\uC785 \uC2B9\uC778 \uB300\uAE30',
                                  ),
                                  subtitle: Text(
                                    friendlyError(pendingSnap.error),
                                  ),
                                ),
                              );
                            }
                            if (!pendingSnap.hasData) {
                              return const AppCard(
                                child: ListTile(
                                  title: Text(
                                    '\uAC00\uC785 \uC2B9\uC778 \uB300\uAE30',
                                  ),
                                  subtitle: Text(
                                    '\uB370\uC774\uD130\uB97C \uBD88\uB7EC\uC624\uB294 \uC911...',
                                  ),
                                ),
                              );
                            }
                            final pendingDocs = pendingSnap.data!.docs;
                            return AppCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '\uAC00\uC785 \uC2B9\uC778 \uB300\uAE30 ${pendingDocs.length}\uBA85',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  if (pendingDocs.isEmpty)
                                    const Text(
                                      '\uB300\uAE30 \uC911\uC778 \uAC00\uC785 \uC694\uCCAD\uC774 \uC5C6\uC2B5\uB2C8\uB2E4.',
                                    ),
                                  for (final doc in pendingDocs)
                                    ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: Text(
                                        doc.data()['displayName'] as String? ??
                                            doc.id,
                                      ),
                                      subtitle: Text('uid: ${doc.id}'),
                                      trailing: ElevatedButton(
                                        onPressed: _approving.contains(doc.id)
                                            ? null
                                            : () => _approvePending(
                                                context: context,
                                                userId: doc.id,
                                              ),
                                        child: Text(
                                          _approving.contains(doc.id)
                                              ? '\uCC98\uB9AC \uC911...'
                                              : '\uC2B9\uC778',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (canApproveMembers) const SizedBox(height: 8),
                      AppCard(
                        child: Row(
                          children: [
                            _GroupEmblem(
                              groupName: groupName,
                              emblemUrl: emblemUrl,
                              radius: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    groupName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text('활성 팀원 ${sortedMembers.length}명'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SectionHeader(
                        title: '팀원 목록',
                        icon: Icons.people_alt_outlined,
                        actionLabel: '정렬: $_sortLabel',
                        onActionTap: _toggleSort,
                      ),
                      for (final member in sortedMembers)
                        _MemberTile(
                          groupId: widget.groupId,
                          currentUserId: user.uid,
                          currentUserRole: myPermission.role,
                          canGrantRole: canGrantRole,
                          canKickMembers: canKickMembers,
                          member: member,
                          profile: profiles[member.id],
                        ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  int _compareMembers(
    QueryDocumentSnapshot<Map<String, dynamic>> a,
    QueryDocumentSnapshot<Map<String, dynamic>> b,
    Map<String, _MemberProfile> profiles,
  ) {
    final nameA = _displayNameOf(a, profiles[a.id]);
    final nameB = _displayNameOf(b, profiles[b.id]);
    if (_sortOption == _MembersSortOption.name) {
      return nameA.compareTo(nameB);
    }

    final joinedA = _extractJoinedAt(a.data());
    final joinedB = _extractJoinedAt(b.data());
    if (joinedA == null && joinedB == null) {
      return nameA.compareTo(nameB);
    }
    if (joinedA == null) return 1;
    if (joinedB == null) return -1;

    final byDate = joinedB.compareTo(joinedA);
    if (byDate != 0) return byDate;
    return nameA.compareTo(nameB);
  }

  static Future<Map<String, _MemberProfile>> _loadMemberProfiles(
    List<String> uids,
  ) async {
    if (uids.isEmpty) return const <String, _MemberProfile>{};
    final db = FirebaseFirestore.instance;
    final chunks = <List<String>>[];
    for (var i = 0; i < uids.length; i += 30) {
      final end = (i + 30 < uids.length) ? i + 30 : uids.length;
      chunks.add(uids.sublist(i, end));
    }

    final map = <String, _MemberProfile>{};
    for (final chunk in chunks) {
      final snap = await db
          .collection('users')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        map[doc.id] = _MemberProfile(
          name: (data['displayName']?.toString().trim().isNotEmpty ?? false)
              ? data['displayName'].toString().trim()
              : (data['nickname']?.toString().trim() ?? ''),
          phoneNumber: data['phoneNumber']?.toString(),
          photoUrl: data['photoUrl']?.toString(),
        );
      }
    }
    return map;
  }

  static String _displayNameOf(
    DocumentSnapshot<Map<String, dynamic>> doc,
    _MemberProfile? profile,
  ) {
    final profileName = profile?.name.trim();
    if (profileName != null && profileName.isNotEmpty) return profileName;
    final data = doc.data() ?? <String, dynamic>{};
    final byDisplayName = data['displayName']?.toString().trim();
    if (byDisplayName != null && byDisplayName.isNotEmpty) return byDisplayName;
    final byPublic = (data['public'] as Map?)?['nickname']?.toString().trim();
    if (byPublic != null && byPublic.isNotEmpty) return byPublic;
    return doc.id;
  }
}

class _MemberTile extends StatelessWidget {
  static const String _delegateOwnerAction = '__delegate_owner__';

  const _MemberTile({
    required this.groupId,
    required this.currentUserId,
    required this.currentUserRole,
    required this.canGrantRole,
    required this.canKickMembers,
    required this.member,
    required this.profile,
  });

  final String groupId;
  final String currentUserId;
  final String currentUserRole;
  final bool canGrantRole;
  final bool canKickMembers;
  final QueryDocumentSnapshot<Map<String, dynamic>> member;
  final _MemberProfile? profile;

  @override
  Widget build(BuildContext context) {
    final data = member.data();
    final permission = PermissionService.fromMemberData(data);
    final displayName = _GroupMembersScreenState._displayNameOf(
      member,
      profile,
    );
    final joinedAt = _extractJoinedAt(data);
    final joinedText = joinedAt == null
        ? '가입일 정보 없음'
        : '가입일 ${formatDateFull(joinedAt)}';
    final normalizedPhone = ProfilePolicy.normalizePhoneNumber(
      profile?.phoneNumber ?? data['phoneNumber']?.toString() ?? '',
    );
    final hasPhone = normalizedPhone.isNotEmpty;
    final photoUrl = (profile?.photoUrl?.trim().isNotEmpty ?? false)
        ? profile!.photoUrl!.trim()
        : data['photoUrl']?.toString();
    final canEditRole = canGrantRole && member.id != currentUserId;
    final canKick =
        canKickMembers &&
        member.id != currentUserId &&
        permission.role != PermissionService.owner &&
        (currentUserRole == PermissionService.owner ||
            permission.role == PermissionService.member);
    final showActions =
        canEditRole ||
        canKick ||
        permission.role != PermissionService.member ||
        hasPhone;

    return AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: _MemberAvatar(displayName: displayName, photoUrl: photoUrl),
        title: Text(displayName),
        subtitle: Text(joinedText),
        trailing: showActions
            ? Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (canEditRole) ...[
                    PopupMenuButton<String>(
                      tooltip: '권한 변경',
                      initialValue: permission.role,
                      onSelected: (nextRole) {
                        if (nextRole == _delegateOwnerAction) {
                          if (!AppConfig.enableServerDependentFeatures) {
                            AppSnackbar.show(
                              context,
                              message: '모임장 위임 기능이 현재 비활성화되어 있습니다.',
                              type: AppSnackType.info,
                            );
                            return;
                          }
                          _delegateOwner(
                            context: context,
                            groupId: groupId,
                            newOwnerUid: member.id,
                            newOwnerName: displayName,
                          );
                          return;
                        }
                        _setRole(
                          context: context,
                          groupId: groupId,
                          userId: member.id,
                          nextRole: nextRole,
                        );
                      },
                      itemBuilder: (context) {
                        final items = <PopupMenuEntry<String>>[
                          const PopupMenuItem(
                            value: PermissionService.member,
                            child: Text('일반 멤버'),
                          ),
                          const PopupMenuItem(
                            value: PermissionService.admin,
                            child: Text('운영진'),
                          ),
                          const PopupMenuItem(
                            value: PermissionService.treasurer,
                            child: Text('회계 운영진'),
                          ),
                        ];
                        if (permission.role != PermissionService.owner) {
                          if (!AppConfig.enableServerDependentFeatures) {
                            return items;
                          }
                          items.add(const PopupMenuDivider());
                          items.add(
                            const PopupMenuItem(
                              value: _delegateOwnerAction,
                              child: Row(
                                children: [
                                  ExcludeSemantics(
                                    child: Icon(
                                      Icons.workspace_premium,
                                      size: 16,
                                      color: Color(0xFFF4B400),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text('모임장 위임'),
                                ],
                              ),
                            ),
                          );
                        }
                        return items;
                      },
                      icon: const Icon(Icons.manage_accounts_outlined),
                    ),
                    if (permission.role != PermissionService.member || hasPhone)
                      const SizedBox(width: 6),
                  ],
                  if (permission.role != PermissionService.member) ...[
                    _RoleBadge(role: permission.role),
                    if (canKick || hasPhone) const SizedBox(width: 6),
                  ],
                  if (canKick) ...[
                    IconButton(
                      tooltip: '팀원 강퇴',
                      icon: const Icon(Icons.person_remove_alt_1_outlined),
                      onPressed: () => _kickMember(
                        context: context,
                        groupId: groupId,
                        userId: member.id,
                        displayName: displayName,
                      ),
                    ),
                    if (hasPhone) const SizedBox(width: 6),
                  ],
                  if (hasPhone)
                    IconButton(
                      tooltip: '전화 걸기',
                      icon: const Icon(Icons.call_outlined),
                      onPressed: () => _callPhone(context, normalizedPhone),
                    ),
                ],
              )
            : null,
      ),
    );
  }

  static Future<void> _kickMember({
    required BuildContext context,
    required String groupId,
    required String userId,
    required String displayName,
  }) async {
    if (!AppConfig.enableServerDependentFeatures) {
      AppSnackbar.show(
        context,
        message: '현재 요금제에서는 팀원 강퇴 기능이 비활성화되어 있습니다.',
        type: AppSnackType.info,
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('팀원 강퇴'),
        content: Text('"$displayName" 님을 강퇴할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('강퇴'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FunctionsCaller.callWithRetry(
        () => FirebaseFunctions.instanceFor(
          region: FirebaseConfig.functionsRegion,
        ).httpsCallable('kickMember').call({
          'groupId': groupId,
          'userId': userId,
        }),
      );
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: '팀원이 강퇴되었습니다.',
        type: AppSnackType.success,
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      final message = switch (e.code) {
        'permission-denied' => '강퇴 권한이 없습니다.',
        'failed-precondition' => e.message ?? '강퇴할 수 없는 대상입니다.',
        'not-found' => '대상 멤버를 찾을 수 없습니다.',
        _ => '강퇴 실패: ${e.code}',
      };
      AppSnackbar.show(context, message: message, type: AppSnackType.error);
    } catch (_) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: '강퇴 처리 중 오류가 발생했습니다.',
        type: AppSnackType.error,
      );
    }
  }

  static Future<void> _setRole({
    required BuildContext context,
    required String groupId,
    required String userId,
    required String nextRole,
  }) async {
    try {
      final permissions = switch (nextRole) {
        PermissionService.admin => <String>[
          'member.manage',
          'event.manage',
          'settings.manage',
        ],
        PermissionService.treasurer => <String>[
          'finance.manage',
          'member.manage',
        ],
        _ => <String>[],
      };
      await FunctionsCaller.callWithRetry(
        () => FirebaseFunctions.instanceFor(
          region: FirebaseConfig.functionsRegion,
        ).httpsCallable('setRoleAndClaims').call({
          'groupId': groupId,
          'userId': userId,
          'role': nextRole,
          'permissions': permissions,
        }),
      );
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: '권한이 변경되었습니다.',
        type: AppSnackType.success,
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      final message = e.code == 'permission-denied'
          ? '권한이 없습니다.'
          : '권한 변경 실패: ${e.code}';
      AppSnackbar.show(context, message: message, type: AppSnackType.error);
    } catch (_) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: '권한 변경 중 오류가 발생했습니다.',
        type: AppSnackType.error,
      );
    }
  }

  static Future<void> _delegateOwner({
    required BuildContext context,
    required String groupId,
    required String newOwnerUid,
    required String newOwnerName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('모임장 위임'),
        content: Text(
          '$newOwnerName 님에게 모임장을 위임할까요?\n위임 후 현재 모임장은 운영진으로 전환됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('위임'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await FunctionsCaller.callWithRetry(
        () => FirebaseFunctions.instanceFor(
          region: FirebaseConfig.functionsRegion,
        ).httpsCallable('delegateGroupOwner').call({
          'groupId': groupId,
          'newOwnerUid': newOwnerUid,
        }),
      );
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: '모임장 위임이 완료되었습니다.',
        type: AppSnackType.success,
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      final message = e.code == 'permission-denied'
          ? '모임장만 위임할 수 있습니다.'
          : '모임장 위임 실패: ${e.code}';
      AppSnackbar.show(context, message: message, type: AppSnackType.error);
    } catch (_) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: '모임장 위임 중 오류가 발생했습니다.',
        type: AppSnackType.error,
      );
    }
  }

  static Future<void> _callPhone(BuildContext context, String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
      return;
    }
    if (!context.mounted) return;
    AppSnackbar.show(
      context,
      message: '전화 앱을 실행할 수 없습니다.',
      type: AppSnackType.error,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    String? label;
    IconData icon;
    Color accent;
    switch (role) {
      case PermissionService.owner:
        label = '\uBAA8\uC784\uC7A5';
        icon = Icons.workspace_premium;
        accent = const Color(0xFFF4B400);
      case PermissionService.admin:
        label = '\uC6B4\uC601\uC9C4';
        icon = Icons.workspace_premium;
        accent = const Color(0xFFF4B400);
      case PermissionService.treasurer:
        label = '\uD68C\uACC4 \uC6B4\uC601\uC9C4';
        icon = Icons.attach_money;
        accent = const Color(0xFF2E7D32);
      default:
        label = null;
        icon = Icons.workspace_premium;
        accent = const Color(0xFFF4B400);
    }
    if (label == null) {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 16, color: accent)),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

DateTime? _extractJoinedAt(Map<String, dynamic> data) {
  final joined = data['joinedAt'];
  if (joined is Timestamp) return joined.toDate();
  final approved = data['approvedAt'];
  if (approved is Timestamp) return approved.toDate();
  final requested = data['requestedAt'];
  if (requested is Timestamp) return requested.toDate();
  final publicJoined = (data['public'] as Map?)?['joinedAt'];
  if (publicJoined is Timestamp) return publicJoined.toDate();
  return null;
}

class _GroupEmblem extends StatelessWidget {
  const _GroupEmblem({
    required this.groupName,
    required this.emblemUrl,
    this.radius = 18,
  });

  final String groupName;
  final String? emblemUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final hasImage = emblemUrl != null && emblemUrl!.trim().isNotEmpty;
    final initial = groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G';
    return CircleAvatar(
      radius: radius,
      backgroundImage: hasImage ? NetworkImage(emblemUrl!.trim()) : null,
      onBackgroundImageError: hasImage ? (_, __) {} : null,
      child: hasImage ? null : Text(initial),
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({required this.displayName, required this.photoUrl});

  final String displayName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = photoUrl != null && photoUrl!.trim().isNotEmpty;
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U';
    return CircleAvatar(
      backgroundImage: hasImage ? NetworkImage(photoUrl!.trim()) : null,
      onBackgroundImageError: hasImage ? (_, __) {} : null,
      child: hasImage ? null : Text(initial),
    );
  }
}

class _MemberProfile {
  const _MemberProfile({
    required this.name,
    required this.phoneNumber,
    required this.photoUrl,
  });

  final String name;
  final String? phoneNumber;
  final String? photoUrl;
}
