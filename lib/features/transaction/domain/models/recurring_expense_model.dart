import 'transaction_model.dart';

class RecurringExpense {
  final String id;
  final String projectId;
  final String userId;
  final double amount;
  final String description;
  final TransactionCategory category;
  final int dayOfMonth;
  final bool isActive;
  final DateTime createdAt;
  final TransactionType type;

  const RecurringExpense({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.amount,
    required this.description,
    required this.category,
    required this.dayOfMonth,
    required this.isActive,
    required this.createdAt,
    this.type = TransactionType.expense,
  });

  bool get isIncome => type == TransactionType.income;

  factory RecurringExpense.fromFirestore(Map<String, dynamic> data, String id) {
    return RecurringExpense(
      id: id,
      projectId: data['projectId'] ?? '',
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      category: TransactionCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => TransactionCategory.other,
      ),
      dayOfMonth: (data['dayOfMonth'] ?? 1) as int,
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => TransactionType.expense,
      ),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'projectId': projectId,
        'userId': userId,
        'amount': amount,
        'description': description,
        'category': category.name,
        'dayOfMonth': dayOfMonth,
        'isActive': isActive,
        'createdAt': createdAt,
        'type': type.name,
      };
}
