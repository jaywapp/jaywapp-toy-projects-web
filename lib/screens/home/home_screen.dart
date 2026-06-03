import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_strings.dart';
import '../../providers.dart';
import '../../services/app_cache.dart';
import '../../services/map_launcher_service.dart';
import '../stats/stats_screen.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/date_badge.dart';
import '../../widgets/debug_panel_card.dart';
import '../../widgets/response_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/status_badge.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String? _groupId;
  String? _uid;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _groupStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _memberStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _settingsStream;
  Stream<DocumentSnapshot<Map<String, dynamic>>>? _profileStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _eventsStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _noticesStream;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _pollsStream;

  void _initStreams(String groupId, String uid) {
    final db = FirebaseFirestore.instance;
    _groupStream = db.collection('groups').doc(groupId).snapshots();
    _memberStream = db
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(uid)
        .snapshots();
    _settingsStream = db
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(uid)
        .collection('notificationSettings')
        .doc('default')
        .snapshots();
    _profileStream = db.collection('users').doc(uid).snapshots();
    _eventsStream = db
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .orderBy('startAt')
        .limit(10)
        .snapshots();
    _noticesStream = db
        .collection('groups')
        .doc(groupId)
        .collection('notices')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots();
    _pollsStream = db
        .collection('groups')
        .doc(groupId)
        .collection('polls')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final groupId = ref.read(selectedGroupIdProvider);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (groupId != _groupId || uid != _uid) {
      _groupId = groupId;
      _uid = uid;
      if (groupId != null && uid != null) {
        _initStreams(groupId, uid);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupId = ref.watch(selectedGroupIdProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (groupId == null || user == null) {
      return const Center(child: Text(AppStrings.selectGroupFirst));
    }

    final lastError = ref.watch(debugFirestoreErrorProvider);
    final currentFcmToken = ref.watch(currentFcmTokenProvider);
    final tokenStored = ref.watch(tokenStoredProvider);

    void switchTab(int index) {
      ref.read(shellTabIndexProvider.notifier).setIndex(index);
    }

    void openStatsScreen() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StatsScreen(groupId: groupId, uid: user.uid),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _groupStream,
      builder: (context, g) {
        if (g.hasError) {
          final msg = friendlyError(g.error);
          ref.read(debugFirestoreErrorProvider.notifier).setError(msg);
          return Center(
            child: Padding(padding: const EdgeInsets.all(16), child: Text(msg)),
          );
        }
        if (!g.hasData) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: const [
              AppSkeleton(height: 28, width: 180),
              SizedBox(height: 12),
              AppSkeleton(height: 84),
              SizedBox(height: 12),
              AppSkeleton(height: 120),
              SizedBox(height: 12),
              AppSkeleton(height: 120),
            ],
          );
        }

        final groupName = g.data!.data()?['name'] as String? ?? groupId;
        final emblemUrl = g.data!.data()?['emblemUrl']?.toString();
        final monthText = currentPeriodKey().replaceAll('-', '.');
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      _GroupEmblemAvatar(
                        groupName: groupName,
                        emblemUrl: emblemUrl,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              groupName,
                              style: Theme.of(context).textTheme.headlineMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "$monthText 통계 요약",
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: _profileStream,
                  builder: (context, profileSnap) {
                    final data = profileSnap.data?.data();
                    final nickname = data?['nickname']?.toString() ?? '';
                    final photoUrl = data?['photoUrl']?.toString();
                    final initial = nickname.isNotEmpty
                        ? nickname[0].toUpperCase()
                        : null;
                    return Row(
                      children: [
                        IconButton(
                          tooltip: "통합 검색",
                          onPressed: () => context.push('/search?groupId=$groupId'),
                          icon: const Icon(Icons.search_outlined),
                        ),
                        IconButton(
                          tooltip: "그룹 전환",
                          onPressed: () {
                            AppCacheService.instance.invalidatePrefix('group:');
                            AppCacheService.instance.invalidatePrefix(
                              'member:',
                            );
                            AppCacheService.instance.invalidatePrefix(
                              'settings:',
                            );
                            ref
                                .read(selectedGroupIdProvider.notifier)
                                .setGroup(null);
                          },
                          icon: const Icon(Icons.swap_horiz_outlined),
                        ),
                        Semantics(
                          label: '프로필',
                          hint: '탭하여 프로필 보기',
                          button: true,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => context.push('/profile'),
                            child: ExcludeSemantics(
                              child: CircleAvatar(
                                radius: 16,
                                backgroundImage:
                                    (photoUrl != null && photoUrl.isNotEmpty)
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: (photoUrl == null || photoUrl.isEmpty)
                                    ? Text(initial ?? 'U')
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: "알림 설정",
                          onPressed: () =>
                              context.push('/notification-settings'),
                          icon: const Icon(Icons.settings_outlined),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            ref.watch(homeKpiProvider((groupId, user.uid))).when(
              data: (kpi) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    StatTile(
                      title: "참여율",
                      value: kpi['attendanceRate'] ?? '-',
                      onTap: openStatsScreen,
                    ),
                    StatTile(
                      title: "미납 회비",
                      value: kpi['unpaidCount'] ?? '-',
                      onTap: () => context.push('/finance?groupId=$groupId'),
                    ),
                    StatTile(
                      title: "다가오는 일정",
                      value: kpi['upcomingCount'] ?? '-',
                      onTap: () => switchTab(1),
                    ),
                  ],
                ),
              ),
              loading: () => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    StatTile(title: "참여율", value: '-', onTap: openStatsScreen),
                    StatTile(
                      title: "미납 회비",
                      value: '-',
                      onTap: () => context.push('/finance?groupId=$groupId'),
                    ),
                    StatTile(
                      title: "다가오는 일정",
                      value: '-',
                      onTap: () => switchTab(1),
                    ),
                  ],
                ),
              ),
              error: (_, __) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    StatTile(title: "참여율", value: '-', onTap: openStatsScreen),
                    StatTile(
                      title: "미납 회비",
                      value: '-',
                      onTap: () => context.push('/finance?groupId=$groupId'),
                    ),
                    StatTile(
                      title: "다가오는 일정",
                      value: '-',
                      onTap: () => switchTab(1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SectionHeader(
              title: "활동 인사이트",
              icon: Icons.event_note_outlined,
              actionLabel: "통계 보기",
              onActionTap: openStatsScreen,
            ),
            ref.watch(homeEngagementProvider((groupId, user.uid))).when(
              data: (data) => AppCard(
                child: Semantics(
                  label: "이번 주 참여 요약",
                  hint: "탭하여 통계 보기",
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: openStatsScreen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("이번 주 참여 요약"),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            StatusBadge(
                              label: "미응답 ${data["weeklyNoResponse"]}",
                              tone: StatusBadgeTone.warning,
                            ),
                            StatusBadge(
                              label: "연속 출석 ${data["attendanceStreak"]}",
                              tone: StatusBadgeTone.success,
                            ),
                            StatusBadge(
                              label: "활동 순위 ${data["activityRank"]}",
                              tone: StatusBadgeTone.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              loading: () => AppCard(
                child: Semantics(
                  label: "이번 주 참여 요약",
                  hint: "탭하여 통계 보기",
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: openStatsScreen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("이번 주 참여 요약"),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            StatusBadge(
                              label: "미응답 -",
                              tone: StatusBadgeTone.warning,
                            ),
                            StatusBadge(
                              label: "연속 출석 -",
                              tone: StatusBadgeTone.success,
                            ),
                            StatusBadge(
                              label: "활동 순위 -",
                              tone: StatusBadgeTone.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              error: (_, __) => AppCard(
                child: Semantics(
                  label: "이번 주 참여 요약",
                  hint: "탭하여 통계 보기",
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: openStatsScreen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("이번 주 참여 요약"),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: const [
                            StatusBadge(
                              label: "미응답 -",
                              tone: StatusBadgeTone.warning,
                            ),
                            StatusBadge(
                              label: "연속 출석 -",
                              tone: StatusBadgeTone.success,
                            ),
                            StatusBadge(
                              label: "활동 순위 -",
                              tone: StatusBadgeTone.primary,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SectionHeader(
              title: "다가오는 일정",
              icon: Icons.event_available_outlined,
              actionLabel: "전체 보기",
              onActionTap: () => switchTab(1),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _eventsStream,
              builder: (context, e) {
                if (e.hasError)
                  return AppCard(child: Text(friendlyError(e.error)));
                if (!e.hasData)
                  return const AppCard(child: Text(AppStrings.loadingData));

                final events = e.data!.docs
                    .where((d) => d.data()['isDeleted'] != true)
                    .toList();
                final upcoming = events
                    .where((d) {
                      final ts = d.data()['startAt'];
                      return ts is Timestamp &&
                          ts.toDate().isAfter(DateTime.now());
                    })
                    .take(2)
                    .toList();

                if (upcoming.isEmpty)
                  return const AppCard(child: Text("등록된 일정이 없습니다."));

                return Column(
                  children: [
                    for (final event in upcoming)
                      Semantics(
                        label: '일정: ${event.data()['title'] ?? ''}',
                        hint: '탭하여 상세 보기',
                        button: true,
                        child: AppCard(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.push('/event/${event.id}'),
                          child:
                              StreamBuilder<
                                DocumentSnapshot<Map<String, dynamic>>
                              >(
                                stream: FirebaseFirestore.instance
                                    .collection('groups')
                                    .doc(groupId)
                                    .collection('events')
                                    .doc(event.id)
                                    .collection('responses')
                                    .doc(user.uid)
                                    .snapshots(),
                                builder: (context, rs) {
                                  final response =
                                      rs.data?.data()?['response'] as String? ??
                                      'maybe';
                                  final isResponseClosed =
                                      isEventResponseClosed(event.data());
                                  final needsResponse =
                                      (!rs.hasData ||
                                          !rs.data!.exists ||
                                          response == 'maybe') &&
                                      !isResponseClosed;
                                  final ts = event.data()['startAt'];
                                  final dateText = ts is Timestamp
                                      ? formatDate(ts.toDate())
                                      : '-';
                                  final isPast =
                                      ts is Timestamp &&
                                      ts.toDate().isBefore(DateTime.now());
                                  final primaryPlace = eventPrimaryPlace(
                                    event.data(),
                                  );
                                  final address = event
                                      .data()['address']
                                      ?.toString();
                                  final mapQuery = eventMapQuery(event.data());
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        DateBadge(text: dateText, past: isPast),
                                        if (needsResponse) ...[
                                          const SizedBox(height: 6),
                                          const StatusBadge(
                                            label: "응답 필요",
                                            tone: StatusBadgeTone.warning,
                                          ),
                                        ] else if (isResponseClosed) ...[
                                          const SizedBox(height: 6),
                                          const StatusBadge(
                                            label: "응답 마감",
                                            tone: StatusBadgeTone.primary,
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Text(
                                          event.data()['title'] as String? ??
                                              "(제목 없음)",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleMedium,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          "장소: $primaryPlace",
                                          style: Theme.of(
                                            context,
                                          ).textTheme.bodySmall,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (address != null &&
                                            address.isNotEmpty &&
                                            address != primaryPlace) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            "주소: $address",
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        if (mapQuery != null)
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton.icon(
                                              onPressed: () =>
                                                  MapLauncherService.openNaverMapSearch(
                                                    mapQuery,
                                                  ),
                                              icon: const Icon(
                                                Icons.map_outlined,
                                                size: 16,
                                              ),
                                              label: const Text("지도 열기"),
                                            ),
                                          )
                                        else
                                          Align(
                                            alignment: Alignment.centerLeft,
                                            child: TextButton.icon(
                                              onPressed: () => AppSnackbar.show(
                                                context,
                                                message:
                                                    "주소 정보가 없어 지도를 열 수 없습니다.",
                                                type: AppSnackType.info,
                                              ),
                                              icon: const Icon(
                                                Icons.map_outlined,
                                                size: 16,
                                              ),
                                              label: const Text("지도 열기"),
                                            ),
                                          ),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 6,
                                          children: [
                                            ResponseButton(
                                              label: "미정",
                                              selected: response == 'maybe',
                                              onPressed:
                                                  (isPast || isResponseClosed)
                                                  ? null
                                                  : () => writeResponse(
                                                      groupId: groupId,
                                                      eventId: event.id,
                                                      uid: user.uid,
                                                      response: 'maybe',
                                                      context: context,
                                                    ),
                                            ),
                                            ResponseButton(
                                              label: "참석",
                                              selected: response == 'going',
                                              onPressed:
                                                  (isPast || isResponseClosed)
                                                  ? null
                                                  : () => writeResponse(
                                                      groupId: groupId,
                                                      eventId: event.id,
                                                      uid: user.uid,
                                                      response: 'going',
                                                      context: context,
                                                    ),
                                            ),
                                            ResponseButton(
                                              label: "불참",
                                              selected: response == 'notGoing',
                                              onPressed:
                                                  (isPast || isResponseClosed)
                                                  ? null
                                                  : () => writeResponse(
                                                      groupId: groupId,
                                                      eventId: event.id,
                                                      uid: user.uid,
                                                      response: 'notGoing',
                                                      context: context,
                                                    ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                        ),
                      ),
                      ),  // Semantics
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            SectionHeader(
              title: "진행중인 투표",
              icon: Icons.how_to_vote_outlined,
              actionLabel: "전체 보기",
              onActionTap: () => switchTab(4),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _pollsStream,
              builder: (context, p) {
                if (p.hasError) {
                  return AppCard(child: Text(friendlyError(p.error)));
                }
                if (!p.hasData) {
                  return const AppCard(child: Text(AppStrings.loadingData));
                }

                final openPolls = p.data!.docs
                    .where((d) {
                      final data = d.data();
                      final status = data['status']?.toString() ?? 'open';
                      final endAt = data['endAt'];
                      final endAtDateTime = endAt is Timestamp
                          ? endAt.toDate()
                          : null;
                      final expired =
                          endAtDateTime != null &&
                          !endAtDateTime.isAfter(DateTime.now());
                      return status == 'open' && !expired;
                    })
                    .take(3)
                    .toList();
                if (openPolls.isEmpty) {
                  return const AppCard(child: Text("현재 진행중인 투표가 없습니다."));
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: openPolls.map((pollDoc) {
                    final data = pollDoc.data();
                    final title = data['title']?.toString() ?? '(제목 없음)';
                    final description = data['description']?.toString() ?? '';
                    final options = (data['options'] is List)
                        ? (data['options'] as List)
                              .map((e) => e.toString())
                              .where((e) => e.isNotEmpty)
                              .toList()
                        : <String>[];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AppCard(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => switchTab(4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (description.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(height: 8),
                              StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: pollDoc.reference
                                    .collection('votes')
                                    .snapshots(),
                                builder: (context, voteSnap) {
                                  final totalVotes =
                                      voteSnap.data?.docs.length ?? 0;
                                  return Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      StatusBadge(
                                        label: "참여 ${totalVotes}명",
                                        tone: StatusBadgeTone.primary,
                                      ),
                                      StatusBadge(
                                        label: "선택지 ${options.length}개",
                                        tone: StatusBadgeTone.success,
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "하단의 투표 메뉴에서 바로 참여할 수 있어요.",
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            SectionHeader(
              title: "공지",
              icon: Icons.campaign_outlined,
              actionLabel: "전체 보기",
              onActionTap: () => switchTab(3),
            ),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _noticesStream,
              builder: (context, n) {
                if (n.hasError)
                  return AppCard(child: Text(friendlyError(n.error)));
                if (!n.hasData)
                  return const AppCard(child: Text(AppStrings.loadingData));

                final notices = n.data!.docs;
                final pinned = notices
                    .where((d) => d.data()['pinned'] == true)
                    .toList();
                final latest = notices.isNotEmpty ? notices.first : null;

                return Semantics(
                  label: '공지 요약',
                  hint: '탭하여 공지 전체 보기',
                  button: true,
                  child: AppCard(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => switchTab(3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (pinned.isNotEmpty)
                          Text(
                            "고정 공지: ${pinned.first.data()["title"] ?? "(제목 없음)"}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (latest != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            "최신 공지: ${latest.data()["title"] ?? "(제목 없음)"}",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (pinned.isEmpty && latest == null)
                          const Text("등록된 공지가 없습니다."),
                        const SizedBox(height: 8),
                        StatusBadge(
                          label: "전체 공지 수 ${notices.length}건",
                          tone: StatusBadgeTone.primary,
                        ),
                      ],
                    ),
                  ),
                  ),  // Semantics
                );
              },
            ),
            const SizedBox(height: 12),
            SectionHeader(
              title: "내 통계",
              icon: Icons.insights_outlined,
              actionLabel: "통계 보기",
              onActionTap: openStatsScreen,
            ),
            ref.watch(myHomeSummaryProvider((groupId, user.uid))).when(
              data: (data) => AppCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: openStatsScreen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("참여 TOP3: ${data["top3"]}"),
                      const Divider(height: 16),
                      Text("나의 활동 순위 ${data["rank"]}"),
                    ],
                  ),
                ),
              ),
              loading: () => AppCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: openStatsScreen,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("참여 TOP3: -"),
                      Divider(height: 16),
                      Text("나의 활동 순위 -"),
                    ],
                  ),
                ),
              ),
              error: (_, __) => AppCard(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: openStatsScreen,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("참여 TOP3: -"),
                      Divider(height: 16),
                      Text("나의 활동 순위 -"),
                    ],
                  ),
                ),
              ),
            ),
            if (kEnableDebugPanel)
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: _memberStream,
                builder: (context, m) {
                  return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    stream: _settingsStream,
                    builder: (context, ss) {
                      final settings = ss.data?.data();
                      final settingsSummary = settings == null
                          ? "설정 불러오는 중"
                          : "공지=${settings["noticeEnabled"] ?? true}, D-1=${settings["eventReminderEnabled"] ?? true}, 13:00=${settings["noResponseReminderEnabled"] ?? true}";
                      return DebugPanelCard(
                        uid: user.uid,
                        selectedGroupId: groupId,
                        memberDocExists: m.data?.exists,
                        memberStatus: m.data?.data()?['status']?.toString(),
                        lastFirestoreError: lastError,
                        currentFcmToken: currentFcmToken,
                        tokenStored: tokenStored,
                        notificationSettingsSummary: settingsSummary,
                      );
                    },
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _GroupEmblemAvatar extends StatelessWidget {
  const _GroupEmblemAvatar({required this.groupName, required this.emblemUrl});

  final String groupName;
  final String? emblemUrl;

  @override
  Widget build(BuildContext context) {
    final hasImage = emblemUrl != null && emblemUrl!.trim().isNotEmpty;
    final initial = groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G';
    return Semantics(
      label: groupName,
      child: CircleAvatar(
        radius: 20,
        backgroundImage: hasImage ? NetworkImage(emblemUrl!.trim()) : null,
        onBackgroundImageError: hasImage ? (_, __) {} : null,
        child: hasImage ? ExcludeSemantics(child: Text(initial)) : Text(initial),
      ),
    );
  }
}
