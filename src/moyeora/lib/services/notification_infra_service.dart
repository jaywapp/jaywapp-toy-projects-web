import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationInfraService {
  NotificationInfraService._();
  static final NotificationInfraService instance = NotificationInfraService._();

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _localInitialized = false;
  String? _boundGroupId;
  String? _boundUid;

  Future<void> configure({
    required String groupId,
    required String uid,
    required void Function(String? token, bool? stored) onTokenState,
    required void Function(String type) onNavigateType,
    required void Function(String error) onError,
  }) async {
    if (_boundGroupId == groupId && _boundUid == uid) return;
    _boundGroupId = groupId;
    _boundUid = uid;

    try {
      await FirebaseMessaging.instance.requestPermission();
      if (!kIsWeb) {
        await _initLocalIfNeeded();
      }

      Future<void> saveToken(String token) async {
        try {
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(groupId)
              .collection('members')
              .doc(uid)
              .collection('fcmTokens')
              .doc(token)
              .set({
                'token': token,
                'platform': kIsWeb ? 'web' : 'android',
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
          onTokenState(token, true);
        } on FirebaseException catch (e) {
          onTokenState(token, false);
          onError('FCM 토큰 저장 실패: ${e.code}');
        }
      }

      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        await saveToken(token);
      } else {
        onTokenState(null, false);
      }

      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) async => saveToken(token),
      );

      await _foregroundSub?.cancel();
      _foregroundSub = FirebaseMessaging.onMessage.listen((message) async {
        try {
          final title = message.notification?.title ?? '확인';
          final body = message.notification?.body ?? '';
          final type = message.data['type']?.toString();

          if (!kIsWeb) {
            final android = AndroidNotificationDetails(
              'moyeora_default',
              'Moyeora Default',
              importance: Importance.defaultImportance,
              priority: Priority.defaultPriority,
            );
            await _local.show(
              id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              title: title,
              body: body,
              notificationDetails: NotificationDetails(android: android),
            );
          }

          if (type != null && (type == 'notice' || type == 'event')) {
            onNavigateType(type);
          }
        } catch (e) {
          onError('포그라운드 알림 처리 실패: $e');
        }
      });
    } catch (e) {
      onError('FCM 초기화 실패: $e');
    }
  }

  Future<void> _initLocalIfNeeded() async {
    if (_localInitialized) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _local.initialize(settings: settings);
    _localInitialized = true;
  }

  Future<void> dispose() async {
    await _foregroundSub?.cancel();
    await _tokenRefreshSub?.cancel();
    _foregroundSub = null;
    _tokenRefreshSub = null;
    _boundGroupId = null;
    _boundUid = null;
  }
}
