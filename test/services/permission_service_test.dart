import 'package:flutter_test/flutter_test.dart';
import 'package:moyeora/services/permission_service.dart';

void main() {
  group('PermissionService.fromMemberData', () {
    test('null 데이터 → member 역할, 권한 없음', () {
      final svc = PermissionService.fromMemberData(null);
      expect(svc.role, PermissionService.member);
      expect(svc.canManageMembers(), isFalse);
      expect(svc.canManageEvents(), isFalse);
      expect(svc.canManageFinance(), isFalse);
      expect(svc.canManageRoles(), isFalse);
    });

    test('status가 active가 아니면 → member 역할로 강등', () {
      final svc = PermissionService.fromMemberData({
        'role': 'owner',
        'status': 'inactive',
      });
      expect(svc.role, PermissionService.member);
      expect(svc.isOwner, isFalse);
    });

    test('role = owner', () {
      final svc = PermissionService.fromMemberData({
        'role': 'owner',
        'status': 'active',
      });
      expect(svc.isOwner, isTrue);
      expect(svc.canManageMembers(), isTrue);
      expect(svc.canManageEvents(), isTrue);
      expect(svc.canManageFinance(), isTrue);
      expect(svc.canManageRoles(), isTrue);
      expect(svc.isReadOnly(), isFalse);
    });

    test('role = admin', () {
      final svc = PermissionService.fromMemberData({
        'role': 'admin',
        'status': 'active',
      });
      expect(svc.isAdmin, isTrue);
      expect(svc.canManageMembers(), isTrue);
      expect(svc.canManageEvents(), isTrue);
      expect(svc.canManageFinance(), isFalse);
      expect(svc.canManageRoles(), isFalse);
    });

    test('role = treasurer', () {
      final svc = PermissionService.fromMemberData({
        'role': 'treasurer',
        'status': 'active',
      });
      expect(svc.isTreasurer, isTrue);
      expect(svc.canManageFinance(), isTrue);
      expect(svc.canManageMembers(), isFalse);
      expect(svc.canManageEvents(), isFalse);
      expect(svc.canManageRoles(), isFalse);
    });

    test('role = member → 읽기 전용', () {
      final svc = PermissionService.fromMemberData({
        'role': 'member',
        'status': 'active',
      });
      expect(svc.isMember, isTrue);
      expect(svc.isReadOnly(), isTrue);
      expect(svc.canAccessAdminDashboard(), isFalse);
    });

    test('알 수 없는 role → member로 폴백', () {
      final svc = PermissionService.fromMemberData({
        'role': 'superadmin',
        'status': 'active',
      });
      expect(svc.role, PermissionService.member);
    });

    test('대소문자 무관하게 역할 정규화', () {
      final svc = PermissionService.fromMemberData({
        'role': 'OWNER',
        'status': 'active',
      });
      expect(svc.isOwner, isTrue);
    });
  });

  group('레거시 permissions (List 형식)', () {
    test('member.manage 권한 → canManageMembers()', () {
      final svc = PermissionService.fromMemberData({
        'role': 'member',
        'status': 'active',
        'permissions': ['member.manage'],
      });
      expect(svc.canManageMembers(), isTrue);
      expect(svc.canManageEvents(), isFalse);
    });

    test('fee.manage 권한 → canManageFinance()', () {
      final svc = PermissionService.fromMemberData({
        'role': 'member',
        'status': 'active',
        'permissions': ['fee.manage'],
      });
      expect(svc.canManageFinance(), isTrue);
    });

    test('복수 레거시 권한 조합', () {
      final svc = PermissionService.fromMemberData({
        'role': 'member',
        'status': 'active',
        'permissions': ['event.manage', 'role.manage'],
      });
      expect(svc.canManageEvents(), isTrue);
      expect(svc.canManageRoles(), isTrue);
      expect(svc.isReadOnly(), isFalse);
    });
  });

  group('레거시 permissions (Map 형식)', () {
    test('Map 형식 권한 파싱', () {
      final svc = PermissionService.fromMemberData({
        'role': 'member',
        'status': 'active',
        'permissions': {
          'member': {'manage': true},
          'fee': {'manage': false},
        },
      });
      expect(svc.canManageMembers(), isTrue);
      expect(svc.canManageFinance(), isFalse);
    });

    test('최상위 Map 권한 파싱', () {
      final svc = PermissionService.fromMemberData({
        'role': 'member',
        'status': 'active',
        'permissions': {'event.manage': true},
      });
      expect(svc.canManageEvents(), isTrue);
    });

    test('permissions가 null 이면 빈 권한', () {
      final svc = PermissionService.fromMemberData({
        'role': 'member',
        'status': 'active',
        'permissions': null,
      });
      expect(svc.isReadOnly(), isTrue);
    });
  });

  group('canAccessAdminDashboard', () {
    test('owner → 대시보드 접근 가능', () {
      final svc = PermissionService.fromMemberData({
        'role': 'owner',
        'status': 'active',
      });
      expect(svc.canAccessAdminDashboard(), isTrue);
    });

    test('일반 member → 대시보드 접근 불가', () {
      final svc = PermissionService.fromMemberData({
        'role': 'member',
        'status': 'active',
      });
      expect(svc.canAccessAdminDashboard(), isFalse);
    });
  });
}
