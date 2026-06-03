import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/app_config.dart';
import '../../config/app_strings.dart';
import '../../config/firebase_config.dart';
import '../../dev/firestore_metrics.dart';
import '../../providers.dart';
import '../../services/functions_caller.dart';
import '../../services/map_launcher_service.dart';
import '../../services/permission_service.dart';
import '../../services/user_error_message.dart';
import '../../theme/app_theme.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_skeleton.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/animated_list_entry.dart';
import '../../widgets/date_badge.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/response_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/status_badge.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  Future<void> _deleteEvent({
    required String groupId,
    required String eventId,
    required String title,
  }) async {
    if (!AppConfig.enableServerDependentFeatures) {
      AppSnackbar.show(
        context,
        message: '현재 요금제에서는 일정 삭제 기능이 비활성화되어 있습니다.',
        type: AppSnackType.info,
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('"$title" 일정을 삭제할까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await FunctionsCaller.callWithRetry(
        () => FirebaseFunctions.instanceFor(
          region: FirebaseConfig.functionsRegion,
        ).httpsCallable('deleteEvent').call(<String, dynamic>{
          'groupId': groupId,
          'eventId': eventId,
        }),
      );
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '일정이 삭제되었습니다.',
        type: AppSnackType.success,
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      final message = switch (e.code) {
        'permission-denied' => '운영진 또는 작성자만 삭제할 수 있습니다.',
        'not-found' => '이미 삭제되었거나 존재하지 않는 일정입니다.',
        'internal' => '일정 삭제 중 오류가 발생했습니다. 잠시 후 다시 시도해 주세요.',
        _ => '일정 삭제 실패: ${e.code}',
      };
      AppSnackbar.show(context, message: message, type: AppSnackType.error);
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '일정 삭제 중 오류가 발생했습니다.',
        type: AppSnackType.error,
      );
    }
  }

  Future<void> _refresh(String groupId) async {
    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .limit(1)
        .get();
  }

  Future<int> _resolveMonthlyEventLimit(String groupId) async {
    final groupDoc = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .get();
    final data = groupDoc.data();
    final limits = data?['limits'];
    if (limits is Map<String, dynamic>) {
      final rawLimit = limits['eventCreateMonthlyMax'];
      if (rawLimit is int && rawLimit > 0) {
        return rawLimit;
      }
    }
    return 20;
  }

  Future<int> _countEventsInMonth(String groupId, DateTime target) async {
    final monthStart = DateTime(target.year, target.month, 1);
    final nextMonth = DateTime(target.year, target.month + 1, 1);
    final snap = await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .where(
          'startAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
        )
        .where('startAt', isLessThan: Timestamp.fromDate(nextMonth))
        .get();
    return snap.docs.where((doc) => doc.data()['isDeleted'] != true).length;
  }

  DateTime _nextRecurringStartAt(
    DateTime startAt,
    _EventRecurrenceOption recurrence,
  ) {
    switch (recurrence) {
      case _EventRecurrenceOption.none:
        return startAt;
      case _EventRecurrenceOption.weekly:
        return startAt.add(const Duration(days: 7));
      case _EventRecurrenceOption.biweekly:
        return startAt.add(const Duration(days: 14));
      case _EventRecurrenceOption.monthly:
        final base = startAt.toUtc();
        final targetYear = base.month == 12 ? base.year + 1 : base.year;
        final targetMonth = base.month == 12 ? 1 : base.month + 1;
        final lastDay = DateTime.utc(targetYear, targetMonth + 1, 0).day;
        final day = base.day <= lastDay ? base.day : lastDay;
        return DateTime.utc(
          targetYear,
          targetMonth,
          day,
          base.hour,
          base.minute,
          base.second,
          base.millisecond,
          base.microsecond,
        ).toLocal();
    }
  }

  Future<bool> _createEvent({
    required String groupId,
    required String uid,
    required String title,
    required String description,
    required DateTime startAt,
    required String locationName,
    required String address,
    required _EventRecurrenceOption recurrence,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      AppSnackbar.show(
        context,
        message: '일정 제목을 입력해 주세요.',
        type: AppSnackType.error,
      );
      return false;
    }

    try {
      final monthlyLimit = await _resolveMonthlyEventLimit(groupId);
      final createdCount = await _countEventsInMonth(groupId, startAt);
      if (createdCount >= monthlyLimit) {
        if (!mounted) return false;
        AppSnackbar.show(
          context,
          message: '이번 달 일정 생성 한도($monthlyLimit건)를 초과했습니다.',
          type: AppSnackType.error,
        );
        return false;
      }

      final eventRef = FirebaseFirestore.instance
          .collection('groups')
          .doc(groupId)
          .collection('events')
          .doc();

      final payload = <String, dynamic>{
        'title': trimmedTitle,
        'startAt': Timestamp.fromDate(startAt),
        'status': 'open',
        'isDeleted': false,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': uid,
        'autoGenerated': false,
      };
      final trimmedDescription = description.trim();
      if (trimmedDescription.isNotEmpty) {
        payload['description'] = trimmedDescription;
      }
      final trimmedLocation = locationName.trim();
      final trimmedAddress = address.trim();
      if (trimmedLocation.isNotEmpty) {
        payload['locationName'] = trimmedLocation;
        payload['location'] = trimmedLocation;
      }
      if (trimmedAddress.isNotEmpty) {
        payload['address'] = trimmedAddress;
      }
      if (AppConfig.enableBlazeAutomationFeatures &&
          recurrence != _EventRecurrenceOption.none) {
        payload['recurrenceEnabled'] = true;
        payload['recurrenceRule'] = recurrence.code;
        payload['recurrenceRootEventId'] = eventRef.id;
        payload['recurrenceGeneratedCount'] = 0;
        payload['recurrenceNextStartAt'] = Timestamp.fromDate(
          _nextRecurringStartAt(startAt, recurrence),
        );
      } else {
        payload['recurrenceEnabled'] = false;
      }

      await eventRef.set(payload);
      FirestoreMetrics.instance.addWrites();
      if (mounted) {
        AppSnackbar.show(
          context,
          message: '일정을 추가했습니다.',
          type: AppSnackType.success,
        );
      }
      return true;
    } on FirebaseException catch (e) {
      if (mounted) {
        AppSnackbar.show(
          context,
          message: toUserMessage(e),
          type: AppSnackType.error,
        );
      }
      return false;
    }
  }

  Future<void> _openCreateEventDialog({
    required String groupId,
    required String uid,
  }) async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationNameController = TextEditingController();
    final addressController = TextEditingController();
    var selectedAt = DateTime.now().add(const Duration(hours: 1));
    var recurrence = _EventRecurrenceOption.none;
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            sheetContext,
                          ).colorScheme.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '일정 추가',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: titleController,
                      maxLength: 80,
                      decoration: const InputDecoration(labelText: '제목'),
                    ),
                    TextField(
                      controller: descriptionController,
                      maxLength: 2000,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: '설명 (선택)',
                        hintText: '준비물, 참고사항, 주의사항 등을 작성해 주세요.',
                      ),
                    ),
                    TextField(
                      controller: locationNameController,
                      maxLength: 80,
                      decoration: const InputDecoration(labelText: '장소명 (선택)'),
                    ),
                    TextField(
                      controller: addressController,
                      maxLength: 120,
                      decoration: const InputDecoration(labelText: '주소 (선택)'),
                    ),
                    const SizedBox(height: 8),
                    Text('일시: ${formatDate(selectedAt)}'),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final pickedDate = await showDatePicker(
                              context: sheetContext,
                              initialDate: selectedAt,
                              firstDate: DateTime.now().subtract(
                                const Duration(days: 1),
                              ),
                              lastDate: DateTime.now().add(
                                const Duration(days: 3650),
                              ),
                            );
                            if (pickedDate == null) return;
                            setSheetState(() {
                              selectedAt = DateTime(
                                pickedDate.year,
                                pickedDate.month,
                                pickedDate.day,
                                selectedAt.hour,
                                selectedAt.minute,
                              );
                            });
                          },
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: const Text('날짜'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final pickedTime = await showTimePicker(
                              context: sheetContext,
                              initialTime: TimeOfDay.fromDateTime(selectedAt),
                            );
                            if (pickedTime == null) return;
                            setSheetState(() {
                              selectedAt = DateTime(
                                selectedAt.year,
                                selectedAt.month,
                                selectedAt.day,
                                pickedTime.hour,
                                pickedTime.minute,
                              );
                            });
                          },
                          icon: const Icon(Icons.access_time, size: 16),
                          label: const Text('시간'),
                        ),
                      ],
                    ),
                    if (AppConfig.enableBlazeAutomationFeatures) ...[
                      const SizedBox(height: 10),
                      Text(
                        '반복 일정',
                        style: Theme.of(sheetContext).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _EventRecurrenceOption.values.map((option) {
                          final selected = recurrence == option;
                          return ChoiceChip(
                            label: Text(option.label),
                            selected: selected,
                            onSelected: saving
                                ? null
                                : (_) =>
                                      setSheetState(() => recurrence = option),
                          );
                        }).toList(),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: saving
                                ? null
                                : () => Navigator.of(sheetContext).pop(),
                            child: const Text('취소'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: saving
                                ? null
                                : () async {
                                    setSheetState(() => saving = true);
                                    final created = await _createEvent(
                                      groupId: groupId,
                                      uid: uid,
                                      title: titleController.text,
                                      description: descriptionController.text,
                                      startAt: selectedAt,
                                      locationName: locationNameController.text,
                                      address: addressController.text,
                                      recurrence: recurrence,
                                    );
                                    if (created && sheetContext.mounted) {
                                      Navigator.of(sheetContext).pop();
                                    } else {
                                      setSheetState(() => saving = false);
                                    }
                                  },
                            child: Text(saving ? '저장 중...' : '저장'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    descriptionController.dispose();
    locationNameController.dispose();
    addressController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final groupId = ref.watch(selectedGroupIdProvider);
    final user = FirebaseAuth.instance.currentUser;
    if (groupId == null || user == null)
      return const Center(child: Text(AppStrings.selectGroupFirst));

    final memberStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(user.uid)
        .snapshots();

    final eventsStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .orderBy('startAt')
        .snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: memberStream,
      builder: (context, memberSnap) {
        final permission = PermissionService.fromMemberData(
          memberSnap.data?.data(),
        );
        final canCreateEvents =
            permission.canManageEvents() || permission.canManageMembers();
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: eventsStream,
          builder: (context, s) {
            if (s.hasError)
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(friendlyError(s.error)),
                ),
              );
            if (!s.hasData) {
              return ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  AppSkeleton(height: 24, width: 140),
                  SizedBox(height: 12),
                  AppSkeleton(height: 108),
                  SizedBox(height: 8),
                  AppSkeleton(height: 108),
                ],
              );
            }

            final now = DateTime.now();
            final allEvents = s.data!.docs
                .where((d) => d.data()['isDeleted'] != true)
                .toList();
            final upcomingEvents =
                allEvents.where((d) {
                  final ts = d.data()['startAt'];
                  return ts is Timestamp && !ts.toDate().isBefore(now);
                }).toList()..sort((a, b) {
                  final at =
                      (a.data()['startAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final bt =
                      (b.data()['startAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return at.compareTo(bt);
                });
            final pastEvents =
                allEvents.where((d) {
                  final ts = d.data()['startAt'];
                  return ts is Timestamp && ts.toDate().isBefore(now);
                }).toList()..sort((a, b) {
                  final at =
                      (a.data()['startAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  final bt =
                      (b.data()['startAt'] as Timestamp?)?.toDate() ??
                      DateTime.fromMillisecondsSinceEpoch(0);
                  return bt.compareTo(at);
                });
            final events = <QueryDocumentSnapshot<Map<String, dynamic>>>[
              ...upcomingEvents,
              ...pastEvents,
            ];
            if (events.isEmpty) {
              return EmptyState(
                icon: Icons.event_busy_outlined,
                title: "일정이 없어요",
                description: "등록된 일정이 없습니다.",
                actionLabel: canCreateEvents ? "일정 추가" : "새로고침",
                onAction: () => canCreateEvents
                    ? _openCreateEventDialog(groupId: groupId, uid: user.uid)
                    : _refresh(groupId),
              );
            }

            // 날짜별 그룹핑을 위한 아이템 목록 생성
            final items = <_EventListItem>[];
            items.add(const _EventListItem(type: _EventListItemType.header));
            String? lastDateKey;
            for (final eventDoc in events) {
              final ts = eventDoc.data()['startAt'];
              final date = ts is Timestamp ? ts.toDate() : null;
              final dateKey = date != null
                  ? '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}'
                  : '날짜 미정';
              if (dateKey != lastDateKey) {
                final weekday = date != null
                    ? ['월', '화', '수', '목', '금', '토', '일'][date.weekday - 1]
                    : '';
                final label = date != null ? '$dateKey ($weekday)' : dateKey;
                items.add(
                  _EventListItem(
                    type: _EventListItemType.dateHeader,
                    dateLabel: label,
                  ),
                );
                lastDateKey = dateKey;
              }
              items.add(
                _EventListItem(
                  type: _EventListItemType.event,
                  eventDoc: eventDoc,
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () => _refresh(groupId),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final item = items[i];
                  if (item.type == _EventListItemType.header) {
                    return SectionHeader(
                      title: "전체 일정",
                      icon: Icons.event_available_outlined,
                      actionLabel: canCreateEvents ? "일정 추가" : null,
                      onActionTap: canCreateEvents
                          ? () => _openCreateEventDialog(
                              groupId: groupId,
                              uid: user.uid,
                            )
                          : null,
                    );
                  }
                  if (item.type == _EventListItemType.dateHeader) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 4),
                      child: Text(
                        item.dateLabel!,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    );
                  }
                  final eventDoc = item.eventDoc!;
                  final eventId = eventDoc.id;
                  final title =
                      eventDoc.data()["title"] as String? ?? "(제목 없음)";
                  final ts = eventDoc.data()['startAt'];
                  final dateText = ts is Timestamp
                      ? formatDate(ts.toDate())
                      : '-';
                  final createdBy = eventDoc.data()['createdBy']?.toString();
                  final canDeleteEvent =
                      AppConfig.enableServerDependentFeatures &&
                      (permission.canManageMembers() ||
                          permission.canManageEvents() ||
                          createdBy == user.uid);
                  final isPast = ts is Timestamp && ts.toDate().isBefore(now);
                  final isResponseClosed = isEventResponseClosed(
                    eventDoc.data(),
                  );
                  final primaryPlace = eventPrimaryPlace(eventDoc.data());
                  final address = eventDoc.data()['address']?.toString();
                  final mapQuery = eventMapQuery(eventDoc.data());
                  final isRecurring =
                      eventDoc.data()['recurrenceEnabled'] == true ||
                      (eventDoc.data()['recurrenceRootEventId'] != null &&
                          eventDoc.data()['autoGenerated'] == true);

                  return AnimatedListEntry(
                    index: i,
                    child: AppCard(
                      borderColor: isPast ? AppTheme.warning : null,
                      child: Semantics(
                        label: '$title ($dateText)',
                        hint: '탭하여 일정 상세 보기',
                        button: true,
                        child: InkWell(
                        onTap: () => context.push('/event/$eventId'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                DateBadge(text: dateText, past: isPast),
                                const Spacer(),
                                if (canDeleteEvent)
                                  PopupMenuButton<String>(
                                    tooltip: '일정 관리',
                                    onSelected: (value) {
                                      if (value == 'delete') {
                                        _deleteEvent(
                                          groupId: groupId,
                                          eventId: eventId,
                                          title: title,
                                        );
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('삭제'),
                                      ),
                                    ],
                                  ),
                                if (isPast)
                                  const StatusBadge(
                                    label: "지난 일정",
                                    tone: StatusBadgeTone.warning,
                                  ),
                                if (!isPast && isResponseClosed) ...[
                                  const SizedBox(width: 6),
                                  const StatusBadge(
                                    label: "응답 마감",
                                    tone: StatusBadgeTone.primary,
                                  ),
                                ],
                                if (isRecurring) ...[
                                  const SizedBox(width: 6),
                                  const StatusBadge(
                                    label: "반복",
                                    tone: StatusBadgeTone.success,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    primaryPlace,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (mapQuery != null)
                                  GestureDetector(
                                    onTap: () =>
                                        MapLauncherService.openNaverMapSearch(
                                          mapQuery,
                                        ),
                                    child: Icon(
                                      Icons.map_outlined,
                                      size: 16,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                              ],
                            ),
                            if (address != null &&
                                address.isNotEmpty &&
                                address != primaryPlace) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.markunread_mailbox_outlined,
                                    size: 16,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      address,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            Divider(
                              height: 20,
                              color: Theme.of(
                                context,
                              ).colorScheme.outlineVariant,
                            ),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ResponseButton(
                                  label: "미정",
                                  selected: false,
                                  onPressed: (isPast || isResponseClosed)
                                      ? null
                                      : () => writeResponse(
                                          groupId: groupId,
                                          eventId: eventId,
                                          uid: user.uid,
                                          response: 'maybe',
                                          context: context,
                                        ),
                                ),
                                ResponseButton(
                                  label: "참석",
                                  selected: false,
                                  onPressed: (isPast || isResponseClosed)
                                      ? null
                                      : () => writeResponse(
                                          groupId: groupId,
                                          eventId: eventId,
                                          uid: user.uid,
                                          response: 'going',
                                          context: context,
                                        ),
                                ),
                                ResponseButton(
                                  label: "불참",
                                  selected: false,
                                  onPressed: (isPast || isResponseClosed)
                                      ? null
                                      : () => writeResponse(
                                          groupId: groupId,
                                          eventId: eventId,
                                          uid: user.uid,
                                          response: 'notGoing',
                                          context: context,
                                        ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

enum _EventListItemType { header, dateHeader, event }

class _EventListItem {
  const _EventListItem({required this.type, this.dateLabel, this.eventDoc});

  final _EventListItemType type;
  final String? dateLabel;
  final QueryDocumentSnapshot<Map<String, dynamic>>? eventDoc;
}

enum _EventRecurrenceOption {
  none('none', '반복 안 함'),
  weekly('weekly', '매주'),
  biweekly('biweekly', '격주'),
  monthly('monthly', '매월');

  const _EventRecurrenceOption(this.code, this.label);

  final String code;
  final String label;
}
