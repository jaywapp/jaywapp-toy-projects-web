import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleSignInCanceledException implements Exception {}

class GoogleAuthService {
  GoogleAuthService._();

  static bool _isUserCanceledCode(String code) {
    return code == 'popup-closed-by-user' ||
        code == 'cancelled-popup-request' ||
        code == 'web-context-cancelled';
  }

  static Future<AuthCredential> getGoogleCredential() async {
    final googleSignIn = GoogleSignIn(scopes: const ['email', 'profile']);
    final account = await googleSignIn.signIn();
    if (account == null) {
      throw GoogleSignInCanceledException();
    }

    final authentication = await account.authentication;
    final accessToken = authentication.accessToken;
    final idToken = authentication.idToken;
    if (accessToken == null || idToken == null) {
      throw FirebaseAuthException(
        code: 'missing-google-token',
        message: 'Google token is missing.',
      );
    }

    return GoogleAuthProvider.credential(
      accessToken: accessToken,
      idToken: idToken,
    );
  }

  static Future<UserCredential> signInWithGoogle() async {
    final auth = FirebaseAuth.instance;
    final provider = GoogleAuthProvider();

    if (kIsWeb) {
      try {
        return await auth.signInWithPopup(provider);
      } on FirebaseAuthException catch (e) {
        if (_isUserCanceledCode(e.code)) {
          throw GoogleSignInCanceledException();
        }
        return auth.signInWithProvider(provider);
      }
    }

    final credential = await getGoogleCredential();
    return auth.signInWithCredential(credential);
  }

  static Future<UserCredential> linkCurrentUserWithGoogle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'no-current-user',
        message: 'No signed-in user.',
      );
    }
    final hasGoogleLinked = user.providerData.any(
      (provider) => provider.providerId == 'google.com',
    );
    if (hasGoogleLinked) {
      throw FirebaseAuthException(
        code: 'provider-already-linked',
        message: 'Google provider is already linked.',
      );
    }

    if (kIsWeb) {
      try {
        return await user.linkWithPopup(GoogleAuthProvider());
      } on FirebaseAuthException catch (e) {
        if (_isUserCanceledCode(e.code)) {
          throw GoogleSignInCanceledException();
        }
        rethrow;
      }
    }

    final credential = await getGoogleCredential();
    return user.linkWithCredential(credential);
  }
}
