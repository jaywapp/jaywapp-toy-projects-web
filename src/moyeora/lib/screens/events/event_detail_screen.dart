import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_strings.dart';
import '../../providers.dart';
import '../../services/event_calendar_service.dart';
import '../../services/map_launcher_service.dart';
import '../../services/permission_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/date_badge.dart';
import '../../widgets/emoji_reaction_bar.dart';
import '../../widgets/response_button.dart';
import '../../widgets/status_badge.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  bool _showAttendance = false;
  bool _showGoingResponsesOnly = false;
  bool _savingComment = false;
  bool _descriptionExpanded = false;
  final Set<String> _savingAttendanceUids = <String>{};
  final Map<String, String> _memberNameCache = <String, String>{};
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _setAttendance({
    required String groupId,
    required String targetUid,
    required String status,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (_savingAttendanceUids.contains(targetUid)) return;

    setState(() => _savingAttendanceUids.add(targetUid));
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('events')
          .doc(widget.eventId)
          .collection('attendances')
          .doc(targetUid)
          .set({
            'uid': targetUid,
            'status': status,
            'checkedBy': user.uid,
            'checkedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '출석 상태가 저장되었습니다.',
        type: AppSnackType.success,
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: friendlyError(e),
        type: AppSnackType.error,
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '출석 상태 저장 중 오류가 발생했습니다.',
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _savingAttendanceUids.remove(targetUid));
      }
    }
  }

  String _attendanceLabel(String? status) {
    return switch (status) {
      'present' => '출석',
      'late' => '지각',
      'absent' => '결석',
      _ => '미체크',
    };
  }

  StatusBadgeTone _attendanceTone(String? status) {
    return switch (status) {
      'present' => StatusBadgeTone.success,
      'late' => StatusBadgeTone.warning,
      'absent' => StatusBadgeTone.danger,
      _ => StatusBadgeTone.primary,
    };
  }

  StatusBadgeTone _responseTone(String? response) {
    return switch (response) {
      'going' => StatusBadgeTone.success,
      'notGoing' => StatusBadgeTone.danger,
      _ => StatusBadgeTone.warning,
    };
  }

  String _fallbackDisplayNameOfMemberDoc(
    Map<String, dynamic> memberData,
    String uid,
  ) {
    final byDisplayName = memberData['displayName']?.toString().trim();
    if (byDisplayName != null && byDisplayName.isNotEmpty) return byDisplayName;
    final byPublic = (memberData['public'] as Map?)?['nickname']
        ?.toString()
        .trim();
    if (byPublic != null && byPublic.isNotEmpty) return byPublic;
    return uid;
  }

  String _profileNameFromUserDoc(Map<String, dynamic> userData) {
    final displayName = userData['displayName']?.toString().trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;
    final nickname = userData['nickname']?.toString().trim();
    if (nickname != null && nickname.isNotEmpty) return nickname;
    return '';
  }

  Future<Map<String, String>> _loadMemberDisplayNames(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> members,
  ) async {
    if (members.isEmpty) return const <String, String>{};

    final uidToMemberData = <String, Map<String, dynamic>>{
      for (final member in members) member.id: member.data(),
    };
    final uids = uidToMemberData.keys.toList(growable: false);
    final missing = uids
        .where((uid) => !_memberNameCache.containsKey(uid))
        .toList();

    if (missing.isNotEmpty) {
      for (var i = 0; i < missing.length; i += 30) {
        final end = (i + 30 < missing.length) ? i + 30 : missing.length;
        final chunk = missing.sublist(i, end);
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final doc in snap.docs) {
          final profileName = _profileNameFromUserDoc(doc.data());
          if (profileName.isNotEmpty) {
            _memberNameCache[doc.id] = profileName;
          }
        }
      }

      for (final uid in missing) {
        _memberNameCache.putIfAbsent(
          uid,
          () => _fallbackDisplayNameOfMemberDoc(
            uidToMemberData[uid] ?? const <String, dynamic>{},
            uid,
          ),
        );
      }
    }

    return {for (final uid in uids) uid: _memberNameCache[uid] ?? uid};
  }

  Widget _buildInfoRow(IconData icon, String text, {TextStyle? style}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(icon, size: 16, color: colorScheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style:
                style ??
                Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }

  Future<void> _openGoogleCalendar({
    required String title,
    required DateTime startAt,
    required String description,
    required String location,
  }) async {
    final endAt = startAt.add(const Duration(hours: 2));
    final opened = await EventCalendarService.openGoogleCalendar(
      title: title,
      startAt: startAt,
      endAt: endAt,
      description: description,
      location: location,
    );
    if (!mounted) return;
    if (!opened) {
      AppSnackbar.show(
        context,
        message: '캘린더 앱을 열 수 없습니다.',
        type: AppSnackType.error,
      );
      return;
    }
    AppSnackbar.show(
      context,
      message: '구글 캘린더 화면으로 이동했습니다.',
      type: AppSnackType.info,
    );
  }

  Future<void> _openIcsCalendar({
    required String title,
    required DateTime startAt,
    required String description,
    required String location,
    required String eventId,
  }) async {
    final endAt = startAt.add(const Duration(hours: 2));
    final opened = await EventCalendarService.openIcsImport(
      title: title,
      startAt: startAt,
      endAt: endAt,
      description: description,
      location: location,
      uid: '$eventId@moyeora',
    );
    if (!mounted) return;
    if (!opened) {
      await EventCalendarService.shareIcs(
        title: title,
        startAt: startAt,
        endAt: endAt,
        description: description,
        location: location,
        uid: '$eventId@moyeora',
      );
      if (!mounted) return;
    }
    AppSnackbar.show(
      context,
      message: opened ? '캘린더 가져오기 화면을 열었습니다.' : 'ICS 공유 창을 열었습니다.',
      type: AppSnackType.success,
    );
  }

  Widget _buildSummaryRow({
    required String title,
    required IconData icon,
    required List<Widget> badges,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ExcludeSemantics(child: Icon(icon, size: 14, color: colorScheme.onSurfaceVariant)),
            const SizedBox(width: 6),
            Text(
              title,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: badges),
      ],
    );
  }

  Widget _buildAttendanceActionChip({
    required String groupId,
    required String targetUid,
    required String status,
    required String label,
    required bool selected,
  }) {
    final saving = _savingAttendanceUids.contains(targetUid);
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: label,
      hint: '탭하여 출석 상태 변경',
      button: true,
      selected: selected,
      child: InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: saving
          ? null
          : () => _setAttendance(
              groupId: groupId,
              targetUid: targetUid,
              status: status,
            ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? colorScheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: selected
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildMemberRow({
    required String groupId,
    required _AttendanceRowData row,
    required bool canManageAttendance,
    required bool isLast,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text(
                row.memberLabel.isNotEmpty
                    ? row.memberLabel.characters.first
                    : '?',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.memberLabel,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      StatusBadge(
                        label: row.responseLabel,
                        tone: _responseTone(row.responseCode),
                      ),
                      if (row.respondedAt != null) ...[
                        const SizedBox(width: 6),
                        ExcludeSemantics(
                          child: Icon(
                            Icons.schedule,
                            size: 12,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          row.respondedAt!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            StatusBadge(
              label: _attendanceLabel(row.attendanceStatus),
              tone: _attendanceTone(row.attendanceStatus),
            ),
          ],
        ),
        if (canManageAttendance) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildAttendanceActionChip(
                  groupId: groupId,
                  targetUid: row.uid,
                  status: 'present',
                  label: '출석',
                  selected: row.attendanceStatus == 'present',
                ),
                _buildAttendanceActionChip(
                  groupId: groupId,
                  targetUid: row.uid,
                  status: 'late',
                  label: '지각',
                  selected: row.attendanceStatus == 'late',
                ),
                _buildAttendanceActionChip(
                  groupId: groupId,
                  targetUid: row.uid,
                  status: 'absent',
                  label: '결석',
                  selected: row.attendanceStatus == 'absent',
                ),
              ],
            ),
          ),
        ],
        if (row.checkedAt != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 42),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  row.checkedAt!,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (!isLast)
          Divider(
            height: 1,
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
      ],
    );
  }

  Future<void> _submitComment({
    required DocumentReference<Map<String, dynamic>> eventRef,
    required String uid,
    required String displayName,
  }) async {
    final message = _commentController.text.trim();
    if (message.isEmpty || _savingComment) return;

    setState(() => _savingComment = true);
    try {
      await eventRef.collection('comments').add({
        'uid': uid,
        'displayName': displayName,
        'message': message,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      _commentController.clear();
      AppSnackbar.show(
        context,
        message: '댓글을 등록했습니다.',
        type: AppSnackType.success,
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: friendlyError(e),
        type: AppSnackType.error,
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '댓글 등록 중 오류가 발생했습니다.',
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) {
        setState(() => _savingComment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groupId = ref.watch(selectedGroupIdProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (groupId == null || user == null) {
      return const Scaffold(body: Center(child: Text(AppStrings.selectGroupFirst)));
    }

    final eventRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .doc(widget.eventId);
    final myMemberRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(user.uid);
    final myResponseRef = eventRef.collection('responses').doc(user.uid);
    final colorScheme = Theme.of(context).colorScheme;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: myMemberRef.snapshots(),
      builder: (context, myMember) {
        final permission = PermissionService.fromMemberData(
          myMember.data?.data(),
        );
        final myMemberData = myMember.data?.data() ?? const <String, dynamic>{};
        final myDisplayName = _fallbackDisplayNameOfMemberDoc(
          myMemberData,
          user.uid,
        );
        final canViewAttendance =
            permission.canManageMembers() || permission.canManageEvents();
        final canManageAttendance = permission.canManageEvents();

        return Scaffold(
          appBar: AppBar(title: const Text('일정 상세')),
          body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: eventRef.snapshots(),
            builder: (context, eventSnap) {
              if (eventSnap.hasError) {
                return Center(child: Text(friendlyError(eventSnap.error)));
              }
              if (!eventSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = eventSnap.data!.data();
              if (data == null || data['isDeleted'] == true) {
                return const Center(child: Text('삭제되었거나 없는 일정입니다.'));
              }

              final title = data['title']?.toString() ?? '(제목 없음)';
              final ts = data['startAt'];
              final startAtDateTime = ts is Timestamp ? ts.toDate() : null;
              final dateText = ts is Timestamp
                  ? formatDateTime(ts.toDate())
                  : '-';
              final isPast =
                  ts is Timestamp && ts.toDate().isBefore(DateTime.now());
              final isResponseClosed = isEventResponseClosed(data);
              final primaryPlace = eventPrimaryPlace(data);
              final address = data['address']?.toString();
              final description = data['description']?.toString() ?? '';
              final mapQuery = eventMapQuery(data);

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // -- 일정 정보 카드 --
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            DateBadge(text: dateText, past: isPast),
                            if (isPast) ...[
                              const SizedBox(width: 8),
                              const StatusBadge(
                                label: '지난 일정',
                                tone: StatusBadgeTone.primary,
                              ),
                            ],
                            if (!isPast && isResponseClosed) ...[
                              const SizedBox(width: 8),
                              const StatusBadge(
                                label: '응답 마감',
                                tone: StatusBadgeTone.warning,
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            description,
                            maxLines: _descriptionExpanded ? null : 4,
                            overflow: _descriptionExpanded
                                ? null
                                : TextOverflow.ellipsis,
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(height: 1.45),
                          ),
                          if (description.length > 100) ...[
                            const SizedBox(height: 4),
                            Semantics(
                              label: _descriptionExpanded ? '설명 접기' : '설명 더 보기',
                              button: true,
                              child: InkWell(
                              onTap: () => setState(
                                () => _descriptionExpanded =
                                    !_descriptionExpanded,
                              ),
                              child: Text(
                                _descriptionExpanded ? '접기' : '더 보기',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 12),
                        _buildInfoRow(Icons.place_outlined, primaryPlace),
                        if (address != null &&
                            address.isNotEmpty &&
                            address != primaryPlace) ...[
                          const SizedBox(height: 6),
                          _buildInfoRow(Icons.pin_drop_outlined, address),
                        ],
                        if (mapQuery != null) ...[
                          const SizedBox(height: 12),
                          Semantics(
                            label: '지도에서 보기',
                            hint: '탭하여 지도 앱 열기',
                            button: true,
                            child: InkWell(
                            borderRadius: BorderRadius.circular(6),
                            onTap: () =>
                                MapLauncherService.openNaverMapSearch(mapQuery),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.06,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ExcludeSemantics(
                                    child: Icon(
                                    Icons.map_outlined,
                                    size: 16,
                                    color: colorScheme.primary,
                                  ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '지도에서 보기',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          ),
                        ],
                        if (startAtDateTime != null) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Semantics(
                                label: '구글 캘린더에 일정 추가',
                                hint: '탭하여 구글 캘린더 열기',
                                button: true,
                                child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => _openGoogleCalendar(
                                  title: title,
                                  startAt: startAtDateTime,
                                  description: description,
                                  location: primaryPlace,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.06,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ExcludeSemantics(
                                        child: Icon(
                                        Icons.calendar_today_outlined,
                                        size: 16,
                                        color: colorScheme.primary,
                                      ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '구글 캘린더',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ),
                              Semantics(
                                label: '기기 캘린더에 일정 추가',
                                hint: '탭하여 기기 캘린더 열기',
                                button: true,
                                child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => _openIcsCalendar(
                                  title: title,
                                  startAt: startAtDateTime,
                                  description: description,
                                  location: primaryPlace,
                                  eventId: widget.eventId,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colorScheme.primary.withValues(
                                      alpha: 0.06,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ExcludeSemantics(
                                        child: Icon(
                                        Icons.event_available_outlined,
                                        size: 16,
                                        color: colorScheme.primary,
                                      ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '기기 캘린더',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: colorScheme.primary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // -- 나의 응답 카드 --
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                              Icons.how_to_vote_outlined,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '나의 응답',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                          stream: myResponseRef.snapshots(),
                          builder: (context, r) {
                            final selected =
                                r.data?.data()?['response'] as String? ??
                                'maybe';
                            return Row(
                              children: [
                                Expanded(
                                  child: ResponseButton(
                                    label: '미정',
                                    selected: selected == 'maybe',
                                    onPressed: (isPast || isResponseClosed)
                                        ? null
                                        : () => writeResponse(
                                            groupId: groupId,
                                            eventId: widget.eventId,
                                            uid: user.uid,
                                            response: 'maybe',
                                            context: context,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ResponseButton(
                                    label: '참석',
                                    selected: selected == 'going',
                                    onPressed: (isPast || isResponseClosed)
                                        ? null
                                        : () => writeResponse(
                                            groupId: groupId,
                                            eventId: widget.eventId,
                                            uid: user.uid,
                                            response: 'going',
                                            context: context,
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ResponseButton(
                                    label: '불참',
                                    selected: selected == 'notGoing',
                                    onPressed: (isPast || isResponseClosed)
                                        ? null
                                        : () => writeResponse(
                                            groupId: groupId,
                                            eventId: widget.eventId,
                                            uid: user.uid,
                                            response: 'notGoing',
                                            context: context,
                                          ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        if (isPast || isResponseClosed) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.warning.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const ExcludeSemantics(
                                  child: Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: AppTheme.warning,
                                ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isPast
                                        ? '지난 일정입니다. 응답 변경 시 통계 반영에 제한이 있을 수 있습니다.'
                                        : '응답이 마감된 일정입니다.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(color: AppTheme.warning),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // -- 일정 댓글/메모 --
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            ExcludeSemantics(
                              child: Icon(
                              Icons.chat_bubble_outline,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '일정 댓글/메모',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: eventRef
                              .collection('comments')
                              .orderBy('createdAt', descending: true)
                              .limit(50)
                              .snapshots(),
                          builder: (context, commentSnap) {
                            if (commentSnap.hasError) {
                              return Text(friendlyError(commentSnap.error));
                            }
                            if (!commentSnap.hasData) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }

                            final commentDocs = commentSnap.data!.docs;
                            return Column(
                              children: [
                                if (commentDocs.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text('아직 댓글이 없습니다.'),
                                    ),
                                  ),
                                for (
                                  var index = 0;
                                  index < commentDocs.length;
                                  index++
                                ) ...[
                                  _EventCommentTile(
                                    commentDoc: commentDocs[index],
                                    currentUid: user.uid,
                                    currentDisplayName: myDisplayName,
                                  ),
                                  if (index != commentDocs.length - 1)
                                    Divider(
                                      height: 14,
                                      color: colorScheme.outlineVariant
                                          .withValues(alpha: 0.45),
                                    ),
                                ],
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                enabled: !(isPast || isResponseClosed),
                                maxLength: 500,
                                minLines: 1,
                                maxLines: 3,
                                textInputAction: TextInputAction.newline,
                                decoration: const InputDecoration(
                                  labelText: '댓글 입력',
                                  hintText: '예: 주차 가능합니다, 장소 변경 가능성 있습니다.',
                                  counterText: '',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Semantics(
                              label: '댓글 전송',
                              button: true,
                              child: InkWell(
                              borderRadius: BorderRadius.circular(6),
                              onTap:
                                  (_savingComment || isPast || isResponseClosed)
                                  ? null
                                  : () => _submitComment(
                                      eventRef: eventRef,
                                      uid: user.uid,
                                      displayName: myDisplayName,
                                    ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: (isPast || isResponseClosed)
                                      ? colorScheme.surfaceContainerHighest
                                            .withValues(alpha: 0.6)
                                      : colorScheme.primary.withValues(
                                          alpha: 0.08,
                                        ),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: (isPast || isResponseClosed)
                                        ? colorScheme.outlineVariant
                                        : colorScheme.primary.withValues(
                                            alpha: 0.2,
                                          ),
                                  ),
                                ),
                                child: _savingComment
                                    ? SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.primary,
                                        ),
                                      )
                                    : Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          ExcludeSemantics(
                                            child: Icon(
                                            Icons.send_rounded,
                                            size: 14,
                                            color: (isPast || isResponseClosed)
                                                ? colorScheme.onSurfaceVariant
                                                : colorScheme.primary,
                                          ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '전송',
                                            style: Theme.of(context)
                                                .textTheme
                                                .labelMedium
                                                ?.copyWith(
                                                  color:
                                                      (isPast ||
                                                          isResponseClosed)
                                                      ? colorScheme
                                                            .onSurfaceVariant
                                                      : colorScheme.primary,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // -- 참여/출석 현황 --
                  if (canViewAttendance) ...[
                    AppCard(
                      child: Semantics(
                        label: '참여/출석 현황',
                        hint: _showAttendance ? '탭하여 접기' : '탭하여 펼치기',
                        button: true,
                        child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () =>
                            setState(() => _showAttendance = !_showAttendance),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: colorScheme.primary.withValues(
                                  alpha: 0.08,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: ExcludeSemantics(
                                child: Icon(
                                Icons.assignment_turned_in_outlined,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '참여/출석 현황',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    canManageAttendance
                                        ? '응답 현황 조회 및 출석 체크'
                                        : '참석/미정/불참 응답 확인',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            ExcludeSemantics(
                              child: Icon(
                              _showAttendance
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 20,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            ),
                          ],
                        ),
                      ),
                      ),
                    ),
                    if (_showAttendance)
                      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('groups')
                            .doc(groupId)
                            .collection('members')
                            .where('status', isEqualTo: 'active')
                            .snapshots(),
                        builder: (context, membersSnap) {
                          if (membersSnap.hasError) {
                            return AppCard(
                              child: Text(friendlyError(membersSnap.error)),
                            );
                          }
                          if (!membersSnap.hasData) {
                            return const AppCard(
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            );
                          }

                          return StreamBuilder<
                            QuerySnapshot<Map<String, dynamic>>
                          >(
                            stream: eventRef
                                .collection('responses')
                                .snapshots(),
                            builder: (context, responsesSnap) {
                              if (responsesSnap.hasError) {
                                return AppCard(
                                  child: Text(
                                    friendlyError(responsesSnap.error),
                                  ),
                                );
                              }
                              if (!responsesSnap.hasData) {
                                return const AppCard(
                                  child: Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return StreamBuilder<
                                QuerySnapshot<Map<String, dynamic>>
                              >(
                                stream: eventRef
                                    .collection('attendances')
                                    .snapshots(),
                                builder: (context, attendanceSnap) {
                                  if (attendanceSnap.hasError) {
                                    return AppCard(
                                      child: Text(
                                        friendlyError(attendanceSnap.error),
                                      ),
                                    );
                                  }
                                  if (!attendanceSnap.hasData) {
                                    return const AppCard(
                                      child: Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(16),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                    );
                                  }

                                  final members = membersSnap.data!.docs;
                                  final hasMissingMemberName = members.any(
                                    (member) => !_memberNameCache.containsKey(
                                      member.id,
                                    ),
                                  );
                                  if (hasMissingMemberName) {
                                    _loadMemberDisplayNames(members).then((_) {
                                      if (mounted) {
                                        setState(() {});
                                      }
                                    });
                                  }
                                  final responseByUid =
                                      <String, Map<String, dynamic>>{
                                        for (final r
                                            in responsesSnap.data!.docs)
                                          r.id: r.data(),
                                      };
                                  final attendanceByUid =
                                      <String, Map<String, dynamic>>{
                                        for (final a
                                            in attendanceSnap.data!.docs)
                                          a.id: a.data(),
                                      };

                                  var going = 0;
                                  var maybe = 0;
                                  var notGoing = 0;
                                  var noResponse = 0;
                                  var present = 0;
                                  var late = 0;
                                  var absent = 0;
                                  var notChecked = 0;

                                  final rows = <_AttendanceRowData>[];
                                  for (final m in members) {
                                    final uid = m.id;
                                    final memberData = m.data();
                                    final memberLabel =
                                        _memberNameCache[uid] ??
                                        _fallbackDisplayNameOfMemberDoc(
                                          memberData,
                                          uid,
                                        );

                                    final responseData = responseByUid[uid];
                                    final response = responseData?['response']
                                        ?.toString();
                                    final respondedAt =
                                        responseData?['respondedAt'];
                                    final responseLabel = switch (response) {
                                      'going' => '참석',
                                      'maybe' => '미정',
                                      'notGoing' => '불참',
                                      _ => '미응답',
                                    };

                                    switch (response) {
                                      case 'going':
                                        going++;
                                        break;
                                      case 'maybe':
                                        maybe++;
                                        break;
                                      case 'notGoing':
                                        notGoing++;
                                        break;
                                      default:
                                        noResponse++;
                                        break;
                                    }

                                    final attendanceData = attendanceByUid[uid];
                                    final attendanceStatus =
                                        attendanceData?['status']?.toString();
                                    final checkedAt =
                                        attendanceData?['checkedAt'];

                                    switch (attendanceStatus) {
                                      case 'present':
                                        present++;
                                        break;
                                      case 'late':
                                        late++;
                                        break;
                                      case 'absent':
                                        absent++;
                                        break;
                                      default:
                                        notChecked++;
                                        break;
                                    }

                                    rows.add(
                                      _AttendanceRowData(
                                        uid: uid,
                                        memberLabel: memberLabel,
                                        responseCode: response,
                                        responseLabel: responseLabel,
                                        respondedAt: respondedAt is Timestamp
                                            ? formatDate(respondedAt.toDate())
                                            : null,
                                        attendanceStatus: attendanceStatus,
                                        checkedAt: checkedAt is Timestamp
                                            ? formatDate(checkedAt.toDate())
                                            : null,
                                      ),
                                    );
                                  }

                                  final displayedRows = _showGoingResponsesOnly
                                      ? rows
                                            .where(
                                              (row) =>
                                                  row.responseCode == 'going',
                                            )
                                            .toList()
                                      : rows;

                                  return AppCard(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // 응답 현황 요약
                                        _buildSummaryRow(
                                          title: _showGoingResponsesOnly
                                              ? '응답 현황 (참석만)'
                                              : '응답 현황',
                                          icon: Icons.question_answer_outlined,
                                          badges: _showGoingResponsesOnly
                                              ? [
                                                  StatusBadge(
                                                    label: '참석 $going',
                                                    tone:
                                                        StatusBadgeTone.success,
                                                  ),
                                                ]
                                              : [
                                                  StatusBadge(
                                                    label: '참석 $going',
                                                    tone:
                                                        StatusBadgeTone.success,
                                                  ),
                                                  StatusBadge(
                                                    label: '미정 $maybe',
                                                    tone:
                                                        StatusBadgeTone.warning,
                                                  ),
                                                  StatusBadge(
                                                    label: '불참 $notGoing',
                                                    tone:
                                                        StatusBadgeTone.danger,
                                                  ),
                                                  StatusBadge(
                                                    label: '미응답 $noResponse',
                                                    tone:
                                                        StatusBadgeTone.primary,
                                                  ),
                                                ],
                                        ),
                                        const SizedBox(height: 14),
                                        // 출석 체크 요약
                                        _buildSummaryRow(
                                          title: '출석 체크',
                                          icon: Icons.fact_check_outlined,
                                          badges: [
                                            StatusBadge(
                                              label: '출석 $present',
                                              tone: StatusBadgeTone.success,
                                            ),
                                            StatusBadge(
                                              label: '지각 $late',
                                              tone: StatusBadgeTone.warning,
                                            ),
                                            StatusBadge(
                                              label: '결석 $absent',
                                              tone: StatusBadgeTone.danger,
                                            ),
                                            StatusBadge(
                                              label: '미체크 $notChecked',
                                              tone: StatusBadgeTone.primary,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 14),
                                        const Divider(height: 1),
                                        const SizedBox(height: 10),
                                        // 필터 토글
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                '참석 응답 인원만 보기',
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium,
                                              ),
                                            ),
                                            SizedBox(
                                              height: 28,
                                              child: Switch.adaptive(
                                                value: _showGoingResponsesOnly,
                                                onChanged: (value) {
                                                  setState(
                                                    () =>
                                                        _showGoingResponsesOnly =
                                                            value,
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        // 멤버 수 표시
                                        Text(
                                          '총 ${displayedRows.length}명',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: colorScheme
                                                    .onSurfaceVariant,
                                              ),
                                        ),
                                        if (displayedRows.isEmpty)
                                          Padding(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 20,
                                            ),
                                            child: Center(
                                              child: Text(
                                                '표시할 인원이 없습니다.',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.copyWith(
                                                      color: colorScheme
                                                          .onSurfaceVariant,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        for (
                                          var i = 0;
                                          i < displayedRows.length;
                                          i++
                                        )
                                          _buildMemberRow(
                                            groupId: groupId,
                                            row: displayedRows[i],
                                            canManageAttendance:
                                                canManageAttendance,
                                            isLast:
                                                i == displayedRows.length - 1,
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _AttendanceRowData {
  const _AttendanceRowData({
    required this.uid,
    required this.memberLabel,
    required this.responseCode,
    required this.responseLabel,
    required this.respondedAt,
    required this.attendanceStatus,
    required this.checkedAt,
  });

  final String uid;
  final String memberLabel;
  final String? responseCode;
  final String responseLabel;
  final String? respondedAt;
  final String? attendanceStatus;
  final String? checkedAt;
}

class _EventCommentTile extends StatelessWidget {
  const _EventCommentTile({
    required this.commentDoc,
    this.currentUid,
    this.currentDisplayName,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> commentDoc;
  final String? currentUid;
  final String? currentDisplayName;

  Future<void> _handleReactionToggle(
    BuildContext context,
    String emoji,
    String? myEmoji,
  ) async {
    final uid = currentUid;
    if (uid == null || uid.isEmpty) return;
    final myReactionRef = commentDoc.reference.collection('reactions').doc(uid);
    try {
      if (myEmoji == emoji) {
        await myReactionRef.delete();
      } else {
        await myReactionRef.set({
          'uid': uid,
          'emoji': emoji,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } on FirebaseException catch (e) {
      if (!context.mounted) return;
      AppSnackbar.show(
        context,
        message: friendlyError(e),
        type: AppSnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = commentDoc.data();
    final storedDisplayName = data['displayName']?.toString().trim();
    final message = data['message']?.toString().trim() ?? '';
    final createdAtRaw = data['createdAt'];
    final createdAt = createdAtRaw is Timestamp ? createdAtRaw.toDate() : null;
    final commentUid = data['uid']?.toString();

    // 현재 사용자의 댓글이면 최신 displayName 우선 사용
    final label =
        (currentUid != null &&
            commentUid == currentUid &&
            currentDisplayName != null &&
            currentDisplayName!.isNotEmpty)
        ? currentDisplayName!
        : (storedDisplayName != null && storedDisplayName.isNotEmpty)
        ? storedDisplayName
        : (commentUid ?? '멤버');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (createdAt != null)
                Text(
                  formatDate(createdAt),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            message.isEmpty ? '-' : message,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: commentDoc.reference.collection('reactions').snapshots(),
            builder: (context, reactionSnap) {
              if (reactionSnap.hasError) {
                return Text(
                  friendlyError(reactionSnap.error),
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
              final reactionCounts = <String, int>{};
              String? myEmoji;
              if (reactionSnap.hasData) {
                for (final doc in reactionSnap.data!.docs) {
                  final emoji = doc.data()['emoji']?.toString();
                  if (emoji == null || emoji.isEmpty) continue;
                  reactionCounts[emoji] = (reactionCounts[emoji] ?? 0) + 1;
                  if (doc.id == currentUid) {
                    myEmoji = emoji;
                  }
                }
              }
              return EmojiReactionBar(
                reactionCounts: reactionCounts,
                myEmoji: myEmoji,
                onToggle: (currentUid == null || currentUid!.isEmpty)
                    ? null
                    : (emoji) => _handleReactionToggle(context, emoji, myEmoji),
              );
            },
          ),
        ],
      ),
    );
  }
}
