import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/feedback_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_badge.dart';

class GroupSuggestionsScreen extends StatefulWidget {
  const GroupSuggestionsScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<GroupSuggestionsScreen> createState() => _GroupSuggestionsScreenState();
}

class _GroupSuggestionsScreenState extends State<GroupSuggestionsScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _anonymous = false;
  bool _submitting = false;

  bool get _canSubmit =>
      !_submitting &&
      _titleController.text.trim().isNotEmpty &&
      _bodyController.text.trim().isNotEmpty;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      AppSnackbar.show(
        context,
        message: '제목과 내용을 모두 입력해 주세요.',
        type: AppSnackType.info,
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await FeedbackService.createSuggestion(
        groupId: widget.groupId,
        title: title,
        body: body,
        isAnonymous: _anonymous,
      );
      if (!mounted) return;
      _titleController.clear();
      _bodyController.clear();
      setState(() => _anonymous = false);
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
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }

    final suggestionsStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('suggestions')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            ExcludeSemantics(child: Icon(Icons.forum_outlined, size: 18)),
            SizedBox(width: 6),
            Text('의견 건의'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SectionHeader(
            title: '의견 건의하기',
            icon: Icons.edit_note_outlined,
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: '제목'),
                  maxLength: 80,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bodyController,
                  decoration: const InputDecoration(labelText: '내용'),
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 1000,
                  onChanged: (_) => setState(() {}),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _anonymous,
                  onChanged: (value) => setState(() => _anonymous = value),
                  title: const Text('익명으로 등록'),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _canSubmit ? _submit : null,
                    icon: _submitting
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined, size: 16),
                    label: Text(_submitting ? '전송 중...' : '제보 전송'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const SectionHeader(
            title: '등록된 건의',
            icon: Icons.inbox_outlined,
          ),
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
                return const EmptyState(
                  icon: Icons.forum_outlined,
                  title: '아직 등록된 건의가 없습니다',
                  description: '첫 번째 건의를 등록해 보세요.',
                );
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
                  final statusTone = switch (status) {
                    'planned' => StatusBadgeTone.primary,
                    'closed' => StatusBadgeTone.success,
                    _ => StatusBadgeTone.warning,
                  };
                  final statusText = switch (status) {
                    'planned' => '검토중',
                    'closed' => '완료',
                    _ => '접수',
                  };
                  final colorScheme = Theme.of(context).colorScheme;
                  return AppCard(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            StatusBadge(
                              label: statusText,
                              tone: statusTone,
                            ),
                            const Spacer(),
                            Text(
                              createdAtText,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (body.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            body,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                              isAnonymous
                                  ? Icons.visibility_off_outlined
                                  : Icons.person_outline,
                              size: 14,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              writer,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
