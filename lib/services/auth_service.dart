import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

/// Consolidated Auth Service managing Supabase Authentication and Profile operations.
class AuthService {
  SupabaseClient? get _client => SupabaseConfig.isConfigured ? SupabaseConfig.client : null;

  User? get currentUser => _client?.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState>? get authStateChanges => _client?.auth.onAuthStateChange;

  /// Light client-side sanity check for the signup/login email field.
  static bool looksLikeEmail(String input) => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(input);

  // Dart's http client has no default timeout, so a bad connection (no
  // internet, blocked DNS, a flaky network) leaves an awaited call hanging
  // forever with no error and no UI update — it looks exactly like a stuck
  // loading spinner. Every network call below is bounded so that case
  // surfaces as a real, catchable error instead.
  static const _networkTimeout = Duration(seconds: 15);
  static Never _throwTimeout() => throw const AuthException(
      'Request timed out — check your internet connection and try again.');

  /// Sign Up with an email, Password, Name, an optional contact-only mobile
  /// number (stored on the profile, never used to sign in or verified),
  /// and optional extra profile metadata. This is a direct, password-based
  /// signup with no verification step — prefer sending a real code first
  /// via [sendEmailOtp] and verifying it; this exists as a fallback for
  /// when that wasn't done.
  Future<AuthResponse?> signUp({
    required String name,
    required String email,
    required String password,
    String? phone,
    Map<String, dynamic>? extraMetaData,
  }) async {
    final client = _client;
    if (client == null) return null;

    final trimmedEmail = email.trim();
    final metaData = {
      'full_name': name,
      if (extraMetaData != null) ...extraMetaData,
    };

    final response = await client.auth
        .signUp(email: trimmedEmail, password: password, data: metaData)
        .timeout(_networkTimeout, onTimeout: _throwTimeout);

    final user = response.user;
    if (user != null) {
      await client.from('profiles').upsert({
        'id': user.id,
        'full_name': name,
        'email': trimmedEmail,
        if (phone != null && phone.trim().isNotEmpty) 'mobile_number': phone.trim(),
        if (extraMetaData != null) ...extraMetaData,
      }).timeout(_networkTimeout, onTimeout: _throwTimeout);
    }
    return response;
  }

  /// Sign In with an email address and password.
  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) return null;
    return client.auth
        .signInWithPassword(email: email.trim(), password: password)
        .timeout(_networkTimeout, onTimeout: _throwTimeout);
  }

  /// Send a real 6-digit verification code to an email address. Creates the
  /// auth user now (passwordless) if they don't exist yet — [setPassword]
  /// must be called after [verifyEmailOtp] succeeds to give the account a
  /// password, since OTP sign-up/sign-in is passwordless by default.
  Future<void> sendEmailOtp({required String email, String? name}) async {
    final client = _client;
    if (client == null) return;
    await client.auth
        .signInWithOtp(
          email: email,
          shouldCreateUser: true,
          data: name != null && name.isNotEmpty ? {'full_name': name} : null,
        )
        .timeout(_networkTimeout, onTimeout: _throwTimeout);
  }

  /// Verify a 6-digit email code. On success this starts a real session.
  Future<AuthResponse?> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    final client = _client;
    if (client == null) return null;
    return client.auth
        .verifyOTP(type: OtpType.email, email: email, token: token)
        .timeout(_networkTimeout, onTimeout: _throwTimeout);
  }

  /// Set the password on the current session's account — used right after
  /// email OTP verification, since that sign-in path has no password yet.
  Future<void> setPassword(String password) async {
    final client = _client;
    if (client == null) return;
    await client.auth
        .updateUser(UserAttributes(password: password))
        .timeout(_networkTimeout, onTimeout: _throwTimeout);
  }

  /// Sign Out User
  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  /// Fetch full user profile record from `profiles` table
  Future<Map<String, dynamic>?> fetchProfile() async {
    final user = currentUser;
    final client = _client;
    if (user == null || client == null) return null;

    final data = await client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return data;
  }

  /// Fetch User Display Name
  Future<String> fetchDisplayName() async {
    final profile = await fetchProfile();
    if (profile != null && profile['full_name'] != null) {
      final name = profile['full_name'] as String;
      if (name.isNotEmpty) return name;
    }
    final user = currentUser;
    if (user == null) return 'User';
    final metaName = user.userMetadata?['full_name'] as String?;
    return metaName ?? user.email?.split('@').first ?? 'User';
  }

  /// Update User Profile Attributes (role, occupation, district, language, etc.)
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = currentUser;
    final client = _client;
    if (user == null || client == null) return;

    updates['updated_at'] = DateTime.now().toIso8601String();

    await client.from('profiles').upsert({
      'id': user.id,
      ...updates,
    }).timeout(_networkTimeout, onTimeout: _throwTimeout);
  }
}
