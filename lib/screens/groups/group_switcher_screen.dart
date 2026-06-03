import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_strings.dart';
import '../../providers.dart';
import '../../services/app_cache.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/debug_panel_card.dart';
import '../../widgets/empty_state.dart';
import 'create_group_screen.dart';

class GroupSwitcherScreen extends ConsumerStatefulWidget {
  const GroupSwitcherScreen({super.key});

  @override
  ConsumerState<GroupSwitcherScreen> createState() =>
      _GroupSwitcherScreenState();
}

class _GroupSwitcherScreenState extends ConsumerState<GroupSwitcherScreen> {
  final _groupNameQueryController = TextEditingController();
  Future<List<String>>? _fallbackGroupIdsFuture;
  String? _fallbackUid;

  @override
  void dispose() {
    _groupNameQueryController.dispose();
    super.dispose();
  }

  Future<Map<String, _GroupSummary>> _loadGroupSummaries(
    List<String> groupIds,
  ) async {
    final result = <String, _GroupSummary>{};
    for (final groupId in groupIds) {
      final groupDoc = await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .get();
      final data = groupDoc.data() ?? const <String, dynamic>{};
      final name = data['name'] as String? ?? groupId;
      final emblemUrl = data['emblemUrl']?.toString().trim();
      result[groupId] = _GroupSummary(
        name: name,
        emblemUrl: (emblemUrl != null && emblemUrl.isNotEmpty)
            ? emblemUrl
            : null,
      );
    }
    return result;
  }

  Future<List<String>> _loadFallbackGroupIdsByMember(String uid) async {
    final snap = await FirebaseFirestore.instance
        .collectionGroup('members')
        .where(FieldPath.documentId, isEqualTo: uid)
        .where('status', isEqualTo: 'active')
        .get();

    final ids = <String>{};
    for (final doc in snap.docs) {
      final groupId = doc.reference.parent.parent?.id;
      if (groupId != null && groupId.isNotEmpty) {
        ids.add(groupId);
      }
    }
    return ids.toList()..sort();
  }

  Future<List<String>> _getFallbackFuture(String uid) {
    if (_fallbackGroupIdsFuture == null || _fallbackUid != uid) {
      _fallbackUid = uid;
      _fallbackGroupIdsFuture = _loadFallbackGroupIdsByMember(uid);
    }
    return _fallbackGroupIdsFuture!;
  }

  void _selectGroup(String groupId) {
    HapticFeedback.lightImpact();
    AppCacheService.instance.invalidatePrefix('group:');
    AppCacheService.instance.invalidatePrefix('member:');
    AppCacheService.instance.invalidatePrefix('settings:');
    ref.read(selectedGroupIdProvider.notifier).setGroup(groupId);
  }

  Future<void> _openCreateGroup() async {
    final createdGroupId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const CreateGroupScreen()),
    );
    if (!mounted || createdGroupId == null) return;

    _selectGroup(createdGroupId);
    AppSnackbar.show(
      context,
      message: '모임을 생성했습니다.',
      type: AppSnackType.success,
    );
  }

  Widget _buildJoinedGroupCards(List<String> groupIds) {
    return FutureBuilder<Map<String, _GroupSummary>>(
      future: _loadGroupSummaries(groupIds),
      builder: (context, groupsSnapshot) {
        final groups = groupsSnapshot.data ?? <String, _GroupSummary>{};
        final allGroups =
            groupIds
                .map(
                  (id) => _JoinedGroupItem(
                    id: id,
                    name: groups[id]?.name ?? id,
                    emblemUrl: groups[id]?.emblemUrl,
                  ),
                )
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));

        final query = _groupNameQueryController.text.trim().toLowerCase();
        final filteredGroups = query.isEmpty
            ? allGroups
            : allGroups
                  .where((g) => g.name.toLowerCase().contains(query))
                  .toList();

        return Column(
          children: [
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('참여 중인 그룹 목록'),
                    const SizedBox(height: 8),
                    for (final group in allGroups)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: _GroupEmblemAvatar(
                          groupName: group.name,
                          emblemUrl: group.emblemUrl,
                        ),
                        title: Text(
                          group.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: SizedBox(
                          height: 44,
                          child: ElevatedButton(
                            onPressed: () => _selectGroup(group.id),
                            child: const Text('선택'),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('그룹 이름으로 찾기'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _groupNameQueryController,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: '그룹 이름 검색',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (query.isEmpty)
                      const Text('그룹 이름을 입력하면 참여 중인 그룹에서 빠르게 찾을 수 있습니다.'),
                    if (query.isNotEmpty && filteredGroups.isEmpty)
                      const Text('검색 결과가 없습니다.'),
                    if (query.isNotEmpty && filteredGroups.isNotEmpty)
                      for (final group in filteredGroups)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: _GroupEmblemAvatar(
                            groupName: group.name,
                            emblemUrl: group.emblemUrl,
                          ),
                          title: Text(group.name),
                          trailing: TextButton(
                            onPressed: () => _selectGroup(group.id),
                            child: const Text('선택'),
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final selectedGroupId = ref.watch(selectedGroupIdProvider);
    final lastError = ref.watch(debugFirestoreErrorProvider);
    final currentFcmToken = ref.watch(currentFcmTokenProvider);
    final tokenStored = ref.watch(tokenStoredProvider);

    if (user == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }

    final membershipsStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('memberships')
        .where('status', isEqualTo: 'active')
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            ExcludeSemantics(child: Icon(Icons.groups_outlined, size: 18)),
            SizedBox(width: 6),
            Text('그룹 선택'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: membershipsStream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return AppCard(
                  child: ListTile(
                    title: const Text('그룹 목록을 불러오지 못했습니다.'),
                    subtitle: Text(friendlyError(snapshot.error)),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const AppCard(
                  child: ListTile(
                    title: Text('참여 중인 그룹'),
                    subtitle: Text(AppStrings.loadingData),
                  ),
                );
              }

              final docs = snapshot.data!.docs;
              final groupIds = docs.map((d) => d.id).toSet().toList();
              if (groupIds.isNotEmpty) {
                return _buildJoinedGroupCards(groupIds);
              }

              return FutureBuilder<List<String>>(
                future: _getFallbackFuture(user.uid),
                builder: (context, fallbackSnap) {
                  if (fallbackSnap.hasError) {
                    return const EmptyState(
                      icon: Icons.groups_2_outlined,
                      title: '참여 중인 그룹이 없습니다',
                      description:
                          '프로필에서 닉네임을 설정하고 모임장이 보낸 초대 코드로 가입 요청을 보내 주세요.',
                    );
                  }
                  if (!fallbackSnap.hasData) {
                    return const AppCard(
                      child: ListTile(
                        title: Text('참여 중인 그룹'),
                        subtitle: Text(AppStrings.loadingData),
                      ),
                    );
                  }

                  final fallbackIds = fallbackSnap.data!;
                  if (fallbackIds.isEmpty) {
                    return const EmptyState(
                      icon: Icons.groups_2_outlined,
                      title: '참여 중인 그룹이 없습니다',
                      description:
                          '프로필에서 닉네임을 설정하고 모임장이 보낸 초대 코드로 가입 요청을 보내 주세요.',
                    );
                  }
                  return _buildJoinedGroupCards(fallbackIds);
                },
              );
            },
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '처음 사용하시나요?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text('새 모임을 만들고 무료/Pro 플랜 조건을 확인해 보세요.'),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: _openCreateGroup,
                      icon: const Icon(Icons.add),
                      label: const Text('새 모임 만들기'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '모임 초대를 받으셨나요?',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text('모임장이 발급한 초대 링크 또는 초대 코드로 참여할 수 있어요.'),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton.icon(
                      onPressed: () => context.push('/join-invite'),
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: const Text('초대 코드로 참여'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (kEnableDebugPanel)
            DebugPanelCard(
              uid: user.uid,
              selectedGroupId: selectedGroupId,
              memberDocExists: null,
              memberStatus: null,
              lastFirestoreError: lastError,
              currentFcmToken: currentFcmToken,
              tokenStored: tokenStored,
              notificationSettingsSummary: null,
            ),
        ],
      ),
    );
  }
}

class _JoinedGroupItem {
  const _JoinedGroupItem({
    required this.id,
    required this.name,
    required this.emblemUrl,
  });

  final String id;
  final String name;
  final String? emblemUrl;
}

class _GroupSummary {
  const _GroupSummary({required this.name, required this.emblemUrl});

  final String name;
  final String? emblemUrl;
}

class _GroupEmblemAvatar extends StatelessWidget {
  const _GroupEmblemAvatar({required this.groupName, required this.emblemUrl});

  final String groupName;
  final String? emblemUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = emblemUrl != null && emblemUrl!.trim().isNotEmpty;
    final initial = groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G';
    return CircleAvatar(
      radius: 18,
      backgroundImage: hasImage ? NetworkImage(emblemUrl!.trim()) : null,
      onBackgroundImageError: hasImage ? (_, __) {} : null,
      child: hasImage ? null : Text(initial),
    );
  }
}
