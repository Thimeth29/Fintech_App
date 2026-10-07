import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/config/supabase_config.dart';

class AuthService {
  SupabaseClient? get _client => SupabaseConfig.isConfigured ? SupabaseConfig.client : null;

  User? get currentUser => _client?.auth.currentUser;

  Stream<AuthState>? get authStateChanges => _client?.auth.onAuthStateChange;

  Future<AuthResponse?> signUp({
    required String name,
    required String email,
    required String password,
    required String mobile,
  }) async {
    final client = _client;
    if (client == null) return null;

    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name, 'mobile_number': mobile},
    );

    final user = response.user;
    if (user != null) {
      await client.from('profiles').upsert({
        'id': user.id,
        'full_name': name,
        'email': email,
        'mobile_number': mobile,
      });
    }
    return response;
  }

  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) return null;
    return client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _client?.auth.signOut();
  }

  Future<String> fetchDisplayName() async {
    final user = currentUser;
    final client = _client;
    if (user == null || client == null) return 'Nimali';
    try {
      final row = await client
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .maybeSingle();
      final name = row?['full_name'] as String?;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {
      // fall through
    }
    final metaName = user.userMetadata?['full_name'] as String?;
    return metaName ?? user.email?.split('@').first ?? 'User';
  }
}

