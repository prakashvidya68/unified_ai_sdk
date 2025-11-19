/// Mapper for converting between unified SDK models and Google Gemini-specific models.
///
/// This class provides bidirectional conversion between the provider-agnostic
/// SDK models ([ChatRequest], [ChatResponse], [EmbeddingRequest], [EmbeddingResponse])
/// and Google-specific models ([GoogleChatRequest], [GoogleChatResponse], etc.).
///
/// **Design Pattern:** Adapter/Mapper Pattern
///
/// This mapper allows the SDK to maintain a unified API while supporting
/// provider-specific features and formats. Users interact with unified models,
/// but internally the SDK converts to/from Google-specific formats.
///
/// **Key Features:**
/// - Handles multimodal inputs (text + images) via message.meta
/// - Extracts system messages into system_instruction field
/// - Converts Google's "parts" structure to/from SDK messages
/// - Maps Google's finish reasons to SDK format
///
/// **Example usage:**
/// ```dart
/// // SDK → Google
/// final chatRequest = ChatRequest(
///   messages: [
///     Message(role: Role.system, content: 'You are helpful.'),
///     Message(role: Role.user, content: 'Hello!'),
///   ],
///   maxTokens: 1024,
/// );
/// final mapper = GoogleMapper.instance;
/// final googleRequest = mapper.mapChatRequest(chatRequest);
///
/// // Google → SDK
/// final googleResponse = GoogleChatResponse.fromJson(apiResponse);
/// final chatResponse = mapper.mapChatResponse(googleResponse);
/// ```
library;

import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../error/error_types.dart';
import '../../models/common/message.dart';
import '../../models/common/usage.dart';
import '../../models/requests/chat_request.dart';
import '../../models/requests/embedding_request.dart';
import '../../models/requests/image_request.dart';
import '../../models/requests/stt_request.dart';
import '../../models/requests/tts_request.dart';
import '../../models/requests/video_analysis_request.dart';
import '../../models/requests/video_request.dart';
import '../../models/responses/audio_response.dart';
import '../../models/responses/chat_response.dart';
import '../../models/responses/embedding_response.dart';
import '../../models/responses/image_response.dart';
import '../../models/responses/transcription_response.dart';
import '../../models/responses/video_analysis_response.dart';
import '../../models/responses/video_response.dart';
import '../../models/base_enums.dart';
import '../base/provider_mapper.dart';
import 'google_models.dart';

/// Mapper for converting between unified SDK models and Google Gemini-specific models.
///
/// Implements [ProviderMapper] to provide Google-specific conversion logic.
/// This class uses a singleton pattern and provides instance methods for
/// converting between unified SDK models and Google-specific formats.
///
/// **Usage:**
/// ```dart
/// final mapper = GoogleMapper.instance;
/// final request = mapper.mapChatRequest(chatRequest);
/// final response = mapper.mapChatResponse(googleResponse);
/// ```
class GoogleMapper implements ProviderMapper {
  /// Private constructor to enforce singleton pattern.
  /// Use [GoogleMapper.instance] to access the mapper instance.
  GoogleMapper._();

  /// Singleton instance for instance-based usage.
  ///
  /// Use this when you need to inject the mapper as a dependency or
  /// when working with the [ProviderMapper] interface.
  static final GoogleMapper instance = GoogleMapper._();

  // Instance methods implementing ProviderMapper interface

  @override
  GoogleChatRequest mapChatRequest(ChatRequest request,
      {String? defaultModel}) {
    return _mapChatRequestImpl(request, defaultModel: defaultModel);
  }

  @override
  ChatResponse mapChatResponse(dynamic response) {
    if (response is! GoogleChatResponse) {
      throw ArgumentError(
          'Expected GoogleChatResponse, got ${response.runtimeType}');
    }
    return _mapChatResponseImpl(response);
  }

  @override
  GoogleEmbeddingRequest mapEmbeddingRequest(EmbeddingRequest request,
      {String? defaultModel}) {
    // Determine model - default to text-embedding-004 if not specified
    final model = request.model ?? defaultModel ?? 'text-embedding-004';
    if (model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in EmbeddingRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Extract Google-specific options
    final googleOptions =
        request.providerOptions?['google'] ?? <String, dynamic>{};

    // Convert inputs to content format
    // Google expects a single content object or array of content objects
    dynamic content;
    if (request.inputs.length == 1) {
      // Single input - create content with parts
      content = {
        'parts': [
          {'text': request.inputs.first}
        ]
      };
    } else {
      // Multiple inputs - Google may need batch processing
      // For now, use first input (could be enhanced for batch)
      content = {
        'parts': [
          {'text': request.inputs.first}
        ]
      };
    }

    return GoogleEmbeddingRequest(
      model: model,
      content: content,
      taskType: googleOptions['taskType'] as String?,
      title: googleOptions['title'] as String?,
    );
  }

  @override
  EmbeddingResponse mapEmbeddingResponse(dynamic response) {
    if (response is! GoogleEmbeddingResponse) {
      throw ArgumentError(
        'Expected GoogleEmbeddingResponse, got ${response.runtimeType}',
      );
    }

    // Convert Google embedding to SDK EmbeddingData
    final embedding = response.embedding;
    final embeddingData = EmbeddingData(
      vector: embedding.values,
      dimension: embedding.values.length,
      index: 0,
    );

    // Extract model from response (if available) or use default
    final model = 'text-embedding-004'; // Default, could be enhanced

    return EmbeddingResponse(
      embeddings: [embeddingData],
      model: model,
      provider: 'google',
    );
  }

  @override
  GoogleImageRequest mapImageRequest(ImageRequest request,
      {String? defaultModel}) {
    // Determine model - default to imagen-4.0-generate-001 (latest Imagen model)
    // See: https://ai.google.dev/gemini-api/docs/imagen
    final model = request.model ?? defaultModel ?? 'imagen-4.0-generate-001';
    if (model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in ImageRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Extract Google-specific options
    final googleOptions =
        request.providerOptions?['google'] ?? <String, dynamic>{};

    // Convert ImageSize to aspect ratio string
    String? aspectRatio;
    if (request.size != null) {
      // Convert from "WIDTHxHEIGHT" format to Google's aspect ratio
      final sizeStr = request.size!.toString();
      if (sizeStr.contains('1024x1024')) {
        aspectRatio = '1:1';
      } else if (sizeStr.contains('1024x1792')) {
        aspectRatio = '9:16';
      } else if (sizeStr.contains('1792x1024')) {
        aspectRatio = '16:9';
      } else {
        // Try to extract from size string
        final parts = sizeStr.split('x');
        if (parts.length == 2) {
          final width = int.tryParse(parts[0]);
          final height = int.tryParse(parts[1]);
          if (width != null && height != null) {
            // Calculate aspect ratio
            final ratio = width / height;
            if (ratio == 1.0) {
              aspectRatio = '1:1';
            } else if (ratio > 1.0) {
              aspectRatio = '16:9'; // Approximate
            } else {
              aspectRatio = '9:16'; // Approximate
            }
          }
        }
      }
    }

    return GoogleImageRequest(
      model: model,
      prompt: request.prompt,
      numberOfImages: request.n,
      aspectRatio: aspectRatio ?? googleOptions['aspectRatio'] as String?,
      imageSize: googleOptions['imageSize'] as String?,
      safetyFilterLevel: googleOptions['safetyFilterLevel'] as String?,
      personGeneration: googleOptions['personGeneration'] as String?,
    );
  }

  @override
  ImageResponse mapImageResponse(dynamic response) {
    if (response is! GoogleImageResponse) {
      throw ArgumentError(
        'Expected GoogleImageResponse, got ${response.runtimeType}',
      );
    }

    // Convert Google image data to SDK ImageAsset
    final assets = response.predictions.map((imageData) {
      return ImageAsset(
        base64: imageData.bytesBase64Encoded,
        // Google Imagen returns base64, not URLs
        url: null,
      );
    }).toList();

    // Extract model from response (if available) or use default
    final model = 'imagen-4.0-generate-001'; // Default, could be enhanced

    return ImageResponse(
      assets: assets,
      model: model,
      provider: 'google',
    );
  }

  /// Maps a Gemini image generation response to SDK format.
  ///
  /// Gemini image models return responses in the same format as chat responses,
  /// but with image data in the candidates' parts instead of text.
  ImageResponse mapGeminiImageResponse(
    Map<String, dynamic> responseJson,
    String model,
  ) {
    final candidates = responseJson['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw ClientError(
        message: 'No candidates in Gemini image response',
        code: 'INVALID_RESPONSE',
        provider: 'google',
      );
    }

    // Extract image data from candidates
    final assets = <ImageAsset>[];
    for (final candidate in candidates) {
      final candidateMap = candidate as Map<String, dynamic>;
      final content = candidateMap['content'] as Map<String, dynamic>?;
      if (content != null) {
        final parts = content['parts'] as List<dynamic>?;
        if (parts != null) {
          for (final part in parts) {
            if (part is Map<String, dynamic>) {
              // Check for inline_data (base64 image) - Google uses snake_case in JSON
              final inlineData = part['inline_data'] as Map<String, dynamic>? ??
                  part['inlineData'] as Map<String, dynamic>?;
              if (inlineData != null) {
                final data = inlineData['data'] as String?;
                if (data != null) {
                  assets.add(ImageAsset(
                    base64: data,
                    // Gemini image models return base64, not URLs
                    url: null,
                  ));
                }
              }
              // Also check for image field (alternative format)
              final imageData = part['image'] as Map<String, dynamic>?;
              if (imageData != null) {
                final data = imageData['data'] as String? ??
                    imageData['bytesBase64Encoded'] as String?;
                if (data != null) {
                  assets.add(ImageAsset(
                    base64: data,
                    url: null,
                  ));
                }
              }
            }
          }
        }
      }
    }

    if (assets.isEmpty) {
      throw ClientError(
        message: 'No image data found in Gemini response',
        code: 'INVALID_RESPONSE',
        provider: 'google',
      );
    }

    return ImageResponse(
      assets: assets,
      model: model,
      provider: 'google',
    );
  }

  // Private implementation methods

  GoogleChatRequest _mapChatRequestImpl(
    ChatRequest request, {
    String? defaultModel,
  }) {
    String? systemInstruction;
    final List<GoogleMessage> contents = [];

    // Extract system message and convert other messages
    for (final msg in request.messages) {
      if (msg.role == Role.system) {
        // Google uses system_instruction field (can be text or parts)
        if (systemInstruction == null) {
          systemInstruction = msg.content;
        } else {
          // If multiple system messages, combine them
          systemInstruction = '$systemInstruction\n${msg.content}';
        }
      } else {
        // Convert message to Google format with parts
        final parts = _convertMessageToParts(msg);
        final role = _mapRoleToGoogle(msg.role);
        contents.add(GoogleMessage(role: role, parts: parts));
      }
    }

    // Determine model - use request.model, then defaultModel, or throw error
    final model = request.model ?? defaultModel;
    if (model == null || model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in ChatRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Extract Google-specific options from providerOptions
    final googleOptions =
        request.providerOptions?['google'] ?? <String, dynamic>{};

    // Build system instruction object if present
    Map<String, dynamic>? systemInstructionObj;
    if (systemInstruction != null) {
      systemInstructionObj = {
        'parts': [
          {'text': systemInstruction}
        ]
      };
    }

    // Build generationConfig object - Google requires temperature, topP, etc. inside generationConfig
    Map<String, dynamic>? generationConfig;
    final existingGenerationConfig =
        googleOptions['generation_config'] as Map<String, dynamic>? ??
            googleOptions['generationConfig'] as Map<String, dynamic>?;

    // Only create generationConfig if we have at least one parameter to include
    if (request.temperature != null ||
        request.topP != null ||
        request.maxTokens != null ||
        request.stop != null ||
        googleOptions['top_k'] != null ||
        googleOptions['topK'] != null ||
        googleOptions['max_output_tokens'] != null ||
        googleOptions['maxOutputTokens'] != null ||
        googleOptions['stop_sequences'] != null ||
        googleOptions['stopSequences'] != null ||
        existingGenerationConfig != null) {
      generationConfig = <String, dynamic>{
        ...?existingGenerationConfig,
        if (request.temperature != null) 'temperature': request.temperature,
        if (request.topP != null) 'topP': request.topP,
        if (googleOptions['top_k'] != null) 'topK': googleOptions['top_k'],
        if (googleOptions['topK'] != null && googleOptions['top_k'] == null)
          'topK': googleOptions['topK'],
        if (request.maxTokens != null) 'maxOutputTokens': request.maxTokens,
        if (googleOptions['max_output_tokens'] != null)
          'maxOutputTokens': googleOptions['max_output_tokens'],
        if (googleOptions['maxOutputTokens'] != null &&
            request.maxTokens == null &&
            googleOptions['max_output_tokens'] == null)
          'maxOutputTokens': googleOptions['maxOutputTokens'],
        if (request.stop != null) 'stopSequences': request.stop,
        if (googleOptions['stop_sequences'] != null)
          'stopSequences': googleOptions['stop_sequences'],
        if (googleOptions['stopSequences'] != null &&
            request.stop == null &&
            googleOptions['stop_sequences'] == null)
          'stopSequences': googleOptions['stopSequences'],
      };
    }

    // Build Google request
    return GoogleChatRequest(
      contents: contents,
      systemInstruction: systemInstructionObj ??
          (googleOptions['system_instruction'] as Map<String, dynamic>?),
      model: model,
      // temperature and topP are now in generationConfig, not top-level
      temperature: null,
      topP: null,
      topK: null,
      maxOutputTokens: null,
      stopSequences: null,
      candidateCount: googleOptions['candidate_count'] as int? ??
          googleOptions['candidateCount'] as int?,
      safetySettings:
          googleOptions['safety_settings'] as Map<String, dynamic>? ??
              googleOptions['safetySettings'] as Map<String, dynamic>?,
      generationConfig: generationConfig,
    );
  }

  /// Converts a SDK Message to Google ContentParts.
  ///
  /// Handles multimodal content:
  /// - Text content goes to text part
  /// - Images from message.meta['images'] are converted to inline_data parts
  /// - Supports base64 encoded images with mime_type
  List<GoogleContentPart> _convertMessageToParts(Message msg) {
    final parts = <GoogleContentPart>[];

    // Add text content if present
    if (msg.content.isNotEmpty) {
      parts.add(GoogleContentPart(text: msg.content));
    }

    // Handle multimodal inputs (images) from message.meta
    if (msg.meta != null) {
      final images = msg.meta!['images'] as List<dynamic>?;
      if (images != null) {
        for (final image in images) {
          if (image is Map<String, dynamic>) {
            // Expected format: {"mime_type": "image/jpeg", "data": "base64..."}
            final mimeType = image['mime_type'] as String? ??
                image['mimeType'] as String? ??
                'image/jpeg';
            final data = image['data'] as String?;
            if (data != null) {
              parts.add(GoogleContentPart(
                inlineData: {
                  'mime_type': mimeType,
                  'data': data,
                },
              ));
            }
          } else if (image is String) {
            // Assume base64 string, try to infer mime type
            parts.add(GoogleContentPart(
              inlineData: {
                'mime_type': 'image/jpeg', // Default
                'data': image,
              },
            ));
          }
        }
      }
    }

    // If no parts were created, add empty text part (required by Google)
    if (parts.isEmpty) {
      parts.add(GoogleContentPart(text: ''));
    }

    return parts;
  }

  ChatResponse _mapChatResponseImpl(GoogleChatResponse response) {
    // Convert Google candidates to SDK choices
    final choices = <ChatChoice>[];
    for (int i = 0; i < response.candidates.length; i++) {
      final candidate = response.candidates[i];

      // Extract text content from candidate.content.parts
      String content = '';
      if (candidate.content != null) {
        final parts = candidate.content!['parts'] as List<dynamic>?;
        if (parts != null) {
          for (final part in parts) {
            if (part is Map<String, dynamic>) {
              final text = part['text'] as String?;
              if (text != null) {
                content = content.isEmpty ? text : '$content\n$text';
              }
            }
          }
        }
      }

      // Map Google finish reason to SDK format
      String? finishReason;
      if (candidate.finishReason != null) {
        switch (candidate.finishReason) {
          case 'STOP':
            finishReason = 'stop';
            break;
          case 'MAX_TOKENS':
            finishReason = 'length';
            break;
          case 'SAFETY':
            finishReason = 'content_filter';
            break;
          case 'RECITATION':
            finishReason = 'recitation';
            break;
          default:
            finishReason = candidate.finishReason?.toLowerCase();
        }
      }

      choices.add(ChatChoice(
        index: candidate.index ?? i,
        message: Message(role: Role.assistant, content: content),
        finishReason: finishReason,
      ));
    }

    // Convert Google usage to SDK usage
    final usage = response.usageMetadata != null
        ? Usage(
            promptTokens: response.usageMetadata!.promptTokenCount ?? 0,
            completionTokens: response.usageMetadata!.candidatesTokenCount ?? 0,
            totalTokens: response.usageMetadata!.totalTokenCount ?? 0,
          )
        : const Usage(promptTokens: 0, completionTokens: 0, totalTokens: 0);

    // Extract model name from response.model
    String modelName = 'unknown';
    if (response.model != null) {
      modelName = response.model!['name'] as String? ??
          response.model!['base_model_id'] as String? ??
          'unknown';
    }

    // Build metadata from Google-specific fields
    final metadata = <String, dynamic>{
      if (response.promptFeedback != null)
        'prompt_feedback': response.promptFeedback,
    };

    return ChatResponse(
      id: 'google-${DateTime.now().millisecondsSinceEpoch}',
      choices: choices,
      usage: usage,
      model: modelName,
      provider: 'google',
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }

  String _mapRoleToGoogle(Role role) {
    switch (role) {
      case Role.user:
        return 'user';
      case Role.assistant:
        return 'model';
      case Role.system:
        // System messages are handled separately in Google
        throw ArgumentError(
            'System role should be handled as system_instruction field.');
      case Role.function:
        // Google doesn't have a direct function role
        // Could be handled as user message with metadata
        return 'user';
    }
  }

  @override
  GoogleTtsRequest mapTtsRequest(TtsRequest request, {String? defaultModel}) {
    // Extract Google-specific options
    final googleOptions =
        request.providerOptions?['google'] ?? <String, dynamic>{};

    // Build voice configuration
    final voice = <String, dynamic>{
      'languageCode': googleOptions['languageCode'] as String? ??
          request.providerOptions?['language'] as String? ??
          'en-US',
      'name': request.voice ??
          googleOptions['voiceName'] as String? ??
          'en-US-Standard-A',
      'ssmlGender': googleOptions['ssmlGender'] as String? ?? 'NEUTRAL',
    };

    // Build audio configuration
    final audioConfig = <String, dynamic>{
      'audioEncoding': googleOptions['audioEncoding'] as String? ?? 'MP3',
      if (request.speed != null) 'speakingRate': request.speed,
      'sampleRateHertz': googleOptions['sampleRateHertz'] as int? ?? 24000,
    };

    return GoogleTtsRequest(
      input: request.text,
      voice: voice,
      audioConfig: audioConfig,
    );
  }

  @override
  AudioResponse mapTtsResponse(
    dynamic response,
    Uint8List audioBytes,
    TtsRequest request,
  ) {
    // Extract format from response or provider options
    String format = 'mp3';
    if (response is http.Response) {
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('mp3')) format = 'mp3';
      if (contentType.contains('wav')) format = 'wav';
      if (contentType.contains('ogg')) format = 'ogg';
    } else {
      // Try to get from provider options
      final googleOptions =
          request.providerOptions?['google'] ?? <String, dynamic>{};
      final audioEncoding = googleOptions['audioEncoding'] as String?;
      if (audioEncoding != null) {
        format = audioEncoding.toLowerCase().replaceAll('_', '');
      }
    }

    // Extract model from request
    final model = request.model ?? 'google-tts';

    return AudioResponse(
      bytes: audioBytes,
      format: format,
      model: model,
      provider: 'google',
    );
  }

  @override
  GoogleSttRequest mapSttRequest(SttRequest request, {String? defaultModel}) {
    // Extract Google-specific options
    final googleOptions =
        request.providerOptions?['google'] ?? <String, dynamic>{};

    // Build audio configuration
    final config = <String, dynamic>{
      'encoding': googleOptions['encoding'] as String? ?? 'LINEAR16',
      'sampleRateHertz': googleOptions['sampleRateHertz'] as int? ?? 16000,
      'languageCode': request.language ??
          googleOptions['languageCode'] as String? ??
          'en-US',
      if (request.prompt != null) 'alternativeLanguageCodes': <String>[],
      'enableAutomaticPunctuation':
          googleOptions['enableAutomaticPunctuation'] as bool? ?? true,
      'enableWordTimeOffsets':
          googleOptions['enableWordTimeOffsets'] as bool? ?? false,
    };

    return GoogleSttRequest(
      audio: request.audio,
      config: config,
    );
  }

  @override
  TranscriptionResponse mapSttResponse(
    dynamic response,
    SttRequest request,
  ) {
    // Google STT response format
    String text = '';
    String? language;

    if (response is Map<String, dynamic>) {
      final results = response['results'] as List<dynamic>?;
      if (results != null && results.isNotEmpty) {
        final alternatives = results[0]['alternatives'] as List<dynamic>?;
        if (alternatives != null && alternatives.isNotEmpty) {
          text = alternatives[0]['transcript'] as String? ?? '';
        }
      }
      language = response['languageCode'] as String?;
    } else if (response is String) {
      text = response;
    }

    return TranscriptionResponse(
      text: text,
      language: language,
      model: 'google-stt',
      provider: 'google',
    );
  }

  @override
  GoogleVideoRequest mapVideoRequest(VideoRequest request,
      {String? defaultModel}) {
    // Determine model - default to veo-3.1 if not specified
    final model = request.model ?? defaultModel ?? 'veo-3.1';
    if (model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in VideoRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    return GoogleVideoRequest(
      model: model,
      prompt: request.prompt,
      duration: request.duration,
      aspectRatio: request.aspectRatio,
      frameRate: request.frameRate,
      quality: request.quality,
      seed: request.seed,
    );
  }

  @override
  VideoResponse mapVideoResponse(dynamic response) {
    if (response is! GoogleVideoResponse) {
      throw ArgumentError(
        'Expected GoogleVideoResponse, got ${response.runtimeType}',
      );
    }

    // Convert Google video data to SDK VideoAsset
    final assets = response.videos.map((videoData) {
      return VideoAsset(
        url: videoData.url,
        base64: videoData.base64,
        width: videoData.width,
        height: videoData.height,
        duration: videoData.duration,
        frameRate: videoData.frameRate,
      );
    }).toList();

    return VideoResponse(
      assets: assets,
      model: response.model,
      provider: 'google',
      timestamp: DateTime.now(),
    );
  }

  @override
  GoogleVideoAnalysisRequest mapVideoAnalysisRequest(
    VideoAnalysisRequest request, {
    String? defaultModel,
  }) {
    // Determine model - default to gemini-1.5-pro if not specified
    final model = request.model ?? defaultModel ?? 'gemini-1.5-pro';
    if (model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in VideoAnalysisRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Extract Google-specific options
    final googleOptions =
        request.providerOptions?['google'] ?? <String, dynamic>{};

    // Build messages for video analysis
    final contents = <GoogleMessage>[];

    // Build user message with video content
    final parts = <GoogleContentPart>[];

    // Add text prompt if provided via features or as a prompt
    final promptText = googleOptions['prompt'] as String? ??
        (request.features != null && request.features!.isNotEmpty
            ? 'Analyze this video and extract: ${request.features!.join(", ")}'
            : 'Analyze this video and provide a detailed description.');

    if (promptText.isNotEmpty) {
      parts.add(GoogleContentPart(text: promptText));
    }

    // Add video content
    if (request.videoUrl != null) {
      // For URL, we need to use file_data format
      parts.add(GoogleContentPart(
        fileData: {
          'file_uri': request.videoUrl,
          'mime_type': googleOptions['mime_type'] as String? ?? 'video/mp4',
        },
      ));
    } else if (request.videoBase64 != null) {
      // For base64, use inline_data format
      final mimeType = googleOptions['mime_type'] as String? ?? 'video/mp4';
      parts.add(GoogleContentPart(
        inlineData: {
          'mime_type': mimeType,
          'data': request.videoBase64,
        },
      ));
    }

    if (parts.isEmpty) {
      throw ClientError(
        message: 'Either videoUrl or videoBase64 must be provided',
        code: 'MISSING_VIDEO',
      );
    }

    contents.add(GoogleMessage(role: 'user', parts: parts));

    // Build system instruction if provided
    Map<String, dynamic>? systemInstruction;
    final systemMessage = googleOptions['system_message'] as String?;
    if (systemMessage != null && systemMessage.isNotEmpty) {
      systemInstruction = {
        'parts': [
          {'text': systemMessage}
        ]
      };
    }

    return GoogleVideoAnalysisRequest(
      model: model,
      contents: contents,
      systemInstruction: systemInstruction,
      generationConfig: {
        if (request.confidenceThreshold != null)
          'temperature': 1.0 - request.confidenceThreshold!,
        if (request.language != null) 'language': request.language,
      },
    );
  }

  @override
  VideoAnalysisResponse mapVideoAnalysisResponse(dynamic response) {
    if (response is! GoogleVideoAnalysisResponse) {
      throw ArgumentError(
        'Expected GoogleVideoAnalysisResponse, got ${response.runtimeType}',
      );
    }

    // Extract analysis text from the first candidate
    String analysisText = '';
    if (response.candidates.isNotEmpty) {
      final candidate = response.candidates.first;
      if (candidate.content != null) {
        final parts = candidate.content!['parts'] as List<dynamic>?;
        if (parts != null) {
          for (final part in parts) {
            if (part is Map<String, dynamic>) {
              final text = part['text'] as String?;
              if (text != null) {
                analysisText =
                    analysisText.isEmpty ? text : '$analysisText\n$text';
              }
            }
          }
        }
      }
    }

    // Parse the analysis text to extract structured information
    // This is a simplified implementation - in practice, you might want to
    // use structured output or parse the text more intelligently
    final objects = <DetectedObject>[];
    final scenes = <DetectedScene>[];
    final actions = <DetectedAction>[];
    final text = <ExtractedText>[];
    final labels = <String>[];

    // Basic parsing - extract labels from the analysis text
    if (analysisText.isNotEmpty) {
      // Extract potential labels (simple heuristic)
      final words = analysisText.split(RegExp(r'[.,;!?\s]+'));
      for (final word in words) {
        if (word.length > 3 && word[0].toUpperCase() == word[0]) {
          labels.add(word);
        }
      }

      // If no labels found, add the full text as a label
      if (labels.isEmpty && analysisText.length < 100) {
        labels.add(analysisText);
      }
    }

    // Build metadata from Google-specific fields
    final metadata = <String, dynamic>{
      if (response.usageMetadata != null)
        'usage': {
          'prompt_tokens': response.usageMetadata!.promptTokenCount,
          'completion_tokens': response.usageMetadata!.candidatesTokenCount,
          'total_tokens': response.usageMetadata!.totalTokenCount,
        },
      'analysis_text': analysisText,
    };

    // Extract model name
    String modelName = 'gemini-1.5-pro';
    if (response.model != null) {
      modelName = response.model!['name'] as String? ??
          response.model!['base_model_id'] as String? ??
          'gemini-1.5-pro';
    }

    return VideoAnalysisResponse(
      objects: objects,
      scenes: scenes,
      actions: actions,
      text: text,
      labels: labels,
      model: modelName,
      provider: 'google',
      timestamp: DateTime.now(),
      metadata: metadata,
    );
  }
}
