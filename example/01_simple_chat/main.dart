// ignore_for_file: avoid_print, prefer_const_constructors

import 'dart:io';

import 'package:unified_ai_sdk/unified_ai_sdk.dart';

/// Simple Chat Example
///
/// Demonstrates basic chat completion using the Unified AI SDK.
/// This is the simplest example showing how to:
/// - Initialize the SDK
/// - Make a chat request
/// - Display the response
///
/// **Prerequisites:**
/// - Set `OPENAI_API_KEY` environment variable
///
/// **Run:**
/// ```bash
/// dart run example/01_simple_chat/main.dart
/// ```
void main() async {
  final apiKey = Platform.environment['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    print('❌ Error: OPENAI_API_KEY not set');
    print('Set it with: export OPENAI_API_KEY=\'sk-your-key-here\'');
    exit(1);
  }

  try {
    print('🚀 Initializing Unified AI SDK...');
    await UnifiedAI.init(
      UnifiedAIConfig(
        defaultProvider: 'openai',
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            auth: ApiKeyAuth(apiKey: apiKey),
          ),
        },
      ),
    );
    print('✅ SDK initialized\n');

    final ai = UnifiedAI.instance;

    print('💬 Sending chat request...');
    final response = await ai.chat(
      request: ChatRequest(
        messages: [
          const Message(
              role: Role.user, content: 'Hello! Can you tell me a fun fact?'),
        ],
      ),
    );

    print('\n📝 Response:\n');
    print('${response.choices.first.message.content}\n');
    print('─' * 50);
    print('Model: ${response.model}');
    print('Provider: ${response.provider}');
    print(
        'Tokens: ${response.usage.totalTokens} (prompt: ${response.usage.promptTokens}, completion: ${response.usage.completionTokens})');
  } on AuthError catch (e) {
    print('❌ Authentication error: ${e.message}');
    exit(1);
  } on Exception catch (e) {
    print('❌ Error: $e');
    exit(1);
  } finally {
    try {
      await UnifiedAI.instance.dispose();
    } on Object {
      // Ignore disposal errors
    }
  }
}
