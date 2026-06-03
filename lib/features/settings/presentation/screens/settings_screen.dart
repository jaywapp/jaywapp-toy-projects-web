import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _keyController = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  bool _isSaved = false;

  static const _apiKeyUrl = 'https://aistudio.google.com/app/apikey';

  @override
  void initState() {
    super.initState();
    _loadSavedKey();
  }

  Future<void> _loadSavedKey() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final key = doc.data()?['geminiApiKey'] as String?;
    if (key != null && key.isNotEmpty) {
      setState(() {
        _keyController.text = key;
        _isSaved = true;
      });
    }
  }

  Future<void> _save() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'geminiApiKey': key,
      });
      setState(() => _isSaved = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API 키가 저장되었습니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'geminiApiKey': FieldValue.delete(),
    });
    setState(() {
      _keyController.clear();
      _isSaved = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('API 키가 삭제되었습니다.')),
      );
    }
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Gemini API 키', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            'AI 지출 분석 및 월별 리포트 기능을 사용하려면 Google Gemini API 키가 필요합니다.',
            style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () => launchUrl(Uri.parse(_apiKeyUrl), mode: LaunchMode.externalApplication),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.open_in_new, size: 16, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Google AI Studio에서 API 키 발급',
                          style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                        Text(
                          'aistudio.google.com/app/apikey',
                          style: TextStyle(color: context.appColors.textHint, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _keyController,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'API 키',
              hintText: 'AIza...',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                    tooltip: _obscure ? '키 표시' : '키 숨기기',
                  ),
                  if (_isSaved)
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _keyController.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('API 키가 복사되었습니다.')),
                        );
                      },
                      tooltip: 'API 키 복사',
                    ),
                ],
              ),
            ),
            onChanged: (_) => setState(() => _isSaved = false),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isSaved ? '저장됨 ✓' : '저장'),
                ),
              ),
              if (_isSaved) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('삭제'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),
          const Text('화면 설정', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 12),
          Builder(builder: (context) {
            final themeMode = ref.watch(themeModeProvider);
            return SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('라이트 모드'),
              subtitle: Text(
                themeMode == ThemeMode.light ? '라이트 모드 사용 중' : '다크 모드 사용 중',
                style: const TextStyle(fontSize: 12),
              ),
              secondary: Icon(
                themeMode == ThemeMode.light ? Icons.light_mode : Icons.dark_mode,
                color: AppColors.primary,
              ),
              value: themeMode == ThemeMode.light,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggle(),
              activeColor: AppColors.primary,
            );
          }),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.lock_outline, size: 14, color: context.appColors.textSecondary),
                    const SizedBox(width: 6),
                    Text('보안 안내', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: context.appColors.textSecondary)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'API 키는 귀하의 계정에만 저장되며, AI 기능 처리에만 사용됩니다. 제3자와 공유되지 않습니다.',
                  style: TextStyle(fontSize: 12, color: context.appColors.textHint, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
