import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyeora/services/user_error_message.dart';

void main() {
  test('maps auth wrong-password to user friendly message', () {
    final error = FirebaseAuthException(code: 'wrong-password');

    final message = toUserMessage(error);
    expect(message, '이메일 또는 비밀번호를 확인해 주세요.');
  });

  test('maps permission-denied to user friendly message', () {
    final error = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );

    final message = toUserMessage(error);
    expect(message, '권한이 없습니다. 운영진 승인 여부를 확인하세요.');
  });

  test('returns default message for unknown object', () {
    final message = toUserMessage(Exception('unknown'));
    expect(message, kDefaultUserErrorMessage);
  });
}
