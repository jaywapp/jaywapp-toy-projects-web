import 'package:cloud_functions/cloud_functions.dart';

/// Cloud Functions 호출 시 일시적 장애에 대한 지수 백오프 재시도 유틸리티.
///
/// - 재시도 대상 코드: `unavailable` (서버 일시 불가)
/// - 최대 3회 시도, 초기 대기 2초 (시도마다 2배 증가)
/// - 인증/입력 오류(unauthenticated, invalid-argument 등)는 즉시 rethrow
///
/// 사용 예:
/// ```dart
/// final result = await FunctionsCaller.callWithRetry(
///   () => FirebaseFunctions.instance.httpsCallable('myFunc').call(payload),
/// );
/// ```
class FunctionsCaller {
  FunctionsCaller._();

  /// [unavailable] 코드에 해당하는 경우에만 지수 백오프 재시도합니다.
  static const Set<String> _retriableCodes = {'unavailable'};

  static const int _maxAttempts = 3;
  static const Duration _initialDelay = Duration(seconds: 2);

  /// [action]을 호출하고 필요 시 재시도합니다.
  ///
  /// [action]은 `HttpsCallableResult`를 반환하는 비동기 함수입니다.
  /// 재시도 불가 예외는 즉시 rethrow 됩니다.
  static Future<HttpsCallableResult<T>> callWithRetry<T>(
    Future<HttpsCallableResult<T>> Function() action,
  ) async {
    Object? lastError;
    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      try {
        return await action();
      } on FirebaseFunctionsException catch (e) {
        if (!_retriableCodes.contains(e.code)) {
          rethrow;
        }
        lastError = e;
        if (attempt < _maxAttempts - 1) {
          final delay = _initialDelay * (1 << attempt);
          await Future<void>.delayed(delay);
        }
      }
    }
    throw lastError!;
  }
}
