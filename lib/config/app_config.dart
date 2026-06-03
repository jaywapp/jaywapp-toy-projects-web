import 'package:flutter/foundation.dart';

enum AppEnvironment { dev, stage, prod }

class AppConfig {
  AppConfig._();

  static const String _rawEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'dev',
  );

  static AppEnvironment get environment {
    switch (_rawEnv) {
      case 'prod':
        return AppEnvironment.prod;
      case 'stage':
        return AppEnvironment.stage;
      default:
        return AppEnvironment.dev;
    }
  }

  // 운영 배포에서 디버그 패널이 노출되지 않도록 디버그 빌드에서만 활성화.
  static bool get enableDevTools => kDebugMode;

  static bool get showDebugBanner => kDebugMode;

  // Blaze 전환 이후 서버 의존 기능은 기본 활성화한다.
  static bool get enableServerDependentFeatures => true;

  static bool get enableStorageUpload => true;

  static bool get enableBlazeAutomationFeatures => true;
}
