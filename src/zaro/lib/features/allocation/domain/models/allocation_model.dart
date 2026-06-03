enum AllocationFrequency { once, monthly }

class RecurringAllocation {
  final String id;
  final String fromProjectId;
  final String toProjectId;
  final double amount;
  final String description;
  final AllocationFrequency frequency;
  final DateTime nextExecutionDate;
  final bool isActive;
  final String createdByUserId;
  final DateTime createdAt;

  const RecurringAllocation({
    required this.id,
    required this.fromProjectId,
    required this.toProjectId,
    required this.amount,
    required this.description,
    required this.frequency,
    required this.nextExecutionDate,
    required this.isActive,
    required this.createdByUserId,
    required this.createdAt,
  });

  factory RecurringAllocation.fromFirestore(Map<String, dynamic> data, String id) {
    return RecurringAllocation(
      id: id,
      fromProjectId: data['fromProjectId'] ?? '',
      toProjectId: data['toProjectId'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      description: data['description'] ?? '',
      frequency: AllocationFrequency.values.firstWhere(
        (e) => e.name == data['frequency'],
        orElse: () => AllocationFrequency.once,
      ),
      nextExecutionDate: (data['nextExecutionDate'] as dynamic)?.toDate() ?? DateTime.now(),
      isActive: data['isActive'] ?? true,
      createdByUserId: data['createdByUserId'] ?? '',
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'fromProjectId': fromProjectId,
        'toProjectId': toProjectId,
        'amount': amount,
        'description': description,
        'frequency': frequency.name,
        'nextExecutionDate': nextExecutionDate,
        'isActive': isActive,
        'createdByUserId': createdByUserId,
        'createdAt': createdAt,
      };
}
