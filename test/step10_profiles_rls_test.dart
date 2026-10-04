import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_app/data/services/auth_service.dart';
import 'package:school_app/data/models/user_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('STEP 10 — Profiles RLS & Auth Profile Select Tests', () {
    late AuthService authService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      authService = AuthService();
    });

    test('TEST 1: Query profile by auth_user_id returns correct profile model', () async {
      final profile = await authService.fetchUserProfile('auth_admin_001');
      expect(profile, isNotNull);
      expect(profile!.authUserId, equals('auth_admin_001'));
      expect(profile.role.isAdministrator, isTrue);
      expect(profile.status, equals(AccountStatus.active));
      expect(profile.schoolId, isNotEmpty);
    });

    test('TEST 2: Invalid auth_user_id returns null when profile does not exist', () async {
      final profile = await authService.fetchUserProfile('nonexistent_uid_99999');
      expect(profile, isNull);
    });

    test('TEST 3: Verify signInWithEmailAndPassword profile loading & admin portal validation', () async {
      final admin = await authService.signInWithEmailAndPassword(
        email: 'admin@school.com',
        password: 'password123',
        requiresAdminPortal: true,
      );

      expect(admin, isNotNull);
      expect(admin.role.isAdministrator, isTrue);
      expect(admin.status, equals(AccountStatus.active));
      expect(admin.schoolId, isNotEmpty);
    });
  });
}
