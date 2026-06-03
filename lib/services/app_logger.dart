import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../config/firebase_config.dart';

enum AppLogLevel { debug, info, warn, error }

class AppLogger {
  AppLogger._();

  static bool _handlersInstalled = false;
  static bool _sending = false;
  static final List<Map<String, dynamic>> _queue = <Map<String, dynamic>>[];

  static void installGlobalHandlers() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;

    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (details) {
      previousFlutterError?.call(details);
      unawaited(
        error(
          'flutter_error',
          error: details.exception,
          stack: details.stack,
          context: {
            'library': details.library,
            'context': details.context?.toDescription(),
            'information': details.informationCollector == null
                ? null
                : 'collected',
          },
        ),
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(AppLogger.error('platform_error', error: error, stack: stack));
      return false;
    };
  }

  static Future<void> debug(
    String message, {
    String? groupId,
    Map<String, dynamic>? context,
  }) async {
    await _log(
      level: AppLogLevel.debug,
      message: message,
      groupId: groupId,
      context: context,
    );
  }

  static Future<void> info(
    String message, {
    String? groupId,
    Map<String, dynamic>? context,
  }) async {
    await _log(
      level: AppLogLevel.info,
      message: message,
      groupId: groupId,
      context: context,
    );
  }

  static Future<void> warn(
    String message, {
    Object? error,
    StackTrace? stack,
    String? groupId,
    Map<String, dynamic>? context,
  }) async {
    await _log(
      level: AppLogLevel.warn,
      message: message,
      error: error,
      stack: stack,
      groupId: groupId,
      context: context,
    );
  }

  static Future<void> error(
    String message, {
    Object? error,
    StackTrace? stack,
    String? groupId,
    Map<String, dynamic>? context,
  }) async {
    await _log(
      level: AppLogLevel.error,
      message: message,
      error: error,
      stack: stack,
      groupId: groupId,
      context: context,
    );
  }

  static Future<void> _log({
    required AppLogLevel level,
    required String message,
    Object? error,
    StackTrace? stack,
    String? groupId,
    Map<String, dynamic>? context,
  }) async {
    final payload = <String, dynamic>{
      'level': level.name,
      'message': message,
      if (groupId != null && groupId.isNotEmpty) 'groupId': groupId,
      if (stack != null) 'stack': stack.toString(),
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'context': <String, dynamic>{
        if (context != null) ...context,
        if (error != null) 'error': error.toString(),
        // uid는 디버깅 식별용으로 앞 8자리만 포함합니다. 전체 uid는 PII이므로 전송하지 않습니다.
        'uid': _redactUid(FirebaseAuth.instance.currentUser?.uid),
      },
    };

    final local =
        '[${level.name.toUpperCase()}] $message'
        '${error == null ? '' : ' | $error'}';
    debugPrint(local);
    if (!AppConfig.enableServerDependentFeatures) return;
    if (kDebugMode && level == AppLogLevel.debug) return;

    _queue.add(payload);
    await _flush();
  }

  /// uid 전체를 로그로 전송하지 않도록 앞 8자리만 반환합니다.
  static String? _redactUid(String? uid) {
    if (uid == null) return null;
    final prefix = uid.length > 8 ? uid.substring(0, 8) : uid;
    return '$prefix…';
  }

  static Future<void> _flush() async {
    if (_sending) return;
    if (Firebase.apps.isEmpty) return;
    if (_queue.isEmpty) return;

    _sending = true;
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: FirebaseConfig.functionsRegion,
      ).httpsCallable('logClientEvent');
      while (_queue.isNotEmpty) {
        final event = _queue.removeAt(0);
        try {
          await callable.call(event);
        } catch (e) {
          // 네트워크 일시 오류 시 손실을 허용해 무한 재시도 루프를 방지합니다.
          debugPrint('[AppLogger] log flush failed: $e');
        }
      }
    } finally {
      _sending = false;
    }
  }
}
