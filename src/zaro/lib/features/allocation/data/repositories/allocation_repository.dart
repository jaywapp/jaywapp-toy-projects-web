import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/allocation_model.dart';

class AllocationRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// 수동 또는 최초 예산 이전 실행
  Future<void> allocate({
    required String fromProjectId,
    required String toProjectId,
    required double amount,
    required String description,
    required String userId,
  }) async {
    final now = DateTime.now();
    final batch = _firestore.batch();

    final fromRef = _firestore.collection('transactions').doc();
    final toRef = _firestore.collection('transactions').doc();

    // 상위 프로젝트: 지출
    batch.set(fromRef, {
      'projectId': fromProjectId,
      'userId': userId,
      'amount': amount,
      'description': description,
      'type': 'expense',
      'linkedTransactionId': toRef.id,
      'confirmedAt': now,
      'date': now,
      'createdAt': now,
    });

    // 하위 프로젝트: 수입
    batch.set(toRef, {
      'projectId': toProjectId,
      'userId': userId,
      'amount': amount,
      'description': description,
      'type': 'income',
      'linkedTransactionId': fromRef.id,
      'confirmedAt': now,
      'date': now,
      'createdAt': now,
    });

    await batch.commit();
  }

  /// 반복 이전 설정 저장
  Future<RecurringAllocation> createRecurring({
    required String fromProjectId,
    required String toProjectId,
    required double amount,
    required String description,
    required AllocationFrequency frequency,
    required String userId,
  }) async {
    final now = DateTime.now();
    final nextDate = _calcNextDate(now, frequency);

    // 최초 즉시 실행
    await allocate(
      fromProjectId: fromProjectId,
      toProjectId: toProjectId,
      amount: amount,
      description: description,
      userId: userId,
    );

    final data = {
      'fromProjectId': fromProjectId,
      'toProjectId': toProjectId,
      'amount': amount,
      'description': description,
      'frequency': frequency.name,
      'nextExecutionDate': nextDate,
      'isActive': true,
      'createdByUserId': userId,
      'createdAt': now,
    };

    final ref = await _firestore.collection('recurringAllocations').add(data);
    final doc = await ref.get();
    return RecurringAllocation.fromFirestore(doc.data()!, doc.id);
  }

  Future<List<RecurringAllocation>> getRecurringAllocations(String projectId) async {
    final snapshot = await _firestore
        .collection('recurringAllocations')
        .where('fromProjectId', isEqualTo: projectId)
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs
        .map((doc) => RecurringAllocation.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<void> deactivateRecurring(String allocationId) async {
    await _firestore.collection('recurringAllocations').doc(allocationId).update({'isActive': false});
  }

  DateTime _calcNextDate(DateTime from, AllocationFrequency frequency) {
    switch (frequency) {
      case AllocationFrequency.monthly:
        return DateTime(from.year, from.month + 1, from.day);
      case AllocationFrequency.once:
        return from;
    }
  }
}
