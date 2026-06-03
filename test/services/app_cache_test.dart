import 'package:flutter_test/flutter_test.dart';
import 'package:moyeora/services/app_cache.dart';

void main() {
  setUp(() {
    AppCacheService.instance.clearAll();
  });

  test('set/get works for cached value', () {
    AppCacheService.instance.set<String>('user:nickname', 'moyeora');

    final cached = AppCacheService.instance.get<String>('user:nickname');
    expect(cached, 'moyeora');
  });

  test('ttl expiration removes stale value', () async {
    AppCacheService.instance.set<String>(
      'group:name',
      'demo',
      ttl: const Duration(milliseconds: 5),
    );

    await Future<void>.delayed(const Duration(milliseconds: 15));
    final cached = AppCacheService.instance.get<String>('group:name');
    expect(cached, isNull);
  });

  test('invalidatePrefix removes matching keys only', () {
    AppCacheService.instance.set<String>('group:g_demo', 'demo');
    AppCacheService.instance.set<String>('group:g_prod', 'prod');
    AppCacheService.instance.set<String>('user:u1', 'u1');

    AppCacheService.instance.invalidatePrefix('group:');

    expect(AppCacheService.instance.get<String>('group:g_demo'), isNull);
    expect(AppCacheService.instance.get<String>('group:g_prod'), isNull);
    expect(AppCacheService.instance.get<String>('user:u1'), 'u1');
  });
}
