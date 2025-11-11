// ignore_for_file: avoid_print, prefer_const_constructors

import 'dart:io';

import 'package:unified_ai_sdk/unified_ai_sdk.dart';

/// Error Handling Example
///
/// Demonstrates comprehensive error handling.
/// Shows how to:
/// - Handle different error types (AuthError, QuotaError, etc.)
/// - Implement retry logic
/// - Provide user-friendly error messages
/// - Gracefully degrade on errors
///
/// **Prerequisites:**
/// - Set `OPENAI_API_KEY` environment variable (or use invalid key to test errors)
///
/// **Run:**
/// ```bash
/// dart run example/06_error_handling/main.dart
/// ```
void main() async {
  // Test with invalid key to demonstrate error handling
  final apiKey =
      Platform.environment['OPENAI_API_KEY'] ?? 'invalid-key-for-testing';

  try {
    print('🚀 Initializing SDK...');
    await UnifiedAI.init(
      UnifiedAIConfig(
        defaultProvider: 'openai',
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            auth: ApiKeyAuth(apiKey: apiKey),
          ),
        },
        retryPolicy: RetryPolicy(
          maxAttempts: 3,
          initialDelay: Duration(milliseconds: 500),
        ),
      ),
    );
    print('✅ SDK initialized\n');

    final ai = UnifiedAI.instance;

    print('📝 Testing error handling scenarios...\n');

    // Scenario 1: Invalid API key
    print('1️⃣ Testing with potentially invalid API key...');
    try {
      final response = await ai.chat(
        request: ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello')],
        ),
      );
      print('   ✅ Request succeeded');
      print('   Response: ${response.choices.first.message.content}\n');
    } on AuthError catch (e) {
      print('   ❌ Authentication error: ${e.message}');
      print('   💡 Action: Check your API key\n');
    } on Exception catch (e) {
      print('   ❌ Unexpected error: $e\n');
    }

    // Scenario 2: Invalid provider
    print('2️⃣ Testing with invalid provider...');
    try {
      await ai.chat(
        provider: 'nonexistent-provider',
        request: ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello')],
        ),
      );
    } on ClientError catch (e) {
      print('   ❌ Client error: ${e.message}');
      print('   💡 Action: Use a valid provider ID\n');
    } on Exception catch (e) {
      print('   ❌ Error: $e\n');
    }

    // Scenario 3: Unsupported capability
    print('3️⃣ Testing unsupported capability...');
    try {
      // Try image generation with a provider that might not support it
      await ai.generateImage(
        provider: 'anthropic', // Anthropic doesn't support image generation
        request: ImageRequest(
          prompt: 'A cat',
        ),
      );
    } on CapabilityError catch (e) {
      print('   ❌ Capability error: ${e.message}');
      print('   💡 Action: Use a provider that supports this capability\n');
    } on Exception catch (e) {
      print('   ❌ Error: $e\n');
    }

    // Scenario 4: Rate limiting (simulated)
    print('4️⃣ Testing rate limit handling...');
    print('   ℹ️  SDK automatically retries on rate limit errors');
    print('   ℹ️  Configure rate limits in ProviderConfig.settings\n');

    // Scenario 5: Graceful degradation
    print('5️⃣ Testing graceful degradation...');
    try {
      await ai.chat(
        request: ChatRequest(
          messages: [const Message(role: Role.user, content: 'Hello')],
        ),
      );
      print('   ✅ Primary provider succeeded');
    } on Exception catch (e) {
      print('   ⚠️  Primary provider failed: $e');
      print('   💡 Action: Try fallback provider or show cached result\n');
    }

    // Scenario 6: Comprehensive error handler
    print('6️⃣ Comprehensive error handler example...');
    await handleWithComprehensiveErrorHandling(ai);

    print('─' * 50);
    print('✅ Error handling demo complete');
  } on Exception catch (e) {
    print('❌ Fatal error: $e');
    exit(1);
  } finally {
    try {
      await UnifiedAI.instance.dispose();
    } on Object {
      // Ignore
    }
  }
}

Future<void> handleWithComprehensiveErrorHandling(UnifiedAI ai) async {
  try {
    final response = await ai.chat(
      request: ChatRequest(
        messages: [const Message(role: Role.user, content: 'Hello')],
      ),
    );
    print('   ✅ Success: ${response.choices.first.message.content}');
  } on AuthError {
    print('   ❌ Auth Error: Invalid credentials');
    print('   💡 Check API key configuration');
  } on QuotaError {
    print('   ❌ Quota Error: Rate limit exceeded');
    print('   💡 Wait before retrying or upgrade plan');
  } on TransientError {
    print('   ❌ Transient Error: Temporary failure');
    print('   💡 SDK will retry automatically');
  } on CapabilityError {
    print('   ❌ Capability Error: Feature not supported');
    print('   💡 Use a different provider');
  } on ClientError {
    print('   ❌ Client Error: Invalid request');
    print('   💡 Check request parameters');
  } on AiException catch (e) {
    print('   ❌ AI Error: ${e.message}');
    print('   Code: ${e.code}, Provider: ${e.provider}');
  } on Exception catch (e) {
    print('   ❌ Unexpected Error: $e');
  }
}
