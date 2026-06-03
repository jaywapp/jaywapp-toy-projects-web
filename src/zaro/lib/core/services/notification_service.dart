import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

// VAPID 키: Firebase Console > Project Settings > Cloud Messaging > Web Push certificates
// 발급 후 아래 값을 교체하세요.
const _webVapidKey = 'BAWG5CF-Eeye3KHgOWp_qnx2qoUjCjvRKco5zjLK11zuWy_WTZlx52QalFSDAosnUzCJnb9GT-xwPVc8y0DjDTM';

@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {}

class NotificationService {
  static Future<void> initialize() async {
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);
    }

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      try {
        await saveToken();
        messaging.onTokenRefresh.listen((_) => saveToken());
      } catch (_) {}
    }
  }

  static Future<void> saveToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final token = kIsWeb
        ? await FirebaseMessaging.instance.getToken(vapidKey: _webVapidKey)
        : await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
  }
}
