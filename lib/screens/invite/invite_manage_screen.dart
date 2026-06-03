import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/invite_service.dart';
import '../../services/kakao_share_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_loading_button.dart';
import '../../widgets/app_snackbar.dart';

class InviteManageScreen extends StatefulWidget {
  const InviteManageScreen({super.key, required this.groupId});

  final String groupId;

  @override
  State<InviteManageScreen> createState() => _InviteManageScreenState();
}

class _InviteManageScreenState extends State<InviteManageScreen> {
  bool _issuing = false;
  int _expiresInDays = 7;

  Future<void> _issueInvite() async {
    if (_issuing) return;
    setState(() => _issuing = true);

    try {
      final issued = await InviteService.createInvite(
        groupId: widget.groupId,
        expiresInDays: _expiresInDays,
      );
      if (!mounted) return;
      final expiryText = issued.expiresAt == null
          ? '만료 없음'
          : formatDateTime(issued.expiresAt!);
      AppSnackbar.show(
        context,
        type: AppSnackType.success,
        message: '초대코드 ${issued.code} 발급 완료 (만료: $expiryText)',
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        type: AppSnackType.error,
        message: '초대코드 발급 실패: ${e.code}',
      );
    } finally {
      if (mounted) {
        setState(() => _issuing = false);
      }
    }
  }

  Future<void> _revokeInvite(String code) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('초대코드 회수'),
        content: Text('$code 코드를 회수할까요? 이미 전달한 링크/코드는 더 이상 사용할 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('회수'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;

    try {
      await InviteService.revokeInvite(groupId: widget.groupId, code: code);
      if (!mounted) return;
      AppSnackbar.show(
        context,
        type: AppSnackType.success,
        message: '$code 코드를 회수했습니다.',
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        type: AppSnackType.error,
        message: '회수 실패: ${e.code}',
      );
    }
  }

  Future<void> _copyCode(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    AppSnackbar.show(context, message: '초대코드를 복사했습니다.');
  }

  Future<void> _copyLink(String code) async {
    final link = _buildInviteLink(code);
    final text = _buildShareText(code: code, link: link);
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    AppSnackbar.show(context, message: '초대 링크 문구를 복사했습니다.');
  }

  Future<void> _shareInvite(String code) async {
    final link = _buildInviteLink(code);
    final text = _buildShareText(code: code, link: link);
    try {
      await Share.share(text, subject: '모여라 모임 초대');
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        type: AppSnackType.error,
        message: '공유 기능 실행에 실패했습니다. 링크 복사를 이용해 주세요.',
      );
    }
  }

  Future<void> _shareViaKakao(String code) async {
    final error = await KakaoShareService.shareInvite(code: code);
    if (!mounted) return;
    if (error != null) {
      AppSnackbar.show(context, type: AppSnackType.error, message: error);
    }
  }

  String _buildInviteLink(String code) {
    final normalized = InviteService.normalizeCode(code);
    if (kIsWeb && (Uri.base.scheme == 'http' || Uri.base.scheme == 'https')) {
      final uri = Uri(
        scheme: Uri.base.scheme,
        host: Uri.base.host,
        port: Uri.base.hasPort ? Uri.base.port : null,
        path: '/join-invite',
        queryParameters: <String, String>{'code': normalized},
      );
      return uri.toString();
    }
    return 'moyeora://app/join-invite?code=$normalized';
  }

  String _buildShareText({required String code, required String link}) {
    return '모여라 모임 초대\n'
        '초대코드: ${InviteService.normalizeCode(code)}\n'
        '초대링크: $link\n'
        '앱에서 링크를 열거나, 그룹 선택 화면의 "초대 코드로 참여"에서 코드를 입력해 주세요.';
  }

  String _statusText({
    required String rawStatus,
    required DateTime? expiresAt,
  }) {
    if (rawStatus == 'revoked') return '회수됨';
    if (expiresAt != null && expiresAt.isBefore(DateTime.now())) return '만료됨';
    return '사용 가능';
  }

  @override
  Widget build(BuildContext context) {
    final invitesRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('invites')
        .orderBy('createdAt', descending: true)
        .limit(30);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            ExcludeSemantics(child: Icon(Icons.person_add_alt_1_outlined, size: 18)),
            SizedBox(width: 6),
            Text('모임원 초대'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('초대코드 발급', style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text('모임원이 코드를 입력하면 가입 요청이 생성되고, 모임장이 승인하면 참여가 완료됩니다.'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '발급 조건',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: _expiresInDays,
                  decoration: const InputDecoration(labelText: '만료(일)'),
                  items: const [1, 3, 7, 14, 30]
                      .map(
                        (day) => DropdownMenuItem<int>(
                          value: day,
                          child: Text('$day일'),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _expiresInDays = value);
                  },
                ),
                const SizedBox(height: 10),
                AppLoadingButton(
                  loading: _issuing,
                  enabled: true,
                  label: '새 초대코드 발급',
                  onPressed: _issueInvite,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text('발급된 코드', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: invitesRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppCard(
                  child: Text('초대코드 목록을 불러오지 못했습니다: ${snapshot.error}'),
                );
              }
              if (!snapshot.hasData) {
                return const AppCard(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final docs = snapshot.data!.docs;
              if (docs.isEmpty) {
                return const AppCard(child: Text('아직 발급된 초대코드가 없습니다.'));
              }

              return Column(
                children: docs.map((doc) {
                  final data = doc.data();
                  final code = data['code']?.toString() ?? doc.id;
                  final rawStatus = data['status']?.toString() ?? 'active';
                  final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
                  final statusText = _statusText(
                    rawStatus: rawStatus,
                    expiresAt: expiresAt,
                  );
                  final isActive = rawStatus == 'active';

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                code,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusText == '사용 가능'
                                      ? AppTheme.success.withValues(alpha: 0.12)
                                      : Theme.of(
                                          context,
                                        ).colorScheme.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  statusText,
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '만료: ${expiresAt == null ? '없음' : formatDateTime(expiresAt)}',
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => _copyCode(code),
                                child: const Text('코드 복사'),
                              ),
                              OutlinedButton(
                                onPressed: () => _copyLink(code),
                                child: const Text('링크 복사'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _shareInvite(code),
                                icon: const Icon(
                                  Icons.share_outlined,
                                  size: 18,
                                ),
                                label: const Text('공유'),
                              ),
                              if (isActive)
                                OutlinedButton.icon(
                                  onPressed: () => _shareViaKakao(code),
                                  icon: const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 18,
                                    color: Color(0xFF391B1B),
                                  ),
                                  label: const Text(
                                    '카카오톡',
                                    style: TextStyle(color: Color(0xFF391B1B)),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFEE500),
                                    side: BorderSide.none,
                                  ),
                                ),
                              if (isActive)
                                TextButton(
                                  onPressed: () => _revokeInvite(code),
                                  child: const Text('회수'),
                                ),
                            ],
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
      ),
    );
  }
}
