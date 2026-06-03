import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/analytics_service.dart';
import '../../services/firebase_custom_auth_service.dart';
import '../../services/google_auth_service.dart';
import '../../services/kakao_auth_service.dart';
import '../../services/user_error_message.dart';
import '../../services/user_profile_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_loading_button.dart';
import '../../widgets/google_login_button.dart';
import '../../widgets/kakao_login_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _signUpMode = false;
  bool _loading = false;
  bool _obscurePassword = true;
  String? _message;

  @override
  void dispose() {
    try {
      _emailFocus.unfocus();
      _passwordFocus.unfocus();
      _emailController.dispose();
      _passwordController.dispose();
      _emailFocus.dispose();
      _passwordFocus.dispose();
    } finally {
      super.dispose();
    }
  }

  Future<void> _runAuth(Future<UserCredential> Function() action) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) {
      setState(() => _message = "이메일과 비밀번호(6자 이상)를 올바르게 입력해 주세요.");
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final credential = await action();
      final uid = credential.user?.uid;
      if (uid != null) {
        unawaited(AnalyticsService.logLogin('email'));
        final rawFallback = _emailController.text.trim().split('@').first;
        // 특수문자(언더스코어 등) 제거 — 한글/영문/공백만 허용
        final fallback =
            rawFallback.replaceAll(RegExp(r'[^가-힣a-zA-Z ]'), '').trim();
        await UserProfileService.ensurePasswordProfile(
          uid: uid,
          email: credential.user?.email,
          fallbackNickname: fallback,
        );
        if (credential.user != null) {
          await UserProfileService.syncLinkedProvidersFromAuth(
            credential.user!,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _message = toUserMessage(e));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _promptEmailPasswordLink({
    required String email,
    required AuthCredential pendingCredential,
  }) async {
    final passwordController = TextEditingController();
    final linked = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text("기존 계정 연결"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "이미 가입된 이메일($email)입니다. 기존 계정 비밀번호를 입력하면 소셜 계정을 연결할 수 있습니다.",
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "비밀번호"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text("취소"),
            ),
            FilledButton(
              onPressed: () async {
                final password = passwordController.text;
                if (password.isEmpty) return;
                try {
                  final signIn = await FirebaseAuth.instance
                      .signInWithEmailAndPassword(
                        email: email,
                        password: password,
                      );
                  await signIn.user?.linkWithCredential(pendingCredential);
                  if (signIn.user != null) {
                    await UserProfileService.syncLinkedProvidersFromAuth(
                      signIn.user!,
                    );
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop(true);
                } on FirebaseAuthException {
                  if (ctx.mounted) Navigator.of(ctx).pop(false);
                }
              },
              child: const Text("연결"),
            ),
          ],
        );
      },
    );
    return linked == true;
  }

  Future<void> _runKakaoLogin() async {
    if (_loading) return;
    if (!AppConfig.enableServerDependentFeatures) {
      setState(
        () => _message = "카카오 로그인은 현재 비활성화되어 있습니다. 이메일 또는 Google 로그인을 이용해 주세요.",
      );
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final kakaoAuthResult = await KakaoAuthService.login();
      final exchange = kakaoAuthResult.isAccessTokenFlow
          ? await FirebaseCustomAuthService.exchangeKakaoToken(
              kakaoAuthResult.accessToken!,
            )
          : await FirebaseCustomAuthService.exchangeKakaoAuthCode(
              authCode: kakaoAuthResult.authCode!,
              redirectUri: kakaoAuthResult.redirectUri!,
            );
      final credential = await FirebaseCustomAuthService.signInWithCustomToken(
        exchange.customToken,
      );
      final uid = credential.user?.uid;
      if (uid != null) {
        unawaited(AnalyticsService.logLogin('kakao'));
        await UserProfileService.upsertAfterKakaoLogin(
          uid: uid,
          kakaoNickname: exchange.kakaoProfileNickname,
          kakaoPhotoUrl: exchange.kakaoProfileImageUrl,
          kakaoId: exchange.kakaoId,
        );
        if (credential.user != null) {
          await UserProfileService.syncLinkedProvidersFromAuth(
            credential.user!,
          );
        }
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() => _message = "카카오 로그인 처리에 실패했습니다: ${e.code}");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential' &&
          e.email != null &&
          e.credential != null) {
        final linked = await _promptEmailPasswordLink(
          email: e.email!,
          pendingCredential: e.credential!,
        );
        setState(
          () => _message = linked
              ? "계정 연결이 완료되었습니다."
              : "계정 연결에 실패했습니다. 다시 시도해 주세요.",
        );
      } else if (e.code == 'account-exists-with-different-credential') {
        setState(
          () => _message = "이미 다른 방식으로 가입된 계정입니다. 이메일 로그인 후 계정 연결을 시도해 주세요.",
        );
      } else {
        setState(() => _message = toUserMessage(e));
      }
    } catch (_) {
      setState(() => _message = "카카오 로그인 처리에 실패했습니다.");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _runGoogleLogin() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final credential = await GoogleAuthService.signInWithGoogle();
      final user = credential.user;
      if (user != null) {
        unawaited(AnalyticsService.logLogin('google'));
        await UserProfileService.upsertAfterGoogleLogin(
          uid: user.uid,
          email: user.email,
          googleDisplayName: user.displayName,
          googlePhotoUrl: user.photoURL,
        );
        await UserProfileService.syncLinkedProvidersFromAuth(user);
      }
    } on GoogleSignInCanceledException {
      setState(() => _message = "Google 로그인을 취소했습니다.");
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential' &&
          e.email != null &&
          e.credential != null) {
        final linked = await _promptEmailPasswordLink(
          email: e.email!,
          pendingCredential: e.credential!,
        );
        setState(
          () => _message = linked
              ? "계정 연결이 완료되었습니다."
              : "계정 연결에 실패했습니다. 다시 시도해 주세요.",
        );
      } else {
        setState(() => _message = toUserMessage(e));
      }
    } catch (_) {
      setState(() => _message = "Google 로그인 처리에 실패했습니다.");
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _message = "비밀번호를 재설정할 이메일 주소를 먼저 입력해 주세요.");
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        setState(() => _message = "비밀번호 재설정 이메일을 발송했습니다. 메일함을 확인해 주세요.");
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _message = toUserMessage(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  bool get _isFormValid {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    return email.contains('@') && password.length >= 6;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/branding/app_icon.png',
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "모여라 로그인",
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "모임 일정을 함께 관리하고 투표/공지/통계를 확인해 보세요.",
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          textInputAction: TextInputAction.next,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _passwordFocus.requestFocus(),
                          decoration: const InputDecoration(labelText: "이메일"),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          textInputAction: TextInputAction.done,
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) {
                            if (!_loading && _isFormValid) {
                              _runAuth(
                                () => _signUpMode
                                    ? FirebaseAuth.instance
                                          .createUserWithEmailAndPassword(
                                            email: _emailController.text.trim(),
                                            password: _passwordController.text,
                                          )
                                    : FirebaseAuth.instance
                                          .signInWithEmailAndPassword(
                                            email: _emailController.text.trim(),
                                            password: _passwordController.text,
                                          ),
                              );
                            }
                          },
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: "비밀번호",
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword ? '비밀번호 표시' : '비밀번호 숨기기',
                              icon: ExcludeSemantics(
                                child: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _message!,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.danger),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: SizedBox(
                            height: 46,
                            child: AppLoadingButton(
                              loading: _loading,
                              enabled: _isFormValid,
                              label: _signUpMode ? "회원가입" : "로그인",
                              onPressed: () => _runAuth(
                                () => _signUpMode
                                    ? FirebaseAuth.instance
                                          .createUserWithEmailAndPassword(
                                            email: _emailController.text.trim(),
                                            password: _passwordController.text,
                                          )
                                    : FirebaseAuth.instance
                                          .signInWithEmailAndPassword(
                                            email: _emailController.text.trim(),
                                            password: _passwordController.text,
                                          ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () => setState(() {
                                      _signUpMode = !_signUpMode;
                                      _message = null;
                                    }),
                              child: Text(
                                _signUpMode
                                    ? "이미 계정이 있나요? 로그인"
                                    : "처음이신가요? 회원가입",
                              ),
                            ),
                            if (!_signUpMode)
                              TextButton(
                                onPressed: _loading ? null : _resetPassword,
                                child: Text(
                                  "비밀번호 찾기",
                                  style: TextStyle(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Divider(height: 1)),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text("또는"),
                              ),
                              Expanded(child: Divider(height: 1)),
                            ],
                          ),
                        ),
                        KakaoLoginButton(
                          loading: _loading,
                          onPressed: _runKakaoLogin,
                        ),
                        const SizedBox(height: 8),
                        GoogleLoginButton(
                          loading: _loading,
                          onPressed: _runGoogleLogin,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
