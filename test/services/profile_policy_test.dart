import 'package:flutter_test/flutter_test.dart';
import 'package:moyeora/services/profile_policy.dart';

void main() {
  group('ProfilePolicy.isValidRealName', () {
    test('한국어 이름 유효', () {
      expect(ProfilePolicy.isValidRealName('홍길동'), isTrue);
      expect(ProfilePolicy.isValidRealName('김 철수'), isTrue);
    });

    test('영어 이름 유효', () {
      expect(ProfilePolicy.isValidRealName('John'), isTrue);
      expect(ProfilePolicy.isValidRealName('Mary Jane'), isTrue);
    });

    test('한영 혼합 유효', () {
      expect(ProfilePolicy.isValidRealName('Kim Cheolsu'), isTrue);
    });

    test('빈 문자열 → 무효', () {
      expect(ProfilePolicy.isValidRealName(''), isFalse);
    });

    test('공백만 → 무효', () {
      expect(ProfilePolicy.isValidRealName('   '), isFalse);
    });

    test('1자 이름 → 무효 (최소 2자)', () {
      expect(ProfilePolicy.isValidRealName('김'), isFalse);
    });

    test('21자 이름 → 무효 (최대 20자)', () {
      expect(ProfilePolicy.isValidRealName('a' * 21), isFalse);
    });

    test('앞 공백은 trim() 처리되어 유효', () {
      // isValidRealName은 내부적으로 trim()하므로 앞/뒤 공백은 허용됨
      expect(ProfilePolicy.isValidRealName(' 홍길동'), isTrue);
    });

    test('뒤 공백은 trim() 처리되어 유효', () {
      expect(ProfilePolicy.isValidRealName('홍길동 '), isTrue);
    });

    test('연속 공백 → 무효', () {
      expect(ProfilePolicy.isValidRealName('홍  길동'), isFalse);
    });

    test('숫자 포함 → 무효', () {
      expect(ProfilePolicy.isValidRealName('홍길동1'), isFalse);
    });

    test('특수문자 포함 → 무효', () {
      expect(ProfilePolicy.isValidRealName('홍@길동'), isFalse);
    });
  });

  group('ProfilePolicy.normalizePhoneNumber', () {
    test('일반 숫자 → 숫자만 추출', () {
      expect(ProfilePolicy.normalizePhoneNumber('010-1234-5678'), '01012345678');
    });

    test('공백 포함 → 숫자만 추출', () {
      expect(ProfilePolicy.normalizePhoneNumber('010 1234 5678'), '01012345678');
    });

    test('+ 접두사 보존', () {
      expect(
        ProfilePolicy.normalizePhoneNumber('+82 10-1234-5678'),
        '+821012345678',
      );
    });

    test('빈 문자열 → 빈 문자열', () {
      expect(ProfilePolicy.normalizePhoneNumber(''), '');
    });

    test('공백만 → 빈 문자열', () {
      expect(ProfilePolicy.normalizePhoneNumber('   '), '');
    });

    test('숫자 없음 → 빈 문자열', () {
      expect(ProfilePolicy.normalizePhoneNumber('abc'), '');
    });
  });

  group('ProfilePolicy.isValidPhoneNumber', () {
    test('일반 번호 유효 (11자리)', () {
      expect(ProfilePolicy.isValidPhoneNumber('01012345678'), isTrue);
    });

    test('국제 번호 유효', () {
      expect(ProfilePolicy.isValidPhoneNumber('+821012345678'), isTrue);
    });

    test('너무 짧음 (8자리 이하) → 무효', () {
      expect(ProfilePolicy.isValidPhoneNumber('1234567'), isFalse);
    });

    test('너무 긺 (16자리 이상) → 무효', () {
      expect(ProfilePolicy.isValidPhoneNumber('1234567890123456'), isFalse);
    });

    test('빈 문자열 → 무효', () {
      expect(ProfilePolicy.isValidPhoneNumber(''), isFalse);
    });

    test('숫자만 있는 최소 길이 (9자리) → 유효', () {
      expect(ProfilePolicy.isValidPhoneNumber('123456789'), isTrue);
    });

    test('최대 길이 (15자리) → 유효', () {
      expect(ProfilePolicy.isValidPhoneNumber('123456789012345'), isTrue);
    });
  });
}
