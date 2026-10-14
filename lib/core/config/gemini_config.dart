// lib/core/config/gemini_config.dart
//
// HOW TO SUPPLY YOUR KEY (never commit a real key here):
//   1. Copy dart_defines.env.example → dart_defines.env  (gitignored)
//   2. Set GEMINI_API_KEY=your_real_key inside dart_defines.env
//   3. Run:  flutter run --dart-define-from-file=dart_defines.env
//      Or:   flutter run --dart-define=GEMINI_API_KEY=YOUR_KEY_HERE

class GeminiConfig {
  /// Read the key from --dart-define (injected at build/run time).
  /// No default value — an empty string means "not configured".
  static String get apiKey =>
      const String.fromEnvironment(
        'GEMINI_API_KEY',
        defaultValue: '',
      );

  /// gemini-1.5-flash/-pro, gemini-pro and gemini-2.0-flash are all retired
  /// (confirmed 404 from the API) — gemini-flash-lite-latest is the model
  /// actually used (see AiService._candidateModels), kept fast and reliable
  /// as of this writing.
  static const String model = 'gemini-flash-lite-latest';

  static bool get isConfigured => apiKey.isNotEmpty;
}
