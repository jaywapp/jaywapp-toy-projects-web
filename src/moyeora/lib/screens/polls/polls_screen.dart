import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../config/firebase_config.dart';
import '../../services/feedback_service.dart';
import '../../services/functions_caller.dart';
import '../../services/permission_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_loading_button.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_badge.dart';

class PollsScreen extends StatefulWidget {
  const PollsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  Future<void> _openCreatePollModal() async {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final optionControllers = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];
    var selectedEndAt = DateTime.now().add(const Duration(days: 1));
    var submitting = false;

    Future<void> submitPoll({
      required StateSetter setModalState,
      required BuildContext modalContext,
    }) async {
      if (submitting) return;
      final title = titleController.text.trim();
      final options = optionControllers
          .map((c) => c.text.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (title.isEmpty || options.length < 2) {
        AppSnackbar.show(
          context,
          message: '투표 제목과 선택지 2개 이상을 입력해 주세요.',
          type: AppSnackType.info,
        );
        return;
      }
      if (!selectedEndAt.isAfter(DateTime.now())) {
        AppSnackbar.show(
          context,
          message: '종료 일시는 현재 시각 이후로 설정해 주세요.',
          type: AppSnackType.info,
        );
        return;
      }

      setModalState(() => submitting = true);
      try {
        await FeedbackService.createPoll(
          groupId: widget.groupId,
          title: title,
          description: descController.text.trim(),
          options: options,
          endAt: selectedEndAt,
        );
        if (!mounted) return;
        if (modalContext.mounted && Navigator.of(modalContext).canPop()) {
          Navigator.of(modalContext).pop();
        }
        AppSnackbar.show(
          context,
          message: '투표가 등록되었습니다.',
          type: AppSnackType.success,
        );
      } catch (e) {
        if (!mounted) return;
        AppSnackbar.show(
          context,
          message: '투표 등록 실패: ${friendlyError(e)}',
          type: AppSnackType.error,
        );
      } finally {
        if (modalContext.mounted) {
          setModalState(() => submitting = false);
        }
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  top: 16,
                  right: 16,
                  bottom: MediaQuery.of(modalContext).viewInsets.bottom + 16,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '투표 생성',
                            style: Theme.of(modalContext).textTheme.titleLarge,
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: '닫기',
                            onPressed: () => Navigator.of(modalContext).pop(),
                            icon: const ExcludeSemantics(child: Icon(Icons.close)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(labelText: '투표 제목'),
                        maxLength: 80,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: descController,
                        decoration: const InputDecoration(labelText: '설명(선택)'),
                        maxLength: 400,
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('종료 일시'),
                        subtitle: Row(
                          children: [
                            const ExcludeSemantics(child: Icon(Icons.schedule, size: 16)),
                            const SizedBox(width: 6),
                            Text(
                              formatDateTime(selectedEndAt),
                              style: Theme.of(modalContext).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        trailing: Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton(
                              onPressed: () async {
                                final next = await _pickEndDate(
                                  context: modalContext,
                                  current: selectedEndAt,
                                );
                                if (next == null) return;
                                setModalState(() => selectedEndAt = next);
                              },
                              child: const Text('날짜'),
                            ),
                            OutlinedButton(
                              onPressed: () async {
                                final next = await _pickEndTime(
                                  context: modalContext,
                                  current: selectedEndAt,
                                );
                                if (next == null) return;
                                setModalState(() => selectedEndAt = next);
                              },
                              child: const Text('시간'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (var i = 0; i < optionControllers.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: optionControllers[i],
                                  decoration: InputDecoration(
                                    labelText: '선택지 ${i + 1}',
                                  ),
                                ),
                              ),
                              if (optionControllers.length > 2)
                                IconButton(
                                  tooltip: '선택지 삭제',
                                  onPressed: () {
                                    setModalState(() {
                                      final removed = optionControllers
                                          .removeAt(i);
                                      removed.dispose();
                                    });
                                  },
                                  icon: const ExcludeSemantics(child: Icon(Icons.remove_circle_outline)),
                                ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              if (optionControllers.length >= 6) return;
                              setModalState(() {
                                optionControllers.add(TextEditingController());
                              });
                            },
                            icon: const ExcludeSemantics(child: Icon(Icons.add)),
                            label: const Text('선택지 추가'),
                          ),
                          const Spacer(),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AppLoadingButton(
                        loading: submitting,
                        enabled: true,
                        label: '생성',
                        onPressed: () => submitPoll(
                          setModalState: setModalState,
                          modalContext: modalContext,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    descController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
  }

  Future<DateTime?> _pickEndDate({
    required BuildContext context,
    required DateTime current,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked == null) return null;
    return DateTime(
      picked.year,
      picked.month,
      picked.day,
      current.hour,
      current.minute,
    );
  }

  Future<DateTime?> _pickEndTime({
    required BuildContext context,
    required DateTime current,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (picked == null) return null;
    return DateTime(
      current.year,
      current.month,
      current.day,
      picked.hour,
      picked.minute,
    );
  }

  Future<void> _vote({required String pollId, required int optionIndex}) async {
    try {
      await FeedbackService.votePoll(
        groupId: widget.groupId,
        pollId: pollId,
        optionIndex: optionIndex,
      );
      if (!mounted) return;
      AppSnackbar.show(context, message: '투표가 반영되었습니다.');
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '투표 반영 실패: ${friendlyError(e)}',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _togglePollStatus({
    required String pollId,
    required bool currentlyOpen,
  }) async {
    try {
      await FeedbackService.setPollStatus(
        groupId: widget.groupId,
        pollId: pollId,
        status: currentlyOpen ? 'closed' : 'open',
      );
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: currentlyOpen ? '투표를 마감했습니다.' : '투표를 다시 열었습니다.',
        type: AppSnackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '투표 상태 변경 실패: ${friendlyError(e)}',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _deletePoll({
    required String pollId,
    required String title,
  }) async {
    if (!AppConfig.enableServerDependentFeatures) {
      AppSnackbar.show(
        context,
        message: '현재 요금제에서는 투표 삭제 기능이 비활성화되어 있습니다.',
        type: AppSnackType.info,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('투표 삭제'),
        content: Text('"$title" 투표를 삭제할까요?'),
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
        ).httpsCallable('deletePoll').call(<String, dynamic>{
          'groupId': widget.groupId,
          'pollId': pollId,
        }),
      );
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '투표가 삭제되었습니다.',
        type: AppSnackType.success,
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'permission-denied' => '운영진 또는 작성자만 삭제할 수 있습니다.',
        'not-found' => '이미 삭제되었거나 존재하지 않는 투표입니다.',
        'internal' => '투표 삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
        _ => '투표 삭제 실패: ${e.code}',
      };
      AppSnackbar.show(context, message: message, type: AppSnackType.error);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '투표 삭제 중 오류가 발생했습니다.',
        type: AppSnackType.error,
      );
    }
  }

  Widget _buildPollOption({
    required BuildContext context,
    required String label,
    required int count,
    required int total,
    required bool isMyVote,
    required bool isOpen,
    required VoidCallback? onTap,
  }) {
    final ratio = total > 0 ? count / total : 0.0;
    final pct = (ratio * 100).round();
    final colorScheme = Theme.of(context).colorScheme;
    final barColor = isMyVote
        ? colorScheme.primary
        : colorScheme.outlineVariant;

    return Semantics(
      label: '$label $count표 ($pct%)',
      hint: onTap != null ? '탭하여 투표' : null,
      button: onTap != null,
      selected: isMyVote,
      child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isMyVote ? colorScheme.primary : colorScheme.outlineVariant,
          ),
          color: isMyVote
              ? colorScheme.primary.withValues(alpha: 0.06)
              : Colors.transparent,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isMyVote) ...[
                  ExcludeSemantics(
                    child: Icon(
                      Icons.check_circle,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isMyVote ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Text(
                  '$count표 ($pct%)',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 4,
                backgroundColor: colorScheme.outlineVariant.withValues(
                  alpha: 0.3,
                ),
                color: barColor,
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildPollCard({
    required BuildContext context,
    required QueryDocumentSnapshot<Map<String, dynamic>> pollDoc,
    required String uid,
    required bool canManagePoll,
    required bool canDeletePoll,
  }) {
    final data = pollDoc.data();
    final title = data['title']?.toString() ?? '(제목 없음)';
    final description = data['description']?.toString() ?? '';
    final rawStatus = data['status']?.toString() ?? 'open';
    final endAt = data['endAt'];
    final endAtDateTime = endAt is Timestamp ? endAt.toDate() : null;
    final isExpired =
        endAtDateTime != null && !endAtDateTime.isAfter(DateTime.now());
    final isOpen = rawStatus == 'open' && !isExpired;
    final statusLabel = isOpen ? '진행중' : '종료';
    final options = (data['options'] is List)
        ? (data['options'] as List)
              .map((e) => e.toString())
              .where((e) => e.isNotEmpty)
              .toList()
        : <String>[];

    if (options.isEmpty) {
      return const SizedBox.shrink();
    }

    return AppCard(
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: pollDoc.reference.collection('votes').snapshots(),
        builder: (context, votesSnap) {
          final counts = List<int>.filled(options.length, 0);
          int? myVote;
          if (votesSnap.hasData) {
            for (final voteDoc in votesSnap.data!.docs) {
              final index = voteDoc.data()['optionIndex'];
              if (index is int && index >= 0 && index < options.length) {
                counts[index] += 1;
                if (voteDoc.id == uid) {
                  myVote = index;
                }
              }
            }
          }
          final totalVotes = counts.fold<int>(0, (a, b) => a + b);
          final colorScheme = Theme.of(context).colorScheme;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusBadge(
                    label: statusLabel,
                    tone: isOpen
                        ? StatusBadgeTone.success
                        : StatusBadgeTone.warning,
                  ),
                  const Spacer(),
                  if (endAtDateTime != null)
                    Text(
                      '마감 ${formatDateTime(endAtDateTime)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  if (canDeletePoll)
                    PopupMenuButton<String>(
                      tooltip: '투표 관리',
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deletePoll(pollId: pollDoc.id, title: title);
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
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              for (var i = 0; i < options.length; i++) ...[
                _buildPollOption(
                  context: context,
                  label: options[i],
                  count: counts[i],
                  total: totalVotes,
                  isMyVote: myVote == i,
                  isOpen: isOpen,
                  onTap: isOpen
                      ? () => _vote(pollId: pollDoc.id, optionIndex: i)
                      : null,
                ),
                if (i < options.length - 1) const SizedBox(height: 6),
              ],
              if (totalVotes > 0) ...[
                const SizedBox(height: 8),
                Text(
                  '총 $totalVotes표',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (canManagePoll) ...[
                Divider(height: 20, color: colorScheme.outlineVariant),
                Align(
                  alignment: Alignment.centerRight,
                  child: (rawStatus == 'open' && !isExpired)
                      ? TextButton(
                          onPressed: () => _togglePollStatus(
                            pollId: pollDoc.id,
                            currentlyOpen: true,
                          ),
                          child: const Text('마감하기'),
                        )
                      : (rawStatus == 'closed')
                      ? TextButton(
                          onPressed: () => _togglePollStatus(
                            pollId: pollDoc.id,
                            currentlyOpen: false,
                          ),
                          child: const Text('재오픈'),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('로그인이 필요합니다.'));
    }

    final myMemberStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('members')
        .doc(user.uid)
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: myMemberStream,
      builder: (context, memberSnap) {
        if (!memberSnap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final permission = PermissionService.fromMemberData(
          memberSnap.data?.data(),
        );
        final canCreatePoll =
            permission.canManageMembers() ||
            permission.canManageEvents() ||
            permission.isOwner;

        final pollsStream = FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('polls')
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '투표',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                if (canCreatePoll)
                  FilledButton.icon(
                    onPressed: _openCreatePollModal,
                    icon: const Icon(Icons.add),
                    label: const Text('생성'),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: pollsStream,
              builder: (context, pollSnap) {
                if (pollSnap.hasError) {
                  return AppCard(child: Text(friendlyError(pollSnap.error)));
                }
                if (!pollSnap.hasData) {
                  return const AppCard(
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final polls = pollSnap.data!.docs;
                final openPolls = polls.where((doc) {
                  final data = doc.data();
                  final status = data['status']?.toString() ?? 'open';
                  final endAt = data['endAt'];
                  final endAtDateTime = endAt is Timestamp
                      ? endAt.toDate()
                      : null;
                  final expired =
                      endAtDateTime != null &&
                      !endAtDateTime.isAfter(DateTime.now());
                  return status == 'open' && !expired;
                }).toList();
                final closedPolls = polls.where((doc) {
                  final data = doc.data();
                  final status = data['status']?.toString() ?? 'open';
                  final endAt = data['endAt'];
                  final endAtDateTime = endAt is Timestamp
                      ? endAt.toDate()
                      : null;
                  final expired =
                      endAtDateTime != null &&
                      !endAtDateTime.isAfter(DateTime.now());
                  return status != 'open' || expired;
                }).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader(
                      title: '진행중인 투표',
                      icon: Icons.how_to_vote_outlined,
                    ),
                    if (openPolls.isEmpty)
                      const AppCard(child: Text('현재 진행중인 투표가 없습니다.')),
                    if (openPolls.isNotEmpty)
                      ...openPolls.map((pollDoc) {
                        final createdBy = pollDoc
                            .data()['createdBy']
                            ?.toString();
                        final canDeletePoll =
                            AppConfig.enableServerDependentFeatures &&
                            (canCreatePoll || createdBy == user.uid);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildPollCard(
                            context: context,
                            pollDoc: pollDoc,
                            uid: user.uid,
                            canManagePoll: canCreatePoll,
                            canDeletePoll: canDeletePoll,
                          ),
                        );
                      }),
                    const SizedBox(height: 12),
                    const SectionHeader(
                      title: '종료된 투표',
                      icon: Icons.history_toggle_off,
                    ),
                    if (closedPolls.isEmpty)
                      const AppCard(child: Text('종료된 투표가 없습니다.')),
                    if (closedPolls.isNotEmpty)
                      ...closedPolls.map((pollDoc) {
                        final createdBy = pollDoc
                            .data()['createdBy']
                            ?.toString();
                        final canDeletePoll =
                            AppConfig.enableServerDependentFeatures &&
                            (canCreatePoll || createdBy == user.uid);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildPollCard(
                            context: context,
                            pollDoc: pollDoc,
                            uid: user.uid,
                            canManagePoll: canCreatePoll,
                            canDeletePoll: canDeletePoll,
                          ),
                        );
                      }),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}
