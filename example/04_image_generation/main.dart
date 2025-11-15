// ignore_for_file: avoid_print

import 'dart:io';

import 'package:unified_ai_sdk/unified_ai_sdk.dart';

/// Image Generation Example
///
/// Demonstrates AI-powered image generation with multiple providers.
/// Shows how to:
/// - Generate images from text prompts
/// - Use different providers (OpenAI, xAI)
/// - Access generated image URLs
///
/// **Prerequisites:**
/// - Set `OPENAI_API_KEY` or `XAI_API_KEY` environment variable
/// - For OpenAI: Image generation requires GPT Image 1 access
/// - For xAI: Uses grok-2-image-1212 model
///
/// **Run:**
/// ```bash
/// dart run example/04_image_generation/main.dart
/// ```
void main() async {
  final openaiKey = Platform.environment['OPENAI_API_KEY'];
  final xaiKey = Platform.environment['XAI_API_KEY'];

  if ((openaiKey == null || openaiKey.isEmpty) &&
      (xaiKey == null || xaiKey.isEmpty)) {
    print('❌ Error: Either OPENAI_API_KEY or XAI_API_KEY must be set');
    exit(1);
  }

  try {
    print('🚀 Initializing SDK...');
    final perProviderConfig = <String, ProviderConfig>{};

    if (openaiKey != null && openaiKey.isNotEmpty) {
      perProviderConfig['openai'] = ProviderConfig(
        id: 'openai',
        auth: ApiKeyAuth(apiKey: openaiKey),
      );
    }

    if (xaiKey != null && xaiKey.isNotEmpty) {
      perProviderConfig['xai'] = ProviderConfig(
        id: 'xai',
        auth: ApiKeyAuth(apiKey: xaiKey),
        settings: {
          'defaultModel': 'grok-2-image-1212',
        },
      );
    }

    // Use the first available provider as default
    final defaultProvider = perProviderConfig.keys.first;

    await UnifiedAI.init(
      UnifiedAIConfig(
        defaultProvider: defaultProvider,
        perProviderConfig: perProviderConfig,
      ),
    );
    print('✅ SDK initialized with provider: $defaultProvider\n');

    final ai = UnifiedAI.instance;

    final prompts = [
      'A serene mountain landscape at sunset with a lake in the foreground',
      'A futuristic cityscape with flying cars and neon lights',
      'A cute robot reading a book in a cozy library',
    ];

    for (int i = 0; i < prompts.length; i++) {
      final prompt = prompts[i];
      print('🎨 Generating image ${i + 1}/${prompts.length}...');
      print('   Prompt: "$prompt"\n');

      try {
        // Build request based on provider
        ImageRequest request;
        if (defaultProvider == 'xai') {
          // xAI only supports: prompt, model, n, response_format
          // size, quality, and style are not supported
          request = ImageRequest(
            prompt: prompt,
            model: 'grok-2-image-1212',
            n: 1,
          );
        } else {
          // OpenAI supports all parameters
          request = ImageRequest(
            prompt: prompt,
            model: 'gpt-image-1',
            size: ImageSize.w1024h1024,
            n: 1,
            quality: 'standard',
          );
        }

        final response = await ai.generateImage(request: request);

        print('✅ Image generated successfully!');
        for (final asset in response.assets) {
          if (asset.url != null) {
            print('   📷 URL: ${asset.url}');
          } else if (asset.base64 != null) {
            print(
                '   📷 Base64 data available (${asset.base64!.length} bytes)');
          }
        }
        print('   Provider: ${response.provider}');
        print('   Model: ${response.model}\n');
      } on CapabilityError catch (e) {
        print('❌ Capability error: ${e.message}');
        print('   Make sure your provider supports image generation\n');
      } on Exception catch (e) {
        print('❌ Error: $e\n');
      }
    }

    print('─' * 50);
    print('✅ Image generation complete');
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
