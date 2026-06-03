import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../project/domain/models/project_model.dart';
import '../../../project/presentation/providers/project_provider.dart';
import '../../data/repositories/allocation_repository.dart';
import '../../domain/models/allocation_model.dart';

class AllocationScreen extends ConsumerStatefulWidget {
  final ProjectModel fromProject;

  const AllocationScreen({super.key, required this.fromProject});

  @override
  ConsumerState<AllocationScreen> createState() => _AllocationScreenState();
}

class _AllocationScreenState extends ConsumerState<AllocationScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  ProjectModel? _selectedTarget;
  AllocationFrequency _frequency = AllocationFrequency.once;
  bool _isLoading = false;
  final _repo = AllocationRepository();

  @override
  void dispose() {
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0 || _selectedTarget == null) return;

    final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
    final desc = _descController.text.trim().isEmpty
        ? '예산 이전: ${widget.fromProject.name} → ${_selectedTarget!.name}'
        : _descController.text.trim();

    setState(() => _isLoading = true);
    try {
      if (_frequency == AllocationFrequency.once) {
        await _repo.allocate(
          fromProjectId: widget.fromProject.id,
          toProjectId: _selectedTarget!.id,
          amount: amount,
          description: desc,
          userId: uid,
        );
      } else {
        await _repo.createRecurring(
          fromProjectId: widget.fromProject.id,
          toProjectId: _selectedTarget!.id,
          amount: amount,
          description: desc,
          frequency: _frequency,
          userId: uid,
        );
      }
      ref.invalidate(projectBalanceProvider(widget.fromProject.id));
      ref.invalidate(projectBalanceProvider(_selectedTarget!.id));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subProjectsAsync = ref.watch(subProjectsProvider(widget.fromProject.id));

    return Scaffold(
      appBar: AppBar(title: const Text('예산 이전')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '출처: ${widget.fromProject.icon ?? "📁"} ${widget.fromProject.name}',
              style: TextStyle(color: context.appColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            const Text('이전할 가계부', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            subProjectsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('오류: $e'),
              data: (subs) => subs.isEmpty
                  ? Text('하위 가계부가 없습니다.', style: TextStyle(color: context.appColors.textSecondary))
                  : Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subs.map((sub) {
                        final selected = _selectedTarget?.id == sub.id;
                        return ChoiceChip(
                          label: Text('${sub.icon ?? "📁"} ${sub.name}'),
                          selected: selected,
                          onSelected: (_) => setState(() => _selectedTarget = sub),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(color: selected ? Colors.white : context.appColors.textPrimary),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '금액', prefixText: '₩ '),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: '설명 (선택)',
                hintText: '예산 이전: ${widget.fromProject.name} → ${_selectedTarget?.name ?? "..."}',
              ),
            ),
            const SizedBox(height: 20),
            const Text('반복 설정', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                _freqChip(AllocationFrequency.once, '1회'),
                const SizedBox(width: 8),
                _freqChip(AllocationFrequency.monthly, '매월 반복'),
              ],
            ),
            if (_frequency == AllocationFrequency.monthly) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.primary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '매월 오늘 날짜에 자동으로 이전됩니다.',
                        style: TextStyle(fontSize: 13, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: (_isLoading || _selectedTarget == null) ? null : _submit,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('이전하기'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _freqChip(AllocationFrequency freq, String label) {
    final selected = _frequency == freq;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _frequency = freq),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: selected ? Colors.white : context.appColors.textPrimary),
    );
  }
}
