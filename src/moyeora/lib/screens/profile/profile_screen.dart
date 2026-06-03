import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/app_config.dart';
import '../../services/google_auth_service.dart';
import '../../services/image_upload_service.dart';
import '../../services/profile_policy.dart';
import '../../services/user_error_message.dart';
import '../../services/user_profile_service.dart';
import '../../utils/helpers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_loading_button.dart';
import '../../widgets/app_snackbar.dart';
import '../../widgets/section_header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.forceSetup = false, this.forceMessage});

  final bool forceSetup;
  final String? forceMessage;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nicknameController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nicknameFocus = FocusNode();

  bool _loading = false;
  bool _initialized = false;
  bool _removePhoto = false;
  double? _uploadProgress;

  Uint8List? _photoBytes;
  String? _photoMimeType;
  String? _photoFileName;

  bool get _useStorageUpload => AppConfig.enableStorageUpload;
  bool _hasProvider(User user, String providerId) =>
      user.providerData.any((provider) => provider.providerId == providerId);

  @override
  void initState() {
    super.initState();
    _nicknameController.addListener(_onTextChanged);
    _photoUrlController.addListener(_onTextChanged);
    _phoneController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_photoUrlController.text.trim().isNotEmpty) {
      _removePhoto = false;
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nicknameController.removeListener(_onTextChanged);
    _photoUrlController.removeListener(_onTextChanged);
    _phoneController.removeListener(_onTextChanged);
    _nicknameController.dispose();
    _photoUrlController.dispose();
    _phoneController.dispose();
    _nicknameFocus.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_loading) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 90,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photoBytes = bytes;
        _photoMimeType = picked.mimeType;
        _photoFileName = picked.name;
        _removePhoto = false;
      });
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '사진 파일을 불러오지 못했습니다.',
        type: AppSnackType.error,
      );
    }
  }

  void _clearPhoto() {
    if (_loading) return;
    setState(() {
      _photoBytes = null;
      _photoMimeType = null;
      _photoFileName = null;
      _removePhoto = true;
      _photoUrlController.clear();
    });
  }

  Future<void> _save() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _loading) return;

    final nickname = _nicknameController.text.trim();
    if (!ProfilePolicy.isValidRealName(nickname)) {
      AppSnackbar.show(
        context,
        message: '실명을 2~20자로 입력해 주세요. (한글/영문/공백)',
        type: AppSnackType.error,
      );
      return;
    }

    final rawPhone = _phoneController.text;
    final normalizedPhone = ProfilePolicy.normalizePhoneNumber(rawPhone);
    if (rawPhone.trim().isNotEmpty &&
        !ProfilePolicy.isValidPhoneNumber(rawPhone)) {
      AppSnackbar.show(
        context,
        message: '전화번호 형식이 올바르지 않습니다.',
        type: AppSnackType.error,
      );
      return;
    }

    setState(() => _loading = true);
    try {
      String? nextPhotoUrl;
      if (_useStorageUpload) {
        if (!_removePhoto) {
          final current = _photoUrlController.text.trim();
          nextPhotoUrl = current.isEmpty ? null : current;
        }
        if (_photoBytes != null) {
          setState(() => _uploadProgress = 0);
          nextPhotoUrl = await ImageUploadService.uploadProfilePhoto(
            uid: user.uid,
            bytes: _photoBytes!,
            mimeType: _photoMimeType,
            onProgress: (progress) {
              if (!mounted) return;
              setState(() => _uploadProgress = progress);
            },
          );
        }
      } else {
        final url = _photoUrlController.text.trim();
        nextPhotoUrl = url.isEmpty ? null : url;
      }

      await UserProfileService.saveUserProfile(
        uid: user.uid,
        nickname: nickname,
        photoUrl: nextPhotoUrl,
        phoneNumber: normalizedPhone.isEmpty ? null : normalizedPhone,
      );

      _removePhoto = false;
      _photoBytes = null;
      _photoMimeType = null;
      _photoFileName = null;
      _photoUrlController.text = nextPhotoUrl ?? '';

      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '프로필이 저장되었습니다.',
        type: AppSnackType.success,
      );
      if (widget.forceSetup) {
        // RootGate를 강제 재평가하여 업데이트된 프로필로 다음 화면으로 진행합니다.
        // profileStream 타임아웃으로 스트림이 닫혀있을 수 있으므로 직접 이동합니다.
        if (!mounted) return;
        context.go('/');
      } else {
        Navigator.of(context).maybePop();
      }
    } on TimeoutException {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '이미지 업로드 시간이 초과되었습니다. 네트워크 상태를 확인해 주세요.',
        type: AppSnackType.error,
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '프로필 저장 실패: ${e.code}',
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _uploadProgress = null;
        });
      }
    }
  }

  Future<void> _linkGoogleProvider() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _loading) return;
    if (_hasProvider(user, 'google.com')) {
      AppSnackbar.show(
        context,
        message: '이미 Google 계정이 연결되어 있습니다.',
        type: AppSnackType.info,
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final linked = await GoogleAuthService.linkCurrentUserWithGoogle();
      if (linked.user != null) {
        await UserProfileService.syncLinkedProvidersFromAuth(linked.user!);
      }
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Google 계정 연결이 완료되었습니다.',
        type: AppSnackType.success,
      );
    } on GoogleSignInCanceledException {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: 'Google 연결을 취소했습니다.',
        type: AppSnackType.info,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: toUserMessage(e),
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _linkEmailProvider() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _loading) return;
    if (_hasProvider(user, 'password')) {
      AppSnackbar.show(
        context,
        message: '이미 이메일 계정이 연결되어 있습니다.',
        type: AppSnackType.info,
      );
      return;
    }

    final emailController = TextEditingController(text: user.email ?? '');
    final passwordController = TextEditingController();
    final result = await showDialog<(String, String)?>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('이메일 계정 연결'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: '이메일'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: '비밀번호'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                final email = emailController.text.trim();
                final password = passwordController.text.trim();
                if (email.isEmpty || password.length < 6) return;
                Navigator.of(ctx).pop((email, password));
              },
              child: const Text('연결'),
            ),
          ],
        );
      },
    );
    emailController.dispose();
    passwordController.dispose();

    if (result == null) return;
    setState(() => _loading = true);
    try {
      final credential = EmailAuthProvider.credential(
        email: result.$1,
        password: result.$2,
      );
      final linked = await user.linkWithCredential(credential);
      if (linked.user != null) {
        await UserProfileService.syncLinkedProvidersFromAuth(linked.user!);
      }
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: '이메일 계정 연결이 완료되었습니다.',
        type: AppSnackType.success,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      AppSnackbar.show(
        context,
        message: toUserMessage(e),
        type: AppSnackType.error,
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _providerLabel(String providerId) {
    return switch (providerId) {
      'password' => '이메일',
      'google.com' => 'Google',
      'kakao.com' => 'Kakao',
      _ => providerId,
    };
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('로그인이 필요합니다.')));
    }

    final linkedProviderIds =
        user.providerData
            .map((e) => e.providerId)
            .where((e) => e.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    final profileStream = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots();

    final nickname = _nicknameController.text.trim();
    final previewUrl = _removePhoto ? '' : _photoUrlController.text.trim();
    final ImageProvider<Object>? photoProvider = _photoBytes != null
        ? MemoryImage(_photoBytes!)
        : (previewUrl.isNotEmpty ? NetworkImage(previewUrl) : null);
    final phoneNumber = _phoneController.text.trim();
    final canSaveName = ProfilePolicy.isValidRealName(nickname);
    final canSavePhone =
        phoneNumber.isEmpty || ProfilePolicy.isValidPhoneNumber(phoneNumber);

    return Scaffold(
      appBar: widget.forceSetup ? null : AppBar(title: const Text('회원정보')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: profileStream,
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          if (!_initialized && snapshot.hasData) {
            _initialized = true;
            _nicknameController.text =
                data['nickname']?.toString() ??
                data['displayName']?.toString() ??
                '';
            _photoUrlController.text = data['photoUrl']?.toString() ?? '';
            _phoneController.text = data['phoneNumber']?.toString() ?? '';
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.forceSetup)
                AppCard(child: Text(widget.forceMessage ?? '프로필 설정을 완료해 주세요.')),
              FutureBuilder<List<String>>(
                future: _loadProfileBadges(user.uid),
                builder: (context, badgeSnap) {
                  final badges = badgeSnap.data ?? const <String>[];
                  if (badges.isEmpty) return const SizedBox.shrink();
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('내 배지'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final badge in badges)
                              Chip(
                                label: Text(badge),
                                avatar: const ExcludeSemantics(
                                  child: Icon(
                                    Icons.verified_outlined,
                                    size: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SectionHeader(title: '회원정보', icon: Icons.person_outline),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('연결된 로그인 수단'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final provider in linkedProviderIds)
                          Chip(label: Text(_providerLabel(provider))),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('계정 연결'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _loading ? null : _linkGoogleProvider,
                          child: const Text('Google 연결'),
                        ),
                        OutlinedButton(
                          onPressed: _loading ? null : _linkEmailProvider,
                          child: const Text('이메일 연결'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 36,
                        backgroundImage: photoProvider,
                        child: photoProvider == null
                            ? Text(nickname.isEmpty ? '?' : nickname[0])
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nicknameController,
                      focusNode: _nicknameFocus,
                      enabled: !_loading,
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: '실명',
                        hintText: '실명을 입력해 주세요. (2~20자)',
                      ),
                    ),
                    if (nickname.isNotEmpty && !canSaveName)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          '한글/영문/공백만 사용해 실명을 입력해 주세요.',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 12),
                    if (_useStorageUpload) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _loading ? null : _pickPhoto,
                            icon: const Icon(Icons.upload_file_outlined),
                            label: const Text('사진 파일 선택'),
                          ),
                          if (_photoBytes != null || previewUrl.isNotEmpty)
                            OutlinedButton(
                              onPressed: _loading ? null : _clearPhoto,
                              child: const Text('사진 제거'),
                            ),
                        ],
                      ),
                      if (_photoFileName != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _photoFileName!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      if (_loading && _uploadProgress != null) ...[
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: _uploadProgress),
                        const SizedBox(height: 6),
                        Text(
                          '이미지 업로드 ${(100 * _uploadProgress!).round()}%',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ] else ...[
                      TextField(
                        controller: _photoUrlController,
                        enabled: !_loading,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: '사진 URL (선택)',
                          hintText: 'https://...',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: _loading
                                ? null
                                : () => AppSnackbar.show(
                                    context,
                                    message: '사진 URL을 입력하면 프로필 이미지가 변경됩니다.',
                                    type: AppSnackType.info,
                                  ),
                            child: const Text('사진 변경 안내'),
                          ),
                          const SizedBox(width: 8),
                          if (previewUrl.isNotEmpty)
                            OutlinedButton(
                              onPressed: _loading ? null : _clearPhoto,
                              child: const Text('사진 제거'),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneController,
                      enabled: !_loading,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _save(),
                      decoration: const InputDecoration(
                        labelText: '전화번호 (선택)',
                        hintText: '01012345678 또는 +821012345678',
                      ),
                    ),
                    if (phoneNumber.isNotEmpty && !canSavePhone)
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Text(
                          '전화번호 형식이 올바르지 않습니다.',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: AppLoadingButton(
                        loading: _loading,
                        enabled: canSaveName && canSavePhone,
                        label: '저장',
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Future<List<String>> _loadProfileBadges(String uid) async {
  final db = FirebaseFirestore.instance;
  final memberships = await db
      .collection('users')
      .doc(uid)
      .collection('memberships')
      .where('status', isEqualTo: 'active')
      .limit(1)
      .get();

  if (memberships.docs.isEmpty) return const <String>[];
  final groupId = memberships.docs.first.id;

  final memberDoc = await db
      .collection('groups')
      .doc(groupId)
      .collection('members')
      .doc(uid)
      .get();
  final role = memberDoc.data()?['role']?.toString() ?? 'member';

  final periodKey = currentPeriodKey();
  final leaderboardDoc = await db
      .collection('groups')
      .doc(groupId)
      .collection('leaderboards')
      .doc(periodKey)
      .get();

  final badges = <String>[];
  final attendanceTop =
      leaderboardDoc.data()?['attendanceTop'] as List<dynamic>? ?? const [];
  final activityTop =
      leaderboardDoc.data()?['activityTop'] as List<dynamic>? ?? const [];

  final attendanceRank = _rankInList(attendanceTop, uid);
  final activityRank = _rankInList(activityTop, uid);

  if (attendanceRank != null && attendanceRank <= 3) badges.add('출석왕');
  if (activityRank != null && activityRank <= 3) badges.add('활동왕');
  if (role == 'owner' || role == 'admin' || role == 'treasurer') {
    badges.add('운영 기여');
  }

  return badges;
}

int? _rankInList(List<dynamic> list, String uid) {
  for (var i = 0; i < list.length; i++) {
    final item = list[i];
    if (item is Map && item['uid']?.toString() == uid) {
      return i + 1;
    }
  }
  return null;
}
