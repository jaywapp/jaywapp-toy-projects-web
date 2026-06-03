import 'package:equatable/equatable.dart';

enum TransactionType { income, expense }

enum TransactionCategory {
  food,
  transport,
  shopping,
  leisure,
  health,
  housing,
  education,
  other;

  String get label => switch (this) {
        food => '식비',
        transport => '교통',
        shopping => '쇼핑',
        leisure => '여가',
        health => '의료',
        housing => '주거',
        education => '교육',
        other => '기타',
      };

  String get emoji => switch (this) {
        food => '🍔',
        transport => '🚌',
        shopping => '🛍️',
        leisure => '🎮',
        health => '💊',
        housing => '🏠',
        education => '📚',
        other => '💡',
      };
}

class AiSuggestion {
  final String projectId;
  final double confidence;
  final String reason;

  const AiSuggestion({
    required this.projectId,
    required this.confidence,
    required this.reason,
  });

  factory AiSuggestion.fromMap(Map<String, dynamic> data) {
    return AiSuggestion(
      projectId: data['projectId'] ?? '',
      confidence: (data['confidence'] ?? 0).toDouble(),
      reason: data['reason'] ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'projectId': projectId,
        'confidence': confidence,
        'reason': reason,
      };
}

class TransactionModel extends Equatable {
  final String id;
  final String projectId;
  final String userId;
  final double amount;
  final String description;
  final TransactionType type;
  final TransactionCategory category;
  final String? rawInput;
  final AiSuggestion? aiSuggestion;
  final DateTime? confirmedAt;
  final DateTime date;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.projectId,
    required this.userId,
    required this.amount,
    required this.description,
    this.type = TransactionType.expense,
    this.category = TransactionCategory.other,
    this.rawInput,
    this.aiSuggestion,
    this.confirmedAt,
    required this.date,
    required this.createdAt,
  });

  bool get isConfirmed => confirmedAt != null;
  bool get isIncome => type == TransactionType.income;

  factory TransactionModel.fromFirestore(Map<String, dynamic> data, String id) {
    return TransactionModel(
      id: id,
      projectId: data['projectId'] ?? '',
      userId: data['userId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      type: TransactionType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => TransactionType.expense,
      ),
      category: TransactionCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => TransactionCategory.other,
      ),
      rawInput: data['rawInput'],
      aiSuggestion: data['aiSuggestion'] != null
          ? AiSuggestion.fromMap(data['aiSuggestion'])
          : null,
      confirmedAt: data['confirmedAt']?.toDate(),
      date: data['date']?.toDate() ?? DateTime.now(),
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'projectId': projectId,
        'userId': userId,
        'amount': amount,
        'description': description,
        'type': type.name,
        'category': category.name,
        'rawInput': rawInput,
        'aiSuggestion': aiSuggestion?.toMap(),
        'confirmedAt': confirmedAt,
        'date': date,
        'createdAt': createdAt,
      };

  @override
  List<Object?> get props => [id, projectId, userId, amount, description, date];
}
