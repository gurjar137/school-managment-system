import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../../core/config/supabase_config.dart';

class AuthService {
  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) {
        return Supabase.instance.client;
      }
    } catch (_) {}
    return null;
  }

  final List<UserProfileModel> _mockProfiles = [
    UserProfileModel(
      id: 'prof_001',
      authUserId: 'auth_admin_001',
      schoolId: 'SCH-2026-DELHI',
      schoolName: 'Primary School Campus',
      name: 'School Administrator',
      email: 'admin@school.com',
      role: UserRole.owner,
      status: AccountStatus.active,
      designation: 'Principal & Director',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      createdAt: DateTime.now().subtract(const Duration(days: 365)),
    ),
    UserProfileModel(
      id: 'prof_teacher',
      authUserId: 'auth_teacher_001',
      schoolId: 'SCH-2026-DELHI',
      schoolName: 'Primary School Campus',
      name: 'Faculty Educator',
      email: 'teacher@school.com',
      role: UserRole.teacher,
      status: AccountStatus.active,
      designation: 'Faculty Member',
      createdAt: DateTime.now().subtract(const Duration(days: 200)),
    ),
  ];

  // --- SIGN IN WITH ROLE PROTECTION ---
  Future<UserProfileModel> signInWithEmailAndPassword({
    required String email,
    required String password,
    required bool requiresAdminPortal,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final trimmedEmail = email.trim().toLowerCase();

    // 1. Supabase Auth if configured (Production / Real Mode)
    final client = _client;
    if (SupabaseConfig.isConfigured && client != null) {

      print('========================================');
      print('LOGIN DEBUG');
      print('email = $trimmedEmail');
      print('SupabaseConfig.isConfigured = ${SupabaseConfig.isConfigured}');
      print('Supabase client initialized = true');
      print('currentUser before login = ${client.auth.currentUser?.email}');
      print('currentSession before login = ${client.auth.currentSession != null}');
      print('Supabase URL host = ${Uri.tryParse(SupabaseConfig.url)?.host ?? SupabaseConfig.url}');
      print('========================================');

      try {
        final res = await client.auth.signInWithPassword(
          email: trimmedEmail,
          password: password,
        );

        final user = res.user ?? client.auth.currentUser;
        final sessionActive = client.auth.currentSession != null;

        print('========================================');
        print('AUTH RESULT');
        print('success = true');
        print('status/error code = 200');
        print('error message = null');
        print('returned user id = ${user?.id}');
        print('returned user email = ${user?.email}');
        print('session active = $sessionActive');
        print('========================================');

        if (user == null) {
          throw Exception('Authentication succeeded, but no user session was returned.');
        }

        final profile = await fetchUserProfile(user.id);
        print('PROFILE LOOKUP: found=${profile != null}, role=${profile?.role}, schoolId=${profile?.schoolId}');

        if (profile == null) {
          await _client?.auth.signOut();
          throw Exception('Account authenticated, but the user profile could not be loaded.');
        }

        try {
          _validateRoleAndStatus(profile, requiresAdminPortal);
        } catch (e) {
          await _client?.auth.signOut();
          rethrow;
        }
        print('ROLE VALIDATION: passed for ${profile.email}');
        return profile;
      } on AuthException catch (e) {
        print('========================================');
        print('AUTH RESULT');
        print('success = false');
        print('status/error code = ${e.statusCode}');
        print('error message = ${e.message}');
        print('returned user id = null');
        print('returned user email = null');
        print('session active = false');
        print('========================================');

        final msg = e.message.toLowerCase();
        if (msg.contains('email not confirmed')) {
          throw Exception('Please verify your email before signing in.');
        } else if (msg.contains('invalid login credentials') || msg.contains('invalid_credentials')) {
          throw Exception('Invalid email or password.');
        } else if (msg.contains('failed to fetch') ||
            msg.contains('clientexception') ||
            msg.contains('networkerror') ||
            msg.contains('socketexception') ||
            msg.contains('connection')) {
          throw Exception('Unable to connect to the authentication server. Check your internet connection.');
        } else {
          throw Exception(e.message);
        }
      } catch (e) {
        print('========================================');
        print('AUTH RESULT');
        print('success = false');
        print('status/error code = unexpected_exception');
        print('error message = $e');
        print('returned user id = null');
        print('returned user email = null');
        print('session active = false');
        print('========================================');

        final msg = e.toString().toLowerCase();
        if (msg.contains('failed to fetch') ||
            msg.contains('clientexception') ||
            msg.contains('networkerror') ||
            msg.contains('socketexception') ||
            msg.contains('connection')) {
          throw Exception('Unable to connect to the authentication server. Check your internet connection.');
        }
        rethrow;
      }
    }

    // 2. Offline / Mock-only Mode (ONLY when Supabase is NOT configured)
    final match = _mockProfiles.firstWhere(
      (p) => p.email.toLowerCase() == trimmedEmail,
      orElse: () {
        throw Exception('Invalid email or password.');
      },
    );

    _validateRoleAndStatus(match, requiresAdminPortal);
    return match;
  }

  void _validateRoleAndStatus(UserProfileModel profile, bool requiresAdminPortal) {
    if (profile.status == AccountStatus.inactive || profile.status == AccountStatus.suspended) {
      throw Exception('Your account is currently ${profile.status.displayName}. Please contact your school administrator.');
    }

    if (requiresAdminPortal && !profile.role.isAdministrator) {
      throw Exception('This account does not have administrator access. Please use Staff Login.');
    }
  }

  // --- PASSWORD RECOVERY FLOW ---
  Future<void> sendPasswordResetEmail({
    required String email,
    String? redirectTo,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();
    if (trimmedEmail.isEmpty) {
      throw Exception('Please enter your administrator email address.');
    }

    if (SupabaseConfig.isConfigured) {
      final client = _client;
      if (client == null) {
        throw Exception('Authentication service is not initialized. Please restart the app.');
      }

      final targetRedirectUrl = redirectTo ?? SupabaseConfig.passwordResetRedirectUrl;
      debugPrint('[AuthService] Sending password reset for $trimmedEmail with redirectTo: $targetRedirectUrl');

      try {
        // Isolated recovery client with AuthFlowType.implicit to generate standard implicit recovery tokens
        // (#access_token=...&type=recovery), eliminating cross-browser PKCE code-verifier dependency
        final recoveryClient = SupabaseClient(
          SupabaseConfig.url,
          SupabaseConfig.publishableKey,
          authOptions: const AuthClientOptions(
            authFlowType: AuthFlowType.implicit,
          ),
        );

        await recoveryClient.auth.resetPasswordForEmail(
          trimmedEmail,
          redirectTo: targetRedirectUrl,
        );
        debugPrint('[AuthService] Password reset email dispatched successfully via implicit recovery.');
      } on AuthException catch (e) {
        debugPrint('[AuthService AuthException]: ${e.message} (status: ${e.statusCode})');
        final msg = e.message.toLowerCase();
        if (msg.contains('rate limit') || msg.contains('over_email_send_rate_limit')) {
          throw Exception('Password reset requested recently. Please wait a minute before requesting again.');
        }
        throw Exception(e.message);
      } catch (e) {
        debugPrint('[AuthService Error]: $e');
        final msg = e.toString().toLowerCase();
        if (msg.contains('failed to fetch') || msg.contains('network') || msg.contains('connection')) {
          throw Exception('Unable to connect to authentication server. Check your internet connection.');
        }
        throw Exception('Failed to send password reset email: $e');
      }
      return;
    }

    // Offline / Mock Mode
    debugPrint('[AuthService Mock] Password reset email simulated for $trimmedEmail');
  }

  Future<void> updatePassword({required String newPassword}) async {
    if (newPassword.trim().length < 6) {
      throw Exception('Password must be at least 6 characters long.');
    }

    if (SupabaseConfig.isConfigured) {
      final client = _client;
      if (client == null) {
        throw Exception('Authentication service is not initialized. Please restart the app.');
      }

      try {
        debugPrint('[AuthService] Updating user password via Supabase Auth...');
        final res = await client.auth.updateUser(
          UserAttributes(password: newPassword.trim()),
        );

        if (res.user == null) {
          throw Exception('Password update did not return a valid user confirmation.');
        }

        debugPrint('[AuthService] Password updated successfully for: ${res.user?.email}');
        // Sign out temporary recovery session so administrator can sign in cleanly
        await client.auth.signOut();
      } on AuthException catch (e) {
        debugPrint('[AuthService AuthException]: ${e.message} (status: ${e.statusCode})');
        throw Exception(e.message);
      } catch (e) {
        debugPrint('[AuthService Error]: $e');
        final msg = e.toString().toLowerCase();
        if (msg.contains('failed to fetch') || msg.contains('network') || msg.contains('connection')) {
          throw Exception('Unable to connect to authentication server. Check your internet connection.');
        }
        throw Exception('Failed to update password: $e');
      }
      return;
    }

    // Offline / Mock Mode
    debugPrint('[AuthService Mock] Password updated simulated.');
  }

  Future<void> changePassword({
    required String newPassword,
    bool isFirstLogin = false,
  }) async {
    if (newPassword.trim().length < 8) {
      throw Exception('Password must be at least 8 characters long.');
    }

    if (SupabaseConfig.isConfigured) {
      final client = _client;
      if (client == null) {
        throw Exception('Authentication service is not initialized. Please restart the app.');
      }

      try {
        debugPrint('[AuthService] Changing user password via Supabase Auth (isFirstLogin=$isFirstLogin)...');
        final res = await client.auth.updateUser(
          UserAttributes(
            password: newPassword.trim(),
            data: {'must_change_password': false},
          ),
        );

        if (res.user == null) {
          throw Exception('Password update did not return a valid user confirmation.');
        }

        debugPrint('[AuthService] Password updated successfully for: ${res.user?.email}');
      } on AuthException catch (e) {
        debugPrint('[AuthService AuthException]: ${e.message} (status: ${e.statusCode})');
        throw Exception(e.message);
      } catch (e) {
        debugPrint('[AuthService Error]: $e');
        final msg = e.toString().toLowerCase();
        if (msg.contains('failed to fetch') || msg.contains('network') || msg.contains('connection')) {
          throw Exception('Unable to connect to authentication server. Check your internet connection.');
        }
        rethrow;
      }
      return;
    }

    // Offline / Mock Mode
    debugPrint('[AuthService Mock] Password changed successfully (isFirstLogin=$isFirstLogin)');
  }

  // --- FETCH USER PROFILE ---
  Future<UserProfileModel?> fetchUserProfile(String authUserId) async {
    final client = _client;
    if (SupabaseConfig.isConfigured && client != null) {
      try {
        final data = await client
            .from('profiles')
            .select()
            .or('auth_user_id.eq.$authUserId,id.eq.$authUserId')
            .maybeSingle();

        if (data != null) {
          final rawClass = data['assigned_class']?.toString() ?? data['class']?.toString();
          String? parsedClass = rawClass;
          String? parsedSection = data['assigned_section']?.toString() ?? data['section']?.toString();

          final meta = client.auth.currentUser?.id == authUserId
              ? (client.auth.currentUser?.userMetadata ?? {})
              : <String, dynamic>{};

          if (parsedClass == null || parsedClass.isEmpty) {
            parsedClass = meta['assigned_class']?.toString() ?? meta['class']?.toString();
          }
          if (parsedSection == null || parsedSection.isEmpty) {
            parsedSection = meta['assigned_section']?.toString() ?? meta['section']?.toString();
          }

          if (parsedClass != null && parsedClass.contains('-') && (parsedSection == null || parsedSection.isEmpty)) {
            final parts = parsedClass.split('-');
            parsedClass = parts.first.trim();
            if (parts.length > 1) {
              parsedSection = parts.sublist(1).join('-').trim();
            }
          }

          final emailStr = (data['email'] != null && data['email'].toString().isNotEmpty)
              ? data['email'].toString()
              : (client.auth.currentUser?.id == authUserId ? (client.auth.currentUser?.email ?? '') : '');

          return UserProfileModel(
            id: data['id']?.toString() ?? authUserId,
            authUserId: data['auth_user_id']?.toString() ?? authUserId,
            schoolId: data['school_id']?.toString() ?? '',
            schoolName: data['school_name']?.toString() ?? 'School',
            name: data['full_name']?.toString() ?? data['name']?.toString() ?? 'Faculty Member',
            email: emailStr,
            role: _parseRole(data['role']?.toString()),
            status: _parseStatus(data['status']?.toString()),
            designation: data['designation']?.toString() ?? 'Teacher',
            assignedClass: parsedClass,
            assignedSection: parsedSection,
            subject: data['subject']?.toString(),
            mustChangePassword: (data['must_change_password'] == true) ||
                (client.auth.currentUser?.id == authUserId &&
                    client.auth.currentUser?.userMetadata?['must_change_password'] == true),
            createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
          );
        } else if (client.auth.currentUser?.id == authUserId) {
          final user = client.auth.currentUser!;
          final meta = user.userMetadata ?? {};
          final metaSchoolId = meta['school_id']?.toString().trim();
          if (metaSchoolId != null && metaSchoolId.isNotEmpty) {
            return UserProfileModel(
              id: user.id,
              authUserId: user.id,
              schoolId: metaSchoolId,
              schoolName: meta['school_name']?.toString() ?? 'School',
              name: meta['full_name']?.toString() ?? user.email?.split('@').first ?? 'School Admin',
              email: user.email ?? '',
              role: _parseRole(meta['role']?.toString()),
              status: AccountStatus.active,
              designation: meta['designation']?.toString() ?? 'Administrator',
              assignedClass: meta['assigned_class']?.toString(),
              assignedSection: meta['assigned_section']?.toString(),
              mustChangePassword: meta['must_change_password'] == true,
              createdAt: DateTime.tryParse(user.createdAt) ?? DateTime.now(),
            );
          }
        }
      } catch (e) {
        debugPrint('[AuthService Profile Fetch Warning]: $e');
      }
    }

    // Fallback for tests or offline profiles
    try {
      return _mockProfiles.firstWhere((p) => p.authUserId == authUserId || p.id == authUserId);
    } catch (_) {
      return null;
    }
  }

  // --- SCHOOL ONBOARDING (PRIMARY ADMIN REGISTRATION) ---
  Future<UserProfileModel> registerPrimarySchoolAdmin({
    required String schoolName,
    required String address,
    required String adminName,
    required String email,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 350));
    final schoolId = 'sch_${DateTime.now().millisecondsSinceEpoch}';
    final trimmedEmail = email.trim().toLowerCase();

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        debugPrint('[ONBOARDING LOG STEP 1]: Initiating signUp for $trimmedEmail');
        final authRes = await _client!.auth.signUp(
          email: trimmedEmail,
          password: password,
        );

        debugPrint('[ONBOARDING LOG STEP 2]: signUp result -> User: ${authRes.user?.id}, Session: ${authRes.session != null}');

        if (authRes.user != null) {
          // If session is null (Email confirmation enabled), attempt auto signInWithPassword to obtain active session
          if (authRes.session == null) {
            debugPrint('[ONBOARDING LOG STEP 2b]: Session is null. Attempting signInWithPassword to obtain active session.');
            try {
              final signInRes = await _client!.auth.signInWithPassword(
                email: trimmedEmail,
                password: password,
              );
              debugPrint('[ONBOARDING LOG STEP 2c]: Auto-login result -> Session: ${signInRes.session != null}');
            } catch (signInErr) {
              debugPrint('[ONBOARDING LOG STEP 2c Warning]: Auto-login failed (unconfirmed email setting): $signInErr');
            }
          }

          final currentUser = _client!.auth.currentUser;
          debugPrint('[ONBOARDING LOG STEP 3]: Current Auth User: ${currentUser?.id}');

          if (currentUser != null) {
            try {
              debugPrint('[ONBOARDING LOG STEP 4]: Calling register_primary_school_admin RPC...');
              final rpcRes = await _client!.rpc('register_primary_school_admin', params: {
                'p_school_name': schoolName,
                'p_address': address,
                'p_admin_name': adminName,
                'p_admin_email': trimmedEmail,
              });
              debugPrint('[ONBOARDING LOG STEP 5]: RPC Success -> $rpcRes');
            } on PostgrestException catch (rpcErr) {
              debugPrint('[ONBOARDING LOG STEP 4 Error]: PostgrestException code=${rpcErr.code}, message=${rpcErr.message}');
              if (rpcErr.code == '42883' || rpcErr.message.contains('does not exist') || rpcErr.code == 'PGRST202') {
                throw Exception('School onboarding is not configured yet. Please contact the administrator.');
              } else {
                throw Exception(rpcErr.message);
              }
            }

            final profile = await fetchUserProfile(currentUser.id);
            if (profile != null) return profile;
          } else {
            throw Exception('Account created! Please verify your email inbox before signing in.');
          }
        }
      } on AuthException catch (e) {
        final msg = e.message.toLowerCase();
        if (msg.contains('rate_limit') || msg.contains('rate limit') || msg.contains('too many requests') || e.statusCode == '429') {
          throw Exception('Supabase email rate limit reached. Please wait 60 seconds, or turn off "Confirm Email" in your Supabase Auth Dashboard settings for development testing.');
        } else if (msg.contains('already registered') || msg.contains('already in use')) {
          throw Exception('An account with this email is already registered. Please sign in instead.');
        } else if (msg.contains('weak')) {
          throw Exception('Password is too weak. Please use at least 8 characters with numbers & symbols.');
        } else {
          throw Exception(e.message);
        }
      } catch (e) {
        if (e is Exception) rethrow;
        debugPrint('[AuthService Onboarding Warning]: $e');
      }
    }

    final newOwner = UserProfileModel(
      id: 'prof_${DateTime.now().millisecondsSinceEpoch}',
      authUserId: 'auth_owner_${DateTime.now().millisecondsSinceEpoch}',
      schoolId: schoolId,
      schoolName: schoolName,
      name: adminName,
      email: trimmedEmail,
      role: UserRole.schoolAdmin,
      status: AccountStatus.active,
      designation: 'Primary School Administrator',
      createdAt: DateTime.now(),
    );

    _mockProfiles.insert(0, newOwner);
    return newOwner;
  }

  // --- ADMIN CREATES NEW ADMIN ---
  Future<UserProfileModel> createAdminAccount({
    required String schoolId,
    required String schoolName,
    required String name,
    required String email,
    required String designation,
    required UserRole role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));

    final newAdmin = UserProfileModel(
      id: 'prof_${DateTime.now().millisecondsSinceEpoch}',
      authUserId: 'auth_admin_${DateTime.now().millisecondsSinceEpoch}',
      schoolId: schoolId,
      schoolName: schoolName,
      name: name,
      email: email,
      role: role,
      status: AccountStatus.active,
      designation: designation,
      createdAt: DateTime.now(),
    );

    _mockProfiles.insert(0, newAdmin);
    return newAdmin;
  }

  UserProfileModel _mapProfile(Map<String, dynamic> data) {
    final rawClass = data['assigned_class']?.toString() ?? data['class']?.toString();
    String? parsedClass = rawClass;
    String? parsedSection = data['assigned_section']?.toString() ?? data['section']?.toString();

    if (parsedClass != null && parsedClass.contains('-') && (parsedSection == null || parsedSection.isEmpty)) {
      final parts = parsedClass.split('-');
      parsedClass = parts.first.trim();
      if (parts.length > 1) {
        parsedSection = parts.sublist(1).join('-').trim();
      }
    }

    return UserProfileModel(
      id: data['id']?.toString() ?? '',
      authUserId: data['auth_user_id']?.toString() ?? data['id']?.toString() ?? '',
      schoolId: data['school_id']?.toString() ?? '',
      schoolName: data['school_name']?.toString() ?? 'School',
      name: data['full_name']?.toString() ?? data['name']?.toString() ?? 'Faculty Member',
      email: data['email']?.toString() ?? '',
      role: _parseRole(data['role']?.toString()),
      status: _parseStatus(data['status']?.toString()),
      designation: data['designation']?.toString() ?? 'Staff',
      assignedClass: parsedClass,
      assignedSection: parsedSection,
      subject: data['subject']?.toString(),
      mustChangePassword: data['must_change_password'] == true,
      createdAt: DateTime.tryParse(data['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  // --- GET ADMINS FOR SCHOOL ---
  Future<List<UserProfileModel>> getAdminsForSchool(String schoolId) async {
    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        final data = await _client!
            .from('profiles')
            .select()
            .eq('school_id', schoolId)
            .or('role.eq.school_admin,role.eq.super_admin,role.eq.owner')
            .order('full_name', ascending: true);
        if (data is List) {
          return data.map((d) => _mapProfile(d)).toList();
        }
        return [];
      } catch (e) {
        debugPrint('[AuthService getAdminsForSchool Error]: $e');
        rethrow;
      }
    }
    return _mockProfiles.where((p) => p.role.isAdministrator && p.schoolId == schoolId).toList();
  }

  // --- TOGGLE ADMIN STATUS ---
  Future<void> toggleAdminStatus(String profileId, AccountStatus newStatus) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final idx = _mockProfiles.indexWhere((p) => p.id == profileId);
    if (idx != -1) {
      _mockProfiles[idx] = _mockProfiles[idx].copyWith(status: newStatus);
    }
  }

  // --- SIGN OUT ---
  Future<void> signOut() async {
    if (_client != null) {
      try {
        await _client!.auth.signOut();
      } catch (e) {
        debugPrint('[AuthService SignOut Warning]: $e');
      }
    }
  }

  // --- STAFF / TEACHER ACCOUNT CREATION BY ADMIN ---
  Future<UserProfileModel> createStaffAccount({
    required String name,
    required String email,
    required String phone,
    required String empId,
    required String designation,
    required String subject,
    required String assignedClass,
    required String password,
    required UserRole role,
  }) async {
    final trimmedEmail = email.trim().toLowerCase();

    if (password.trim().length < 8) {
      throw Exception('Password must be at least 8 characters long.');
    }

    final existsInMock = _mockProfiles.any((p) => p.email.toLowerCase() == trimmedEmail);
    if (existsInMock) {
      throw Exception('An account with this email already exists.');
    }
    
    // Ensure role is strictly staff or teacher (cannot escalate to school_admin or super_admin)
    final safeRole = (role == UserRole.staff) ? UserRole.staff : UserRole.teacher;

    final schoolAdmin = _client?.auth.currentUser;
    final adminProfile = schoolAdmin != null ? await fetchUserProfile(schoolAdmin.id) : null;
    final resolvedSchoolId = adminProfile?.schoolId ?? (schoolAdmin?.userMetadata?['school_id'] as String?);
    if (_client != null && SupabaseConfig.isConfigured && (resolvedSchoolId == null || resolvedSchoolId.isEmpty)) {
      throw Exception('Active school profile not found. Cannot provision staff.');
    }
    final schoolId = resolvedSchoolId ?? 'mock_school_id';
    final schoolName = adminProfile?.schoolName ?? 'School';

    if (_client != null && SupabaseConfig.isConfigured) {
      try {
        debugPrint('[AuthService createStaffAccount]: Creating Supabase Auth user via isolated HTTP for $trimmedEmail');
        final roleStr = (safeRole == UserRole.staff) ? 'staff' : 'teacher';

        final parsedClassName = assignedClass.contains('-') ? assignedClass.split('-').first.trim() : assignedClass;
        final parsedSectionName = assignedClass.contains('-') ? assignedClass.split('-').last.trim() : '';

        // CRITICAL FIX: To prevent replacing or corrupting the active Admin session,
        // we execute the Auth signup via a direct HTTP POST request to /auth/v1/signup
        // rather than instantiating a SupabaseClient.
        // A secondary SupabaseClient on Flutter Web automatically connects to the browser's
        // BroadcastChannel ('sb-<project>-auth-token'), broadcasting SIGNED_IN to the
        // primary SupabaseClient and forcefully hijacking the Admin session!
        final signupUri = Uri.parse('${SupabaseConfig.url}/auth/v1/signup');
        final signupResponse = await http.post(
          signupUri,
          headers: {
            'apikey': SupabaseConfig.publishableKey,
            'Authorization': 'Bearer ${SupabaseConfig.publishableKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'email': trimmedEmail,
            'password': password,
            'data': {
              'role': roleStr,
              'full_name': name,
              'school_id': schoolId,
              'employee_id': empId,
              'designation': designation,
              'subject': subject,
              'assigned_class': assignedClass,
              'phone': phone,
              'class': parsedClassName,
              'section': parsedSectionName,
              'must_change_password': true,
            },
          }),
        );

        debugPrint('[AuthService createStaffAccount]: HTTP signup status=${signupResponse.statusCode}');
        final responseData = jsonDecode(signupResponse.body) as Map<String, dynamic>;

        if (signupResponse.statusCode >= 400) {
          final errorMsg = (responseData['msg'] ?? responseData['message'] ?? responseData['error_description'] ?? 'Failed to create user account').toString();
          final lower = errorMsg.toLowerCase();
          if (lower.contains('already registered') || lower.contains('already in use')) {
            throw Exception('This email is already registered. Please use another email.');
          } else if (lower.contains('weak')) {
            throw Exception('Password is too weak. Please use at least 8 characters with numbers & symbols.');
          } else {
            throw Exception(errorMsg);
          }
        }

        final identities = (responseData['identities'] ?? (responseData['user'] as Map<String, dynamic>?)?['identities']) as List?;
        if (identities != null && identities.isEmpty) {
          throw Exception('This email is already registered. Please use another email.');
        }

        final newAuthUserId = (responseData['id'] ?? (responseData['user'] as Map<String, dynamic>?)?['id']) as String?;
        if (newAuthUserId == null || newAuthUserId.isEmpty) {
          throw Exception('Failed to obtain authenticated user ID from Supabase Auth.');
        }

        debugPrint('[AuthService createStaffAccount]: Auth user created with ID: $newAuthUserId. Active Admin: ${_client?.auth.currentUser?.email}');

        // Target existing table: public.profiles
        bool profileCreated = false;

        // 1. Call secure RPC first
        try {
          await _client!.rpc('create_staff_profile', params: {
            'p_auth_user_id': newAuthUserId,
            'p_school_id': schoolId,
            'p_full_name': name,
            'p_role': roleStr,
          });
          profileCreated = true;
        } catch (rpcErr) {
          debugPrint('[AuthService RPC create_staff_profile notice]: $rpcErr');
        }

        // 2. Direct upsert using active admin client
        try {
          await _client!.from('profiles').upsert({
            'auth_user_id': newAuthUserId,
            'school_id': schoolId,
            'full_name': name,
            'role': roleStr,
            'status': 'active',
          }, onConflict: 'auth_user_id');
          profileCreated = true;
        } catch (pErr) {
          debugPrint('[AuthService direct profiles upsert notice]: $pErr');
        }

        // 3. Fallback: Isolated HTTP insert using newly created user's token (satisfies auth.uid() = auth_user_id RLS policy without affecting Admin session)
        if (!profileCreated) {
          final userToken = (responseData['access_token'] ?? (responseData['session'] as Map<String, dynamic>?)?['access_token']) as String?;
          if (userToken != null) {
            try {
              final profilePostUri = Uri.parse('${SupabaseConfig.url}/rest/v1/profiles');
              final profileRes = await http.post(
                profilePostUri,
                headers: {
                  'apikey': SupabaseConfig.publishableKey,
                  'Authorization': 'Bearer $userToken',
                  'Content-Type': 'application/json',
                  'Prefer': 'return=representation,resolution=merge-duplicates',
                },
                body: jsonEncode({
                  'auth_user_id': newAuthUserId,
                  'school_id': schoolId,
                  'full_name': name,
                  'role': roleStr,
                  'status': 'active',
                }),
              );
              debugPrint('[AuthService isolated token profiles insert]: status=${profileRes.statusCode}, body=${profileRes.body}');
              if (profileRes.statusCode < 300) {
                profileCreated = true;
              }
            } catch (httpErr) {
              debugPrint('[AuthService isolated token profiles insert error]: $httpErr');
            }
          }
        }

        // 4. Return created profile (from database if linked, or construct model with generated auth ID)
        final createdProfile = await fetchUserProfile(newAuthUserId);
        if (createdProfile != null) {
          debugPrint('[AuthService createStaffAccount complete]: Successfully verified $newAuthUserId in DB. Current Admin user: ${_client?.auth.currentUser?.email}');
          return createdProfile;
        }

        debugPrint('[AuthService createStaffAccount complete]: Auth user $newAuthUserId created and metadata linked. Current Admin: ${_client?.auth.currentUser?.email}');
        return UserProfileModel(
          id: newAuthUserId,
          authUserId: newAuthUserId,
          schoolId: schoolId,
          schoolName: schoolName,
          name: name,
          email: trimmedEmail,
          role: safeRole,
          status: AccountStatus.active,
          designation: designation,
          assignedClass: parsedClassName,
          assignedSection: parsedSectionName,
          subject: subject,
          mustChangePassword: true,
          createdAt: DateTime.now(),
        );
      } on AuthException catch (e) {
        debugPrint('[AuthService AuthException]: code=${e.statusCode}, message=${e.message}');
        final msg = e.message.toLowerCase();
        if (msg.contains('already registered') || msg.contains('already in use')) {
          throw Exception('This email is already registered. Please use another email.');
        } else if (msg.contains('weak')) {
          throw Exception('Password is too weak. Please use at least 8 characters with numbers & symbols.');
        } else {
          throw Exception(e.message);
        }
      } catch (e) {
        debugPrint('[AuthService createStaffAccount Error]: $e');
        if (e is Exception) rethrow;
        throw Exception(e.toString());
      }
    }

    final newStaffProfile = UserProfileModel(
      id: 'prof_${DateTime.now().millisecondsSinceEpoch}',
      authUserId: 'auth_staff_${DateTime.now().millisecondsSinceEpoch}',
      schoolId: schoolId,
      schoolName: schoolName,
      name: name,
      email: trimmedEmail,
      role: safeRole,
      status: AccountStatus.active,
      designation: designation,
      assignedClass: assignedClass,
      subject: subject,
      mustChangePassword: true,
      createdAt: DateTime.now(),
    );

    _mockProfiles.insert(0, newStaffProfile);
    return newStaffProfile;
  }

  UserRole _parseRole(String? roleStr) {
    switch (roleStr?.toLowerCase()) {
      case 'owner':
        return UserRole.owner;
      case 'super_admin':
      case 'superadmin':
        return UserRole.superAdmin;
      case 'school_admin':
      case 'admin':
        return UserRole.schoolAdmin;
      case 'staff':
        return UserRole.staff;
      case 'teacher':
      default:
        return UserRole.teacher;
    }
  }

  AccountStatus _parseStatus(String? statusStr) {
    switch (statusStr?.toLowerCase()) {
      case 'inactive':
        return AccountStatus.inactive;
      case 'suspended':
        return AccountStatus.suspended;
      case 'active':
      default:
        return AccountStatus.active;
    }
  }
}
