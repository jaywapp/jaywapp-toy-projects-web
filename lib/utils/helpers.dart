import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../dev/firestore_metrics.dart';
import '../dev/perf_timing.dart';
import '../services/analytics_service.dart';
import '../services/user_error_message.dart';
import '../widgets/app_snackbar.dart';

String eventPrimaryPlace(Map<String, dynamic> eventData) {
  final locationName = eventData['locationName']?.toString();
  final location = eventData['location']?.toString();
  final address = eventData['address']?.toString();

  if (locationName != null && locationName.isNotEmpty) return locationName;
  if (location != null && location.isNotEmpty) return location;
  if (address != null && address.isNotEmpty) return address;
  return '-';
}

String? eventMapQuery(Map<String, dynamic> eventData) {
  final address = eventData['address']?.toString();
  final locationName = eventData['locationName']?.toString();
  final location = eventData['location']?.toString();

  if (address != null && address.isNotEmpty) return address;
  if (locationName != null && locationName.isNotEmpty) return locationName;
  if (location != null && location.isNotEmpty) return location;
  return null;
}

bool isEventResponseClosed(Map<String, dynamic> eventData, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final status = eventData['status']?.toString().trim();
  if (status == 'closed') return true;

  final closedAt = eventData['responseClosedAt'];
  if (closedAt is Timestamp) {
    if (!closedAt.toDate().isAfter(reference)) return true;
  }

  return false;
}

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// MM.DD (요일) HH:mm — 주요 날짜·시간 표기용
String formatDate(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  final w = _weekdays[date.weekday - 1];
  final h = date.hour.toString().padLeft(2, '0');
  final min = date.minute.toString().padLeft(2, '0');
  return '$m.$d ($w) $h:$min';
}

/// YYYY.MM.DD (요일) HH:mm — 연도 포함 표기용
String formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  final y = local.year;
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final w = _weekdays[local.weekday - 1];
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return '$y.$m.$d ($w) $h:$min';
}

/// MM.DD — 날짜만 표기 (월·일)
String formatDateOnly(DateTime date) {
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$m.$d';
}

/// YYYY.MM.DD — 날짜만 표기 (연·월·일)
String formatDateFull(DateTime date) {
  final y = date.year;
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y.$m.$d';
}

String currentPeriodKey([DateTime? date]) {
  final now = date ?? DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  return '${now.year}-$month';
}

String friendlyError(Object? error) {
  if (error == null) return kDefaultUserErrorMessage;
  return toUserMessage(error);
}

Future<void> writeResponse({
  required String groupId,
  required String eventId,
  required String uid,
  required String response,
  required BuildContext context,
}) async {
  final span = PerfSpan('Write response').start();
  try {
    await HapticFeedback.lightImpact();
    final eventRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .doc(eventId);
    final eventSnap = await eventRef.get();
    FirestoreMetrics.instance.addReads(eventSnap.exists ? 1 : 0);
    final eventData = eventSnap.data();
    if (eventData == null || eventData['isDeleted'] == true) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: "삭제되었거나 존재하지 않는 일정입니다.",
          type: AppSnackType.error,
        );
      }
      return;
    }
    final startAtRaw = eventData['startAt'];
    if (startAtRaw is Timestamp &&
        !startAtRaw.toDate().isAfter(DateTime.now())) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: "응답이 마감된 일정입니다.",
          type: AppSnackType.info,
        );
      }
      return;
    }
    if (isEventResponseClosed(eventData)) {
      if (context.mounted) {
        AppSnackbar.show(
          context,
          message: "응답이 마감된 일정입니다.",
          type: AppSnackType.info,
        );
      }
      return;
    }

    await FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('events')
        .doc(eventId)
        .collection('responses')
        .doc(uid)
        .set({
          'response': response,
          'respondedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
    FirestoreMetrics.instance.addWrites();
    unawaited(AnalyticsService.logEventResponse(response));
    if (context.mounted) {
      AppSnackbar.show(
        context,
        message: "응답이 저장되었습니다.",
        type: AppSnackType.success,
      );
    }
  } on FirebaseException catch (e) {
    final message = toUserMessage(e);
    if (context.mounted) {
      AppSnackbar.show(context, message: message, type: AppSnackType.error);
    }
  } finally {
    span.end();
    FirestoreMetrics.instance.dump('response');
  }
}
