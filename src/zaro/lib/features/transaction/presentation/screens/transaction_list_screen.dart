import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/theme_colors.dart';
import '../../../../core/services/csv_export_service.dart';
import '../../domain/models/transaction_model.dart';
import '../../data/repositories/transaction_repository.dart';
import '../providers/transaction_provider.dart';
import '../../../ai_input/presentation/providers/ai_input_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class TransactionListScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String projectName;

  const TransactionListScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  ConsumerState<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends ConsumerState<TransactionListScreen> {
  final Set<TransactionCategory> _selectedCategories = {};
  bool _isSearching = false;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  double? _minAmount;
  double? _maxAmount;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(projectTransactionsProvider(widget.projectId));

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? Builder(builder: (context) {
                final fgColor = Theme.of(context).appBarTheme.foregroundColor ?? Colors.white;
                return TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: TextStyle(color: fgColor),
                  cursorColor: fgColor,
                  decoration: InputDecoration(
                    hintText: '검색...',
                    hintStyle: TextStyle(color: fgColor.withValues(alpha: 0.5)),
                    border: InputBorder.none,
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                );
              })
            : Text('${widget.projectName} 지출 내역'),
        actions: [
          if (!_isSearching)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.filter_alt_outlined),
                  tooltip: '금액 필터',
                  onPressed: () => _showAmountFilter(context),
                ),
                if (_minAmount != null || _maxAmount != null || _startDate != null || _endDate != null)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          if (!_isSearching)
            transactionsAsync.maybeWhen(
              data: (transactions) => IconButton(
                icon: const Icon(Icons.download_outlined),
                tooltip: 'CSV 내보내기',
                onPressed: transactions.isEmpty
                    ? null
                    : () => _export(context, transactions),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
        ],
      ),
      body: transactionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (transactions) {
          var filtered = _selectedCategories.isEmpty
              ? transactions
              : transactions.where((t) => _selectedCategories.contains(t.category)).toList();
          if (_searchQuery.isNotEmpty) {
            final q = _searchQuery.toLowerCase();
            filtered = filtered.where((t) => t.description.toLowerCase().contains(q)).toList();
          }
          if (_minAmount != null) {
            filtered = filtered.where((t) => t.amount >= _minAmount!).toList();
          }
          if (_maxAmount != null) {
            filtered = filtered.where((t) => t.amount <= _maxAmount!).toList();
          }
          if (_startDate != null) {
            filtered = filtered.where((t) => !t.date.isBefore(_startDate!)).toList();
          }
          if (_endDate != null) {
            final endOfDay = DateTime(_endDate!.year, _endDate!.month, _endDate!.day, 23, 59, 59);
            filtered = filtered.where((t) => !t.date.isAfter(endOfDay)).toList();
          }
          return Column(
            children: [
              if (!_isSearching) _buildCategoryFilter(transactions),
              Expanded(
                child: filtered.isEmpty
                    ? _buildEmpty()
                    : _buildList(filtered),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'income_fab',
            mini: true,
            backgroundColor: Colors.teal,
            tooltip: '수입 추가',
            onPressed: () => _showAddIncomeSheet(context),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'ai_expense_fab',
            backgroundColor: AppColors.primary,
            tooltip: 'AI 지출 입력',
            onPressed: () => context.push('/ai-input?projectId=${widget.projectId}'),
            child: const Icon(Icons.auto_awesome),
          ),
        ],
      ),
    );
  }

  void _showAddIncomeSheet(BuildContext context) {
    final amountController = TextEditingController();
    final descController = TextEditingController(text: '수입');
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                      color: context.appColors.textHint,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('수입 추가', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 16),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: '내용'),
                  autofocus: true,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: '금액 (원)', prefixText: '₩ '),
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setS(() => selectedDate = picked);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '날짜',
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(DateFormat('yyyy년 M월 d일').format(selectedDate)),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                    onPressed: () async {
                      final amount = double.tryParse(amountController.text);
                      if (amount == null || amount <= 0) return;
                      final desc = descController.text.trim().isEmpty ? '수입' : descController.text.trim();
                      final uid = ref.read(authStateProvider).valueOrNull?.uid ?? '';
                      final repo = TransactionRepository();
                      await repo.createConfirmedTransaction(
                        projectId: widget.projectId,
                        userId: uid,
                        amount: amount,
                        description: desc,
                        type: TransactionType.income,
                        category: TransactionCategory.other,
                        date: selectedDate,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('수입 추가'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _export(BuildContext context, List<TransactionModel> transactions) async {
    try {
      await CsvExportService.export(
        transactions: transactions,
        projectName: widget.projectName,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              kIsWeb ? 'CSV 파일이 다운로드되었습니다.' : 'CSV가 클립보드에 복사되었습니다.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e')),
        );
      }
    }
  }

  void _showAmountFilter(BuildContext context) {
    final minCtrl = TextEditingController(text: _minAmount?.toInt().toString() ?? '');
    final maxCtrl = TextEditingController(text: _maxAmount?.toInt().toString() ?? '');
    final dateFmt = DateFormat('yyyy.MM.dd', 'ko_KR');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('필터', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 16),
              const Text('금액 범위', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: '최소 금액', prefixText: '₩ '),
                    ),
                  ),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('~')),
                  Expanded(
                    child: TextField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(labelText: '최대 금액', prefixText: '₩ '),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('날짜 범위', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () async {
                  final range = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _startDate != null && _endDate != null
                        ? DateTimeRange(start: _startDate!, end: _endDate!)
                        : null,
                    locale: const Locale('ko'),
                  );
                  if (range != null) {
                    setState(() {
                      _startDate = range.start;
                      _endDate = range.end;
                    });
                    setSheet(() {});
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: context.appColors.textHint),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _startDate != null && _endDate != null
                              ? '${dateFmt.format(_startDate!)} ~ ${dateFmt.format(_endDate!)}'
                              : _startDate != null
                                  ? '${dateFmt.format(_startDate!)} ~ 종료 없음'
                                  : '날짜 범위 선택',
                          style: TextStyle(
                            color: _startDate != null ? null : context.appColors.textHint,
                          ),
                        ),
                      ),
                      if (_startDate != null || _endDate != null)
                        GestureDetector(
                          onTap: () {
                            setState(() { _startDate = null; _endDate = null; });
                            setSheet(() {});
                          },
                          child: Icon(Icons.close, size: 18, color: context.appColors.textHint),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _minAmount = null;
                          _maxAmount = null;
                          _startDate = null;
                          _endDate = null;
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('전체 초기화'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _minAmount = double.tryParse(minCtrl.text);
                          _maxAmount = double.tryParse(maxCtrl.text);
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('적용'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryFilter(List<TransactionModel> transactions) {
    final usedCategories = transactions
        .map((t) => t.category)
        .toSet()
        .toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    if (usedCategories.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          FilterChip(
            label: const Text('전체'),
            selected: _selectedCategories.isEmpty,
            onSelected: (_) => setState(() => _selectedCategories.clear()),
            showCheckmark: false,
          ),
          const SizedBox(width: 6),
          ...usedCategories.map((cat) => Padding(
            padding: const EdgeInsets.only(right: 6),
            child: FilterChip(
              label: Text('${cat.emoji} ${cat.label}'),
              selected: _selectedCategories.contains(cat),
              onSelected: (_) => setState(() {
                if (_selectedCategories.contains(cat)) {
                  _selectedCategories.remove(cat);
                } else {
                  _selectedCategories.add(cat);
                }
              }),
              showCheckmark: false,
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    final hasFilter = _selectedCategories.isNotEmpty || _minAmount != null || _maxAmount != null || _startDate != null || _endDate != null || _searchQuery.isNotEmpty;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: context.appColors.textHint),
          const SizedBox(height: 16),
          Text(
            hasFilter ? '조건에 맞는 내역이 없습니다' : '지출 내역이 없습니다',
            style: TextStyle(color: context.appColors.textSecondary),
          ),
          if (!hasFilter) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => context.push('/ai-input?projectId=${widget.projectId}'),
              icon: const Icon(Icons.auto_awesome, size: 16),
              label: const Text('첫 지출 입력'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildList(List<TransactionModel> transactions) {
    final grouped = _groupByDate(transactions);
    final formatter = NumberFormat('#,###', 'ko_KR');

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped[index];
        if (entry is _DateHeader) {
          return _buildDateHeader(entry.date, entry.total, formatter);
        }
        final tx = entry as TransactionModel;
        return _TransactionTile(transaction: tx, formatter: formatter);
      },
    );
  }

  List<dynamic> _groupByDate(List<TransactionModel> transactions) {
    final result = <dynamic>[];
    String? lastDate;
    double dayTotal = 0;
    int headerIndex = -1;

    for (final tx in transactions) {
      final dateStr = DateFormat('yyyy-MM-dd').format(tx.date);
      if (dateStr != lastDate) {
        if (headerIndex >= 0) {
          result[headerIndex] = _DateHeader(
            date: (result[headerIndex] as _DateHeader).date,
            total: dayTotal,
          );
        }
        dayTotal = 0;
        headerIndex = result.length;
        result.add(_DateHeader(date: tx.date, total: 0));
        lastDate = dateStr;
      }
      dayTotal += tx.isIncome ? tx.amount : -tx.amount;
      result.add(tx);
    }

    if (headerIndex >= 0) {
      result[headerIndex] = _DateHeader(
        date: (result[headerIndex] as _DateHeader).date,
        total: dayTotal,
      );
    }

    return result;
  }

  Widget _buildDateHeader(DateTime date, double total, NumberFormat formatter) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('M월 d일 (E)', 'ko_KR').format(date),
            style: TextStyle(
              color: context.appColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            total >= 0
                ? '+₩${formatter.format(total)}'
                : '-₩${formatter.format(total.abs())}',
            style: TextStyle(
              color: total >= 0 ? Colors.teal : context.appColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateHeader {
  final DateTime date;
  final double total;
  _DateHeader({required this.date, required this.total});
}

class _TransactionTile extends ConsumerWidget {
  final TransactionModel transaction;
  final NumberFormat formatter;

  const _TransactionTile({required this.transaction, required this.formatter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cat = transaction.category;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: context.appColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            transaction.isIncome ? '💰' : cat.emoji,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ),
      title: Text(transaction.description, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Row(
        children: [
          Text(
            DateFormat('HH:mm').format(transaction.date),
            style: TextStyle(color: context.appColors.textHint, fontSize: 12),
          ),
          if (!transaction.isIncome) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: context.appColors.surface,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                cat.label,
                style: TextStyle(color: context.appColors.textSecondary, fontSize: 10),
              ),
            ),
          ],
          const Spacer(),
          Icon(Icons.edit_outlined, size: 11, color: context.appColors.textHint),
        ],
      ),
      trailing: Text(
        transaction.isIncome
            ? '+₩${formatter.format(transaction.amount)}'
            : '-₩${formatter.format(transaction.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: transaction.isIncome ? Colors.teal : context.appColors.textPrimary,
          fontSize: 15,
        ),
      ),
      onTap: () => _showEditSheet(context, ref),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TransactionEditSheet(
        transaction: transaction,
        onSave: (amount, description, date, category, type) async {
          final repo = ref.read(transactionRepositoryProvider);
          await repo.updateTransaction(
            transactionId: transaction.id,
            amount: amount,
            description: description,
            date: date,
            category: category,
            type: type,
          );
        },
        onDelete: () async {
          final repo = ref.read(transactionRepositoryProvider);
          await repo.deleteTransaction(transaction.id);
        },
      ),
    );
  }
}

class _TransactionEditSheet extends StatefulWidget {
  final TransactionModel transaction;
  final Future<void> Function(
    double amount,
    String description,
    DateTime date,
    TransactionCategory category,
    TransactionType type,
  ) onSave;
  final Future<void> Function() onDelete;

  const _TransactionEditSheet({
    required this.transaction,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_TransactionEditSheet> createState() => _TransactionEditSheetState();
}

class _TransactionEditSheetState extends State<_TransactionEditSheet> {
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late TransactionCategory _selectedCategory;
  late TransactionType _selectedType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.transaction.amount.toInt().toString(),
    );
    _descriptionController = TextEditingController(text: widget.transaction.description);
    _selectedDate = widget.transaction.date;
    _selectedCategory = widget.transaction.category;
    _selectedType = widget.transaction.type;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) return;
    final description = _descriptionController.text.trim();
    if (description.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      await widget.onSave(amount, description, _selectedDate, _selectedCategory, _selectedType);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('저장 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('내역 삭제'),
        content: const Text('이 내역을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      await widget.onDelete();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('삭제 실패: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('yyyy년 M월 d일').format(_selectedDate);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: context.appColors.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('내역 수정', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const Spacer(),
                TextButton.icon(
                  onPressed: _isLoading ? null : _delete,
                  icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                  label: const Text('삭제', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(value: TransactionType.expense, label: Text('지출')),
                ButtonSegment(value: TransactionType.income, label: Text('수입')),
              ],
              selected: {_selectedType},
              onSelectionChanged: (s) => setState(() => _selectedType = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.primary,
                selectedForegroundColor: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: '내용'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '금액 (원)', prefixText: '₩ '),
            ),
            if (_selectedType == TransactionType.expense) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<TransactionCategory>(
                value: _selectedCategory,
                decoration: const InputDecoration(labelText: '카테고리'),
                items: TransactionCategory.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text('${c.emoji} ${c.label}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCategory = v!),
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(8),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: '날짜',
                  suffixIcon: Icon(Icons.calendar_today, size: 18),
                ),
                child: Text(dateLabel),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('저장'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
