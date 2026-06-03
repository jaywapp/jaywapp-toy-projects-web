import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class SettlementItem {
  final String fromUserId;
  final String toUserId;
  final double amount;

  const SettlementItem({
    required this.fromUserId,
    required this.toUserId,
    required this.amount,
  });
}

class CompletedSettlement {
  final String id;
  final String projectId;
  final double totalSpent;
  final double averageSpent;
  final List<SettlementItem> settlements;
  final Map<String, double> memberSpent;
  final DateTime completedAt;

  const CompletedSettlement({
    required this.id,
    required this.projectId,
    required this.totalSpent,
    required this.averageSpent,
    required this.settlements,
    required this.memberSpent,
    required this.completedAt,
  });

  factory CompletedSettlement.fromFirestore(Map<String, dynamic> data, String id) {
    final items = (data['settlements'] as List<dynamic>? ?? []).map((s) {
      final m = s as Map<String, dynamic>;
      return SettlementItem(
        fromUserId: m['fromUserId'] as String,
        toUserId: m['toUserId'] as String,
        amount: (m['amount'] as num).toDouble(),
      );
    }).toList();

    final memberSpent = (data['memberSpent'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, (v as num).toDouble()),
    );

    return CompletedSettlement(
      id: id,
      projectId: data['projectId'] as String,
      totalSpent: (data['totalSpent'] as num).toDouble(),
      averageSpent: (data['averageSpent'] as num).toDouble(),
      settlements: items,
      memberSpent: memberSpent,
      completedAt: (data['completedAt'] as Timestamp).toDate(),
    );
  }
}

class SettlementResult extends Equatable {
  final String projectId;
  final Map<String, double> memberSpent;
  final double totalSpent;
  final double averageSpent;
  final List<SettlementItem> settlements;
  final DateTime calculatedAt;

  const SettlementResult({
    required this.projectId,
    required this.memberSpent,
    required this.totalSpent,
    required this.averageSpent,
    required this.settlements,
    required this.calculatedAt,
  });

  @override
  List<Object?> get props => [projectId, calculatedAt];
}
