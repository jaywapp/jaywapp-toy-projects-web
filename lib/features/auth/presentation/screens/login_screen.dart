import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString())),
        );
      }
    });

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              _buildLogo(),
              const SizedBox(height: 16),
              _buildTagline(context),
              const Spacer(flex: 3),
              _buildGoogleSignInButton(context, ref, authState.isLoading),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return ShaderMask(
      shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
      child: const Text(
        'ZARO₩',
        style: TextStyle(
          fontSize: 52,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildTagline(BuildContext context) {
    return Text(
      '혼자 쓰는 돈, 함께 쓰는 가계부',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 15,
        color: context.appColors.textSecondary,
        height: 1.6,
      ),
    );
  }

  Widget _buildGoogleSignInButton(BuildContext context, WidgetRef ref, bool isLoading) {
    return OutlinedButton.icon(
      onPressed: isLoading
          ? null
          : () => ref.read(authNotifierProvider.notifier).signInWithGoogle(),
      icon: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.login, size: 20),
      label: Text(isLoading ? '로그인 중...' : 'Google로 시작하기'),
      style: OutlinedButton.styleFrom(
        foregroundColor: context.appColors.textPrimary,
        side: const BorderSide(color: AppColors.primary),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
