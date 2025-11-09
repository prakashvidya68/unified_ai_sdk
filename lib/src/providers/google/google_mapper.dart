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

import '../../error/error_types.dart';
import '../../models/common/message.dart';
import '../../models/common/usage.dart';
import '../../models/requests/chat_request.dart';
import '../../models/requests/embedding_request.dart';
import '../../models/requests/image_request.dart';
import '../../models/responses/chat_response.dart';
import '../../models/responses/embedding_response.dart';
import '../../models/responses/image_response.dart';
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
  dynamic mapEmbeddingRequest(EmbeddingRequest request,
      {String? defaultModel}) {
    throw CapabilityError(
      message:
          'Google Gemini provider does not support embedding generation via this API.',
      code: 'UNSUPPORTED_OPERATION',
      provider: 'google',
    );
  }

  @override
  EmbeddingResponse mapEmbeddingResponse(dynamic response) {
    throw CapabilityError(
      message:
          'Google Gemini provider does not support embedding generation via this API.',
      code: 'UNSUPPORTED_OPERATION',
      provider: 'google',
    );
  }

  @override
  dynamic mapImageRequest(ImageRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'Google Gemini provider does not support image generation.',
      code: 'UNSUPPORTED_OPERATION',
      provider: 'google',
    );
  }

  @override
  ImageResponse mapImageResponse(dynamic response) {
    throw CapabilityError(
      message: 'Google Gemini provider does not support image generation.',
      code: 'UNSUPPORTED_OPERATION',
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

    // Build Google request
    return GoogleChatRequest(
      contents: contents,
      systemInstruction: systemInstructionObj ??
          (googleOptions['system_instruction'] as Map<String, dynamic>?),
      model: model,
      temperature: request.temperature,
      topP: request.topP,
      // Google-specific fields
      topK: googleOptions['top_k'] as int? ?? googleOptions['topK'] as int?,
      maxOutputTokens: request.maxTokens ??
          googleOptions['max_output_tokens'] as int? ??
          googleOptions['maxOutputTokens'] as int?,
      stopSequences: request.stop ??
          (googleOptions['stop_sequences'] != null
              ? List<String>.from(googleOptions['stop_sequences'] as List)
              : googleOptions['stopSequences'] != null
                  ? List<String>.from(googleOptions['stopSequences'] as List)
                  : null),
      candidateCount: googleOptions['candidate_count'] as int? ??
          googleOptions['candidateCount'] as int?,
      safetySettings:
          googleOptions['safety_settings'] as Map<String, dynamic>? ??
              googleOptions['safetySettings'] as Map<String, dynamic>?,
      generationConfig:
          googleOptions['generation_config'] as Map<String, dynamic>? ??
              googleOptions['generationConfig'] as Map<String, dynamic>?,
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
}
