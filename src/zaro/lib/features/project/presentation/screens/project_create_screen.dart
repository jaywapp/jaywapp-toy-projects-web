import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../domain/models/project_model.dart';
import '../providers/project_provider.dart';

const _icons = ['📁', '🏠', '🚗', '✈️', '🍽️', '👶', '💰', '⚽', '🎮', '💼', '🛒', '💊'];

class ProjectCreateScreen extends ConsumerStatefulWidget {
  final String? parentProjectId;

  const ProjectCreateScreen({super.key, this.parentProjectId});

  @override
  ConsumerState<ProjectCreateScreen> createState() => _ProjectCreateScreenState();
}

class _ProjectCreateScreenState extends ConsumerState<ProjectCreateScreen> {
  final _nameController = TextEditingController();
  final _incomeController = TextEditingController();
  String _selectedIcon = '📁';
  ProjectType _selectedType = ProjectType.standalone;
  CurrencyCode _selectedCurrency = CurrencyCode.krw;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.parentProjectId != null) {
      _selectedType = ProjectType.sub;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final incomeText = _incomeController.text.replaceAll(',', '');
    if (name.isEmpty) return;
    final initialIncome = double.tryParse(incomeText) ?? 0;

    setState(() => _isLoading = true);
    try {
      await ref.read(projectNotifierProvider.notifier).createProject(
            name: name,
            icon: _selectedIcon,
            type: _selectedType,
            parentProjectId: widget.parentProjectId,
            initialIncome: initialIncome,
            currency: _selectedCurrency,
          );
      if (mounted) context.pop();
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
    return Scaffold(
      appBar: AppBar(title: const Text('새 가계부')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIconPicker(),
            const SizedBox(height: 24),
            _buildNameField(),
            const SizedBox(height: 16),
            _buildIncomeField(),
            if (widget.parentProjectId == null) ...[
              const SizedBox(height: 16),
              _buildTypeSelector(),
              const SizedBox(height: 16),
              _buildCurrencySelector(),
            ],
            const SizedBox(height: 32),
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildIconPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('아이콘', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _icons.map((icon) {
            final selected = icon == _selectedIcon;
            return GestureDetector(
              onTap: () => setState(() => _selectedIcon = icon),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary.withValues(alpha: 0.2) : context.appColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: selected ? Border.all(color: AppColors.primary, width: 2) : null,
                ),
                child: Center(child: Text(icon, style: const TextStyle(fontSize: 22))),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildNameField() {
    return TextField(
      controller: _nameController,
      decoration: const InputDecoration(labelText: '가계부 이름', hintText: '예: 생활비, 여행비'),
    );
  }

  Widget _buildIncomeField() {
    return TextField(
      controller: _incomeController,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: widget.parentProjectId != null ? '상위 프로젝트에서 할당받을 금액 (원)' : '초기 수입 (원)',
        hintText: '0',
        prefixText: '₩ ',
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('가계부 유형', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            _typeChip(ProjectType.standalone, '독립'),
            const SizedBox(width: 8),
            _typeChip(ProjectType.parent, '상위'),
          ],
        ),
      ],
    );
  }

  Widget _typeChip(ProjectType type, String label) {
    final selected = _selectedType == type;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _selectedType = type),
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(color: selected ? Colors.white : context.appColors.textPrimary),
    );
  }

  Widget _buildCurrencySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('통화', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        DropdownButtonFormField<CurrencyCode>(
          value: _selectedCurrency,
          decoration: const InputDecoration(labelText: '통화 선택'),
          items: CurrencyCode.values
              .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
              .toList(),
          onChanged: (v) => setState(() => _selectedCurrency = v!),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submit,
      child: _isLoading
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Text('만들기'),
    );
  }
}
