import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/analytics_service.dart';
import '../../services/invite_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_loading_button.dart';

class JoinInviteScreen extends StatefulWidget {
  const JoinInviteScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  State<JoinInviteScreen> createState() => _JoinInviteScreenState();
}

class _JoinInviteScreenState extends State<JoinInviteScreen> {
  late final TextEditingController _codeController;
  bool _submitting = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(
      text: InviteService.normalizeCode(widget.initialCode ?? ''),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = InviteService.normalizeCode(_codeController.text);
    if (code.isEmpty) {
      setState(() => _message = '초대코드를 입력해 주세요.');
      return;
    }

    setState(() {
      _submitting = true;
      _message = null;
    });

    try {
      final result = await InviteService.requestJoinWithCode(code: code);
      unawaited(AnalyticsService.logJoinGroup(
        status: result.status.name,
      ));
      if (!mounted) return;

      final groupNameOrId =
          (result.groupName == null || result.groupName!.isEmpty)
          ? result.groupId
          : result.groupName!;
      final nextMessage = switch (result.status) {
        InviteJoinStatus.joined => '모임 참여가 완료되었습니다.\n대상 모임: $groupNameOrId',
        InviteJoinStatus.pending =>
          '가입 요청을 보냈습니다. 모임장 승인 후 참여가 완료됩니다.\n대상 모임: $groupNameOrId',
        InviteJoinStatus.alreadyPending =>
          '이미 가입 승인 대기 중입니다.\n대상 모임: $groupNameOrId',
        InviteJoinStatus.alreadyActive =>
          '이미 참여 중인 모임입니다. 그룹 선택 화면에서 선택해 주세요.\n대상 모임: $groupNameOrId',
      };
      setState(() => _message = nextMessage);
    } on FirebaseException catch (e) {
      if (!mounted) return;
      final message = (e.message != null && e.message!.trim().isNotEmpty)
          ? e.message!.trim()
          : '가입 요청에 실패했습니다. 잠시 후 다시 시도해 주세요.';
      setState(() => _message = message);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            ExcludeSemantics(child: Icon(Icons.vpn_key_outlined, size: 18)),
            SizedBox(width: 6),
            Text('초대 코드로 참여'),
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
                Text(
                  '가입 요청 보내기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  '모임장이 발급한 초대코드를 입력하면 바로 참여하거나 가입 요청을 보낼 수 있습니다.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _codeController,
                  textInputAction: TextInputAction.done,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _submitting ? null : _submit(),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z0-9\\s-]'),
                    ),
                    TextInputFormatter.withFunction((oldValue, newValue) {
                      final normalized = InviteService.normalizeCode(
                        newValue.text,
                      );
                      return TextEditingValue(
                        text: normalized,
                        selection: TextSelection.collapsed(
                          offset: normalized.length,
                        ),
                      );
                    }),
                  ],
                  decoration: const InputDecoration(
                    labelText: '초대코드',
                    hintText: '예: AB12CD34',
                  ),
                ),
                const SizedBox(height: 10),
                AppLoadingButton(
                  loading: _submitting,
                  enabled: _codeController.text.trim().isNotEmpty,
                  label: '참여하기',
                  onPressed: _submit,
                ),
              ],
            ),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            AppCard(
              child: Text(
                _message!,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.primaryDark),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
