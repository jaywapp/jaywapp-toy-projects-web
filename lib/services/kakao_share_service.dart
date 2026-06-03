import 'package:flutter/foundation.dart';
import 'package:kakao_flutter_sdk_share/kakao_flutter_sdk_share.dart';
import 'package:url_launcher/url_launcher.dart';

/// 카카오링크 피드 템플릿으로 초대 링크를 공유합니다.
///
/// - 모바일: ShareClient (카카오톡 앱 직접 호출)
/// - 웹:    WebSharerClient (카카오 공유 팝업)
class KakaoShareService {
  KakaoShareService._();

  static const _webBaseUrl = 'https://moyeora-dev.web.app';
  static const _imageUrl = '$_webBaseUrl/icons/Icon-512.png';

  /// [code] 초대코드로 카카오톡 피드 메시지를 전송합니다.
  /// 성공 시 null, 실패 시 에러 메시지 문자열을 반환합니다.
  static Future<String?> shareInvite({required String code}) async {
    final webUrl = '$_webBaseUrl/join-invite?code=$code';
    final template = _buildTemplate(code: code, webUrl: webUrl);

    try {
      if (kIsWeb) {
        return await _shareWeb(template);
      } else {
        return await _shareMobile(template);
      }
    } catch (e) {
      return '카카오톡 공유 중 오류가 발생했습니다: $e';
    }
  }

  static FeedTemplate _buildTemplate({
    required String code,
    required String webUrl,
  }) {
    final link = Link(
      webUrl: Uri.parse(webUrl),
      mobileWebUrl: Uri.parse(webUrl),
      androidExecutionParams: {'code': code},
      iosExecutionParams: {'code': code},
    );

    return FeedTemplate(
      content: Content(
        title: '모여라 모임 초대',
        description: '초대 링크를 눌러 모임에 참여하세요.',
        imageUrl: Uri.parse(_imageUrl),
        link: link,
      ),
      buttons: [
        Button(title: '앱으로 열기', link: link),
      ],
    );
  }

  static Future<String?> _shareMobile(FeedTemplate template) async {
    final isInstalled = await ShareClient.instance.isKakaoTalkSharingAvailable();
    if (isInstalled) {
      await ShareClient.instance.shareDefault(template: template);
    } else {
      // 카카오톡 미설치 시 카카오 공유 웹으로 폴백
      final url = await WebSharerClient.instance.makeDefaultUrl(template: template);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        return '카카오톡이 설치되어 있지 않습니다.';
      }
    }
    return null;
  }

  static Future<String?> _shareWeb(FeedTemplate template) async {
    final url = await WebSharerClient.instance.makeDefaultUrl(template: template);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      return '카카오 공유 창을 열 수 없습니다.';
    }
    return null;
  }
}
