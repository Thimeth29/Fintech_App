import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

class SupabaseAuthService {
  final SupabaseClient _client = SupabaseConfig.client;

  User? get currentUser => _client.auth.currentUser;
  bool get isLoggedIn => currentUser != null;

  /// Sign Up with Email, Password & initial profile metadata
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    Map<String, dynamic>? extraMetaData,
  }) async {
    final metaData = {
      'full_name': fullName,
      if (extraMetaData != null) ...extraMetaData,
    };

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: metaData,
    );

    return response;
  }

  /// Sign In with Email & Password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response;
  }

  /// Sign In with Phone OTP (Sri Lanka mobile +94...)
  Future<void> signInWithOtp(String phone) async {
    await _client.auth.signInWithOtp(
      phone: phone,
    );
  }

  /// Verify Phone OTP Code
  Future<AuthResponse> verifyOtp({
    required String phone,
    required String token,
  }) async {
    final response = await _client.auth.verifyOTP(
      type: OtpType.sms,
      phone: phone,
      token: token,
    );
    return response;
  }

  /// Sign Out User
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Fetch User Profile Record
  Future<Map<String, dynamic>?> fetchProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final data = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return data;
  }

  /// Update User Profile Attributes (onboarding steps, role, occupation, etc.)
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final user = currentUser;
    if (user == null) return;

    updates['updated_at'] = DateTime.now().toIso8601String();

    await _client.from('profiles').upsert({
      'id': user.id,
      ...updates,
    });
  }
}
