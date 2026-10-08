import 'package:supabase_flutter/supabase_flutter.dart';

/// Central Configuration Manager for Supabase Integration.
class SupabaseConfig {
  static String _url = const String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://uttemjtuxeasyccxhhlz.supabase.co',
  );

  static String _anonKey = const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_iIm6Mmy6_17819db0Wo1kg_aAtHPbiw',
  );

  static String get supabaseUrl => _url;
  static String get supabaseAnonKey => _anonKey;

  /// Direct access to initialized Supabase Client
  static SupabaseClient get client => Supabase.instance.client;

  /// Check if a custom Supabase URL & Key have been provided
  static bool get isConfigured {
    return _url.isNotEmpty &&
        !_url.contains('xyzcompany') &&
        _anonKey.isNotEmpty &&
        !_anonKey.contains('dummy_anon_key');
  }

  /// Initialize Supabase asynchronously
  static Future<void> initialize({String? customUrl, String? customAnonKey}) async {
    if (customUrl != null && customUrl.isNotEmpty) _url = customUrl;
    if (customAnonKey != null && customAnonKey.isNotEmpty) _anonKey = customAnonKey;

    try {
      await Supabase.initialize(
        url: _url,
        publishableKey: _anonKey,
        debug: true,
      );
    } catch (e) {
      // Supabase initialization fallback
    }
  }

  /// Override URL & Key dynamically at runtime
  static void setCredentials(String url, String anonKey) {
    _url = url;
    _anonKey = anonKey;
  }
}

