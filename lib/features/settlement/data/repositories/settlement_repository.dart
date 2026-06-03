import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/settlement_model.dart';

class SettlementRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<SettlementResult> calculateSettlement(String projectId) async {
    // confirmedAt 불등식 필터 제거 → 클라이언트에서 필터 (인덱스 오류 방지)
    final snapshot = await _firestore
        .collection('transactions')
        .where('projectId', isEqualTo: projectId)
        .get();

    final memberSpent = <String, double>{};
    for (final doc in snapshot.docs) {
      // 미확정 트랜잭션 및 수입 제외
      if (doc['confirmedAt'] == null) continue;
      if ((doc['type'] as String? ?? 'expense') == 'income') continue;

      final userId = doc['userId'] as String;
      final amount = (doc['amount'] as num).toDouble();
      memberSpent[userId] = (memberSpent[userId] ?? 0) + amount;
    }

    if (memberSpent.isEmpty) {
      return SettlementResult(
        projectId: projectId,
        memberSpent: {},
        totalSpent: 0,
        averageSpent: 0,
        settlements: [],
        calculatedAt: DateTime.now(),
      );
    }

    final total = memberSpent.values.fold(0.0, (a, b) => a + b);
    final average = total / memberSpent.length;
    final settlements = _calculateMinTransfers(memberSpent, average);

    return SettlementResult(
      projectId: projectId,
      memberSpent: memberSpent,
      totalSpent: total,
      averageSpent: average,
      settlements: settlements,
      calculatedAt: DateTime.now(),
    );
  }

  Future<void> saveSettlement(SettlementResult result) async {
    await _firestore.collection('settlements').add({
      'projectId': result.projectId,
      'totalSpent': result.totalSpent,
      'averageSpent': result.averageSpent,
      'memberSpent': result.memberSpent,
      'settlements': result.settlements
          .map((s) => {'fromUserId': s.fromUserId, 'toUserId': s.toUserId, 'amount': s.amount})
          .toList(),
      'completedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<CompletedSettlement>> getSettlementHistory(String projectId) async {
    final snapshot = await _firestore
        .collection('settlements')
        .where('projectId', isEqualTo: projectId)
        .orderBy('completedAt', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => CompletedSettlement.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  List<SettlementItem> _calculateMinTransfers(Map<String, double> spent, double average) {
    final balances = spent.map((uid, amount) => MapEntry(uid, amount - average));
    final creditors = balances.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final debtors = balances.entries.where((e) => e.value < 0).toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    final result = <SettlementItem>[];
    var ci = 0;
    var di = 0;
    var creditorBalance = ci < creditors.length ? creditors[ci].value : 0.0;
    var debtorBalance = di < debtors.length ? debtors[di].value : 0.0;

    while (ci < creditors.length && di < debtors.length) {
      final transfer = creditorBalance < -debtorBalance ? creditorBalance : -debtorBalance;
      result.add(SettlementItem(
        fromUserId: debtors[di].key,
        toUserId: creditors[ci].key,
        amount: transfer,
      ));
      creditorBalance -= transfer;
      debtorBalance += transfer;

      if (creditorBalance < 0.01) {
        ci++;
        if (ci < creditors.length) creditorBalance = creditors[ci].value;
      }
      if (debtorBalance > -0.01) {
        di++;
        if (di < debtors.length) debtorBalance = debtors[di].value;
      }
    }

    return result;
  }
}
