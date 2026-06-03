import 'package:equatable/equatable.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? profileImage;
  final String plan; // "basic" | "plus"
  final DateTime? planExpiredAt;
  final int aiCallCount;
  final DateTime? aiCallResetAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.profileImage,
    this.plan = 'basic',
    this.planExpiredAt,
    this.aiCallCount = 0,
    this.aiCallResetAt,
  });

  bool get isPlus => plan == 'plus' && (planExpiredAt?.isAfter(DateTime.now()) ?? false);
  bool get showAds => !isPlus;

  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel(
      id: id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      profileImage: data['profileImage'],
      plan: data['plan'] ?? 'basic',
      planExpiredAt: data['planExpiredAt']?.toDate(),
      aiCallCount: data['aiCallCount'] ?? 0,
      aiCallResetAt: data['aiCallResetAt']?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'email': email,
        'profileImage': profileImage,
        'plan': plan,
        'planExpiredAt': planExpiredAt,
        'aiCallCount': aiCallCount,
        'aiCallResetAt': aiCallResetAt,
      };

  @override
  List<Object?> get props => [id, name, email, plan, planExpiredAt];
}
