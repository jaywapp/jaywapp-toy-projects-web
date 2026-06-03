import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/feedback_service.dart';
import '../../services/permission_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_loading_button.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/section_header.dart';

class FeedbackHubScreen extends StatefulWidget {
  const FeedbackHubScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<FeedbackHubScreen> createState() => _FeedbackHubScreenState();
}

class _FeedbackHubScreenState extends State<FeedbackHubScreen> {
  final _suggestTitleController = TextEditingController();
  final _suggestBodyController = TextEditingController();
  final _pollTitleController = TextEditingController();
  final _pollDescController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers =
      <TextEditingController>[TextEditingController(), TextEditingController()];

  bool _anonymousSuggestion = false;
  bool _submittingSuggestion = false;
  bool _submittingPoll = false;

  @override
  void dispose() {
    _suggestTitleController.dispose();
    _suggestBodyController.dispose();
    _pollTitleController.dispose();
    _pollDescController.dispose();
    for (final c in _pollOptionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submitSuggestion() async {
    if (_submittingSuggestion) return;
    final title = _suggestTitleController.text.trim();
    final body = _suggestBodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      AppSnackbar.show(
        context,
        message: '제목과 내용을 모두 입력해 주세요.',
        type: AppSnackType.info,
      );
      return;
    }
    setState(() => _submittingSuggestion = true);
    try {
      await FeedbackService.createSuggestion(
        groupId: widget.groupId,
        title: title,
        body: body,
        isAnonymous: _anonymousSuggestion,
      );
      if (!mounted) return;
      _suggestTitleController.clear();
      _suggestBodyController.clear();
      setState(() => _anonymousSuggestion = false);
      AppSnackbar.show(
        context,
        message: '건의가 등록되었습니다.',
        type: AppSnackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '건의 등록 실패: ${friendlyError(e)}',
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _submittingSuggestion = false);
    }
  }

  Future<void> _submitPoll() async {
    if (_submittingPoll) return;
    final title = _pollTitleController.text.trim();
    final options = _pollOptionControllers
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

    setState(() => _submittingPoll = true);
    try {
      await FeedbackService.createPoll(
        groupId: widget.groupId,
        title: title,
        description: _pollDescController.text.trim(),
        options: options,
      );
      if (!mounted) return;
      _pollTitleController.clear();
      _pollDescController.clear();
      for (final c in _pollOptionControllers) {
        c.clear();
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
      if (mounted) setState(() => _submittingPoll = false);
    }
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
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
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final permission = PermissionService.fromMemberData(
          memberSnap.data?.data(),
        );
        final canCreatePoll =
            permission.canManageMembers() ||
            permission.canManageEvents() ||
            permission.isOwner;

        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Row(
                children: [
                  ExcludeSemantics(child: Icon(Icons.forum_outlined, size: 18)),
                  SizedBox(width: 6),
                  Text('의견/투표'),
                ],
              ),
              bottom: const TabBar(
                tabs: [
                  Tab(text: '의견 건의'),
                  Tab(text: '투표'),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                _SuggestionTab(
                  groupId: widget.groupId,
                  titleController: _suggestTitleController,
                  bodyController: _suggestBodyController,
                  anonymous: _anonymousSuggestion,
                  submitting: _submittingSuggestion,
                  onAnonymousChanged: (value) =>
                      setState(() => _anonymousSuggestion = value),
                  onSubmit: _submitSuggestion,
                ),
                _PollTab(
                  groupId: widget.groupId,
                  currentUid: user.uid,
                  canCreatePoll: canCreatePoll,
                  pollTitleController: _pollTitleController,
                  pollDescController: _pollDescController,
                  pollOptionControllers: _pollOptionControllers,
                  submittingPoll: _submittingPoll,
                  onAddOption: () {
                    if (_pollOptionControllers.length >= 6) return;
                    setState(() {
                      _pollOptionControllers.add(TextEditingController());
                    });
                  },
                  onRemoveOption: (index) {
                    if (_pollOptionControllers.length <= 2) return;
                    setState(() {
                      final removed = _pollOptionControllers.removeAt(index);
                      removed.dispose();
                    });
                  },
                  onSubmitPoll: _submitPoll,
                  onVote: _vote,
                  onToggleStatus: _togglePollStatus,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SuggestionTab extends StatelessWidget {
  const _SuggestionTab({
    required this.groupId,
    required this.titleController,
    required this.bodyController,
    required this.anonymous,
    required this.submitting,
    required this.onAnonymousChanged,
    required this.onSubmit,
  });

  final String groupId;
  final TextEditingController titleController;
  final TextEditingController bodyController;
  final bool anonymous;
  final bool submitting;
  final ValueChanged<bool> onAnonymousChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final suggestionsStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('suggestions')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SectionHeader(title: '의견 건의하기', icon: Icons.edit_note_outlined),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: '제목'),
                maxLength: 80,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bodyController,
                decoration: const InputDecoration(labelText: '내용'),
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: anonymous,
                onChanged: onAnonymousChanged,
                title: const Text('익명으로 등록'),
              ),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: titleController,
                builder: (context, _, __) {
                  return ValueListenableBuilder<TextEditingValue>(
                    valueListenable: bodyController,
                    builder: (context, _, __) {
                      final canSubmit =
                          !submitting &&
                          titleController.text.trim().isNotEmpty &&
                          bodyController.text.trim().isNotEmpty;
                      return SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: canSubmit ? onSubmit : null,
                          icon: submitting
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_outlined, size: 16),
                          label: Text(submitting ? '전송 중...' : '제보 전송'),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const SectionHeader(title: '등록된 건의', icon: Icons.inbox_outlined),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: suggestionsStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AppCard(child: Text(friendlyError(snapshot.error)));
            }
            if (!snapshot.hasData) {
              return const AppCard(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const AppCard(child: Text('아직 등록된 건의가 없습니다.'));
            }
            return Column(
              children: docs.map((doc) {
                final data = doc.data();
                final isAnonymous = data['isAnonymous'] == true;
                final writer = isAnonymous
                    ? '익명'
                    : (data['createdByName']?.toString() ?? '작성자 없음');
                final title = data['title']?.toString() ?? '(제목 없음)';
                final body = data['body']?.toString() ?? '';
                final createdAt = data['createdAt'];
                final createdAtText = createdAt is Timestamp
                    ? formatDate(createdAt.toDate())
                    : '-';
                final status = data['status']?.toString() ?? 'open';
                final statusText = switch (status) {
                  'planned' => '검토중',
                  'closed' => '완료',
                  _ => '접수',
                };
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(body),
                        const SizedBox(height: 8),
                        Text(
                          '작성: $writer / 등록: $createdAtText / 상태: $statusText',
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _PollTab extends StatelessWidget {
  const _PollTab({
    required this.groupId,
    required this.currentUid,
    required this.canCreatePoll,
    required this.pollTitleController,
    required this.pollDescController,
    required this.pollOptionControllers,
    required this.submittingPoll,
    required this.onAddOption,
    required this.onRemoveOption,
    required this.onSubmitPoll,
    required this.onVote,
    required this.onToggleStatus,
  });

  final String groupId;
  final String currentUid;
  final bool canCreatePoll;
  final TextEditingController pollTitleController;
  final TextEditingController pollDescController;
  final List<TextEditingController> pollOptionControllers;
  final bool submittingPoll;
  final VoidCallback onAddOption;
  final ValueChanged<int> onRemoveOption;
  final VoidCallback onSubmitPoll;
  final Future<void> Function({
    required String pollId,
    required int optionIndex,
  })
  onVote;
  final Future<void> Function({
    required String pollId,
    required bool currentlyOpen,
  })
  onToggleStatus;

  @override
  Widget build(BuildContext context) {
    final pollsStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('polls')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (canCreatePoll) ...[
          const SectionHeader(title: '투표 생성', icon: Icons.add_chart_outlined),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: pollTitleController,
                  decoration: const InputDecoration(labelText: '투표 제목'),
                  maxLength: 80,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: pollDescController,
                  decoration: const InputDecoration(labelText: '설명(선택)'),
                  maxLength: 400,
                ),
                const SizedBox(height: 8),
                for (var i = 0; i < pollOptionControllers.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: pollOptionControllers[i],
                            decoration: InputDecoration(
                              labelText: '선택지 ${i + 1}',
                            ),
                          ),
                        ),
                        if (pollOptionControllers.length > 2)
                          IconButton(
                            tooltip: '선택지 삭제',
                            onPressed: () => onRemoveOption(i),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: onAddOption,
                      icon: const Icon(Icons.add),
                      label: const Text('선택지 추가'),
                    ),
                    const Spacer(),
                  ],
                ),
                const SizedBox(height: 8),
                AppLoadingButton(
                  loading: submittingPoll,
                  enabled: true,
                  label: '투표 등록',
                  onPressed: onSubmitPoll,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SectionHeader(
          title: '진행 중인 투표',
          icon: Icons.how_to_vote_outlined,
        ),
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
            if (polls.isEmpty) {
              return const AppCard(child: Text('등록된 투표가 없습니다.'));
            }

            return Column(
              children: polls.map((pollDoc) {
                final data = pollDoc.data();
                final title = data['title']?.toString() ?? '(제목 없음)';
                final description = data['description']?.toString() ?? '';
                final status = data['status']?.toString() ?? 'open';
                final isOpen = status == 'open';
                final optionsDynamic = data['options'];
                final options = optionsDynamic is List
                    ? optionsDynamic.map((e) => e.toString()).toList()
                    : <String>[];
                if (options.isEmpty) {
                  return const SizedBox.shrink();
                }

                final votesStream = pollDoc.reference
                    .collection('votes')
                    .snapshots();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: votesStream,
                      builder: (context, votesSnap) {
                        final counts = List<int>.filled(options.length, 0);
                        int? myVote;
                        if (votesSnap.hasData) {
                          for (final voteDoc in votesSnap.data!.docs) {
                            final index = voteDoc.data()['optionIndex'];
                            if (index is int &&
                                index >= 0 &&
                                index < options.length) {
                              counts[index] += 1;
                              if (voteDoc.id == currentUid) {
                                myVote = index;
                              }
                            }
                          }
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: isOpen
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : Theme.of(
                                            context,
                                          ).colorScheme.surfaceContainerHighest,
                                  ),
                                  child: Text(isOpen ? '진행중' : '마감'),
                                ),
                                if (canCreatePoll) ...[
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: () => onToggleStatus(
                                      pollId: pollDoc.id,
                                      currentlyOpen: isOpen,
                                    ),
                                    child: Text(isOpen ? '마감' : '재오픈'),
                                  ),
                                ],
                              ],
                            ),
                            if (description.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(description),
                            ],
                            const SizedBox(height: 8),
                            for (var i = 0; i < options.length; i++)
                              RadioListTile<int>(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                value: i,
                                groupValue: myVote,
                                onChanged: isOpen
                                    ? (_) => onVote(
                                        pollId: pollDoc.id,
                                        optionIndex: i,
                                      )
                                    : null,
                                title: Text(options[i]),
                                subtitle: Text('${counts[i]}표'),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
