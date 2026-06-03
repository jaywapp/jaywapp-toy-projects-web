// 이 클래스의 역할/권한 로직은 firestore.rules의 hasPermission(), canManageFinance()
// 함수와 동일한 정책을 구현합니다. 두 곳의 로직이 드리프트(불일치)하지 않도록
// 권한 조건 변경 시 반드시 firestore.rules도 함께 수정해야 합니다.
// 권한 매트릭스 전체 정의: Docs/Moyeora_Role_System.md
class PermissionService {
  PermissionService._(this._role, this._legacyPermissions);

  final String _role;
  final Set<String> _legacyPermissions;

  static const String owner = 'owner';
  static const String admin = 'admin';
  static const String treasurer = 'treasurer';
  static const String member = 'member';

  static PermissionService fromMemberData(Map<String, dynamic>? memberData) {
    if (memberData == null) {
      return PermissionService._(member, <String>{});
    }

    final status = memberData['status']?.toString();
    if (status != 'active') {
      return PermissionService._(member, <String>{});
    }

    final rawRole = memberData['role']?.toString().toLowerCase();
    final normalizedRole = switch (rawRole) {
      owner || admin || treasurer || member => rawRole!,
      _ => member,
    };

    return PermissionService._(
      normalizedRole,
      _normalizeLegacyPermissions(memberData['permissions']),
    );
  }

  String get role => _role;

  bool get isOwner => _role == owner;

  bool get isAdmin => _role == admin;

  bool get isTreasurer => _role == treasurer;

  bool get isMember => _role == member;

  bool canManageMembers() {
    return isOwner || isAdmin || _legacyPermissions.contains('member.manage');
  }

  bool canManageEvents() {
    return isOwner || isAdmin || _legacyPermissions.contains('event.manage');
  }

  bool canManageFinance() {
    return isOwner || isTreasurer || _legacyPermissions.contains('fee.manage');
  }

  bool canManageRoles() {
    return isOwner || _legacyPermissions.contains('role.manage');
  }

  bool isReadOnly() {
    return !(canManageMembers() ||
        canManageEvents() ||
        canManageFinance() ||
        canManageRoles());
  }

  bool canAccessAdminDashboard() {
    return canManageMembers() ||
        canManageEvents() ||
        canManageFinance() ||
        canManageRoles();
  }

  static Set<String> _normalizeLegacyPermissions(dynamic permissions) {
    if (permissions is List) {
      return permissions.whereType<String>().toSet();
    }
    if (permissions is Map<String, dynamic>) {
      final result = <String>{};
      permissions.forEach((key, value) {
        if (value == true) {
          result.add(key);
          return;
        }
        if (value is Map<String, dynamic>) {
          value.forEach((childKey, childValue) {
            if (childValue == true) {
              result.add('$key.$childKey');
            }
          });
        }
      });
      return result;
    }
    return <String>{};
  }
}
