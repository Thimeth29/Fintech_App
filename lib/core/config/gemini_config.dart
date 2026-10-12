// lib/core/config/gemini_config.dart

class GeminiConfig {
  /// Never hardcode a real key here — this file ships inside the compiled
  /// app (APK/web bundle), so anything in source is extractable by anyone
  /// and would run up usage on your Google account. Pass it at build/run
  /// time instead, where it stays out of source control and the binary's
  /// embedded strings:
  ///   flutter run --dart-define=GEMINI_API_KEY=YOUR_GEMINI_API_KEY
  static String get apiKey =>
      const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// gemini-1.5-flash/-pro, gemini-pro and gemini-2.0-flash are all retired
  /// (confirmed 404 from the API) — gemini-flash-lite-latest is the model
  /// actually used (see AiService._candidateModels), kept fast and reliable
  /// as of this writing.
  static const String model = 'gemini-flash-lite-latest';

  static bool get isConfigured => apiKey.isNotEmpty;
}
