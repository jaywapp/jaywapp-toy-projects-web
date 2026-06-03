import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/feedback_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/section_header.dart';

class BetaReportScreen extends StatefulWidget {
  const BetaReportScreen({super.key});

  @override
  State<BetaReportScreen> createState() => _BetaReportScreenState();
}

class _BetaReportScreenState extends State<BetaReportScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _category = 'bug';
  bool _submitting = false;

  static const _categories = <String, String>{
    'bug': '오류/버그',
    'improvement': '기능 개선',
    'feature': '신규 기능 요청',
    'other': '기타',
  };

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
      await FeedbackService.createBetaReport(
        title: title,
        body: body,
        category: _category,
      );
      if (!mounted) return;
      _titleController.clear();
      _bodyController.clear();
      setState(() => _category = 'bug');
      AppSnackbar.show(
        context,
        message: '제보가 등록되었습니다. 검토 후 반영하겠습니다.',
        type: AppSnackType.success,
      );
    } catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '제보 등록 실패: ${friendlyError(e)}',
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

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            ExcludeSemantics(child: Icon(Icons.bug_report_outlined, size: 18)),
            SizedBox(width: 6),
            Text('오류/개선 제보'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            padding: const EdgeInsets.all(12),
            borderColor: colorScheme.primaryContainer,
            child: Row(
              children: [
                ExcludeSemantics(child: Icon(Icons.info_outline, size: 18, color: colorScheme.primary)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '앱 사용 중 발견한 오류나 개선 의견을 보내주세요.\n제보 내용은 개발팀에 자동으로 전달됩니다.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          const SectionHeader(
            title: '제보하기',
            icon: Icons.edit_note_outlined,
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '분류',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _categories.entries.map((entry) {
                    final selected = _category == entry.key;
                    return ChoiceChip(
                      label: Text(entry.value),
                      selected: selected,
                      onSelected: (_) =>
                          setState(() => _category = entry.key),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: '제목',
                    hintText: '간단히 요약해 주세요',
                  ),
                  maxLength: 80,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _bodyController,
                  decoration: const InputDecoration(
                    labelText: '상세 내용',
                    hintText: '어떤 상황에서 발생했는지 자세히 적어주세요',
                  ),
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 2000,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
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
        ],
      ),
    );
  }
}
