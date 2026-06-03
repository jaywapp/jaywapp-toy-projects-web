import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../data/repositories/member_repository.dart';
import '../../data/repositories/invite_repository.dart';
import '../../domain/models/project_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/project_provider.dart';

final _memberRepoProvider = Provider<MemberRepository>((ref) => MemberRepository());
final _inviteRepoProvider = Provider<InviteRepository>((ref) => InviteRepository());

final _activeInviteProvider = FutureProvider.family<({String code, DateTime expiresAt})?, String>(
  (ref, projectId) => ref.read(_inviteRepoProvider).getActiveInviteCode(projectId),
);

final _userNamesProvider = FutureProvider.family<Map<String, String>, List<String>>((ref, ids) async {
  return ref.read(_memberRepoProvider).getUserNames(ids);
});

class MemberManageScreen extends ConsumerStatefulWidget {
  final ProjectModel project;

  const MemberManageScreen({super.key, required this.project});

  @override
  ConsumerState<MemberManageScreen> createState() => _MemberManageScreenState();
}

class _MemberManageScreenState extends ConsumerState<MemberManageScreen> {
  final _emailController = TextEditingController();
  MemberRole _selectedRole = MemberRole.member;
  bool _isInviting = false;
  bool _isGeneratingLink = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _invite() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    setState(() => _isInviting = true);
    try {
      final repo = ref.read(_memberRepoProvider);
      final uid = await repo.findUserIdByEmail(email);
      if (uid == null) throw Exception('해당 이메일로 가입된 사용자가 없습니다.');
      await repo.inviteMember(projectId: widget.project.id, inviteeUserId: uid, role: _selectedRole);
      ref.invalidate(projectDetailProvider(widget.project.id));
      _emailController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('초대 완료!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isInviting = false);
    }
  }

  Future<void> _generateInviteLink() async {
    setState(() => _isGeneratingLink = true);
    try {
      final code = await ref.read(_inviteRepoProvider).createInviteCode(widget.project.id);
      final link = 'https://zaro-55798.web.app/join?code=$code';
      await Clipboard.setData(ClipboardData(text: link));
      ref.invalidate(_activeInviteProvider(widget.project.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('초대 링크가 클립보드에 복사되었습니다. (48시간 유효)')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('링크 생성 실패: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingLink = false);
    }
  }

  Future<void> _copyInviteLink(String code) async {
    final link = 'https://zaro-55798.web.app/join?code=$code';
    await Clipboard.setData(ClipboardData(text: link));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('초대 링크가 클립보드에 복사되었습니다.')),
      );
    }
  }

  Future<void> _confirmKick(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('멤버 강제 탈퇴'),
        content: Text('\'$userName\'을(를) 가계부에서 내보내시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('탈퇴'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(_memberRepoProvider).removeMember(
            projectId: widget.project.id,
            userId: userId,
          );
      ref.invalidate(projectDetailProvider(widget.project.id));
      ref.invalidate(projectNotifierProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('\'$userName\'을(를) 내보냈습니다.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('탈퇴 처리 실패: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final memberIds = widget.project.members.map((m) => m.userId).toList();
    final namesAsync = ref.watch(_userNamesProvider(memberIds));
    final activeInviteAsync = ref.watch(_activeInviteProvider(widget.project.id));
    final currentUid = ref.watch(authNotifierProvider).value?.id;
    final currentMember = widget.project.members.where((m) => m.userId == currentUid).toList();
    final currentRole = currentMember.isNotEmpty ? currentMember.first.role : MemberRole.viewer;
    final isAdmin = currentRole == MemberRole.admin;
    final dtFormat = DateFormat('M월 d일 HH:mm', 'ko_KR');

    return Scaffold(
      appBar: AppBar(title: Text('${widget.project.name} 멤버 관리')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('멤버 초대', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: '초대할 이메일 입력'),
                  ),
                ),
                const SizedBox(width: 8),
                _RoleDropdown(
                  value: _selectedRole,
                  onChanged: (r) => setState(() => _selectedRole = r),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isInviting ? null : _invite,
                child: _isInviting
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('초대'),
              ),
            ),
            const SizedBox(height: 8),
            activeInviteAsync.when(
              loading: () => const SizedBox(height: 44, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
              error: (_, __) => const SizedBox.shrink(),
              data: (active) {
                if (active != null) {
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.link, size: 16, color: AppColors.primary),
                            const SizedBox(width: 6),
                            const Text('활성 초대 링크', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary, fontSize: 13)),
                            const Spacer(),
                            Text('~${dtFormat.format(active.expiresAt)} 까지',
                                style: const TextStyle(fontSize: 11, color: AppColors.primary)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _copyInviteLink(active.code),
                                icon: const Icon(Icons.copy, size: 16),
                                label: const Text('링크 복사'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(color: AppColors.primary),
                                  minimumSize: const Size(0, 38),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: _isGeneratingLink ? null : _generateInviteLink,
                              icon: _isGeneratingLink
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.refresh, size: 16),
                              label: const Text('재생성'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.appColors.textSecondary,
                                side: BorderSide(color: context.appColors.textSecondary),
                                minimumSize: const Size(0, 38),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }
                return SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isGeneratingLink ? null : _generateInviteLink,
                    icon: _isGeneratingLink
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.link, size: 18),
                    label: const Text('초대 링크 생성 (48시간 유효)'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text('현재 멤버', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const SizedBox(height: 8),
            Expanded(
              child: namesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('오류: $e'),
                data: (names) => ListView(
                  children: widget.project.members.map((member) {
                    final memberName = names[member.userId] ?? member.userId;
                    final isCurrentUser = member.userId == currentUid;
                    final canKick = isAdmin && !isCurrentUser && member.role != MemberRole.admin;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: context.appColors.surface,
                        child: Text(
                          memberName.substring(0, 1),
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ),
                      title: Text(memberName),
                      subtitle: isCurrentUser ? const Text('나', style: TextStyle(fontSize: 11)) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _RoleBadge(role: member.role),
                          if (canKick) ...[
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.person_remove_outlined, size: 18, color: AppColors.error),
                              tooltip: '강제 탈퇴',
                              onPressed: () => _confirmKick(member.userId, memberName),
                            ),
                          ],
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  final MemberRole value;
  final ValueChanged<MemberRole> onChanged;

  const _RoleDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButton<MemberRole>(
      value: value,
      items: const [
        DropdownMenuItem(value: MemberRole.admin, child: Text('관리자')),
        DropdownMenuItem(value: MemberRole.member, child: Text('멤버')),
        DropdownMenuItem(value: MemberRole.viewer, child: Text('조회')),
      ],
      onChanged: (r) => r != null ? onChanged(r) : null,
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final MemberRole role;

  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      MemberRole.admin => ('관리자', AppColors.primary),
      MemberRole.member => ('멤버', context.appColors.textSecondary),
      MemberRole.viewer => ('조회', context.appColors.textHint),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
