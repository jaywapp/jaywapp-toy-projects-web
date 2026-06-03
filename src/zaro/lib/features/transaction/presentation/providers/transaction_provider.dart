import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/transaction_model.dart';
import '../../../ai_input/presentation/providers/ai_input_provider.dart';

final projectTransactionsProvider =
    StreamProvider.family<List<TransactionModel>, String>((ref, projectId) {
  return ref.read(transactionRepositoryProvider).watchProjectTransactions(projectId);
});
