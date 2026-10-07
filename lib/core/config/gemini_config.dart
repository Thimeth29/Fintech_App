// lib/core/config/gemini_config.dart

class GeminiConfig {
  /// You can paste your Google Gemini API key here directly, or run with:
  ///   flutter run --dart-define=GEMINI_API_KEY=YOUR_GEMINI_API_KEY
  static const String _customApiKey =
      'AQ.Ab8RN6Jy_GcArvjTnj1X-Ef48azySigFQe8BsHsX3gdtQg2GWQ';

  static String get apiKey {
    if (_customApiKey.isNotEmpty) return _customApiKey;
    return const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  }

  /// Supported Gemini API models: gemini-1.5-flash, gemini-2.0-flash, gemini-1.5-pro
  static const String model = 'gemini-1.5-flash';

  static bool get isConfigured => apiKey.isNotEmpty;
}
