import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError('DefaultFirebaseOptions are not configured for this platform.');
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyB2CIWxQogAXkt2ISkWDfMD7GoHhJK6wSE',
    appId: '1:875777689976:web:d3d3860ea7ebdfe33aa08d',
    messagingSenderId: '875777689976',
    projectId: 'moyeora-dev',
    authDomain: 'moyeora-dev.firebaseapp.com',
    storageBucket: 'moyeora-dev.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBsaz06oC1jlhpvUFkmJSepjuXmo-QV30w',
    appId: '1:875777689976:android:0ac3dbf1c1ef02b03aa08d',
    messagingSenderId: '875777689976',
    projectId: 'moyeora-dev',
    storageBucket: 'moyeora-dev.firebasestorage.app',
  );

}