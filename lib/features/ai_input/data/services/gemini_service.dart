import 'dart:convert';
import 'dart:io';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../project/domain/models/project_model.dart';
import '../../../transaction/domain/models/transaction_model.dart';

class GeminiService {
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  Future<AiAnalysisResult> analyzeExpense({
    required String userInput,
    required List<ProjectModel> projects,
    required String geminiApiKey,
  }) async {
    final callable = _functions.httpsCallable('analyzeExpense');
    final result = await callable.call({
      'userInput': userInput,
      'projects': _projectsPayload(projects),
      'geminiApiKey': geminiApiKey,
    });
    return AiAnalysisResult.fromMap(Map<String, dynamic>.from(result.data as Map));
  }

  Future<AiAnalysisResult> analyzeExpenseWithImage({
    required File imageFile,
    required List<ProjectModel> projects,
    required String geminiApiKey,
    String? additionalText,
  }) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = _mimeType(imageFile.path);

    final callable = _functions.httpsCallable(
      'analyzeExpense',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
    );
    final result = await callable.call({
      'imageBase64': base64Image,
      'imageMimeType': mimeType,
      if (additionalText != null) 'userInput': additionalText,
      'projects': _projectsPayload(projects),
      'geminiApiKey': geminiApiKey,
    });
    return AiAnalysisResult.fromMap(Map<String, dynamic>.from(result.data as Map));
  }

  List<Map<String, String>> _projectsPayload(List<ProjectModel> projects) {
    return projects
        .map((p) => {'id': p.id, 'name': p.name, 'type': p.type.name})
        .toList();
  }

  String _mimeType(String path) {
    final ext = path.toLowerCase().split('.').last;
    return switch (ext) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
  }
}

class AiAnalysisResult {
  final double amount;
  final String description;
  final DateTime date;
  final String suggestedProjectId;
  final double confidence;
  final String reason;
  final TransactionCategory category;

  const AiAnalysisResult({
    required this.amount,
    required this.description,
    required this.date,
    required this.suggestedProjectId,
    required this.confidence,
    required this.reason,
    this.category = TransactionCategory.other,
  });

  factory AiAnalysisResult.fromMap(Map<String, dynamic> data) {
    return AiAnalysisResult(
      amount: (data['amount'] as num).toDouble(),
      description: data['description'] as String,
      date: DateTime.parse(data['date'] as String),
      suggestedProjectId: data['suggestedProjectId'] as String,
      confidence: (data['confidence'] as num).toDouble(),
      reason: data['reason'] as String,
      category: TransactionCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => TransactionCategory.other,
      ),
    );
  }
}

final geminiServiceProvider = Provider<GeminiService>((ref) {
  return GeminiService();
});
