import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/models/recurring_expense_model.dart';
import '../../domain/models/transaction_model.dart';

class RecurringExpenseRepository {
  final _db = FirebaseFirestore.instance;

  Future<List<RecurringExpense>> getRecurringExpenses(String projectId, {TransactionType? type}) async {
    final snapshot = await _db
        .collection('recurringExpenses')
        .where('projectId', isEqualTo: projectId)
        .where('isActive', isEqualTo: true)
        .get();
    final all = snapshot.docs
        .map((doc) => RecurringExpense.fromFirestore(doc.data(), doc.id))
        .toList();
    if (type == null) return all;
    return all.where((e) => e.type == type).toList();
  }

  Future<RecurringExpense> createRecurringExpense({
    required String projectId,
    required double amount,
    required String description,
    required TransactionCategory category,
    required int dayOfMonth,
    TransactionType type = TransactionType.expense,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');

    final data = {
      'projectId': projectId,
      'userId': uid,
      'amount': amount,
      'description': description,
      'category': category.name,
      'dayOfMonth': dayOfMonth,
      'isActive': true,
      'type': type.name,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final ref = await _db.collection('recurringExpenses').add(data);
    final doc = await ref.get();
    return RecurringExpense.fromFirestore(doc.data()!, doc.id);
  }

  Future<void> updateRecurringExpense({
    required String id,
    required double amount,
    required String description,
    required TransactionCategory category,
    required int dayOfMonth,
  }) async {
    await _db.collection('recurringExpenses').doc(id).update({
      'amount': amount,
      'description': description,
      'category': category.name,
      'dayOfMonth': dayOfMonth,
    });
  }

  Future<void> deactivate(String id) async {
    await _db.collection('recurringExpenses').doc(id).update({'isActive': false});
  }
}
