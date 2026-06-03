import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/firestore_paths.dart';
import '../dev/firestore_metrics.dart';
import '../dev/perf_timing.dart';
import '../services/app_cache.dart';

class HomeBundle {
  const HomeBundle({
    required this.group,
    required this.member,
    required this.settings,
    required this.profile,
    required this.events,
    required this.notices,
  });

  final Map<String, dynamic>? group;
  final Map<String, dynamic>? member;
  final Map<String, dynamic>? settings;
  final Map<String, dynamic>? profile;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> events;
  final List<QueryDocumentSnapshot<Map<String, dynamic>>> notices;
}

class GroupRepository {
  GroupRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final AppCacheService _cache = AppCacheService.instance;

  Future<HomeBundle> loadHomeBundle({
    required String groupId,
    required String uid,
    int homeListLimit = 2,
  }) async {
    final span = PerfSpan('Home load').start();
    try {
      // group은 필수 — 실패 시 전파하여 홈 화면에서 에러 표시.
      // 나머지는 선택적 — 부분 실패 시 null / 빈 목록으로 폴백하여 홈 일부 표시 유지.
      final futures = await Future.wait([
        getGroup(groupId: groupId),
        getMember(groupId: groupId, uid: uid)
            .onError((_, __) => null),
        getSettings(groupId: groupId, uid: uid)
            .onError((_, __) => null),
        getProfile(uid: uid)
            .onError((_, __) => null),
        _fetchEvents(groupId: groupId, limit: homeListLimit)
            .onError((_, __) => <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
        _fetchNotices(groupId: groupId, limit: homeListLimit)
            .onError((_, __) => <QueryDocumentSnapshot<Map<String, dynamic>>>[]),
      ]);

      final bundle = HomeBundle(
        group: futures[0] as Map<String, dynamic>?,
        member: futures[1] as Map<String, dynamic>?,
        settings: futures[2] as Map<String, dynamic>?,
        profile: futures[3] as Map<String, dynamic>?,
        events: futures[4] as List<QueryDocumentSnapshot<Map<String, dynamic>>>,
        notices: futures[5] as List<QueryDocumentSnapshot<Map<String, dynamic>>>,
      );
      return bundle;
    } finally {
      span.end();
      FirestoreMetrics.instance.dump('home');
    }
  }

  Future<Map<String, dynamic>?> getGroup({required String groupId}) async {
    final key = 'group:$groupId';
    final cached = _cache.get<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final span = PerfSpan('Repo group').start();
    final doc = await _firestore.collection(FirestorePaths.groups).doc(groupId).get();
    FirestoreMetrics.instance.addReads(doc.exists ? 1 : 0);
    final data = doc.data();
    if (data != null) _cache.set(key, data, ttl: CacheTtl.group);
    span.end();
    return data;
  }

  Future<Map<String, dynamic>?> getMember({
    required String groupId,
    required String uid,
  }) async {
    final key = 'member:$groupId:$uid';
    final cached = _cache.get<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final span = PerfSpan('Repo member').start();
    final doc = await _firestore
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection(FirestorePaths.members)
        .doc(uid)
        .get();
    FirestoreMetrics.instance.addReads(doc.exists ? 1 : 0);
    final data = doc.data();
    if (data != null) _cache.set(key, data, ttl: CacheTtl.member);
    span.end();
    return data;
  }

  Future<Map<String, dynamic>?> getSettings({
    required String groupId,
    required String uid,
  }) async {
    final key = 'settings:$groupId:$uid';
    final cached = _cache.get<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final span = PerfSpan('Repo settings').start();
    final doc = await _firestore
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection(FirestorePaths.members)
        .doc(uid)
        .collection(FirestorePaths.notificationSettings)
        .doc(FirestorePaths.notificationSettingsDefault)
        .get();
    FirestoreMetrics.instance.addReads(doc.exists ? 1 : 0);
    final data = doc.data();
    if (data != null) _cache.set(key, data, ttl: CacheTtl.settings);
    span.end();
    return data;
  }

  Future<Map<String, dynamic>?> getProfile({required String uid}) async {
    final key = 'profile:$uid';
    final cached = _cache.get<Map<String, dynamic>>(key);
    if (cached != null) return cached;

    final span = PerfSpan('Repo profile').start();
    final doc = await _firestore.collection(FirestorePaths.users).doc(uid).get();
    FirestoreMetrics.instance.addReads(doc.exists ? 1 : 0);
    final data = doc.data();
    if (data != null) _cache.set(key, data, ttl: CacheTtl.profile);
    span.end();
    return data;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchEvents({
    required String groupId,
    required int limit,
  }) async {
    final span = PerfSpan('Repo home events').start();
    final snap = await _firestore
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection(FirestorePaths.events)
        .where(FirestorePaths.isDeleted, isEqualTo: false)
        .orderBy(FirestorePaths.startAt)
        .limit(limit)
        .get();
    FirestoreMetrics.instance.addReads(snap.docs.length);
    span.end();
    return snap.docs;
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _fetchNotices({
    required String groupId,
    required int limit,
  }) async {
    final span = PerfSpan('Repo home notices').start();
    final snap = await _firestore
        .collection(FirestorePaths.groups)
        .doc(groupId)
        .collection(FirestorePaths.notices)
        .orderBy(FirestorePaths.createdAt, descending: true)
        .limit(limit)
        .get();
    FirestoreMetrics.instance.addReads(snap.docs.length);
    span.end();
    return snap.docs;
  }

  void invalidateGroupScope(String groupId, String uid) {
    _cache.invalidate('group:$groupId');
    _cache.invalidate('member:$groupId:$uid');
    _cache.invalidate('settings:$groupId:$uid');
  }
}
