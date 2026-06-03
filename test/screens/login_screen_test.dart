import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyeora/widgets/app_loading_button.dart';

/// LoginScreen의 버튼 활성화 조건 (_isFormValid) 을 검증하는 테스트.
///
/// LoginScreen은 FirebaseAuth/FirebaseFirestore에 직접 의존하므로
/// 전체 위젯을 마운트하는 대신, 동일한 활성화 조건 로직을 갖는
/// 미니 위젯으로 테스트합니다.
///
/// 활성화 조건: email.contains('@') && password.length >= 6

bool _isFormValid(String email, String password) {
  return email.contains('@') && password.length >= 6;
}

/// 최소한의 로그인 폼 위젯 — LoginScreen의 이메일/비밀번호 입력 + 버튼 구조를 재현
class _MinimalLoginForm extends StatefulWidget {
  const _MinimalLoginForm();

  @override
  State<_MinimalLoginForm> createState() => _MinimalLoginFormState();
}

class _MinimalLoginFormState extends State<_MinimalLoginForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final valid = _isFormValid(
      _emailController.text,
      _passwordController.text,
    );
    return Column(
      children: [
        TextField(
          key: const Key('email_field'),
          controller: _emailController,
          onChanged: (_) => setState(() {}),
        ),
        TextField(
          key: const Key('password_field'),
          controller: _passwordController,
          onChanged: (_) => setState(() {}),
          obscureText: true,
        ),
        AppLoadingButton(
          key: const Key('login_button'),
          label: '로그인',
          enabled: valid,
          onPressed: valid ? () {} : null,
        ),
      ],
    );
  }
}

void main() {
  group('LoginScreen 버튼 활성화 조건', () {
    testWidgets('이메일, 비밀번호 모두 비어있으면 버튼이 비활성화된다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: _MinimalLoginForm()),
          ),
        ),
      );

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('유효한 이메일과 6자 이상 비밀번호 입력 시 버튼이 활성화된다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: _MinimalLoginForm()),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('email_field')), 'user@example.com');
      await tester.enterText(find.byKey(const Key('password_field')), 'password123');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('@가 없는 이메일이면 버튼이 비활성화된다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: _MinimalLoginForm()),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('email_field')), 'invalidemail');
      await tester.enterText(find.byKey(const Key('password_field')), 'password123');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('비밀번호가 5자이면 버튼이 비활성화된다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: _MinimalLoginForm()),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('email_field')), 'user@example.com');
      await tester.enterText(find.byKey(const Key('password_field')), '12345');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('비밀번호가 정확히 6자이면 버튼이 활성화된다', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: _MinimalLoginForm()),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('email_field')), 'user@example.com');
      await tester.enterText(find.byKey(const Key('password_field')), '123456');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('이메일 입력 후 비밀번호 없으면 버튼 비활성화', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: _MinimalLoginForm()),
          ),
        ),
      );

      await tester.enterText(find.byKey(const Key('email_field')), 'user@example.com');
      await tester.pump();

      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });
  });

  group('_isFormValid 단위 테스트', () {
    test('@포함 이메일 + 6자 이상 비밀번호 → true', () {
      expect(_isFormValid('a@b.com', '123456'), isTrue);
    });

    test('@없는 이메일 → false', () {
      expect(_isFormValid('noemail', '123456'), isFalse);
    });

    test('5자 비밀번호 → false', () {
      expect(_isFormValid('a@b.com', '12345'), isFalse);
    });

    test('빈 이메일 → false', () {
      expect(_isFormValid('', '123456'), isFalse);
    });

    test('빈 비밀번호 → false', () {
      expect(_isFormValid('a@b.com', ''), isFalse);
    });
  });
}
