import 'dart:math' as math;

class UuidHelper {
  static final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static bool isValidUuid(String? val) {
    if (val == null || val.trim().isEmpty) return false;
    return _uuidRegex.hasMatch(val.trim());
  }

  static String generate() {
    final rnd = math.Random();
    String hex(int len) => List.generate(len, (_) => rnd.nextInt(16).toRadixString(16)).join();
    return '${hex(8)}-${hex(4)}-4${hex(3)}-8${hex(3)}-${hex(12)}';
  }
}
