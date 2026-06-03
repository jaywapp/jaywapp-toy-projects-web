class ProfilePolicy {
  ProfilePolicy._();

  static final RegExp _realNamePattern = RegExp(r'^[A-Za-z가-힣\s]{2,20}$');

  static bool isValidRealName(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return false;
    if (!_realNamePattern.hasMatch(value)) return false;
    if (value.startsWith(' ') || value.endsWith(' ')) return false;
    if (value.contains('  ')) return false;
    return true;
  }

  static String normalizePhoneNumber(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    final hasPlus = trimmed.startsWith('+');
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';
    return hasPlus ? '+$digits' : digits;
  }

  static bool isValidPhoneNumber(String raw) {
    final normalized = normalizePhoneNumber(raw);
    if (normalized.isEmpty) return false;
    final digits = normalized.startsWith('+')
        ? normalized.substring(1)
        : normalized;
    return digits.length >= 9 && digits.length <= 15;
  }
}
