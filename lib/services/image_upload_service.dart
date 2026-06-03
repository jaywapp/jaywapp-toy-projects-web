import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

class ImageUploadService {
  ImageUploadService._();

  static Future<String> uploadProfilePhoto({
    required String uid,
    required Uint8List bytes,
    String? mimeType,
    void Function(double progress)? onProgress,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance.ref().child(
      'users/$uid/profile/profile_$now.jpg',
    );
    return _uploadWithProgress(
      ref: ref,
      bytes: bytes,
      mimeType: mimeType,
      onProgress: onProgress,
    );
  }

  static Future<String> uploadGroupEmblem({
    required String uid,
    required Uint8List bytes,
    String? mimeType,
    void Function(double progress)? onProgress,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance.ref().child(
      'groups/$uid/emblems/emblem_$now.jpg',
    );
    return _uploadWithProgress(
      ref: ref,
      bytes: bytes,
      mimeType: mimeType,
      onProgress: onProgress,
    );
  }

  static Future<String> uploadExpenseReceipt({
    required String uid,
    required String groupId,
    required String periodKey,
    required String expenseId,
    required Uint8List bytes,
    String? mimeType,
    void Function(double progress)? onProgress,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final ref = FirebaseStorage.instance.ref().child(
      'groups/$groupId/fees/$periodKey/expenses/$uid/${expenseId}_$now.jpg',
    );
    return _uploadWithProgress(
      ref: ref,
      bytes: bytes,
      mimeType: mimeType,
      onProgress: onProgress,
    );
  }

  static Future<String> _uploadWithProgress({
    required Reference ref,
    required Uint8List bytes,
    String? mimeType,
    void Function(double progress)? onProgress,
    int maxAttempts = 3,
  }) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final uploadTask = ref.putData(
        bytes,
        SettableMetadata(contentType: _normalizedContentType(mimeType)),
      );

      final subscription = uploadTask.snapshotEvents.listen((snapshot) {
        if (onProgress == null) return;
        final total = snapshot.totalBytes;
        if (total <= 0) return;
        final value = snapshot.bytesTransferred / total;
        onProgress(value.clamp(0, 1));
      });

      try {
        await uploadTask.timeout(const Duration(seconds: 60));
        final downloadUrl = await ref.getDownloadURL().timeout(
          const Duration(seconds: 20),
        );
        onProgress?.call(1);
        return downloadUrl;
      } on TimeoutException catch (_) {
        await subscription.cancel();
        if (attempt < maxAttempts - 1) {
          await Future.delayed(Duration(seconds: 2 * (attempt + 1)));
        }
      } catch (e) {
        await subscription.cancel();
        rethrow;
      } finally {
        await subscription.cancel();
      }
    }

    throw TimeoutException(
      '이미지 업로드에 실패했습니다 ($maxAttempts회 시도). 네트워크 상태를 확인해 주세요.',
    );
  }

  static String _normalizedContentType(String? mimeType) {
    if (mimeType != null && mimeType.startsWith('image/')) {
      return mimeType;
    }
    return 'image/jpeg';
  }
}
