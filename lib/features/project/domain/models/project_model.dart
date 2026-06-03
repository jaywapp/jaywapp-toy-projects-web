import 'package:equatable/equatable.dart';
import '../../../transaction/domain/models/transaction_model.dart';

enum ProjectType { parent, sub, standalone }

enum MemberRole { admin, member, viewer }

enum CurrencyCode {
  krw,
  usd,
  eur,
  jpy,
  cny,
  gbp,
  cad,
  aud;

  String get symbol => switch (this) {
        krw => '₩',
        usd => '\$',
        eur => '€',
        jpy => '¥',
        cny => '¥',
        gbp => '£',
        cad => 'CA\$',
        aud => 'A\$',
      };

  String get label => switch (this) {
        krw => 'KRW · 한국 원',
        usd => 'USD · 미국 달러',
        eur => 'EUR · 유로',
        jpy => 'JPY · 일본 엔',
        cny => 'CNY · 중국 위안',
        gbp => 'GBP · 영국 파운드',
        cad => 'CAD · 캐나다 달러',
        aud => 'AUD · 호주 달러',
      };

  bool get noDecimal => this == krw || this == jpy;

  String format(double amount) {
    if (noDecimal) {
      return '$symbol${amount.toInt().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';
    }
    return '$symbol${amount.toStringAsFixed(2).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';
  }
}

class ProjectMember {
  final String userId;
  final MemberRole role;

  const ProjectMember({required this.userId, required this.role});

  factory ProjectMember.fromMap(Map<String, dynamic> data) {
    return ProjectMember(
      userId: data['userId'] ?? '',
      role: MemberRole.values.firstWhere(
        (e) => e.name == data['role'],
        orElse: () => MemberRole.member,
      ),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'role': role.name,
      };
}

class ProjectModel extends Equatable {
  final String id;
  final String name;
  final String? icon;
  final ProjectType type;
  final String? parentProjectId;
  final List<ProjectMember> members;
  final int order;
  final DateTime createdAt;
  final CurrencyCode currency;
  final bool isArchived;
  final double? budgetLimit;
  final Map<TransactionCategory, double> categoryBudgets;

  const ProjectModel({
    required this.id,
    required this.name,
    this.icon,
    required this.type,
    this.parentProjectId,
    required this.members,
    this.order = 0,
    required this.createdAt,
    this.currency = CurrencyCode.krw,
    this.isArchived = false,
    this.budgetLimit,
    this.categoryBudgets = const {},
  });

  factory ProjectModel.fromFirestore(Map<String, dynamic> data, String id) {
    return ProjectModel(
      id: id,
      name: data['name'] ?? '',
      icon: data['icon'],
      type: ProjectType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => ProjectType.standalone,
      ),
      parentProjectId: data['parentProjectId'],
      members: (data['members'] as List<dynamic>? ?? [])
          .map((m) => ProjectMember.fromMap(m as Map<String, dynamic>))
          .toList(),
      order: data['order'] ?? 0,
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
      currency: CurrencyCode.values.firstWhere(
        (e) => e.name == data['currency'],
        orElse: () => CurrencyCode.krw,
      ),
      isArchived: data['isArchived'] == true,
      budgetLimit: (data['budgetLimit'] as num?)?.toDouble(),
      categoryBudgets: _parseCategoryBudgets(data['categoryBudgets']),
    );
  }

  static Map<TransactionCategory, double> _parseCategoryBudgets(dynamic raw) {
    if (raw == null) return {};
    final map = raw as Map<String, dynamic>;
    final result = <TransactionCategory, double>{};
    for (final entry in map.entries) {
      final cat = TransactionCategory.values.firstWhere(
        (e) => e.name == entry.key,
        orElse: () => TransactionCategory.other,
      );
      result[cat] = (entry.value as num).toDouble();
    }
    return result;
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'icon': icon,
        'type': type.name,
        'parentProjectId': parentProjectId,
        'members': members.map((m) => m.toMap()).toList(),
        'order': order,
        'createdAt': createdAt,
        'currency': currency.name,
        'isArchived': isArchived,
        if (budgetLimit != null) 'budgetLimit': budgetLimit,
        if (categoryBudgets.isNotEmpty)
          'categoryBudgets': {for (final e in categoryBudgets.entries) e.key.name: e.value},
      };

  @override
  List<Object?> get props => [id, name, type, parentProjectId];
}
