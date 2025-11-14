// ignore_for_file: avoid_print, prefer_const_constructors

import 'dart:io';

import 'package:unified_ai_sdk/unified_ai_sdk.dart';

/// Streaming Chat Example
///
/// Demonstrates real-time streaming chat responses.
/// Shows how to:
/// - Use chatStream() for incremental responses
/// - Handle stream events (delta, done, metadata)
/// - Display text as it's generated
///
/// **Prerequisites:**
/// - Set `OPENAI_API_KEY` environment variable
///
/// **Run:**
/// ```bash
/// dart run example/02_streaming_chat/main.dart
/// ```
void main() async {
  final apiKey = Platform.environment['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    print('❌ Error: OPENAI_API_KEY not set');
    exit(1);
  }

  try {
    print('🚀 Initializing SDK...');
    await UnifiedAI.init(
      UnifiedAIConfig(
        defaultProvider: 'openai',
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            settings: {'defaultModel': 'gpt-4o'},
            auth: ApiKeyAuth(apiKey: apiKey),
          ),
        },
      ),
    );

    print('✅ SDK initialized\n');

    final ai = UnifiedAI.instance;

    print('💬 Streaming chat response...\n');
    stdout.write('Assistant: ');

    String fullResponse = '';
    int? totalTokens;

    await for (final event in ai.chatStream(
      request: ChatRequest(
        messages: [
          const Message(
            role: Role.user,
            content: 'Write a short story about a robot learning to paint.',
          ),
        ],
        maxTokens: 200,
      ),
    )) {
      // Handle incremental text
      if (event.delta != null) {
        stdout.write(event.delta);
        fullResponse += event.delta!;
      }

      // Handle completion
      if (event.done == true) {
        print('\n');
        if (event.metadata != null) {
          final usage = event.metadata!['usage'];
          if (usage != null && usage is Map) {
            totalTokens = usage['total_tokens'] as int?;
          }
        }
        break;
      }
    }

    print('\n─' * 50);
    print('✅ Stream completed');
    if (totalTokens != null) {
      print('Tokens used: $totalTokens');
    }
    print('Full response length: ${fullResponse.length} characters');
  } on CapabilityError catch (e) {
    print('❌ Capability error: ${e.message}');
    exit(1);
  } on Exception catch (e) {
    print('❌ Error: $e');
    exit(1);
  } finally {
    try {
      await UnifiedAI.instance.dispose();
    } on Object {
      // Ignore
    }
  }
}
