import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../project/domain/models/project_model.dart';
import '../../../project/presentation/providers/project_provider.dart';
import '../../../transaction/data/repositories/transaction_repository.dart';
import '../../../transaction/domain/models/transaction_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/ai_input_provider.dart';

class AiInputScreen extends ConsumerStatefulWidget {
  final String? initialProjectId;

  const AiInputScreen({super.key, this.initialProjectId});

  @override
  ConsumerState<AiInputScreen> createState() => _AiInputScreenState();
}

class _AiInputScreenState extends ConsumerState<AiInputScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiState = ref.watch(aiInputProvider);

    ref.listen(aiInputProvider, (previous, next) {
      if (next.status == AiInputStatus.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지출이 기록되었습니다!'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
      if (next.error != null && previous?.error != next.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppColors.error),
        );
      }
    });

    // AI 확인 화면은 탭 없이 전체 표시
    if (aiState.status == AiInputStatus.confirm || aiState.status == AiInputStatus.saving) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('지출 확인'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => ref.read(aiInputProvider.notifier).reset(),
          ),
        ),
        body: _ConfirmView(aiState: aiState),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('지출 입력'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome, size: 18), text: 'AI 입력'),
            Tab(icon: Icon(Icons.edit_outlined, size: 18), text: '직접 입력'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InputView(
            controller: _controller,
            aiState: aiState,
            initialProjectId: widget.initialProjectId,
          ),
          _ManualInputView(initialProjectId: widget.initialProjectId),
        ],
      ),
    );
  }
}

// ─── AI 입력 탭 ───────────────────────────────────────────────

class _InputView extends ConsumerWidget {
  final TextEditingController controller;
  final AiInputState aiState;
  final String? initialProjectId;

  const _InputView({
    required this.controller,
    required this.aiState,
    this.initialProjectId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAnalyzing = aiState.status == AiInputStatus.analyzing;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('지출 내용을 입력하세요', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('텍스트로 입력하거나 영수증/캡처 이미지를 올려주세요', style: TextStyle(color: context.appColors.textSecondary)),
          const SizedBox(height: 24),
          TextField(
            controller: controller,
            autofocus: true,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: '예: 스타벅스 6500원, 점심 12000원...',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 16),
          _ExampleChips(controller: controller),
          const SizedBox(height: 16),
          _buildImageButtons(context, ref, isAnalyzing),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: isAnalyzing || controller.text.trim().isEmpty
                ? null
                : () => ref.read(aiInputProvider.notifier).analyze(controller.text.trim()),
            icon: isAnalyzing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.auto_awesome),
            label: Text(isAnalyzing ? 'AI 분석 중...' : 'AI로 분석하기'),
          ),
        ],
      ),
    );
  }

  Widget _buildImageButtons(BuildContext context, WidgetRef ref, bool isAnalyzing) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isAnalyzing ? null : () => _pickImage(ref, ImageSource.camera),
            icon: const Icon(Icons.camera_alt_outlined, size: 18),
            label: const Text('카메라'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.appColors.textSecondary,
              side: BorderSide(color: context.appColors.textHint),
              minimumSize: const Size(0, 44),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: isAnalyzing ? null : () => _pickImage(ref, ImageSource.gallery),
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('갤러리'),
            style: OutlinedButton.styleFrom(
              foregroundColor: context.appColors.textSecondary,
              side: BorderSide(color: context.appColors.textHint),
              minimumSize: const Size(0, 44),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage(WidgetRef ref, ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 70, maxWidth: 1024);
    if (picked == null) return;
    await ref.read(aiInputProvider.notifier).analyzeImage(File(picked.path));
  }
}

class _ExampleChips extends StatelessWidget {
  final TextEditingController controller;

  const _ExampleChips({required this.controller});

  @override
  Widget build(BuildContext context) {
    final examples = ['스타벅스 6500원', '점심 12000원', '교통카드 1250원', '마트 35000원'];
    return Wrap(
      spacing: 8,
      children: examples.map((e) => ActionChip(
        label: Text(e, style: const TextStyle(fontSize: 12)),
        onPressed: () => controller.text = e,
      )).toList(),
    );
  }
}

// ─── 수동 입력 탭 ─────────────────────────────────────────────

class _ManualInputView extends ConsumerStatefulWidget {
  final String? initialProjectId;

  const _ManualInputView({this.initialProjectId});

  @override
  ConsumerState<_ManualInputView> createState() => _ManualInputViewState();
}

class _ManualInputViewState extends ConsumerState<_ManualInputView> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  TransactionCategory _category = TransactionCategory.other;
  DateTime _date = DateTime.now();
  ProjectModel? _selectedProject;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('금액을 입력해주세요.')),
      );
      return;
    }
    final desc = _descController.text.trim();
    if (desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('내용을 입력해주세요.')),
      );
      return;
    }
    if (_selectedProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('가계부를 선택해주세요.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
      final repo = TransactionRepository();
      final pending = await repo.createPendingTransaction(
        projectId: _selectedProject!.id,
        userId: uid,
        amount: amount,
        description: desc,
        rawInput: desc,
        aiSuggestion: AiSuggestion(
          projectId: _selectedProject!.id,
          confidence: 1.0,
          reason: '수동 입력',
        ),
        date: _date,
        category: _category,
      );
      await repo.confirmTransaction(
        transactionId: pending.id,
        projectId: _selectedProject!.id,
      );
      ref.invalidate(projectBalanceProvider(_selectedProject!.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('지출이 기록되었습니다!'), backgroundColor: AppColors.success),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final projectsAsync = ref.watch(userProjectsProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _descController,
            decoration: const InputDecoration(labelText: '내용', hintText: '예: 스타벅스 아메리카노'),
            autofocus: false,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: '금액', prefixText: '₩ '),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<TransactionCategory>(
            value: _category,
            decoration: const InputDecoration(labelText: '카테고리'),
            items: TransactionCategory.values
                .map((c) => DropdownMenuItem(value: c, child: Text('${c.emoji} ${c.label}')))
                .toList(),
            onChanged: (v) => setState(() => _category = v!),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '날짜',
                suffixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              child: Text(DateFormat('yyyy년 M월 d일').format(_date)),
            ),
          ),
          const SizedBox(height: 12),
          projectsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('가계부 로드 실패: $e'),
            data: (projects) {
              if (_selectedProject == null && projects.isNotEmpty) {
                final initial = widget.initialProjectId != null
                    ? projects.firstWhere(
                        (p) => p.id == widget.initialProjectId,
                        orElse: () => projects.first,
                      )
                    : projects.first;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _selectedProject = initial);
                });
              }
              return DropdownButtonFormField<ProjectModel>(
                value: _selectedProject,
                decoration: const InputDecoration(labelText: '가계부'),
                items: projects
                    .map((p) => DropdownMenuItem(
                          value: p,
                          child: Text('${p.icon ?? '📁'} ${p.name}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedProject = v),
              );
            },
          ),
          const SizedBox(height: 28),
          ElevatedButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('지출 기록'),
          ),
        ],
      ),
    );
  }
}

// ─── AI 확인 화면 ─────────────────────────────────────────────

class _ConfirmView extends ConsumerWidget {
  final AiInputState aiState;

  const _ConfirmView({required this.aiState});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = aiState.result!;
    final formatter = NumberFormat('#,###', 'ko_KR');
    final isSaving = aiState.status == AiInputStatus.saving;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI 분석 결과', style: TextStyle(color: context.appColors.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '₩${formatter.format(result.amount)}',
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.primary),
                  ),
                  const SizedBox(height: 4),
                  Text(result.description, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(
                    DateFormat('yyyy년 M월 d일').format(result.date),
                    style: TextStyle(color: context.appColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.appColors.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${result.category.emoji} ${result.category.label}',
                      style: TextStyle(fontSize: 12, color: context.appColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('가계부 선택', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: aiState.availableProjects.map((project) {
                final isSelected = aiState.selectedProject?.id == project.id;
                final isSuggested = aiState.suggestedProject?.id == project.id;
                return ListTile(
                  leading: Text(project.icon ?? '📁', style: const TextStyle(fontSize: 20)),
                  title: Row(
                    children: [
                      Text(project.name),
                      if (isSuggested) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'AI 추천 ${(result.confidence * 100).toInt()}%',
                            style: const TextStyle(color: AppColors.primary, fontSize: 10),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: isSuggested
                      ? Text(result.reason, style: TextStyle(fontSize: 11, color: context.appColors.textSecondary))
                      : null,
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: AppColors.primary)
                      : Icon(Icons.circle_outlined, color: context.appColors.textHint),
                  selected: isSelected,
                  onTap: () => ref.read(aiInputProvider.notifier).selectProject(project),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isSaving ? null : () => ref.read(aiInputProvider.notifier).reset(),
                  child: const Text('다시 입력'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: isSaving ? null : () => ref.read(aiInputProvider.notifier).confirm(),
                  child: isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('확인'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
