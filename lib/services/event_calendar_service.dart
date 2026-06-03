import 'dart:convert';

import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class EventCalendarService {
  EventCalendarService._();

  static Uri buildGoogleCalendarUri({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    String? description,
    String? location,
  }) {
    return Uri.https('calendar.google.com', '/calendar/render', {
      'action': 'TEMPLATE',
      'text': title,
      'dates': '${_formatUtc(startAt)}/${_formatUtc(endAt)}',
      if (description != null && description.trim().isNotEmpty)
        'details': description.trim(),
      if (location != null && location.trim().isNotEmpty)
        'location': location.trim(),
    });
  }

  static String buildIcsContent({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    String? description,
    String? location,
    String? uid,
  }) {
    final normalizedUid = (uid != null && uid.trim().isNotEmpty)
        ? uid.trim()
        : '${startAt.millisecondsSinceEpoch}@moyeora';
    final lines = <String>[
      'BEGIN:VCALENDAR',
      'VERSION:2.0',
      'PRODID:-//Moyeora//Calendar Export//KO',
      'CALSCALE:GREGORIAN',
      'METHOD:PUBLISH',
      'BEGIN:VEVENT',
      'UID:$normalizedUid',
      'DTSTAMP:${_formatUtc(DateTime.now())}',
      'DTSTART:${_formatUtc(startAt)}',
      'DTEND:${_formatUtc(endAt)}',
      'SUMMARY:${_escapeIcs(title)}',
      if (description != null && description.trim().isNotEmpty)
        'DESCRIPTION:${_escapeIcs(description.trim())}',
      if (location != null && location.trim().isNotEmpty)
        'LOCATION:${_escapeIcs(location.trim())}',
      'END:VEVENT',
      'END:VCALENDAR',
    ];
    return '${lines.join('\r\n')}\r\n';
  }

  static Future<bool> openGoogleCalendar({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    String? description,
    String? location,
  }) async {
    final uri = buildGoogleCalendarUri(
      title: title,
      startAt: startAt,
      endAt: endAt,
      description: description,
      location: location,
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<bool> openIcsImport({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    String? description,
    String? location,
    String? uid,
  }) async {
    final ics = buildIcsContent(
      title: title,
      startAt: startAt,
      endAt: endAt,
      description: description,
      location: location,
      uid: uid,
    );
    final uri = Uri.dataFromString(
      ics,
      mimeType: 'text/calendar',
      encoding: utf8,
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static Future<void> shareIcs({
    required String title,
    required DateTime startAt,
    required DateTime endAt,
    String? description,
    String? location,
    String? uid,
  }) async {
    final ics = buildIcsContent(
      title: title,
      startAt: startAt,
      endAt: endAt,
      description: description,
      location: location,
      uid: uid,
    );
    await Share.share(ics, subject: '$title 일정 (.ics)');
  }

  static String _formatUtc(DateTime value) {
    final utc = value.toUtc();
    final y = utc.year.toString().padLeft(4, '0');
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    final hh = utc.hour.toString().padLeft(2, '0');
    final mm = utc.minute.toString().padLeft(2, '0');
    final ss = utc.second.toString().padLeft(2, '0');
    return '${y}${m}${d}T${hh}${mm}${ss}Z';
  }

  static String _escapeIcs(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll(';', r'\;')
        .replaceAll(',', r'\,')
        .replaceAll('\r\n', r'\n')
        .replaceAll('\n', r'\n');
  }
}

