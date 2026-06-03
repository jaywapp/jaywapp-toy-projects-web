import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'kakao_auth_service.dart';

Future<KakaoAuthResult> kakaoLoginImpl() async {
  OAuthToken token;
  final talkInstalled = await isKakaoTalkInstalled();
  if (talkInstalled) {
    try {
      token = await UserApi.instance.loginWithKakaoTalk();
    } catch (_) {
      token = await UserApi.instance.loginWithKakaoAccount();
    }
  } else {
    token = await UserApi.instance.loginWithKakaoAccount();
  }

  return KakaoAuthResult.withAccessToken(token.accessToken);
}
