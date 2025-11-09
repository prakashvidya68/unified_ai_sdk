import 'dart:io';

import 'package:unified_ai_sdk/src/core/authentication.dart';
import 'package:unified_ai_sdk/src/core/config.dart';
import 'package:unified_ai_sdk/src/core/provider_config.dart';
import 'package:unified_ai_sdk/src/core/unified_ai.dart';
import 'package:unified_ai_sdk/src/models/base_enums.dart';
import 'package:unified_ai_sdk/src/models/common/message.dart';
import 'package:unified_ai_sdk/src/models/requests/chat_request.dart';

/// Simple Chat Example
///
/// This example demonstrates how to use the Unified AI SDK to:
/// 1. Initialize the SDK with a provider configuration
/// 2. Make a chat request
/// 3. Handle the response
///
/// **Prerequisites:**
/// - Set the `OPENAI_API_KEY` environment variable with your OpenAI API key
/// - Example: `export OPENAI_API_KEY='sk-your-key-here'`
///
/// **Run the example:**
/// ```bash
/// dart run example/simple_chat/main.dart
/// ```
///
/// **Example output:**
/// ```
/// Initializing Unified AI SDK...
/// ✓ SDK initialized successfully
///
/// Sending chat request...
/// ✓ Response received:
///
/// Assistant: Here's a fun fact: Honey never spoils! Archaeologists have found
/// pots of honey in ancient Egyptian tombs that are over 3,000 years old and
/// still perfectly edible.
///
/// ---
/// Model: gpt-4o
/// Provider: openai
/// Tokens used: 45
///   - Prompt: 12
///   - Completion: 33
/// ```
void main() async {
  // Get API key from environment variable
  final apiKey = Platform.environment['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    print('Error: OPENAI_API_KEY environment variable is not set.');
    print('Please set it with: export OPENAI_API_KEY=\'sk-your-key-here\'');
    exit(1);
  }

  try {
    // Step 1: Initialize the SDK
    print('Initializing Unified AI SDK...');
    await UnifiedAI.init(
      UnifiedAIConfig(
        defaultProvider: 'openai',
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            auth: ApiKeyAuth(apiKey: apiKey),
            settings: {
              'defaultModel': 'gpt-4o',
            },
          ),
        },
      ),
    );

    print('✓ SDK initialized successfully\n');

    // Step 2: Get the SDK instance
    final ai = UnifiedAI.instance;

    // Step 3: Make a chat request
    print('Sending chat request...');
    final response = await ai.chat(
      request: ChatRequest(
        messages: [
          const Message(
              role: Role.user, content: 'Hello! Can you tell me a fun fact?'),
        ],
      ),
    );

    // Step 4: Display the response
    print('✓ Response received:\n');
    print('Assistant: ${response.choices.first.message.content}');
    print('\n---');
    print('Model: ${response.model}');
    print('Provider: ${response.provider}');
    print('Tokens used: ${response.usage.totalTokens}');
    print('  - Prompt: ${response.usage.promptTokens}');
    print('  - Completion: ${response.usage.completionTokens}');
  } on Exception catch (e) {
    print('Error: $e');
    exit(1);
  } finally {
    // Clean up
    try {
      UnifiedAI.instance.dispose();
    } on Exception {
      // Ignore if already disposed or other exceptions
    } on Object {
      // Ignore any other errors (StateError, etc.)
    }
  }
}
