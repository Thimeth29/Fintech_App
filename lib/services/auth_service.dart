import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

/// Consolidated Auth Service managing Supabase Authentication and Profile operations.
class AuthService {
  SupabaseClient? get _client => SupabaseConfig.isConfigured ? SupabaseConfig.client : null;

  User? get currentUser => _client?.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  Stream<AuthState>? get authStateChanges => _client?.auth.onAuthStateChange;

  // Supabase's email/password auth needs a real email *format*, but a
  // phone number has no inbox to confirm. Phone sign-ups are mapped to a
  // synthetic "<digits>@finops.app" address so Supabase Auth accepts them,
  // while the actual phone number the user typed is kept verbatim in
  // profiles.mobile_number (and the real `email` column is left unset).
  // This also means phone sign-ups never trigger Supabase's outbound
  // confirmation email, so they're unaffected by its strict rate limit.
  static const _syntheticEmailDomain = 'finops.app';

  static bool looksLikeEmail(String input) => input.contains('@');

  static String _authEmailFor(String emailOrPhone) {
    final trimmed = emailOrPhone.trim();
    if (looksLikeEmail(trimmed)) return trimmed;
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return '$digits@$_syntheticEmailDomain';
  }

  /// Sign Up with either an email address OR a mobile number, Password,
  /// Name, and optional extra profile metadata.
  Future<AuthResponse?> signUp({
    required String name,
    required String emailOrPhone,
    required String password,
    Map<String, dynamic>? extraMetaData,
  }) async {
    final client = _client;
    if (client == null) return null;

    final input = emailOrPhone.trim();
    final isEmail = looksLikeEmail(input);

    final metaData = {
      'full_name': name,
      'mobile_number': isEmail ? null : input,
      if (extraMetaData != null) ...extraMetaData,
    };

    final response = await client.auth.signUp(
      email: _authEmailFor(input),
      password: password,
      data: metaData,
    );

    final user = response.user;
    if (user != null) {
      await client.from('profiles').upsert({
        'id': user.id,
        'full_name': name,
        if (isEmail) 'email': input,
        if (!isEmail) 'mobile_number': input,
        if (extraMetaData != null) ...extraMetaData,
      });
    }
    return response;
  }

  /// Sign In with either an email address OR a mobile number, plus Password.
  Future<AuthResponse?> signIn({
    required String emailOrPhone,
    required String password,
  }) async {
    final client = _client;
    if (client == null) return null;
    return client.auth.signInWithPassword(
      email: _authEmailFor(emailOrPhone),
      password: password,
    );
  }

  /// Sign In with Phone OTP
  Future<void> signInWithOtp(String phone) async {
    final client = _client;
    if (client == null) return;
    await client.auth.signInWithOtp(phone: phone);
  }

  /// Verify Phone OTP Code
  Future<AuthResponse?> verifyOtp({
    required String phone,
    required String token,
  }) async {
    final client = _client;
    if (client == null) return null;
    return client.auth.verifyOTP(
      type: OtpType.sms,
      phone: phone,
      token: token,
    );
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
    });
  }
}
