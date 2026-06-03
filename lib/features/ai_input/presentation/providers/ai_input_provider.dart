import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../project/domain/models/project_model.dart';
import '../../../project/presentation/providers/project_provider.dart';
import '../../../transaction/data/repositories/transaction_repository.dart';
import '../../../transaction/domain/models/transaction_model.dart';
import '../../data/services/gemini_service.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository();
});

class AiInputNotifier extends StateNotifier<AiInputState> {
  final Ref _ref;

  AiInputNotifier(this._ref) : super(const AiInputState());

  Future<void> analyze(String input) async {
    state = state.copyWith(status: AiInputStatus.analyzing, error: null);
    try {
      final projects = await _loadProjects();
      final apiKey = await _getGeminiApiKey();
      final result = await _ref.read(geminiServiceProvider).analyzeExpense(
            userInput: input,
            projects: projects,
            geminiApiKey: apiKey,
          );
      _applyResult(result, projects, rawInput: input);
    } catch (e) {
      state = state.copyWith(status: AiInputStatus.idle, error: _parseError(e));
    }
  }

  Future<void> analyzeImage(File imageFile) async {
    state = state.copyWith(status: AiInputStatus.analyzing, error: null);
    try {
      final projects = await _loadProjects();
      final apiKey = await _getGeminiApiKey();
      final result = await _ref.read(geminiServiceProvider).analyzeExpenseWithImage(
            imageFile: imageFile,
            projects: projects,
            geminiApiKey: apiKey,
          );
      _applyResult(result, projects, rawInput: '[이미지 입력]');
    } catch (e) {
      state = state.copyWith(status: AiInputStatus.idle, error: _parseError(e));
    }
  }

  String _parseError(Object e) {
    if (e is FirebaseFunctionsException) {
      switch (e.code) {
        case 'internal':
          return 'AI 분석 중 오류가 발생했습니다.\nGemini API 키가 유효한지 확인해주세요.\n(설정 → AI 설정)';
        case 'unauthenticated':
          return '로그인이 필요합니다.';
        case 'invalid-argument':
          return e.message ?? '잘못된 입력입니다.';
        case 'resource-exhausted':
          return 'API 할당량이 초과되었습니다. 잠시 후 다시 시도해주세요.';
        default:
          return e.message ?? e.toString();
      }
    }
    return e.toString();
  }

  Future<List<ProjectModel>> _loadProjects() async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');
    final projects = await _ref.read(projectRepositoryProvider).getUserProjects(uid);
    if (projects.isEmpty) throw Exception('프로젝트를 먼저 생성해주세요.');
    return projects;
  }

  Future<String> _getGeminiApiKey() async {
    final uid = _ref.read(authStateProvider).valueOrNull?.uid;
    if (uid == null) throw Exception('로그인이 필요합니다.');
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final key = doc.data()?['geminiApiKey'] as String?;
    if (key == null || key.isEmpty) {
      throw Exception('Gemini API 키가 설정되지 않았습니다.\n설정 → AI 설정에서 API 키를 입력해주세요.');
    }
    if (!key.startsWith('AIza') || key.length < 30) {
      throw Exception('Gemini API 키 형식이 올바르지 않습니다.\n"AIza"로 시작하는 키를 설정 → AI 설정에서 입력해주세요.');
    }
    return key;
  }

  void _applyResult(AiAnalysisResult result, List<ProjectModel> projects, {required String rawInput}) {
    final suggestedProject = projects.firstWhere(
      (p) => p.id == result.suggestedProjectId,
      orElse: () => projects.first,
    );
    state = state.copyWith(
      status: AiInputStatus.confirm,
      result: result,
      suggestedProject: suggestedProject,
      selectedProject: suggestedProject,
      availableProjects: projects,
      rawInput: rawInput,
    );
  }

  void selectProject(ProjectModel project) {
    state = state.copyWith(selectedProject: project);
  }

  Future<void> confirm() async {
    final result = state.result;
    final project = state.selectedProject;
    if (result == null || project == null) return;

    state = state.copyWith(status: AiInputStatus.saving);

    try {
      final uid = _ref.read(authStateProvider).valueOrNull?.uid;
      if (uid == null) throw Exception('로그인이 필요합니다.');

      final pending = await _ref.read(transactionRepositoryProvider).createPendingTransaction(
            projectId: project.id,
            userId: uid,
            amount: result.amount,
            description: result.description,
            rawInput: state.rawInput ?? '',
            aiSuggestion: AiSuggestion(
              projectId: result.suggestedProjectId,
              confidence: result.confidence,
              reason: result.reason,
            ),
            date: result.date,
            category: result.category,
          );

      await _ref.read(transactionRepositoryProvider).confirmTransaction(
            transactionId: pending.id,
            projectId: project.id,
          );

      _ref.invalidate(userProjectsProvider);
      _ref.invalidate(projectSpentProvider(project.id));

      state = state.copyWith(status: AiInputStatus.done);
    } catch (e) {
      state = state.copyWith(status: AiInputStatus.confirm, error: e.toString());
    }
  }

  void reset() {
    state = const AiInputState();
  }
}

enum AiInputStatus { idle, analyzing, confirm, saving, done }

class AiInputState {
  final AiInputStatus status;
  final AiAnalysisResult? result;
  final ProjectModel? suggestedProject;
  final ProjectModel? selectedProject;
  final List<ProjectModel> availableProjects;
  final String? rawInput;
  final String? error;

  const AiInputState({
    this.status = AiInputStatus.idle,
    this.result,
    this.suggestedProject,
    this.selectedProject,
    this.availableProjects = const [],
    this.rawInput,
    this.error,
  });

  AiInputState copyWith({
    AiInputStatus? status,
    AiAnalysisResult? result,
    ProjectModel? suggestedProject,
    ProjectModel? selectedProject,
    List<ProjectModel>? availableProjects,
    String? rawInput,
    String? error,
  }) {
    return AiInputState(
      status: status ?? this.status,
      result: result ?? this.result,
      suggestedProject: suggestedProject ?? this.suggestedProject,
      selectedProject: selectedProject ?? this.selectedProject,
      availableProjects: availableProjects ?? this.availableProjects,
      rawInput: rawInput ?? this.rawInput,
      error: error,
    );
  }
}

final aiInputProvider = StateNotifierProvider.autoDispose<AiInputNotifier, AiInputState>((ref) {
  return AiInputNotifier(ref);
});
