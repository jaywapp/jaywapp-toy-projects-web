import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum GroupPlanTier { free, pro }

extension GroupPlanTierX on GroupPlanTier {
  String get code => this == GroupPlanTier.free ? 'free' : 'pro';

  String get label => this == GroupPlanTier.free ? '무료' : 'Pro';

  int get memberLimit => this == GroupPlanTier.free ? 10 : 200;

  int get monthlyEventCreateLimit => this == GroupPlanTier.free ? 20 : 500;
}

class GroupBootstrapService {
  GroupBootstrapService._();

  static const List<String> ownerPermissions = <String>[
    'member.manage',
    'event.manage',
    'finance.manage',
    'role.manage',
    'settings.manage',
  ];

  static Future<String> createGroup({
    required User user,
    required String groupName,
    required GroupPlanTier plan,
    String? description,
    String? emblemUrl,
  }) async {
    final db = FirebaseFirestore.instance;
    final ownerProfile = await db.collection('users').doc(user.uid).get();
    final ownerProfileData = ownerProfile.data() ?? const <String, dynamic>{};
    final groupRef = db.collection('groups').doc();
    final groupId = groupRef.id;
    final memberRef = groupRef.collection('members').doc(user.uid);
    final membershipRef = db
        .collection('users')
        .doc(user.uid)
        .collection('memberships')
        .doc(groupId);

    final ownerDisplayName = _resolveOwnerDisplayName(user, ownerProfileData);
    final ownerPhoneNumber = ownerProfileData['phoneNumber']?.toString().trim();
    final trimmedDescription = description?.trim();
    final trimmedEmblemUrl = emblemUrl?.trim();
    final now = FieldValue.serverTimestamp();

    await groupRef.set(<String, dynamic>{
      'name': groupName.trim(),
      if (trimmedDescription != null && trimmedDescription.isNotEmpty)
        'description': trimmedDescription,
      if (trimmedEmblemUrl != null && trimmedEmblemUrl.isNotEmpty)
        'emblemUrl': trimmedEmblemUrl,
      'ownerId': user.uid,
      'status': 'active',
      'plan': plan.code,
      'planLabel': plan.label,
      'limits': <String, dynamic>{
        'memberMax': plan.memberLimit,
        'eventCreateMonthlyMax': plan.monthlyEventCreateLimit,
      },
      'memberCount': 1,
      'createdAt': now,
      'updatedAt': now,
    });

    await memberRef.set(<String, dynamic>{
      'status': 'active',
      'role': 'owner',
      'permissions': ownerPermissions,
      'displayName': ownerDisplayName,
      if (user.photoURL != null && user.photoURL!.isNotEmpty)
        'photoUrl': user.photoURL,
      if (ownerPhoneNumber != null && ownerPhoneNumber.isNotEmpty)
        'phoneNumber': ownerPhoneNumber,
      'joinedAt': now,
      'updatedAt': now,
      'public': <String, dynamic>{
        'nickname': ownerDisplayName,
        'joinedAt': now,
        if (ownerPhoneNumber != null && ownerPhoneNumber.isNotEmpty)
          'phoneNumber': ownerPhoneNumber,
      },
    });

    await membershipRef.set(<String, dynamic>{
      'groupId': groupId,
      'status': 'active',
      'role': 'owner',
      'permissions': ownerPermissions,
      'joinedAt': now,
      'updatedAt': now,
    });

    return groupId;
  }

  static String _resolveOwnerDisplayName(
    User user,
    Map<String, dynamic> profileData,
  ) {
    final profileDisplayName = profileData['displayName']?.toString().trim();
    if (profileDisplayName != null && profileDisplayName.isNotEmpty) {
      return profileDisplayName;
    }

    final profileNickname = profileData['nickname']?.toString().trim();
    if (profileNickname != null && profileNickname.isNotEmpty) {
      return profileNickname;
    }

    final displayName = user.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) return displayName;

    final email = user.email?.trim();
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    if (email != null && email.isNotEmpty) return email;

    return 'owner';
  }
}
