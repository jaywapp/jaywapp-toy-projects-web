import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

class MapLauncherService {
  MapLauncherService._();

  static Future<void> openNaverMapSearch(String query) async {
    final encoded = Uri.encodeComponent(query);
    final appUri = Uri.parse('nmap://search?query=$encoded&appname=moyeora');
    final webUri = Uri.parse('https://map.naver.com/v5/search/$encoded');

    try {
      if (!kIsWeb && await canLaunchUrl(appUri)) {
        await launchUrl(appUri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {
      // no-op and fallback to web
    }

    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // no-op
    }
  }
}
