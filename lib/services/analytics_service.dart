import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// Firebase Analytics 이벤트 래퍼 서비스.
///
/// 각 메서드는 대응하는 Analytics 이벤트를 전송하며,
/// 실패해도 앱 흐름에 영향을 주지 않도록 예외를 억제합니다.
class AnalyticsService {
  AnalyticsService._();

  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// 로그인 이벤트.
  ///
  /// [method]: 로그인 방식 (e.g. 'email', 'google', 'kakao')
  static Future<void> logLogin(String method) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e) {
      debugPrint('[Analytics] logLogin error: $e');
    }
  }

  /// 그룹 생성 이벤트.
  static Future<void> logCreateGroup() async {
    try {
      await _analytics.logEvent(name: 'create_group');
    } catch (e) {
      debugPrint('[Analytics] logCreateGroup error: $e');
    }
  }

  /// 그룹 가입 이벤트.
  ///
  /// [status]: 가입 결과 상태 (e.g. 'joined', 'pending', 'already_active')
  static Future<void> logJoinGroup({String? status}) async {
    try {
      await _analytics.logEvent(
        name: 'join_group',
        parameters: status != null ? <String, Object>{'status': status} : null,
      );
    } catch (e) {
      debugPrint('[Analytics] logJoinGroup error: $e');
    }
  }

  /// 이벤트 응답 이벤트.
  ///
  /// [answer]: 응답 값 ('going', 'notGoing', 'maybe')
  static Future<void> logEventResponse(String answer) async {
    try {
      await _analytics.logEvent(
        name: 'event_response',
        parameters: <String, Object>{'answer': answer},
      );
    } catch (e) {
      debugPrint('[Analytics] logEventResponse error: $e');
    }
  }

  /// 공지 조회 이벤트.
  static Future<void> logViewNotice() async {
    try {
      await _analytics.logEvent(name: 'view_notice');
    } catch (e) {
      debugPrint('[Analytics] logViewNotice error: $e');
    }
  }

  /// 투표 참여 이벤트.
  static Future<void> logVotePoll() async {
    try {
      await _analytics.logEvent(name: 'vote_poll');
    } catch (e) {
      debugPrint('[Analytics] logVotePoll error: $e');
    }
  }

  /// 화면 조회 이벤트.
  ///
  /// [screenName]: 화면 이름 (e.g. 'home', 'events', 'notices')
  static Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e) {
      debugPrint('[Analytics] logScreenView error: $e');
    }
  }
}
