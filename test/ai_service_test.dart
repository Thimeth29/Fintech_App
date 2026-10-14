import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/core/config/gemini_config.dart';
import 'package:my_app/services/ai_service.dart';

void main() {
  test('GeminiConfig is configured with active key', () {
    expect(GeminiConfig.isConfigured, isTrue);
    expect(GeminiConfig.apiKey, isNotEmpty);
  });

  test('AiService generates a live response for financial query', () async {
    final ai = AiService(financialContext: 'User is looking for advice on CSE stocks.');
    final reply = await ai.ask('What is the CSE ASPI?');
    expect(reply, isNotEmpty);
    expect(reply.contains("FinBot isn't connected yet"), isFalse);
    expect(reply.contains("Unable to authenticate"), isFalse);
    print('FinBot Live Response:\n$reply');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
