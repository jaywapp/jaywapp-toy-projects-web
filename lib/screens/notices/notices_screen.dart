import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../config/app_strings.dart';
import '../../config/firebase_config.dart';
import '../../dev/firestore_metrics.dart';
import '../../providers.dart';
import '../../services/functions_caller.dart';
import '../../services/permission_service.dart';
import '../../services/user_error_message.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/animated_list_entry.dart';
import '../../widgets/emoji_reaction_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';

class NoticesScreen extends ConsumerStatefulWidget {
  const NoticesScreen({super.key});

  @override
  ConsumerState<NoticesScreen> createState() => _NoticesScreenState();
}

class _NoticesScreenState extends ConsumerState<NoticesScreen> {
  Future<void> _deleteNotice({
    required String groupId,
    required String noticeId,
    required String title,
  }) async {
    if (!AppConfig.enableServerDependentFeatures) {
      AppSnackbar.show(
        context,
        message: '현재 요금제에서는 공지 삭제 기능이 비활성화되어 있습니다.',
        type: AppSnackType.info,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('공지 삭제'),
        content: Text('"$title" 공지를 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await FunctionsCaller.callWithRetry(
        () => FirebaseFunctions.instanceFor(
          region: FirebaseConfig.functionsRegion,
        ).httpsCallable('deleteNotice').call(<String, dynamic>{
          'groupId': groupId,
          'noticeId': noticeId,
        }),
      );
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '공지가 삭제되었습니다.',
        type: AppSnackType.success,
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'permission-denied' => '운영진 또는 작성자만 삭제할 수 있습니다.',
        'not-found' => '이미 삭제되었거나 존재하지 않는 공지입니다.',
        'internal' => '공지 삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
        _ => '공지 삭제 실패: ${e.code}',
      };
      AppSnackbar.show(context, message: message, type: AppSnackType.error);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '공지 삭제 중 오류가 발생했습니다.',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _refresh(String groupId) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('notices')
        .limit(1)
        .get();
  }

  Future<bool> _createNotice({
    required String groupId,
    required String uid,
    required String title,
    required String body,
    required bool pinned,
  }) async {
    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty || trimmedBody.isEmpty) {
      AppSnackbar.show(
        context,
        message: '제목과 본문을 입력해 주세요.',
        type: AppSnackType.error,
      );
      return false;
    }

    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('notices')
          .add({
            'title': trimmedTitle,
            'body': trimmedBody,
            'pinned': pinned,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': uid,
          });
      FirestoreMetrics.instance.addWrites();
      if (mounted) {
        AppSnackbar.show(
          context,
          message: '공지를 등록했습니다.',
          type: AppSnackType.success,
        );
      }
      return true;
    } on FirebaseException catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: toUserMessage(e),
          type: AppSnackType.error,
        );
      }
      return false;
    }
  }

  Future<void> _openCreateNoticeDialog({
    required String groupId,
    required String uid,
  }) async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    var pinned = false;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            sheetContext,
                          ).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '공지 추가',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      maxLength: 80,
                      decoration: const InputDecoration(labelText: '제목'),
                    ),
                    TextField(
                      controller: bodyController,
                      maxLength: 5000,
                      minLines: 4,
                      maxLines: 8,
                      decoration: const InputDecoration(labelText: '본문'),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: pinned,
                      onChanged: saving
                          ? null
                          : (value) => setSheetState(() => pinned = value),
                      title: const Text('상단 고정'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.of(sheetContext).pop(),
                            child: const Text('취소'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    setSheetState(() => saving = true);
                                    final created = await _createNotice(
                                      groupId: groupId,
                                      uid: uid,
                                      title: titleController.text,
                                      body: bodyController.text,
                                      pinned: pinned,
                                    );
                                    if (created && sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    } else {
                                      setSheetState(() => saving = false);
                                    }
                                  },
                            child: Text(saving ? '저장 중...' : '저장'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    bodyController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupId = ref.watch(selectedGroupIdProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (groupId == null || user == null)
      return const Center(child: Text(AppStrings.selectGroupFirst));

    final memberStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(user.uid)
        .snapshots();

    final noticesStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('notices')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: memberStream,
      builder: (context, memberSnap) {
        final permission = PermissionService.fromMemberData(
          memberSnap.data?.data(),
        );
        final canCreateNotices =
            permission.canManageEvents() || permission.canManageMembers();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: noticesStream,
          builder: (context, s) {
            if (s.hasError)
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(friendlyError(s.error)),
                ),
              );
            if (!s.hasData) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  AppSkeleton(height: 24, width: 90),
                  SizedBox(height: 12),
                  AppSkeleton(height: 96),
                  SizedBox(height: 8),
                  AppSkeleton(height: 96),
                ],
              );
            }

            final notices = s.data!.docs.toList();
            if (notices.isEmpty) {
              return EmptyState(
                icon: Icons.campaign_outlined,
                title: "공지가 없어요",
                description: "아직 등록된 공지가 없습니다. 중요한 공지는 상단에 고정할 수 있습니다.",
                actionLabel: canCreateNotices ? "공지 추가" : "새로고침",
                onAction: () => canCreateNotices
                    ? _openCreateNoticeDialog(groupId: groupId, uid: user.uid)
                    : _refresh(groupId),
              );
            }
            notices.sort((a, b) {
              final ap = a.data()['pinned'] == true ? 1 : 0;
              final bp = b.data()['pinned'] == true ? 1 : 0;
              if (ap != bp) return bp.compareTo(ap);
              final at = a.data()['createdAt'];
              final bt = b.data()['createdAt'];
              final ad = at is Timestamp
                  ? at.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);
              final bd = bt is Timestamp
                  ? bt.toDate()
                  : DateTime.fromMillisecondsSinceEpoch(0);
              return bd.compareTo(ad);
            });

            return RefreshIndicator(
              onRefresh: () => _refresh(groupId),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: notices.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0)
                    return SectionHeader(
                      title: "공지 목록",
                      icon: Icons.notifications_active_outlined,
                      actionLabel: canCreateNotices ? "공지 추가" : null,
                      onActionTap: canCreateNotices
                          ? () => _openCreateNoticeDialog(
                              groupId: groupId,
                              uid: user.uid,
                            )
                          : null,
                    );
                  final n = notices[i - 1];
                  final title = n.data()["title"] as String? ?? "(제목 없음)";
                  final body = n.data()['body'] as String? ?? '';
                  final pinned = n.data()['pinned'] == true;
                  final createdBy = n.data()['createdBy']?.toString();
                  final canDeleteNotice =
                      AppConfig.enableServerDependentFeatures &&
                      (permission.canManageMembers() ||
                          permission.canManageEvents() ||
                          createdBy == user.uid);
                  final createdAt = n.data()['createdAt'];
                  final createdAtText = createdAt is Timestamp
                      ? formatDate(createdAt.toDate())
                      : '';

                  return AnimatedListEntry(
                    index: i,
                    child: AppCard(
                      borderColor: pinned ? AppTheme.primary : null,
                      child: Semantics(
                        label: '${pinned ? "고정 공지: " : "공지: "}$title',
                        hint: '탭하여 공지 보기',
                        button: true,
                        child: InkWell(
                        onTap: () => context.push('/notice/${n.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (pinned) ...[
                                  ExcludeSemantics(child: Icon(
                                    Icons.push_pin,
                                    size: 14,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )),
                                  const SizedBox(width: 4),
                                  Text(
                                    "고정",
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                                const Spacer(),
                                if (createdAtText.isNotEmpty)
                                  Text(
                                    createdAtText,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                if (canDeleteNotice)
                                  PopupMenuButton<String>(
                                    tooltip: '공지 관리',
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deleteNotice(
                                          groupId: groupId,
                                          noticeId: n.id,
                                          title: title,
                                        );
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('삭제'),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            if (pinned || createdAtText.isNotEmpty)
                              const SizedBox(height: 8),
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (body.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                body,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: ExcludeSemantics(
                                child: Icon(
                                  Icons.chevron_right,
                                  size: 18,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

class NoticeDetailScreen extends ConsumerStatefulWidget {
  const NoticeDetailScreen({super.key, required this.noticeId});

  final String noticeId;

  @override
  ConsumerState<NoticeDetailScreen> createState() => _NoticeDetailScreenState();
}

class _NoticeDetailScreenState extends ConsumerState<NoticeDetailScreen> {
  bool _wroteRead = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_wroteRead) {
      _wroteRead = true;
      _writeReadReceipt();
    }
  }

  Future<void> _writeReadReceipt() async {
    final user = FirebaseAuth.instance.currentUser;
    final groupId = ref.read(selectedGroupIdProvider);
    if (user == null || groupId == null) return;

    try {
      await ref
          .read(noticesRepositoryProvider)
          .markNoticeRead(
            groupId: groupId,
            noticeId: widget.noticeId,
            uid: user.uid,
          );
    } on FirebaseException {
      // noop
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupId = ref.watch(selectedGroupIdProvider);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (groupId == null)
      return const Scaffold(body: Center(child: Text(AppStrings.selectGroupFirst)));

    final noticeRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('notices')
        .doc(widget.noticeId);
    final stream = noticeRef.snapshots();
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.article_outlined, size: 18),
            SizedBox(width: 6),
            Text("공지 상세"),
          ],
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, s) {
          if (s.hasError)
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(friendlyError(s.error)),
              ),
            );
          if (!s.hasData)
            return const Center(child: CircularProgressIndicator());
          final data = s.data!.data();
          if (data == null)
            return const Center(child: Text("공지 데이터를 찾을 수 없습니다."));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data["title"] as String? ?? "(제목 없음)",
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    Text(
                      data['body'] as String? ?? '',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(height: 1.55),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: noticeRef.collection('reactions').snapshots(),
                      builder: (context, reactionSnap) {
                        if (reactionSnap.hasError) {
                          return Text(
                            friendlyError(reactionSnap.error),
                            style: Theme.of(context).textTheme.bodySmall,
                          );
                        }
                        final reactionCounts = <String, int>{};
                        String? myEmoji;
                        if (reactionSnap.hasData) {
                          for (final doc in reactionSnap.data!.docs) {
                            final emoji = doc.data()['emoji']?.toString();
                            if (emoji == null || emoji.isEmpty) continue;
                            reactionCounts[emoji] =
                                (reactionCounts[emoji] ?? 0) + 1;
                            if (doc.id == currentUid) {
                              myEmoji = emoji;
                            }
                          }
                        }
                        return EmojiReactionBar(
                          reactionCounts: reactionCounts,
                          myEmoji: myEmoji,
                          onToggle: currentUid == null
                              ? null
                              : (emoji) async {
                                  try {
                                    final myReactionRef = noticeRef
                                        .collection('reactions')
                                        .doc(currentUid);
                                    if (myEmoji == emoji) {
                                      await myReactionRef.delete();
                                    } else {
                                      await myReactionRef.set({
                                        'uid': currentUid,
                                        'emoji': emoji,
                                        'updatedAt':
                                            FieldValue.serverTimestamp(),
                                      }, SetOptions(merge: true));
                                    }
                                  } on FirebaseException catch (e) {
                                    if (!context.mounted) return;
                                    AppSnackbar.show(
                                      context,
                                      message: friendlyError(e),
                                      type: AppSnackType.error,
                                    );
                                  }
                                },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('groups')
                    .doc(groupId)
                    .collection('notices')
                    .doc(widget.noticeId)
                    .collection('reads')
                    .orderBy('readAt', descending: true)
                    .limit(300)
                    .snapshots(),
                builder: (context, readSnap) {
                  if (readSnap.hasError) {
                    return AppCard(child: Text(friendlyError(readSnap.error)));
                  }
                  if (!readSnap.hasData) {
                    return const AppCard(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    );
                  }
                  final readDocs = readSnap.data!.docs;
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.mark_email_read_outlined,
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '읽음 ${readDocs.length}명',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (readDocs.isEmpty) const Text('아직 읽음 기록이 없습니다.'),
                        if (readDocs.isNotEmpty)
                          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('groups')
                                .doc(groupId)
                                .collection('members')
                                .where('status', isEqualTo: 'active')
                                .limit(300)
                                .snapshots(),
                            builder: (context, memberSnap) {
                              final namesByUid = <String, String>{};
                              if (memberSnap.hasData) {
                                for (final memberDoc in memberSnap.data!.docs) {
                                  final member = memberDoc.data();
                                  final displayName = member['displayName']
                                      ?.toString()
                                      .trim();
                                  namesByUid[memberDoc.id] =
                                      (displayName != null &&
                                          displayName.isNotEmpty)
                                      ? displayName
                                      : memberDoc.id;
                                }
                              }
                              return Column(
                                children: [
                                  for (final readDoc in readDocs)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 6,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '${namesByUid[readDoc.id] ?? readDoc.id} (@${readDoc.id})',
                                            ),
                                          ),
                                          Text(
                                            (() {
                                              final readAt = readDoc
                                                  .data()['readAt'];
                                              if (readAt is Timestamp) {
                                                return formatDate(
                                                  readAt.toDate(),
                                                );
                                              }
                                              return '-';
                                            })(),
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelSmall
                                                ?.copyWith(
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
