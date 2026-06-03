import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

const String _devSeedKey = 'moyeora_demo_v1';

Future<bool> seedDemoMembersAndData(String groupId, String adminUid) async {
  if (!kDebugMode) return false;

  final db = FirebaseFirestore.instance;
  final groupRef = db.collection('groups').doc(groupId);
  final markerRef = groupRef.collection('_dev').doc('seedMarker');

  final marker = await markerRef.get();
  if (marker.exists) return false;

  final membersRef = groupRef.collection('members');
  final eventsRef = groupRef.collection('events');
  final noticesRef = groupRef.collection('notices');

  final fakeMembers = <Map<String, String>>[
    {'uid': 'demo_user_1', 'nickname': '민수'},
    {'uid': 'demo_user_2', 'nickname': '지연'},
    {'uid': 'demo_user_3', 'nickname': '상호'},
    {'uid': 'demo_user_4', 'nickname': '서연'},
    {'uid': 'demo_user_5', 'nickname': '준호'},
  ];

  for (final m in fakeMembers) {
    await membersRef.doc(m['uid']!).set({
      'status': 'active',
      'public': {
        'nickname': m['nickname'],
        'avatarUrl': null,
        'joinedAt': FieldValue.serverTimestamp(),
      },
      'permissions': <String, dynamic>{},
      'role': 'member',
    }, SetOptions(merge: true));
  }

  // 그룹 생성자(시더 실행자)는 owner로 고정한다.
  await membersRef.doc(adminUid).set({
    'status': 'active',
    'role': 'owner',
    'permissions': <String, dynamic>{},
    'public': {'joinedAt': FieldValue.serverTimestamp()},
  }, SetOptions(merge: true));

  final now = DateTime.now();
  final demoEvents = <Map<String, dynamic>>[
    {
      'title': '주말 정기 모임',
      'startAt': now.subtract(const Duration(days: 2)),
      'locationName': '잠실 실내체육관 A코트',
      'address': '서울 송파구 올림픽로 25',
      'location': '잠실 실내체육관',
    },
    {
      'title': '월간 전략 회의',
      'startAt': now.subtract(const Duration(days: 7)),
      'locationName': '강남 구장 2층 회의실',
      'address': '서울 강남구 테헤란로 123',
      'location': '강남 구장 2층 회의실',
    },
    {
      'title': '평일 저녁 훈련',
      'startAt': now.add(const Duration(days: 1)),
      'locationName': '한강 운동장 A코트',
      'address': '서울 영등포구 여의동로 330',
      'location': '한강 운동장 A코트',
    },
    {
      'title': '친선 경기',
      'startAt': now.add(const Duration(days: 3)),
      'locationName': '송파 풋살파크 1구장',
      'address': '서울 송파구 중대로 10',
      'location': '송파 풋살파크 1구장',
    },
    {
      'title': '월말 평가전',
      'startAt': now.add(const Duration(days: 10)),
      'locationName': '목동 종합운동장',
      'address': '서울 양천구 안양천로 939',
      'location': '목동 종합운동장',
    },
  ];

  final createdEvents = <DocumentReference<Map<String, dynamic>>>[];
  for (final e in demoEvents) {
    final ref = eventsRef.doc();
    await ref.set({
      'title': e['title'],
      'startAt': Timestamp.fromDate(e['startAt'] as DateTime),
      'locationName': e['locationName'],
      'address': e['address'],
      'location': e['location'],
      'isDeleted': false,
      'createdAt': FieldValue.serverTimestamp(),
      '_devSeed': true,
      '_devSeedKey': _devSeedKey,
    });
    createdEvents.add(ref);
  }

  final responsePlan = <int, Map<String, String>>{
    2: {
      'demo_user_1': 'going',
      'demo_user_2': 'maybe',
      'demo_user_3': 'notGoing',
      'demo_user_4': 'going',
      adminUid: 'going',
    },
    3: {
      'demo_user_1': 'going',
      'demo_user_2': 'going',
      'demo_user_3': 'maybe',
      'demo_user_5': 'notGoing',
    },
    4: {'demo_user_2': 'maybe', 'demo_user_4': 'going', adminUid: 'maybe'},
  };

  for (final entry in responsePlan.entries) {
    final eventRef = createdEvents[entry.key];
    for (final r in entry.value.entries) {
      await eventRef.collection('responses').doc(r.key).set({
        'response': r.value,
        'respondedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  await noticesRef.doc().set({
    'title': '3월 회비 안내',
    'body': '이번 달 회비 입금 일정을 확인해 주세요.',
    'pinned': true,
    'createdAt': FieldValue.serverTimestamp(),
    '_devSeed': true,
    '_devSeedKey': _devSeedKey,
  });
  await noticesRef.doc().set({
    'title': '이번 주 일정 변경',
    'body': '이번 주 훈련 일정이 일부 조정되었습니다.',
    'pinned': false,
    'createdAt': FieldValue.serverTimestamp(),
    '_devSeed': true,
    '_devSeedKey': _devSeedKey,
  });

  final periodKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
  final monthStart = DateTime(now.year, now.month, 1);
  final monthEnd = DateTime(now.year, now.month + 1, 1);

  final nicknameByUid = <String, String>{
    for (final m in fakeMembers) m['uid']!: m['nickname']!,
  };
  final adminMember = await membersRef.doc(adminUid).get();
  final adminNickname = adminMember.data()?['public']?['nickname']?.toString();
  nicknameByUid[adminUid] = (adminNickname != null && adminNickname.isNotEmpty)
      ? adminNickname
      : '나';

  final allUids = <String>[...fakeMembers.map((m) => m['uid']!), adminUid];
  final attendanceScore = <String, int>{for (final uid in allUids) uid: 0};
  final activityScore = <String, int>{for (final uid in allUids) uid: 0};

  for (var i = 0; i < createdEvents.length; i++) {
    final eventDate = demoEvents[i]['startAt'] as DateTime;
    final planned = responsePlan[i] ?? const <String, String>{};
    for (final r in planned.entries) {
      if (eventDate.isBefore(now) && r.value == 'going') {
        attendanceScore[r.key] = (attendanceScore[r.key] ?? 0) + 1;
      }
      if (!eventDate.isBefore(monthStart) && eventDate.isBefore(monthEnd)) {
        activityScore[r.key] = (activityScore[r.key] ?? 0) + 1;
      }
    }
  }

  List<MapEntry<String, int>> buildTop(Map<String, int> scoreMap) {
    final sorted = scoreMap.entries.toList();
    sorted.sort((a, b) => b.value.compareTo(a.value));
    return sorted;
  }

  final attendanceTop = buildTop(attendanceScore)
      .take(5)
      .map(
        (e) => {
          'uid': e.key,
          'score': e.value,
          'nickname': nicknameByUid[e.key] ?? e.key,
        },
      )
      .toList();

  final activityTop = buildTop(activityScore)
      .take(5)
      .map(
        (e) => {
          'uid': e.key,
          'score': e.value,
          'nickname': nicknameByUid[e.key] ?? e.key,
        },
      )
      .toList();

  await groupRef.collection('leaderboards').doc(periodKey).set({
    'generatedAt': FieldValue.serverTimestamp(),
    'attendanceTop': attendanceTop,
    'activityTop': activityTop,
    '_devSeed': true,
    '_devSeedKey': _devSeedKey,
  }, SetOptions(merge: true));

  final activeMembers = await membersRef
      .where('status', isEqualTo: 'active')
      .get();
  final eventCountThisMonth = demoEvents.where((e) {
    final dt = e['startAt'] as DateTime;
    return !dt.isBefore(monthStart) && dt.isBefore(monthEnd);
  }).length;

  await groupRef.collection('stats').doc(periodKey).set({
    'activeMemberCount': activeMembers.docs.length,
    'eventCountThisMonth': eventCountThisMonth,
    'generatedAt': FieldValue.serverTimestamp(),
    '_devSeed': true,
    '_devSeedKey': _devSeedKey,
  }, SetOptions(merge: true));

  await markerRef.set({
    'seededAt': FieldValue.serverTimestamp(),
    'seededBy': adminUid,
    'version': 3,
    '_devSeed': true,
    '_devSeedKey': _devSeedKey,
  }, SetOptions(merge: true));

  return true;
}

Future<bool> resetDemoSeedAndReseed(String groupId, String adminUid) async {
  if (!kDebugMode) return false;

  final db = FirebaseFirestore.instance;
  final groupRef = db.collection('groups').doc(groupId);

  final seededEvents = await groupRef
      .collection('events')
      .where('_devSeed', isEqualTo: true)
      .get();
  for (final doc in seededEvents.docs) {
    if (doc.data()['_devSeedKey'] == _devSeedKey) {
      await doc.reference.delete();
    }
  }

  final seededNotices = await groupRef
      .collection('notices')
      .where('_devSeed', isEqualTo: true)
      .get();
  for (final doc in seededNotices.docs) {
    if (doc.data()['_devSeedKey'] == _devSeedKey) {
      await doc.reference.delete();
    }
  }

  final periodKey = _currentPeriodKey();
  final leaderboardRef = groupRef.collection('leaderboards').doc(periodKey);
  final statsRef = groupRef.collection('stats').doc(periodKey);
  final leaderboard = await leaderboardRef.get();
  final stats = await statsRef.get();

  if ((leaderboard.data()?['_devSeed'] ?? false) == true &&
      leaderboard.data()?['_devSeedKey'] == _devSeedKey) {
    await leaderboardRef.delete();
  }
  if ((stats.data()?['_devSeed'] ?? false) == true &&
      stats.data()?['_devSeedKey'] == _devSeedKey) {
    await statsRef.delete();
  }

  await groupRef.collection('_dev').doc('seedMarker').delete();
  return seedDemoMembersAndData(groupId, adminUid);
}

Future<bool> seedDemoData(String groupId, String uid) {
  return seedDemoMembersAndData(groupId, uid);
}

String _currentPeriodKey([DateTime? date]) {
  final now = date ?? DateTime.now();
  final month = now.month.toString().padLeft(2, '0');
  return '${now.year}-$month';
}
