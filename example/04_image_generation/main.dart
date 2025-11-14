// ignore_for_file: avoid_print

import 'dart:io';

import 'package:unified_ai_sdk/unified_ai_sdk.dart';

/// Image Generation Example
///
/// Demonstrates AI-powered image generation.
/// Shows how to:
/// - Generate images from text prompts
/// - Configure image size and quality
/// - Access generated image URLs
///
/// **Prerequisites:**
/// - Set `OPENAI_API_KEY` environment variable
/// - Note: Image generation requires GPT Image 1 access
///
/// **Run:**
/// ```bash
/// dart run example/04_image_generation/main.dart
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
            auth: ApiKeyAuth(apiKey: apiKey),
          ),
        },
      ),
    );
    print('✅ SDK initialized\n');

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
        final response = await ai.generateImage(
          request: ImageRequest(
            prompt: prompt,
            model: 'gpt-image-1',
            size: ImageSize.w1024h1024,
            n: 1,
            quality: 'standard',
          ),
        );

        print('✅ Image generated successfully!');
        for (final asset in response.assets) {
          if (asset.url != null) {
            print('   📷 URL: ${asset.url}');
          } else if (asset.base64 != null) {
            print(
                '   📷 Base64 data available (${asset.base64!.length} bytes)');
          }
        }
        print('   Provider: ${response.provider}\n');
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
