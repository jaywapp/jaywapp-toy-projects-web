import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/project_model.dart';
import '../../../transaction/domain/models/transaction_model.dart';

class ProjectBalance {
  final double income;
  final double expense;

  const ProjectBalance({required this.income, required this.expense});

  double get balance => income - expense;
}

class ProjectRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('projects');

  Stream<List<ProjectModel>> watchUserProjects(String userId) {
    return _col
        .where('members', arrayContains: {'userId': userId, 'role': 'admin'})
        .orderBy('order')
        .snapshots()
        .asyncMap((_) => getUserProjects(userId));
  }

  Future<List<ProjectModel>> getUserProjects(String userId) async {
    final snapshot = await _col.orderBy('order').get();
    return snapshot.docs
        .map((doc) => ProjectModel.fromFirestore(doc.data(), doc.id))
        .where((p) => p.members.any((m) => m.userId == userId))
        .toList();
  }

  Future<ProjectModel> getProject(String projectId) async {
    final doc = await _col.doc(projectId).get();
    if (!doc.exists) throw Exception('프로젝트를 찾을 수 없습니다.');
    return ProjectModel.fromFirestore(doc.data()!, doc.id);
  }

  Future<List<ProjectModel>> getSubProjects(String parentId) async {
    final snapshot = await _col
        .where('parentProjectId', isEqualTo: parentId)
        .orderBy('order')
        .get();
    return snapshot.docs
        .map((doc) => ProjectModel.fromFirestore(doc.data(), doc.id))
        .toList();
  }

  Future<ProjectModel> createProject({
    required String name,
    String? icon,
    required ProjectType type,
    String? parentProjectId,
    required double initialIncome,
    required String creatorId,
    CurrencyCode currency = CurrencyCode.krw,
  }) async {
    final memberCount = await _col.count().get();
    final order = memberCount.count ?? 0;

    final data = {
      'name': name,
      'icon': icon,
      'type': type.name,
      'parentProjectId': parentProjectId,
      'members': [
        {'userId': creatorId, 'role': 'admin'}
      ],
      'memberIds': [creatorId],
      'order': order,
      'currency': currency.name,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final ref = await _col.add(data);
    final now = DateTime.now();

    // 초기 수입 트랜잭션 생성
    if (initialIncome > 0) {
      await _firestore.collection('transactions').add({
        'projectId': ref.id,
        'userId': creatorId,
        'amount': initialIncome,
        'description': '초기 수입',
        'type': 'income',
        'confirmedAt': now,
        'date': now,
        'createdAt': now,
      });
    }

    // 서브 프로젝트인 경우: 부모에서 지출 트랜잭션 생성
    if (parentProjectId != null && initialIncome > 0) {
      await _firestore.collection('transactions').add({
        'projectId': parentProjectId,
        'userId': creatorId,
        'amount': initialIncome,
        'description': '하위 프로젝트 할당: $name',
        'type': 'expense',
        'confirmedAt': now,
        'date': now,
        'createdAt': now,
      });
    }

    final doc = await ref.get();
    return ProjectModel.fromFirestore(doc.data()!, doc.id);
  }

  Future<void> addIncome({
    required String projectId,
    required String userId,
    required double amount,
    required String description,
  }) async {
    final now = DateTime.now();
    await _firestore.collection('transactions').add({
      'projectId': projectId,
      'userId': userId,
      'amount': amount,
      'description': description,
      'type': 'income',
      'confirmedAt': now,
      'date': now,
      'createdAt': now,
    });
  }

  Future<void> updateProject(String projectId, {String? name, String? icon}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (icon != null) updates['icon'] = icon;
    await _col.doc(projectId).update(updates);
  }

  Future<void> archiveProject(String projectId, {bool archive = true}) async {
    await _col.doc(projectId).update({'isArchived': archive});
  }

  Future<void> setBudgetLimit(String projectId, double? limit) async {
    if (limit == null) {
      await _col.doc(projectId).update({'budgetLimit': FieldValue.delete()});
    } else {
      await _col.doc(projectId).update({'budgetLimit': limit});
    }
  }

  Future<void> updateProjectOrder(String projectId, int order) async {
    await _col.doc(projectId).update({'order': order});
  }

  Future<void> setCategoryBudgets(
    String projectId,
    Map<TransactionCategory, double> budgets,
  ) async {
    final data = {for (final e in budgets.entries) e.key.name: e.value};
    await _col.doc(projectId).update({'categoryBudgets': data});
  }

  Future<void> deleteProject(String projectId) async {
    await _col.doc(projectId).delete();
  }

  Future<ProjectBalance> getBalance(String projectId) async {
    final snapshot = await _firestore
        .collection('transactions')
        .where('projectId', isEqualTo: projectId)
        .get();

    double income = 0;
    double expense = 0;
    for (final doc in snapshot.docs) {
      // 미확정 트랜잭션 제외
      if (doc['confirmedAt'] == null) continue;
      final amount = (doc['amount'] as num).toDouble();
      final type = doc['type'] as String? ?? 'expense';
      if (type == 'income') {
        income += amount;
      } else {
        expense += amount;
      }
    }
    return ProjectBalance(income: income, expense: expense);
  }

  // 정산용: 지출만 집계
  Future<double> getSpentAmount(String projectId) async {
    final balance = await getBalance(projectId);
    return balance.expense;
  }
}
