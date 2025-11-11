/// Mapper for converting between unified SDK models and Mistral AI-specific models.
///
/// This class provides bidirectional conversion between the provider-agnostic
/// SDK models ([ChatRequest], [ChatResponse], [EmbeddingRequest], [EmbeddingResponse],
/// [SttRequest], [TranscriptionResponse]) and Mistral AI-specific models.

import 'dart:convert';

import '../../error/error_types.dart';
import '../../models/common/message.dart';
import '../../models/common/usage.dart';
import '../../models/requests/chat_request.dart';
import '../../models/requests/embedding_request.dart';
import '../../models/requests/image_request.dart';
import '../../models/requests/stt_request.dart';
import '../../models/responses/chat_response.dart';
import '../../models/responses/embedding_response.dart';
import '../../models/responses/image_response.dart';
import '../../models/responses/transcription_response.dart';
import '../../models/base_enums.dart';
import '../base/provider_mapper.dart';
import 'mistral_models.dart';

/// Mapper for converting between unified SDK models and Mistral AI-specific models.
///
/// Implements [ProviderMapper] to provide Mistral AI-specific conversion logic.
/// This class uses a singleton pattern and provides instance methods for
/// converting between unified SDK models and Mistral AI-specific formats.
class MistralMapper implements ProviderMapper {
  /// Private constructor to enforce singleton pattern.
  MistralMapper._();

  /// Singleton instance for instance-based usage.
  static final MistralMapper instance = MistralMapper._();

  @override
  MistralChatRequest mapChatRequest(ChatRequest request,
      {String? defaultModel}) {
    return _mapChatRequestImpl(request, defaultModel: defaultModel);
  }

  @override
  ChatResponse mapChatResponse(dynamic response) {
    if (response is! MistralChatResponse) {
      throw ArgumentError(
          'Expected MistralChatResponse, got ${response.runtimeType}');
    }
    return _mapChatResponseImpl(response);
  }

  @override
  MistralEmbeddingRequest mapEmbeddingRequest(EmbeddingRequest request,
      {String? defaultModel}) {
    return _mapEmbeddingRequestImpl(request, defaultModel: defaultModel);
  }

  @override
  EmbeddingResponse mapEmbeddingResponse(dynamic response) {
    if (response is! MistralEmbeddingResponse) {
      throw ArgumentError(
          'Expected MistralEmbeddingResponse, got ${response.runtimeType}');
    }
    return _mapEmbeddingResponseImpl(response);
  }

  @override
  dynamic mapImageRequest(ImageRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'Mistral AI does not support image generation',
      code: 'IMAGE_GENERATION_NOT_SUPPORTED',
      provider: 'mistral',
    );
  }

  @override
  ImageResponse mapImageResponse(dynamic response) {
    throw CapabilityError(
      message: 'Mistral AI does not support image generation',
      code: 'IMAGE_GENERATION_NOT_SUPPORTED',
      provider: 'mistral',
    );
  }

  // Private implementation methods

  MistralChatRequest _mapChatRequestImpl(
    ChatRequest request, {
    String? defaultModel,
  }) {
    // Convert Message objects to Mistral message format
    final messages = request.messages.map((msg) {
      final messageMap = <String, dynamic>{
        'role': _mapRoleToMistral(msg.role),
        'content': msg.content,
      };
      if (msg.name != null) {
        messageMap['name'] = msg.name;
      }
      // Merge any metadata into the message
      if (msg.meta != null) {
        messageMap.addAll(msg.meta!);
      }
      return messageMap;
    }).toList();

    // Extract Mistral-specific options from providerOptions
    final mistralOptions =
        request.providerOptions?['mistral'] ?? <String, dynamic>{};

    // Determine model - use request.model, then defaultModel, or throw error
    final model = request.model ?? defaultModel;
    if (model == null || model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in ChatRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Build Mistral request
    return MistralChatRequest(
      model: model,
      messages: messages,
      temperature: request.temperature,
      maxTokens: request.maxTokens,
      topP: request.topP,
      n: request.n,
      stop: request.stop,
      user: request.user ?? mistralOptions['user'] as String?,
      stream: mistralOptions['stream'] as bool?,
      randomSeed: mistralOptions['random_seed'] as int?,
    );
  }

  ChatResponse _mapChatResponseImpl(MistralChatResponse response) {
    // Convert Mistral choices to SDK choices
    final choices = response.choices.map((choice) {
      // Convert Mistral message map to Message object
      final messageMap = choice.message;
      final role = _mapRoleFromMistral(messageMap['role'] as String);
      final content = messageMap['content'] as String? ?? '';

      // Extract name if present
      final name = messageMap['name'] as String?;

      // Extract any additional fields as metadata
      final meta = <String, dynamic>{};
      messageMap.forEach((key, value) {
        if (key != 'role' && key != 'content' && key != 'name') {
          meta[key] = value;
        }
      });

      final message = Message(
        role: role,
        content: content,
        name: name,
        meta: meta.isEmpty ? null : meta,
      );

      return ChatChoice(
        index: choice.index,
        message: message,
        finishReason: choice.finishReason,
      );
    }).toList();

    // Convert Mistral usage to SDK usage
    final usage = Usage(
      promptTokens: response.usage.promptTokens,
      completionTokens: response.usage.completionTokens,
      totalTokens: response.usage.totalTokens,
    );

    // Convert timestamp from Unix seconds to DateTime
    final timestamp =
        DateTime.fromMillisecondsSinceEpoch(response.created * 1000);

    // Build metadata from Mistral-specific fields
    final metadata = <String, dynamic>{
      'object': response.object,
      'created': response.created,
    };

    return ChatResponse(
      id: response.id,
      choices: choices,
      usage: usage,
      model: response.model,
      provider: 'mistral',
      timestamp: timestamp,
      metadata: metadata,
    );
  }

  /// Maps SDK [Role] enum to Mistral role string.
  ///
  /// Mistral uses lowercase strings: "system", "user", "assistant"
  String _mapRoleToMistral(Role role) {
    switch (role) {
      case Role.system:
        return 'system';
      case Role.user:
        return 'user';
      case Role.assistant:
        return 'assistant';
      case Role.function:
        return 'assistant'; // Mistral doesn't have a function role, use assistant
    }
  }

  /// Maps Mistral role string to SDK [Role] enum.
  ///
  /// Handles Mistral's role strings: "system", "user", "assistant"
  Role _mapRoleFromMistral(String role) {
    switch (role.toLowerCase()) {
      case 'system':
        return Role.system;
      case 'user':
        return Role.user;
      case 'assistant':
        return Role.assistant;
      default:
        throw ClientError(
          message: 'Unknown Mistral role: $role',
          code: 'INVALID_ROLE',
        );
    }
  }

  MistralEmbeddingRequest _mapEmbeddingRequestImpl(
    EmbeddingRequest request, {
    String? defaultModel,
  }) {
    // Determine model
    final model = request.model ?? defaultModel ?? 'mistral-embed';
    if (model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in EmbeddingRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Determine input format - Mistral accepts both string and array
    final input =
        request.inputs.length == 1 ? request.inputs.first : request.inputs;

    // Extract Mistral-specific options
    final mistralOptions =
        request.providerOptions?['mistral'] ?? <String, dynamic>{};

    return MistralEmbeddingRequest(
      model: model,
      input: input,
      encodingFormat: mistralOptions['encoding_format'] as String? ??
          mistralOptions['encodingFormat'] as String?,
    );
  }

  EmbeddingResponse _mapEmbeddingResponseImpl(
      MistralEmbeddingResponse response) {
    // Convert Mistral embeddings to SDK EmbeddingData
    final embeddings = response.data.map((embedding) {
      // Handle both List<double> and String (base64) formats
      List<double> vector;
      if (embedding.embedding is List) {
        vector = (embedding.embedding as List)
            .map((e) => (e as num).toDouble())
            .toList();
      } else if (embedding.embedding is String) {
        // Base64 format - would need decoding, but for now throw error
        throw ClientError(
          message: 'Base64 embedding format not yet supported',
          code: 'UNSUPPORTED_FORMAT',
        );
      } else {
        throw ClientError(
          message: 'Invalid embedding format',
          code: 'INVALID_FORMAT',
        );
      }

      return EmbeddingData(
        vector: vector,
        dimension: vector.length,
        index: embedding.index,
      );
    }).toList();

    // Convert Mistral usage to SDK usage
    final usage = Usage(
      promptTokens: response.usage.promptTokens,
      completionTokens: response.usage.completionTokens,
      totalTokens: response.usage.totalTokens,
    );

    return EmbeddingResponse(
      embeddings: embeddings,
      model: response.model,
      provider: 'mistral',
      usage: usage,
    );
  }

  /// Maps SDK [SttRequest] to Mistral STT request format.
  MistralSttRequest mapSttRequest(SttRequest request, {String? defaultModel}) {
    final model = request.model ?? defaultModel ?? 'voxtral-mini-transcribe';

    // Mistral expects audio as base64 or file path
    // Convert Uint8List to base64
    final audioData = base64Encode(request.audio);

    return MistralSttRequest(
      model: model,
      audio: audioData,
      language: request.language,
    );
  }

  /// Maps Mistral STT response to SDK [TranscriptionResponse].
  TranscriptionResponse mapSttResponse(dynamic response, {String? model}) {
    if (response is! MistralSttResponse) {
      throw ArgumentError(
          'Expected MistralSttResponse, got ${response.runtimeType}');
    }

    return TranscriptionResponse(
      text: response.text,
      language: response.language,
      model: model ?? 'voxtral-mini-transcribe',
      provider: 'mistral',
    );
  }
}
