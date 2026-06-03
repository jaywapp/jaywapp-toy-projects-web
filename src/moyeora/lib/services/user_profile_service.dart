import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProfileService {
  UserProfileService._();

  static Future<void> upsertAfterKakaoLogin({
    required String uid,
    required String? kakaoNickname,
    required String? kakaoPhotoUrl,
    required String? kakaoId,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final existing = await userRef.get();
    final existingData = existing.data() ?? <String, dynamic>{};
    final profileSource = existingData['profileSource']?.toString();
    final userManaged = profileSource == 'user';
    final photoEditedByUser = existingData['photoEditedByUser'] == true;

    final existingNickname = existingData['nickname']?.toString();
    final existingPhotoUrl = existingData['photoUrl']?.toString();
    final finalNickname = userManaged
        ? existingNickname
        : (kakaoNickname ?? existingNickname);
    final finalPhotoUrl = (userManaged || photoEditedByUser)
        ? existingPhotoUrl
        : (kakaoPhotoUrl ?? existingPhotoUrl);

    await userRef.set({
      'provider': 'kakao',
      'displayName': finalNickname,
      'nickname': finalNickname ?? '',
      'photoUrl': finalPhotoUrl,
      'kakaoId': kakaoId,
      'profileSource': userManaged ? 'user' : 'kakao',
      'photoEditedByUser': photoEditedByUser,
      'lastLoginAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> ensurePasswordProfile({
    required String uid,
    String? email,
    String? fallbackNickname,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final existing = await userRef.get();
    final data = existing.data() ?? <String, dynamic>{};
    final nickname = data['nickname']?.toString();
    await userRef.set({
      'provider': data['provider']?.toString() ?? 'password',
      'email': data['email']?.toString() ?? email,
      'nickname': (nickname != null && nickname.trim().isNotEmpty)
          ? nickname
          : (fallbackNickname ?? ''),
      'displayName': data['displayName']?.toString() ?? fallbackNickname,
      'photoUrl': data['photoUrl'],
      'profileSource': data['profileSource']?.toString() ?? 'user',
      'photoEditedByUser': data['photoEditedByUser'] == true,
      'lastLoginAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> upsertAfterGoogleLogin({
    required String uid,
    required String? email,
    required String? googleDisplayName,
    required String? googlePhotoUrl,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    final existing = await userRef.get();
    final existingData = existing.data() ?? <String, dynamic>{};
    final profileSource = existingData['profileSource']?.toString();
    final userManaged = profileSource == 'user';
    final photoEditedByUser = existingData['photoEditedByUser'] == true;

    final existingNickname = existingData['nickname']?.toString();
    final existingPhotoUrl = existingData['photoUrl']?.toString();
    final finalNickname = userManaged
        ? existingNickname
        : (googleDisplayName ?? existingNickname ?? '');
    final finalPhotoUrl = (userManaged || photoEditedByUser)
        ? existingPhotoUrl
        : (googlePhotoUrl ?? existingPhotoUrl);

    await userRef.set({
      'provider': 'google',
      'email': email ?? existingData['email'],
      'displayName': finalNickname,
      'nickname': finalNickname,
      'photoUrl': finalPhotoUrl,
      'profileSource': userManaged ? 'user' : 'google',
      'photoEditedByUser': photoEditedByUser,
      'lastLoginAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> saveUserProfile({
    required String uid,
    required String nickname,
    String? photoUrl,
    String? phoneNumber,
  }) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
    await userRef.set({
      'nickname': nickname.trim(),
      'displayName': nickname.trim(),
      'photoUrl': (photoUrl == null || photoUrl.trim().isEmpty)
          ? null
          : photoUrl.trim(),
      'phoneNumber': (phoneNumber == null || phoneNumber.trim().isEmpty)
          ? null
          : phoneNumber.trim(),
      'profileSource': 'user',
      'photoEditedByUser': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> syncLinkedProvidersFromAuth(User user) async {
    final providers =
        user.providerData
            .map((p) => p.providerId)
            .where((id) => id.isNotEmpty)
            .toSet()
            .toList()
          ..sort();

    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'linkedProviders': providers,
      'primaryProvider': user.providerData.isEmpty
          ? null
          : user.providerData.first.providerId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
