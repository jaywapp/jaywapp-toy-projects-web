import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moyeora/repositories/group_repository.dart';
import 'package:moyeora/services/app_cache.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late GroupRepository repo;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    repo = GroupRepository(firestore: fakeFirestore);
    // 테스트마다 캐시 초기화
    AppCacheService.instance.clearAll();
  });

  group('GroupRepository.getGroup', () {
    test('문서가 존재하면 데이터를 반환한다', () async {
      await fakeFirestore.collection('groups').doc('g1').set({
        'name': '테스트 모임',
        'status': 'active',
      });

      final result = await repo.getGroup(groupId: 'g1');

      expect(result, isNotNull);
      expect(result!['name'], equals('테스트 모임'));
    });

    test('문서가 없으면 null을 반환한다', () async {
      final result = await repo.getGroup(groupId: 'nonexistent');

      expect(result, isNull);
    });

    test('캐시 히트: 두 번째 호출은 캐시에서 반환된다', () async {
      await fakeFirestore.collection('groups').doc('g2').set({
        'name': '캐시 테스트',
      });

      final first = await repo.getGroup(groupId: 'g2');
      // Firestore 문서를 변경해도 캐시된 값이 반환되는지 확인
      await fakeFirestore.collection('groups').doc('g2').update({
        'name': '변경된 이름',
      });
      final second = await repo.getGroup(groupId: 'g2');

      expect(first!['name'], equals('캐시 테스트'));
      expect(second!['name'], equals('캐시 테스트')); // 캐시에서 반환
    });

    test('캐시 미스: invalidate 후 새 데이터를 가져온다', () async {
      await fakeFirestore.collection('groups').doc('g3').set({
        'name': '원본 이름',
      });

      await repo.getGroup(groupId: 'g3');
      AppCacheService.instance.invalidate('group:g3');
      await fakeFirestore.collection('groups').doc('g3').update({
        'name': '새 이름',
      });
      final result = await repo.getGroup(groupId: 'g3');

      expect(result!['name'], equals('새 이름'));
    });
  });

  group('GroupRepository.getMember', () {
    test('멤버 문서가 존재하면 데이터를 반환한다', () async {
      await fakeFirestore
          .collection('groups')
          .doc('g1')
          .collection('members')
          .doc('uid1')
          .set({'role': 'member', 'status': 'active'});

      final result = await repo.getMember(groupId: 'g1', uid: 'uid1');

      expect(result, isNotNull);
      expect(result!['role'], equals('member'));
    });

    test('멤버 문서가 없으면 null을 반환한다', () async {
      final result = await repo.getMember(groupId: 'g1', uid: 'nobody');

      expect(result, isNull);
    });
  });

  group('GroupRepository.loadHomeBundle', () {
    test('기본 번들을 로드한다', () async {
      await fakeFirestore.collection('groups').doc('g1').set({
        'name': '홈 테스트 모임',
        'status': 'active',
      });
      await fakeFirestore
          .collection('groups')
          .doc('g1')
          .collection('members')
          .doc('u1')
          .set({'role': 'owner', 'status': 'active'});

      final now = Timestamp.now();
      await fakeFirestore
          .collection('groups')
          .doc('g1')
          .collection('events')
          .doc('e1')
          .set({'title': '이벤트1', 'startAt': now, 'isDeleted': false});

      final bundle = await repo.loadHomeBundle(
        groupId: 'g1',
        uid: 'u1',
        homeListLimit: 2,
      );

      expect(bundle.group, isNotNull);
      expect(bundle.group!['name'], equals('홈 테스트 모임'));
    });

    test('onError fallback: 그룹은 있지만 멤버가 없으면 번들 반환 (member=null)', () async {
      await fakeFirestore.collection('groups').doc('g1').set({
        'name': '폴백 테스트',
        'status': 'active',
      });

      final bundle = await repo.loadHomeBundle(
        groupId: 'g1',
        uid: 'non_existent_user',
        homeListLimit: 2,
      );

      expect(bundle.group, isNotNull);
      expect(bundle.member, isNull);
    });
  });

  group('GroupRepository.invalidateGroupScope', () {
    test('그룹/멤버/설정 캐시를 모두 무효화한다', () async {
      await fakeFirestore.collection('groups').doc('g1').set({'name': '모임'});
      await fakeFirestore
          .collection('groups')
          .doc('g1')
          .collection('members')
          .doc('u1')
          .set({'role': 'member', 'status': 'active'});

      // 캐시에 적재
      await repo.getGroup(groupId: 'g1');
      await repo.getMember(groupId: 'g1', uid: 'u1');

      // 무효화
      repo.invalidateGroupScope('g1', 'u1');

      // 캐시 키가 제거됐는지 확인
      final groupCached = AppCacheService.instance.get<Map<String, dynamic>>('group:g1');
      final memberCached = AppCacheService.instance.get<Map<String, dynamic>>('member:g1:u1');
      expect(groupCached, isNull);
      expect(memberCached, isNull);
    });
  });
}
