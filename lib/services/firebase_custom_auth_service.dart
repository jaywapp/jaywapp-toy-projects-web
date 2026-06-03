import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/firebase_config.dart';

/// OAuth redirectUri 허용 도메인 목록.
/// 새 도메인 추가 시 이 목록과 Firebase 콘솔 Authorized domains를 함께 갱신해야 합니다.
const List<String> _kAllowedRedirectHosts = [
  'moyeora-dev.web.app',
  'localhost',
  '127.0.0.1',
];

/// [redirectUri]가 허용 목록에 포함된 호스트인지 검증합니다.
///
/// 허용되지 않은 URI가 전달되면 [FirebaseFunctionsException] (code: `invalid-argument`)을
/// throw 하여 오픈 리다이렉트 공격을 사전에 차단합니다.
void _validateRedirectUri(String redirectUri) {
  final uri = Uri.tryParse(redirectUri);
  if (uri == null) {
    throw FirebaseFunctionsException(
      code: 'invalid-argument',
      message: 'redirectUri 형식이 올바르지 않습니다: $redirectUri',
    );
  }
  final host = uri.host;
  if (!_kAllowedRedirectHosts.contains(host)) {
    throw FirebaseFunctionsException(
      code: 'invalid-argument',
      message: 'redirectUri 호스트가 허용 목록에 없습니다: $host',
    );
  }
}

class KakaoExchangeResult {
  KakaoExchangeResult({
    required this.customToken,
    required this.kakaoId,
    required this.kakaoProfileNickname,
    required this.kakaoProfileImageUrl,
  });

  final String customToken;
  final String? kakaoId;
  final String? kakaoProfileNickname;
  final String? kakaoProfileImageUrl;
}

class FirebaseCustomAuthService {
  FirebaseCustomAuthService._();

  /// 일시적 Functions 오류(내부 오류, 타임아웃 등)에 대해 지수 백오프 재시도.
  /// 인증 실패(unauthenticated, invalid-argument 등)는 재시도하지 않음.
  static Future<T> _withRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
  }) async {
    const retriableCodes = {'internal', 'unavailable', 'deadline-exceeded'};
    Object? lastError;
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        return await action();
      } on FirebaseFunctionsException catch (e) {
        if (!retriableCodes.contains(e.code)) rethrow;
        lastError = e;
        if (attempt < maxAttempts - 1) {
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      }
    }
    throw lastError!;
  }

  static Future<KakaoExchangeResult> exchangeKakaoToken(
    String accessToken,
  ) {
    return _withRetry(() async {
      final callable = FirebaseFunctions.instanceFor(
        region: FirebaseConfig.functionsRegion,
      ).httpsCallable('authExchangeKakao');
      final response = await callable.call(<String, dynamic>{
        'accessToken': accessToken,
      });
      return _parseExchangeResult(response.data);
    });
  }

  static Future<KakaoExchangeResult> exchangeKakaoAuthCode({
    required String authCode,
    required String redirectUri,
  }) {
    _validateRedirectUri(redirectUri);
    return _withRetry(() async {
      final callable = FirebaseFunctions.instanceFor(
        region: FirebaseConfig.functionsRegion,
      ).httpsCallable('authExchangeKakaoCode');
      final response = await callable.call(<String, dynamic>{
        'code': authCode,
        'redirectUri': redirectUri,
      });
      return _parseExchangeResult(response.data);
    });
  }

  static KakaoExchangeResult _parseExchangeResult(dynamic data) {
    if (data is! Map) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: '토큰 교환 응답 형식이 올바르지 않습니다.',
      );
    }
    final customToken = data['customToken']?.toString();
    if (customToken == null || customToken.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: '커스텀 토큰이 비어 있습니다.',
      );
    }
    return KakaoExchangeResult(
      customToken: customToken,
      kakaoId: data['kakaoId']?.toString(),
      kakaoProfileNickname: (data['kakaoProfile'] as Map?)?['nickname']
          ?.toString(),
      kakaoProfileImageUrl: (data['kakaoProfile'] as Map?)?['profileImageUrl']
          ?.toString(),
    );
  }

  static Future<UserCredential> signInWithCustomToken(String customToken) {
    return FirebaseAuth.instance.signInWithCustomToken(customToken);
  }
}
