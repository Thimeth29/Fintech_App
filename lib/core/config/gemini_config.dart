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

  /// Supported Gemini API models: gemini-1.5-flash, gemini-2.0-flash, gemini-1.5-pro
  static const String model = 'gemini-1.5-flash';

  static bool get isConfigured => apiKey.isNotEmpty;
}
