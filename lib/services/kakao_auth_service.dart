import 'kakao_auth_service_impl_stub.dart'
    if (dart.library.html) 'kakao_auth_service_impl_web.dart'
    if (dart.library.io) 'kakao_auth_service_impl_mobile.dart'
    as impl;

class KakaoAuthResult {
  const KakaoAuthResult._({this.accessToken, this.authCode, this.redirectUri});

  final String? accessToken;
  final String? authCode;
  final String? redirectUri;

  bool get isAccessTokenFlow =>
      accessToken != null && accessToken!.trim().isNotEmpty;

  bool get isAuthCodeFlow => authCode != null && authCode!.trim().isNotEmpty;

  static KakaoAuthResult withAccessToken(String accessToken) {
    return KakaoAuthResult._(accessToken: accessToken);
  }

  static KakaoAuthResult withAuthCode({
    required String authCode,
    required String redirectUri,
  }) {
    return KakaoAuthResult._(authCode: authCode, redirectUri: redirectUri);
  }
}

class KakaoAuthService {
  KakaoAuthService._();

  static Future<KakaoAuthResult> login() => impl.kakaoLoginImpl();
}
