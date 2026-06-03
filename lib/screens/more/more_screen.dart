import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../config/app_config.dart';
import '../../config/firebase_config.dart';
import '../../dev/dev_seed.dart';
import '../../providers.dart';
import '../../screens/stats/stats_screen.dart';
import '../../services/app_cache.dart';
import '../../services/functions_caller.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  Future<void> _deleteGroup({
    required BuildContext context,
    required WidgetRef ref,
    required String groupId,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('모임 삭제'),
        content: const Text(
          '정말 이 모임을 삭제할까요?\n삭제 후에는 모임원, 일정, 공지, 투표 데이터를 복구할 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.danger),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    var progressShown = false;
    try {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      progressShown = true;

      await FunctionsCaller.callWithRetry(
        () => FirebaseFunctions.instanceFor(
          region: FirebaseConfig.functionsRegion,
        ).httpsCallable('deleteGroup').call(<String, dynamic>{
          'groupId': groupId,
        }),
      );

      if (progressShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        progressShown = false;
      }

      AppCacheService.instance.invalidatePrefix('group:');
      AppCacheService.instance.invalidatePrefix('member:');
      AppCacheService.instance.invalidatePrefix('settings:');
      ref.read(selectedGroupIdProvider.notifier).setGroup(null);

      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: '모임이 삭제되었습니다.',
          type: AppSnackType.success,
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) return;
      final message = switch (e.code) {
        'permission-denied' => '모임장만 모임을 삭제할 수 있습니다.',
        'not-found' => '이미 삭제되었거나 존재하지 않는 모임입니다.',
        _ => '모임 삭제 실패: ${e.code}',
      };
      AppSnackbar.show(context, message: message, type: AppSnackType.error);
    } catch (_) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: '모임 삭제 중 오류가 발생했습니다.',
        type: AppSnackType.error,
      );
    } finally {
      if (progressShown && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = FirebaseAuth.instance.currentUser;
    final gid = ref.watch(selectedGroupIdProvider);
    if (user == null) {
      return const SizedBox.shrink();
    }
    final memberStream = gid == null
        ? const Stream<DocumentSnapshot<Map<String, dynamic>>>.empty()
        : FirebaseFirestore.instance
              .collection('groups')
              .doc(gid)
              .collection('members')
              .doc(user.uid)
              .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: memberStream,
      builder: (context, snapshot) {
        final mode = ref.watch(themeModeProvider);
        final permission = PermissionService.fromMemberData(
          snapshot.data?.data(),
        );
        final inviteEnabled =
            gid != null &&
            (permission.canManageMembers() || permission.isTreasurer);
        final auditLogEnabled = gid != null && permission.canManageRoles();
        final canDeleteGroup = gid != null && permission.isOwner;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── 프로필 섹션 ──
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user.uid)
                  .snapshots(),
              builder: (context, profileSnap) {
                final p = profileSnap.data?.data() ?? <String, dynamic>{};
                final nickname = p['nickname']?.toString().trim();
                final photoUrl = p['photoUrl']?.toString();
                final provider = p['provider']?.toString();
                final providerLabel = switch (provider) {
                  'password' => '이메일',
                  'google.com' => 'Google',
                  'kakao.com' => 'Kakao',
                  _ => provider,
                };
                final title = (nickname != null && nickname.isNotEmpty)
                    ? nickname
                    : (user.email ?? "이메일 없음");
                final initial = title.isNotEmpty ? title[0].toUpperCase() : 'U';
                final subtitle = providerLabel == null || providerLabel.isEmpty
                    ? (user.email ?? "이메일 없음")
                    : "${user.email ?? "이메일 없음"} ($providerLabel)";
                return AppCard(
                  child: Semantics(
                    label: '$title 프로필 보기',
                    hint: '탭하여 프로필 화면 열기',
                    button: true,
                    child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => context.push('/profile'),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage:
                              (photoUrl != null && photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? Text(initial)
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        ExcludeSemantics(
                          child: Icon(
                            Icons.chevron_right,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                );
              },
            ),

            // ── 모임 관리 섹션 ──
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "모임 관리",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  if (gid != null)
                    ListTile(
                      leading: const ExcludeSemantics(child: Icon(Icons.stacked_bar_chart_outlined)),
                      title: const Text("통계"),
                      subtitle: const Text("참여율, 리더보드, 활동 지표"),
                      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right, size: 18)),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              StatsScreen(groupId: gid, uid: user.uid),
                        ),
                      ),
                    ),
                  if (gid != null) const Divider(height: 1, indent: 56),
                  if (gid != null)
                    ListTile(
                      leading: const ExcludeSemantics(child: Icon(Icons.search_outlined)),
                      title: const Text('통합 검색'),
                      subtitle: const Text('멤버, 일정, 공지, 투표를 한 번에 찾기'),
                      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right, size: 18)),
                      onTap: () => context.push('/search?groupId=$gid'),
                    ),
                  if (gid != null) const Divider(height: 1, indent: 56),
                  if (gid != null)
                    ListTile(
                      leading: const ExcludeSemantics(child: Icon(Icons.forum_outlined)),
                      title: const Text("의견 건의"),
                      subtitle: const Text("모임에 개선 의견 전달"),
                      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right, size: 18)),
                      onTap: () => context.push('/suggestions?groupId=$gid'),
                    ),
                  if (gid != null) const Divider(height: 1, indent: 56),
                  if (gid != null)
                    ListTile(
                      leading: const ExcludeSemantics(child: Icon(Icons.payments_outlined)),
                      title: const Text("회비"),
                      subtitle: const Text("납부 현황 확인"),
                      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right, size: 18)),
                      onTap: () => context.push('/finance?groupId=$gid'),
                    ),
                  if (inviteEnabled) const Divider(height: 1, indent: 56),
                  if (inviteEnabled)
                    ListTile(
                      leading: const ExcludeSemantics(child: Icon(Icons.contact_mail_outlined)),
                      title: const Text("모임원 초대"),
                      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right, size: 18)),
                      onTap: () => context.push('/invite?groupId=$gid'),
                    ),
                  if (auditLogEnabled) const Divider(height: 1, indent: 56),
                  if (auditLogEnabled)
                    ListTile(
                      leading: const ExcludeSemantics(child: Icon(Icons.history_outlined)),
                      title: const Text("운영 로그"),
                      subtitle: const Text("권한 변경, 가입 승인, 초대 관리 기록"),
                      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right, size: 18)),
                      onTap: () => context.push('/operation-logs?groupId=$gid'),
                    ),
                  if (canDeleteGroup) const Divider(height: 1, indent: 56),
                  if (canDeleteGroup)
                    ListTile(
                      leading: const ExcludeSemantics(child: Icon(
                        Icons.delete_forever_outlined,
                        color: AppTheme.danger,
                      )),
                      title: const Text('모임 삭제'),
                      subtitle: const Text('모임장만 사용할 수 있으며, 삭제 후 복구할 수 없습니다.'),
                      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right, size: 18)),
                      onTap: () => _deleteGroup(
                        context: context,
                        ref: ref,
                        groupId: gid,
                      ),
                    ),
                  if (gid != null) const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const ExcludeSemantics(child: Icon(Icons.swap_horiz_outlined)),
                    title: const Text("다른 그룹으로 전환"),
                    trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right, size: 18)),
                    onTap: () {
                      AppCacheService.instance.invalidatePrefix('group:');
                      AppCacheService.instance.invalidatePrefix('member:');
                      AppCacheService.instance.invalidatePrefix('settings:');
                      ref.read(selectedGroupIdProvider.notifier).setGroup(null);
                    },
                  ),
                ],
              ),
            ),

            // ── 설정 섹션 ──
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "설정",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const ExcludeSemantics(child: Icon(Icons.notifications_outlined)),
                    title: const Text("알림 설정"),
                    trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right, size: 18)),
                    onTap: () => context.push('/notification-settings'),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const ExcludeSemantics(child: Icon(Icons.bug_report_outlined)),
                    title: const Text("오류/개선 제보"),
                    subtitle: const Text("문제 제보 및 기능 개선 의견 보내기"),
                    trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right, size: 18)),
                    onTap: () => context.push('/beta-report'),
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const ExcludeSemantics(child: Icon(Icons.palette_outlined)),
                    title: const Text("테마"),
                    trailing: SizedBox(
                      width: 220,
                      child: SegmentedButton<AppThemeMode>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(
                            value: AppThemeMode.system,
                            label: Text("시스템"),
                          ),
                          ButtonSegment(
                            value: AppThemeMode.light,
                            label: Text("라이트"),
                          ),
                          ButtonSegment(
                            value: AppThemeMode.dark,
                            label: Text("다크"),
                          ),
                        ],
                        selected: {mode},
                        onSelectionChanged: (set) => ref
                            .read(themeModeProvider.notifier)
                            .setMode(set.first),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 개발자 도구 (dev only) ──
            if (AppConfig.enableDevTools) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  "개발자 도구",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const ExcludeSemantics(child: Icon(Icons.data_object)),
                      title: const Text("데모 데이터 생성"),
                      onTap: () async {
                        try {
                          final seeded = await seedDemoMembersAndData(
                            'g_demo',
                            user.uid,
                          );
                          if (!context.mounted) return;
                          AppSnackbar.show(
                            context,
                            message: seeded
                                ? "데모 데이터 생성이 완료되었습니다."
                                : "데모 데이터 생성에 실패했습니다.",
                            type: AppSnackType.success,
                          );
                        } on FirebaseException catch (e) {
                          if (!context.mounted) return;
                          final message = e.code == 'permission-denied'
                              ? kPermissionDeniedMessage
                              : "데모 데이터 처리 중 오류가 발생했습니다: ${e.code}";
                          AppSnackbar.show(
                            context,
                            message: message,
                            type: AppSnackType.error,
                          );
                        } catch (_) {
                          if (!context.mounted) return;
                          AppSnackbar.show(
                            context,
                            message: "예기치 못한 오류로 데모 데이터 생성에 실패했습니다.",
                            type: AppSnackType.error,
                          );
                        }
                      },
                    ),
                    const Divider(height: 1, indent: 56),
                    ListTile(
                      leading: const ExcludeSemantics(child: Icon(Icons.restart_alt)),
                      title: const Text("데모 데이터 초기화/재생성"),
                      onTap: () async {
                        try {
                          final seeded = await resetDemoSeedAndReseed(
                            'g_demo',
                            user.uid,
                          );
                          if (!context.mounted) return;
                          AppSnackbar.show(
                            context,
                            message: seeded
                                ? "데모 데이터 재생성이 완료되었습니다."
                                : "데모 데이터 재생성에 실패했습니다.",
                            type: seeded
                                ? AppSnackType.success
                                : AppSnackType.error,
                          );
                        } on FirebaseException catch (e) {
                          if (!context.mounted) return;
                          final message = e.code == 'permission-denied'
                              ? kPermissionDeniedMessage
                              : "데모 데이터 처리 중 오류가 발생했습니다: ${e.code}";
                          AppSnackbar.show(
                            context,
                            message: message,
                            type: AppSnackType.error,
                          );
                        } catch (_) {
                          if (!context.mounted) return;
                          AppSnackbar.show(
                            context,
                            message: "예기치 못한 오류로 데모 데이터 재생성에 실패했습니다.",
                            type: AppSnackType.error,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],

            // ── 정보 및 계정 섹션 ──
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "정보",
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  ListTile(
                    leading: const ExcludeSemantics(child: Icon(Icons.description_outlined)),
                    title: const Text("이용약관"),
                    trailing: const ExcludeSemantics(child: Icon(Icons.open_in_new, size: 16)),
                    onTap: () {
                      AppSnackbar.show(
                        context,
                        message: "이용약관 페이지는 준비 중입니다.",
                        type: AppSnackType.info,
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  ListTile(
                    leading: const ExcludeSemantics(child: Icon(Icons.shield_outlined)),
                    title: const Text("개인정보처리방침"),
                    trailing: const ExcludeSemantics(child: Icon(Icons.open_in_new, size: 16)),
                    onTap: () {
                      AppSnackbar.show(
                        context,
                        message: "개인정보처리방침 페이지는 준비 중입니다.",
                        type: AppSnackType.info,
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final version = snapshot.hasData
                          ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}'
                          : '-';
                      return ListTile(
                        leading: const ExcludeSemantics(
                          child: Icon(Icons.info_outline),
                        ),
                        title: const Text("앱 버전"),
                        trailing: Text(
                          version,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // ── 로그아웃 ──
            const SizedBox(height: 16),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                leading: const ExcludeSemantics(child: Icon(Icons.logout, color: Color(0xFFE74C3C))),
                title: Text(
                  "로그아웃",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppTheme.danger),
                ),
                onTap: () async {
                  AppCacheService.instance.clearAll();
                  ref.read(selectedGroupIdProvider.notifier).setGroup(null);
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
