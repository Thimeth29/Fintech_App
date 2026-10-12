class OpenAiConfig {
  // TODO: paste your OpenAI API key here (or better: load it from
  // --dart-define=OPENAI_API_KEY=... at build/run time so it never
  // gets committed to source control).
  //
  // Run example:
  //   flutter run --dart-define=OPENAI_API_KEY=sk-xxxx
  static const String apiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  static const String model = 'gpt-4o-mini';
  static const String chatCompletionsUrl =
      'https://api.openai.com/v1/chat/completions';

  static bool get isConfigured => apiKey.isNotEmpty;
}
