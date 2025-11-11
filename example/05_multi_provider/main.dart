// ignore_for_file: avoid_print, prefer_const_constructors

import 'dart:io';

import 'package:unified_ai_sdk/unified_ai_sdk.dart';

/// Multi-Provider Example
///
/// Demonstrates using multiple AI providers.
/// Shows how to:
/// - Configure multiple providers
/// - Explicitly select a provider
/// - Let SDK auto-route based on capabilities
/// - Compare responses from different providers
///
/// **Prerequisites:**
/// - Set `OPENAI_API_KEY` environment variable
/// - Set `ANTHROPIC_API_KEY` environment variable (optional)
///
/// **Run:**
/// ```bash
/// dart run example/05_multi_provider/main.dart
/// ```
void main() async {
  final openaiKey = Platform.environment['OPENAI_API_KEY'];
  final anthropicKey = Platform.environment['ANTHROPIC_API_KEY'];

  if (openaiKey == null || openaiKey.isEmpty) {
    print('❌ Error: OPENAI_API_KEY not set');
    exit(1);
  }

  try {
    print('🚀 Initializing SDK with multiple providers...');

    final providers = <String, ProviderConfig>{
      'openai': ProviderConfig(
        id: 'openai',
        auth: ApiKeyAuth(apiKey: openaiKey),
      ),
    };

    // Add Anthropic if key is available
    if (anthropicKey != null && anthropicKey.isNotEmpty) {
      providers['anthropic'] = ProviderConfig(
        id: 'anthropic',
        auth: ApiKeyAuth(
          apiKey: anthropicKey,
          headerName: 'x-api-key',
        ),
      );
    }

    await UnifiedAI.init(
      UnifiedAIConfig(
        defaultProvider: 'openai',
        perProviderConfig: providers,
      ),
    );

    final ai = UnifiedAI.instance;
    print('✅ SDK initialized with ${ai.availableProviders.length} provider(s)');
    print('   Available: ${ai.availableProviders.join(", ")}\n');

    final question = 'What is the capital of France?';

    // Test 1: Explicit provider selection
    print('📝 Test 1: Explicit Provider Selection\n');
    print('Question: "$question"\n');

    if (ai.availableProviders.contains('openai')) {
      print('🤖 OpenAI Response:');
      try {
        final response = await ai.chat(
          provider: 'openai',
          request: ChatRequest(
            messages: [Message(role: Role.user, content: question)],
          ),
        );
        print('   ${response.choices.first.message.content}');
        print(
            '   Model: ${response.model}, Tokens: ${response.usage.totalTokens}\n');
      } on Exception catch (e) {
        print('   ❌ Error: $e\n');
      }
    }

    if (ai.availableProviders.contains('anthropic')) {
      print('🤖 Anthropic Response:');
      try {
        final response = await ai.chat(
          provider: 'anthropic',
          request: ChatRequest(
            messages: [Message(role: Role.user, content: question)],
          ),
        );
        print('   ${response.choices.first.message.content}');
        print(
            '   Model: ${response.model}, Tokens: ${response.usage.totalTokens}\n');
      } on Exception catch (e) {
        print('   ❌ Error: $e\n');
      }
    }

    // Test 2: Auto-routing
    print('📝 Test 2: Automatic Provider Routing\n');
    print('Question: "Explain quantum computing in one sentence"\n');

    try {
      final response = await ai.chat(
        request: ChatRequest(
          messages: [
            const Message(
                role: Role.user,
                content: 'Explain quantum computing in one sentence'),
          ],
        ),
      );
      print('✅ Auto-selected provider: ${response.provider}');
      print('Response: ${response.choices.first.message.content}');
      print('Model: ${response.model}\n');
    } on Exception catch (e) {
      print('❌ Error: $e\n');
    }

    // Test 3: Provider capabilities
    print('📝 Test 3: Provider Capabilities\n');
    for (final providerId in ai.availableProviders) {
      final provider = ai.getProvider(providerId);
      if (provider != null) {
        print('$providerId:');
        print('   Name: ${provider.name}');
        print('   Chat: ${provider.capabilities.supportsChat}');
        print('   Streaming: ${provider.capabilities.supportsStreaming}');
        print('   Embeddings: ${provider.capabilities.supportsEmbedding}');
        print('   Image Gen: ${provider.capabilities.supportsImageGeneration}');
        print(
            '   Models: ${provider.capabilities.supportedModels.take(3).join(", ")}...\n');
      }
    }

    print('─' * 50);
    print('✅ Multi-provider demo complete');
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
