import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers.dart';
import '../../services/app_cache.dart';
import '../../services/notification_infra_service.dart';
import '../events/events_screen.dart';
import '../groups/create_group_screen.dart';
import '../groups/group_members_screen.dart';
import '../home/home_screen.dart';
import '../more/more_screen.dart';
import '../notices/notices_screen.dart';
import '../polls/polls_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  String? _configuredGroupId;
  String? _configuredUid;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _configureNotifications();
  }

  Future<void> _configureNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    final groupId = ref.read(selectedGroupIdProvider);
    if (user == null || groupId == null) return;
    if (_configuredGroupId == groupId && _configuredUid == user.uid) return;

    _configuredGroupId = groupId;
    _configuredUid = user.uid;

    await NotificationInfraService.instance.configure(
      groupId: groupId,
      uid: user.uid,
      onTokenState: (token, stored) {
        ref.read(currentFcmTokenProvider.notifier).setToken(token);
        ref.read(tokenStoredProvider.notifier).setStored(stored);
      },
      onNavigateType: (type) {
        if (!mounted) return;
        if (type == 'notice') {
          ref.read(shellTabIndexProvider.notifier).setIndex(3);
        } else if (type == 'event') {
          ref.read(shellTabIndexProvider.notifier).setIndex(1);
        }
      },
      onError: (error) {
        ref.read(debugFirestoreErrorProvider.notifier).setError(error);
      },
    );
  }

  @override
  void dispose() {
    NotificationInfraService.instance.dispose();
    super.dispose();
  }

  Widget _buildNoGroupBody(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.groups_2_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '참여 중인 모임이 없어요',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '모임을 새로 만들거나 초대 코드로 참여해 보세요.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () async {
                  final createdGroupId =
                      await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => const CreateGroupScreen(),
                    ),
                  );
                  if (!mounted || createdGroupId == null) return;
                  AppCacheService.instance.invalidatePrefix('group:');
                  AppCacheService.instance.invalidatePrefix('member:');
                  AppCacheService.instance.invalidatePrefix('settings:');
                  ref
                      .read(selectedGroupIdProvider.notifier)
                      .setGroup(createdGroupId);
                },
                icon: const Icon(Icons.add),
                label: const Text('모임 만들기'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => context.push('/join-invite'),
                icon: const Icon(Icons.vpn_key_outlined),
                label: const Text('초대 코드로 참여'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tabIndex = ref.watch(shellTabIndexProvider);
    final groupId = ref.watch(selectedGroupIdProvider);

    final noGroupBody = _buildNoGroupBody(context);
    final membersPage = (groupId != null)
        ? GroupMembersScreen(groupId: groupId)
        : noGroupBody;
    final pollsPage = (groupId != null)
        ? PollsScreen(groupId: groupId)
        : noGroupBody;

    final pages = [
      groupId != null ? const HomeScreen() : noGroupBody,
      groupId != null ? const EventsScreen() : noGroupBody,
      membersPage,
      groupId != null ? const NoticesScreen() : noGroupBody,
      pollsPage,
      const MoreScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: pages[tabIndex]),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: tabIndex,
        onTap: (i) => ref.read(shellTabIndexProvider.notifier).setIndex(i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_outlined),
            activeIcon: Icon(Icons.event),
            label: '일정',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_2_outlined),
            activeIcon: Icon(Icons.groups_2),
            label: '팀원',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.campaign_outlined),
            activeIcon: Icon(Icons.campaign),
            label: '공지',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.how_to_vote_outlined),
            activeIcon: Icon(Icons.how_to_vote),
            label: '투표',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            activeIcon: Icon(Icons.more_horiz),
            label: '더보기',
          ),
        ],
      ),
    );
  }
}
