class _CacheEntry<T> {
  _CacheEntry(this.value, this.expiresAt);

  final T value;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// 데이터 유형별 캐시 TTL 상수.
/// 변경 빈도가 낮은 데이터는 길게, 멤버 상태처럼 빠르게 바뀌는 데이터는 짧게 설정.
class CacheTtl {
  CacheTtl._();

  /// 그룹 메타데이터 (이름, 엠블럼 등) — 자주 바뀌지 않음.
  static const group = Duration(minutes: 5);

  /// 유저 프로필 (닉네임, 사진) — 가끔 변경.
  static const profile = Duration(minutes: 10);

  /// 멤버 상태/역할 — 관리자 조작으로 바뀔 수 있어 짧게 유지.
  static const member = Duration(minutes: 2);

  /// 알림 설정 — 설정 화면에서만 변경, 중간 TTL.
  static const settings = Duration(minutes: 5);
}

class AppCacheService {
  AppCacheService._();

  static final AppCacheService instance = AppCacheService._();

  final Map<String, _CacheEntry<Object?>> _memory = <String, _CacheEntry<Object?>>{};

  T? get<T>(String key) {
    final entry = _memory[key];
    if (entry == null || entry.isExpired) {
      _memory.remove(key);
      return null;
    }
    return entry.value as T?;
  }

  void set<T>(String key, T value, {Duration ttl = const Duration(seconds: 60)}) {
    _memory[key] = _CacheEntry<Object?>(value, DateTime.now().add(ttl));
  }

  T? getOrCompute<T>(
    String key,
    T Function() compute, {
    Duration ttl = const Duration(seconds: 60),
  }) {
    final cached = get<T>(key);
    if (cached != null) return cached;
    final value = compute();
    set<T>(key, value, ttl: ttl);
    return value;
  }

  void invalidate(String key) {
    _memory.remove(key);
  }

  void invalidatePrefix(String prefix) {
    final keys = _memory.keys.where((key) => key.startsWith(prefix)).toList();
    for (final key in keys) {
      _memory.remove(key);
    }
  }

  void clearAll() {
    _memory.clear();
  }
}
