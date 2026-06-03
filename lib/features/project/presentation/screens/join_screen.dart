import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../data/repositories/invite_repository.dart';

class JoinScreen extends ConsumerStatefulWidget {
  final String code;

  const JoinScreen({super.key, required this.code});

  @override
  ConsumerState<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends ConsumerState<JoinScreen> {
  final _repo = InviteRepository();
  _JoinState _state = _JoinState.loading;
  String? _projectId;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _resolveCode();
  }

  Future<void> _resolveCode() async {
    try {
      final projectId = await _repo.getProjectIdByCode(widget.code);
      if (!mounted) return;
      if (projectId == null) {
        setState(() {
          _state = _JoinState.invalid;
          _errorMessage = '유효하지 않거나 만료된 초대 코드입니다.';
        });
      } else {
        setState(() {
          _state = _JoinState.ready;
          _projectId = projectId;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _JoinState.invalid;
        _errorMessage = '오류가 발생했습니다: $e';
      });
    }
  }

  Future<void> _join() async {
    if (_projectId == null) return;
    setState(() => _state = _JoinState.joining);
    try {
      await _repo.joinProject(_projectId!);
      if (!mounted) return;
      context.go('/projects/$_projectId');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _JoinState.ready;
        _errorMessage = e.toString();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_errorMessage!), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('가계부 참여')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: switch (_state) {
            _JoinState.loading => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('초대 코드 확인 중...'),
                ],
              ),
            _JoinState.ready => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.group_add_outlined, size: 64, color: AppColors.primary),
                  const SizedBox(height: 24),
                  const Text(
                    '가계부에 참여하시겠습니까?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '초대 코드: ${widget.code}',
                    style: TextStyle(color: context.appColors.textSecondary, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _join,
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                      child: const Text('참여하기'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go('/projects'),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                      child: const Text('취소'),
                    ),
                  ),
                ],
              ),
            _JoinState.joining => const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('참여 중...'),
                ],
              ),
            _JoinState.invalid => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.link_off_outlined, size: 64, color: AppColors.error),
                  const SizedBox(height: 24),
                  Text(
                    _errorMessage ?? '초대 링크가 유효하지 않습니다.',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/projects'),
                      style: ElevatedButton.styleFrom(minimumSize: const Size(0, 48)),
                      child: const Text('홈으로'),
                    ),
                  ),
                ],
              ),
          },
        ),
      ),
    );
  }
}

enum _JoinState { loading, ready, joining, invalid }
