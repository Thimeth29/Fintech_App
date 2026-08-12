// lib/core/config/gemini_config.dart

class GeminiConfig {
  // TODO: paste your Google Gemini API key here (or better: load it from
  // --dart-define=GEMINI_API_KEY=... at build/run time so it never
  // gets committed to source control).
  //
  // Run example:
  //   flutter run --dart-define=GEMINI_API_KEY=YOUR_GEMINI_API_KEY
  static const String apiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const String model =
      'gemini-3.6-flash'; // GA model — gemini-2.5-flash is no longer available to new API keys
  static bool get isConfigured => apiKey.isNotEmpty;
}
