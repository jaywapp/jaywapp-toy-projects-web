// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:async';
import 'dart:html' as html;

import '../config/app_keys.dart';
import 'kakao_auth_service.dart';

const String _popupName = 'moyeora_kakao_login';
const String _messageType = 'moyeora_kakao_auth_callback';

Future<KakaoAuthResult> kakaoLoginImpl() async {
  final clientId = kKakaoRestApiKey.isNotEmpty
      ? kKakaoRestApiKey
      : kKakaoJavaScriptKey;
  if (clientId.isEmpty) {
    throw UnsupportedError('카카오 REST API 키 또는 JavaScript 키가 설정되지 않았습니다.');
  }

  final origin = html.window.location.origin;
  final redirectUri = '$origin/kakao_login_callback.html';
  final state = 'moyeora_${DateTime.now().millisecondsSinceEpoch}';
  final authUri = Uri.https('kauth.kakao.com', '/oauth/authorize', {
    'response_type': 'code',
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'state': state,
  });

  final popup = html.window.open(
    authUri.toString(),
    _popupName,
    'popup=yes,width=520,height=700,left=100,top=80',
  );

  final completer = Completer<KakaoAuthResult>();

  void completeWithError(Object error, [StackTrace? stackTrace]) {
    if (!completer.isCompleted) {
      if (stackTrace == null) {
        completer.completeError(error);
      } else {
        completer.completeError(error, stackTrace);
      }
    }
  }

  final subscription = html.window.onMessage.listen((event) {
    if (event.origin != origin) return;
    final data = event.data;
    if (data is! Map) return;
    if (data['type']?.toString() != _messageType) return;
    if (data['state']?.toString() != state) return;

    final error = data['error']?.toString();
    if (error != null && error.isNotEmpty) {
      completeWithError(StateError('카카오 로그인 실패: $error'));
      return;
    }

    final code = data['code']?.toString();
    if (code == null || code.isEmpty) {
      completeWithError(StateError('카카오 인증 코드를 받지 못했습니다.'));
      return;
    }

    if (!completer.isCompleted) {
      completer.complete(
        KakaoAuthResult.withAuthCode(authCode: code, redirectUri: redirectUri),
      );
    }
  });

  final closedWatcher = Timer.periodic(const Duration(milliseconds: 400), (_) {
    if (popup.closed == true && !completer.isCompleted) {
      completeWithError(StateError('카카오 로그인이 취소되었습니다.'));
    }
  });

  try {
    return await completer.future.timeout(const Duration(minutes: 2));
  } finally {
    await subscription.cancel();
    closedWatcher.cancel();
    if (popup.closed != true) {
      popup.close();
    }
  }
}
