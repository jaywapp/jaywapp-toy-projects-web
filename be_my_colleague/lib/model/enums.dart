enum Permission { normal, secretary, vicePresident, president }

class PermissionExt {
  static Permission Parse(String permission) {
    switch (permission) {
      case 'president':
        return Permission.president;
      case 'vicePresident':
        return Permission.vicePresident;
      case 'secretary':
        return Permission.secretary;
      case 'normal':
        return Permission.normal;
      default:
        throw Exception('Unknown permission: $permission');
    }
  }
}
