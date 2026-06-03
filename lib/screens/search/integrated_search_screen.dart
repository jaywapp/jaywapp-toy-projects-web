import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_strings.dart';
import '../../providers.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/section_header.dart';

class IntegratedSearchScreen extends ConsumerStatefulWidget {
  const IntegratedSearchScreen({super.key, this.initialGroupId});

  final String? initialGroupId;

  @override
  ConsumerState<IntegratedSearchScreen> createState() =>
      _IntegratedSearchScreenState();
}

class _IntegratedSearchScreenState
    extends ConsumerState<IntegratedSearchScreen> {
  final _queryController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _loadedGroupId;
  _SearchBundle? _bundle;
  bool _loading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _queryController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() => _query = _queryController.text.trim());
    });
  }

  Future<void> _load(String groupId) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final db = FirebaseFirestore.instance.collection('groups').doc(groupId);
      final futures = await Future.wait([
        db.collection('members').where('status', isEqualTo: 'active').get(),
        db
            .collection('events')
            .orderBy('startAt', descending: true)
            .limit(250)
            .get(),
        db
            .collection('notices')
            .orderBy('createdAt', descending: true)
            .limit(250)
            .get(),
        db
            .collection('polls')
            .orderBy('createdAt', descending: true)
            .limit(250)
            .get(),
      ]);
      if (!mounted) return;
      setState(() {
        _bundle = _SearchBundle(
          members: futures[0].docs,
          events: futures[1].docs,
          notices: futures[2].docs,
          polls: futures[3].docs,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedGroupId = ref.watch(selectedGroupIdProvider);
    final groupId = widget.initialGroupId ?? selectedGroupId;
    final effectiveGroupId = groupId;

    if (effectiveGroupId == null || effectiveGroupId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('통합 검색')),
        body: const Center(child: Text(AppStrings.selectGroupFirst)),
      );
    }

    if (_loadedGroupId != effectiveGroupId) {
      _loadedGroupId = effectiveGroupId;
      unawaited(_load(effectiveGroupId));
    }

    final bundle = _bundle;
    final query = _query.toLowerCase();
    final filtered = bundle == null
        ? const _FilteredSearchResult.empty()
        : _filterBundle(bundle, query);

    return Scaffold(
      appBar: AppBar(title: const Text('통합 검색')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _queryController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: '멤버, 일정, 공지, 투표 검색',
              prefixIcon: const ExcludeSemantics(child: Icon(Icons.search)),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      tooltip: '검색어 지우기',
                      onPressed: () {
                        _queryController.clear();
                        FocusScope.of(context).requestFocus(FocusNode());
                      },
                      icon: const ExcludeSemantics(child: Icon(Icons.close)),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          if (_loading)
            const AppCard(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
          if (_errorMessage != null)
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_errorMessage!),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => _load(effectiveGroupId),
                    icon: const Icon(Icons.refresh),
                    label: const Text('다시 시도'),
                  ),
                ],
              ),
            ),
          if (!_loading && bundle != null && _errorMessage == null) ...[
            AppCard(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CountChip(label: '멤버 ${filtered.members.length}'),
                  _CountChip(label: '일정 ${filtered.events.length}'),
                  _CountChip(label: '공지 ${filtered.notices.length}'),
                  _CountChip(label: '투표 ${filtered.polls.length}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_query.isEmpty)
              const AppCard(child: Text('검색어를 입력하면 통합 결과가 표시됩니다.')),
            if (_query.isNotEmpty &&
                filtered.members.isEmpty &&
                filtered.events.isEmpty &&
                filtered.notices.isEmpty &&
                filtered.polls.isEmpty)
              const AppCard(child: Text('검색 결과가 없습니다.')),
            if (_query.isNotEmpty && filtered.members.isNotEmpty) ...[
              const SectionHeader(title: '멤버', icon: Icons.groups_2_outlined),
              for (final m in filtered.members)
                AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      radius: 16,
                      child: Icon(Icons.person_outline, size: 16),
                    ),
                    title: Text(m.displayName),
                    subtitle: Text('@${m.uid}'),
                    onTap: () {
                      ref.read(shellTabIndexProvider.notifier).setIndex(2);
                      context.pop();
                    },
                  ),
                ),
            ],
            if (_query.isNotEmpty && filtered.events.isNotEmpty) ...[
              const SectionHeader(title: '일정', icon: Icons.event_outlined),
              for (final e in filtered.events)
                AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_note_outlined),
                    title: Text(
                      e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${e.startAtText}${e.locationText.isEmpty ? '' : ' · ${e.locationText}'}',
                    ),
                    onTap: () => context.push('/event/${e.id}'),
                  ),
                ),
            ],
            if (_query.isNotEmpty && filtered.notices.isNotEmpty) ...[
              const SectionHeader(title: '공지', icon: Icons.campaign_outlined),
              for (final n in filtered.notices)
                AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.article_outlined),
                    title: Text(
                      n.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      n.preview,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => context.push('/notice/${n.id}'),
                  ),
                ),
            ],
            if (_query.isNotEmpty && filtered.polls.isNotEmpty) ...[
              const SectionHeader(
                title: '투표',
                icon: Icons.how_to_vote_outlined,
              ),
              for (final p in filtered.polls)
                AppCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.how_to_vote_outlined),
                    title: Text(
                      p.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      p.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      ref.read(shellTabIndexProvider.notifier).setIndex(4);
                      context.pop();
                    },
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }

  _FilteredSearchResult _filterBundle(_SearchBundle bundle, String query) {
    final members = bundle.members
        .map((doc) {
          final data = doc.data();
          final displayName = data['displayName']?.toString().trim();
          final name = (displayName != null && displayName.isNotEmpty)
              ? displayName
              : doc.id;
          return _MemberResult(uid: doc.id, displayName: name);
        })
        .where(
          (m) => query.isEmpty || _containsAny(query, [m.uid, m.displayName]),
        )
        .toList(growable: false);

    final events = bundle.events
        .where((doc) => doc.data()['isDeleted'] != true)
        .map((doc) {
          final data = doc.data();
          final title = data['title']?.toString() ?? '(제목 없음)';
          final desc = data['description']?.toString() ?? '';
          final location = eventPrimaryPlace(data);
          final ts = data['startAt'];
          final startAtText = ts is Timestamp
              ? formatDateTime(ts.toDate())
              : '-';
          return _EventResult(
            id: doc.id,
            title: title,
            locationText: location,
            startAtText: startAtText,
            description: desc,
          );
        })
        .where(
          (e) =>
              query.isEmpty ||
              _containsAny(query, [e.title, e.locationText, e.description]),
        )
        .toList(growable: false);

    final notices = bundle.notices
        .map((doc) {
          final data = doc.data();
          final title = data['title']?.toString() ?? '(제목 없음)';
          final body = data['body']?.toString() ?? '';
          return _NoticeResult(id: doc.id, title: title, preview: body);
        })
        .where(
          (n) => query.isEmpty || _containsAny(query, [n.title, n.preview]),
        )
        .toList(growable: false);

    final polls = bundle.polls
        .map((doc) {
          final data = doc.data();
          final title = data['title']?.toString() ?? '(제목 없음)';
          final description = data['description']?.toString() ?? '';
          final options = (data['options'] is List)
              ? (data['options'] as List).map((e) => e.toString()).join(' / ')
              : '';
          return _PollResult(
            id: doc.id,
            title: title,
            subtitle: description.isNotEmpty ? description : options,
          );
        })
        .where(
          (p) => query.isEmpty || _containsAny(query, [p.title, p.subtitle]),
        )
        .toList(growable: false);

    return _FilteredSearchResult(
      members: members,
      events: events,
      notices: notices,
      polls: polls,
    );
  }

  bool _containsAny(String query, List<String> candidates) {
    if (query.isEmpty) return true;
    final lower = query.toLowerCase();
    for (final candidate in candidates) {
      if (candidate.toLowerCase().contains(lower)) {
        return true;
      }
    }
    return false;
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _SearchBundle {
  const _SearchBundle({
    required this.members,
    required this.events,
    required this.notices,
    required this.polls,
  });

  final List<QueryDocumentSnapshot<Map<String, dynamic>>> members;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> events;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> notices;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> polls;
}

class _FilteredSearchResult {
  const _FilteredSearchResult({
    required this.members,
    required this.events,
    required this.notices,
    required this.polls,
  });

  const _FilteredSearchResult.empty()
    : members = const <_MemberResult>[],
      events = const <_EventResult>[],
      notices = const <_NoticeResult>[],
      polls = const <_PollResult>[];

  final List<_MemberResult> members;
  final List<_EventResult> events;
  final List<_NoticeResult> notices;
  final List<_PollResult> polls;
}

class _MemberResult {
  const _MemberResult({required this.uid, required this.displayName});

  final String uid;
  final String displayName;
}

class _EventResult {
  const _EventResult({
    required this.id,
    required this.title,
    required this.locationText,
    required this.startAtText,
    required this.description,
  });

  final String id;
  final String title;
  final String locationText;
  final String startAtText;
  final String description;
}

class _NoticeResult {
  const _NoticeResult({
    required this.id,
    required this.title,
    required this.preview,
  });

  final String id;
  final String title;
  final String preview;
}

class _PollResult {
  const _PollResult({
    required this.id,
    required this.title,
    required this.subtitle,
  });

  final String id;
  final String title;
  final String subtitle;
}
