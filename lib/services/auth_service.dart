import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String name,
    required String email,
    required String password,
    required String mobile,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name, 'mobile': mobile},
    );

    // In case the DB trigger (see supabase_schema.sql) isn't set up yet,
    // upsert the profile row directly so the app still works end to end.
    final user = response.user;
    if (user != null) {
      await _client.from('profiles').upsert({
        'id': user.id,
        'name': name,
        'email': email,
        'mobile': mobile,
      });
    }
    return response;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<String> fetchDisplayName() async {
    final user = currentUser;
    if (user == null) return 'Guest';
    try {
      final row = await _client
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .maybeSingle();
      final name = row?['name'] as String?;
      if (name != null && name.isNotEmpty) return name;
    } catch (_) {
      // fall through to metadata / email fallback
    }
    final metaName = user.userMetadata?['name'] as String?;
    return metaName ?? user.email ?? 'User';
  }
}
