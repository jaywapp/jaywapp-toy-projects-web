import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_config.dart';
import '../../services/analytics_service.dart';
import '../../services/group_bootstrap_service.dart';
import '../../services/image_upload_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_loading_button.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _emblemUrlController = TextEditingController();

  GroupPlanTier _selectedPlan = GroupPlanTier.free;
  bool _creating = false;
  String? _message;

  Uint8List? _emblemBytes;
  String? _emblemMimeType;
  String? _emblemFileName;
  double? _uploadProgress;

  bool get _useStorageUpload => AppConfig.enableStorageUpload;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _emblemUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickEmblem() async {
    if (_creating) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1400,
        imageQuality: 88,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _emblemBytes = bytes;
        _emblemMimeType = picked.mimeType;
        _emblemFileName = picked.name;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = '이미지 파일을 불러오지 못했습니다.');
    }
  }

  void _clearEmblem() {
    setState(() {
      _emblemBytes = null;
      _emblemMimeType = null;
      _emblemFileName = null;
      _emblemUrlController.clear();
    });
  }

  Future<void> _createGroup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _message = '로그인이 필요합니다.');
      return;
    }

    final name = _nameController.text.trim();
    if (name.length < 2 || name.length > 30) {
      setState(() => _message = '모임 이름은 2~30자로 입력해 주세요.');
      return;
    }

    setState(() {
      _creating = true;
      _message = null;
      _uploadProgress = null;
    });

    try {
      String? emblemUrl;
      if (_useStorageUpload) {
        if (_emblemBytes != null) {
          setState(() => _uploadProgress = 0);
          emblemUrl = await ImageUploadService.uploadGroupEmblem(
            uid: user.uid,
            bytes: _emblemBytes!,
            mimeType: _emblemMimeType,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() => _uploadProgress = progress);
            },
          );
        }
      } else {
        final url = _emblemUrlController.text.trim();
        emblemUrl = url.isEmpty ? null : url;
      }

      final groupId = await GroupBootstrapService.createGroup(
        user: user,
        groupName: name,
        plan: _selectedPlan,
        description: _descriptionController.text,
        emblemUrl: emblemUrl,
      );
      unawaited(AnalyticsService.logCreateGroup());
      if (!mounted) return;
      Navigator.of(context).pop(groupId);
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _message = '이미지 업로드 시간이 초과되었습니다. 네트워크 상태를 확인해 주세요.';
      });
    } on FirebaseException catch (e) {
      if (!mounted) return;
      setState(() => _message = '모임 생성 실패: ${e.code}');
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = '모임 생성 중 오류가 발생했습니다.');
    } finally {
      if (mounted) {
        setState(() {
          _creating = false;
          _uploadProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final freeMemberLimit = GroupPlanTier.free.memberLimit;
    final freeEventLimit = GroupPlanTier.free.monthlyEventCreateLimit;
    final proMemberLimit = GroupPlanTier.pro.memberLimit;
    final proEventLimit = GroupPlanTier.pro.monthlyEventCreateLimit;
    final emblemPreviewUrl = _emblemUrlController.text.trim();

    return Scaffold(
      appBar: AppBar(title: const Text('모임 만들기')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        children: [
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '처음 시작하는 모임을 만들어 보세요',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text('플랜은 이후 변경할 수 있습니다. Pro 결제 연동은 추후 적용 예정입니다.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '모임 정보',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  maxLength: 30,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: '모임 이름',
                    hintText: '예: 주말 풋살 모임',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  maxLength: 120,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: '모임 소개 (선택)',
                    hintText: '모임 성격과 운영 방식을 간단히 적어 주세요.',
                  ),
                ),
                const SizedBox(height: 8),
                if (_useStorageUpload) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _creating ? null : _pickEmblem,
                        icon: const Icon(Icons.upload_file_outlined),
                        label: const Text('엠블럼 파일 선택'),
                      ),
                      if (_emblemBytes != null)
                        OutlinedButton(
                          onPressed: _creating ? null : _clearEmblem,
                          child: const Text('이미지 제거'),
                        ),
                    ],
                  ),
                  if (_emblemFileName != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _emblemFileName!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (_emblemBytes != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundImage: MemoryImage(_emblemBytes!),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('선택한 이미지는 모임 생성 시 자동으로 업로드됩니다.'),
                        ),
                      ],
                    ),
                  ],
                ] else ...[
                  TextField(
                    controller: _emblemUrlController,
                    maxLength: 500,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: '엠블럼 이미지 URL (선택)',
                      hintText: 'https://.../emblem.png',
                    ),
                  ),
                  if (emblemPreviewUrl.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundImage: NetworkImage(emblemPreviewUrl),
                          onBackgroundImageError: (_, __) {},
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text('URL이 유효하면 모임 엠블럼으로 표시됩니다.'),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('요금제 선택', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _PlanCard(
            title: '무료',
            subtitle: '₩0',
            selected: _selectedPlan == GroupPlanTier.free,
            chips: const ['기본 기능', '빠른 시작'],
            bullets: [
              '멤버 최대 ${freeMemberLimit}명',
              '월 일정 생성 최대 ${freeEventLimit}건',
              '기본 통계/공지/응답 관리',
            ],
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedPlan = GroupPlanTier.free);
            },
          ),
          const SizedBox(height: 8),
          _PlanCard(
            title: 'Pro',
            subtitle: '₩9,900 (출시 예정)',
            selected: _selectedPlan == GroupPlanTier.pro,
            chips: const ['고급 기능', '운영 확장'],
            bullets: [
              '멤버 최대 ${proMemberLimit}명',
              '월 일정 생성 최대 ${proEventLimit}건',
              '고급 분석/권한 정책 확장 (예정)',
            ],
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _selectedPlan = GroupPlanTier.pro);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_message != null) ...[
                Text(
                  _message!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.danger),
                ),
                const SizedBox(height: 6),
              ],
              if (_creating && _uploadProgress != null) ...[
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 6),
                Text(
                  '이미지 업로드 ${(100 * _uploadProgress!).round()}%',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
              ],
              AppLoadingButton(
                loading: _creating,
                enabled: _nameController.text.trim().isNotEmpty,
                label: '모임 생성',
                onPressed: _createGroup,
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _creating ? null : () => Navigator.of(context).pop(),
                child: const Text('취소'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.chips,
    required this.bullets,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final List<String> chips;
  final List<String> bullets;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppCard(
      borderColor: selected ? colorScheme.primary : null,
      child: Semantics(
        label: '$title $subtitle',
        button: true,
        selected: selected,
        child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (selected)
                    const ExcludeSemantics(
                      child: Icon(
                        Icons.check_circle,
                        size: 18,
                        color: AppTheme.primary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: chips
                    .map(
                      (chip) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          chip,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
              for (final bullet in bullets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('• $bullet'),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
