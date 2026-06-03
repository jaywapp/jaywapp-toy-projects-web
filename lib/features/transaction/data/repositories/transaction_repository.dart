import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/transaction_model.dart';
export '../../domain/models/transaction_model.dart' show TransactionCategory;

class TransactionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('transactions');

  Stream<List<TransactionModel>> watchProjectTransactions(String projectId) {
    return _col
        .where('projectId', isEqualTo: projectId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc.data(), doc.id))
            .where((tx) => tx.isConfirmed)
            .toList());
  }

  Future<List<TransactionModel>> getProjectTransactions(String projectId) async {
    final snapshot = await _col
        .where('projectId', isEqualTo: projectId)
        .orderBy('date', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => TransactionModel.fromFirestore(doc.data(), doc.id))
        .where((tx) => tx.isConfirmed)
        .toList();
  }

  Future<TransactionModel> createPendingTransaction({
    required String projectId,
    required String userId,
    required double amount,
    required String description,
    required String rawInput,
    required AiSuggestion aiSuggestion,
    required DateTime date,
    TransactionCategory category = TransactionCategory.other,
  }) async {
    final data = {
      'projectId': projectId,
      'userId': userId,
      'amount': amount,
      'description': description,
      'type': 'expense',
      'category': category.name,
      'rawInput': rawInput,
      'aiSuggestion': aiSuggestion.toMap(),
      'confirmedAt': null,
      'date': date,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final ref = await _col.add(data);
    final doc = await ref.get();
    return TransactionModel.fromFirestore(doc.data()!, doc.id);
  }

  Future<TransactionModel> confirmTransaction({
    required String transactionId,
    required String projectId,
  }) async {
    await _col.doc(transactionId).update({
      'projectId': projectId,
      'confirmedAt': FieldValue.serverTimestamp(),
    });

    final doc = await _col.doc(transactionId).get();
    return TransactionModel.fromFirestore(doc.data()!, doc.id);
  }

  Future<void> updateTransaction({
    required String transactionId,
    required double amount,
    required String description,
    required DateTime date,
    TransactionCategory? category,
    TransactionType? type,
  }) async {
    final updates = <String, dynamic>{
      'amount': amount,
      'description': description,
      'date': date,
    };
    if (category != null) updates['category'] = category.name;
    if (type != null) updates['type'] = type.name;
    await _col.doc(transactionId).update(updates);
  }

  Future<void> createConfirmedTransaction({
    required String projectId,
    required String userId,
    required double amount,
    required String description,
    required TransactionType type,
    required TransactionCategory category,
    required DateTime date,
  }) async {
    await _col.add({
      'projectId': projectId,
      'userId': userId,
      'amount': amount,
      'description': description,
      'type': type.name,
      'category': category.name,
      'confirmedAt': FieldValue.serverTimestamp(),
      'date': date,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _col.doc(transactionId).delete();
  }
}
