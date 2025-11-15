import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../../core/authentication.dart';
import '../../core/provider_config.dart';
import '../../error/error_types.dart';
import '../../models/common/capabilities.dart';
import '../../models/requests/chat_request.dart';
import '../../models/requests/embedding_request.dart';
import '../../models/requests/image_request.dart';
import '../../models/requests/stt_request.dart';
import '../../models/requests/tts_request.dart';
import '../../models/requests/video_analysis_request.dart';
import '../../models/requests/video_request.dart';
import '../../models/responses/audio_response.dart';
import '../../models/responses/chat_response.dart';
import '../../models/responses/chat_stream_event.dart';
import '../../models/responses/embedding_response.dart';
import '../../models/responses/image_response.dart';
import '../../models/responses/transcription_response.dart';
import '../../models/responses/video_analysis_response.dart';
import '../../models/responses/video_response.dart';
import '../../error/error_mapper.dart';
import '../../network/http_client_wrapper.dart';
import '../base/ai_provider.dart';
import '../base/provider_mapper.dart';
import '../base/rate_limiter_factory.dart';
import 'xai_mapper.dart';
import 'xai_models.dart';

/// xAI (Grok) provider implementation for the Unified AI SDK.
///
/// This provider integrates with xAI's Grok API to provide:
/// - Chat completions (Grok-4, Grok-4-fast, Grok-3, Grok-3-mini, Grok-code-fast-1)
/// - Image generation (grok-2-image-1212)
/// - Video analysis (grok-2-vision-1212)
/// - Streaming support for chat completions
///
/// **Key Features:**
/// - Uses xAI's Chat Completions API (`/v1/chat/completions`)
/// - Supports image generation via grok-2-image-1212
/// - Supports video analysis via grok-2-vision-1212
/// - Uses `Authorization` header with Bearer token for authentication
///
/// **Example usage:**
/// ```dart
/// final config = ProviderConfig(
///   id: 'xai',
///   auth: ApiKeyAuth(apiKey: 'xai-...'),
///   settings: {
///     'defaultModel': 'grok-4-0709',
///   },
/// );
///
/// final provider = XAIProvider();
/// await provider.init(config);
///
/// final response = await provider.chat(ChatRequest(
///   messages: [
///     Message(role: Role.user, content: 'Hello!'),
///   ],
/// ));
/// ```
class XAIProvider extends AiProvider {
  /// Default base URL for xAI API.
  static const String _defaultBaseUrl = 'https://api.x.ai/v1';

  /// API key for authenticating requests.
  late final String _apiKey;

  /// HTTP client wrapper for making API requests.
  late final HttpClientWrapper _http;

  /// Base URL for API requests (can be overridden in settings).
  late final String _baseUrl;

  /// Default model to use when not specified in requests.
  String? _defaultModel;

  /// Mapper for converting between SDK and xAI models.
  final ProviderMapper _mapper = XAIMapper.instance;

  /// Fallback models used when dynamic fetch is not available.
  ///
  /// These models are always available as a backup, ensuring the SDK works
  /// even when the API is unreachable or model fetching fails.
  static const List<String> _fallbackModels = [
    // Chat/Text Models
    'grok-4-0709',
    'grok-4-fast-reasoning',
    'grok-4-fast-non-reasoning',
    'grok-3',
    'grok-3-mini',
    'grok-code-fast-1',
    // Vision Models (for video/image analysis)
    'grok-2-vision-1212',
    // Image Generation Models
    'grok-2-image-1212',
  ];

  /// Cached capabilities instance.
  ProviderCapabilities? _capabilities;

  @override
  String get id => 'xai';

  @override
  String get name => 'xAI (Grok)';

  @override
  ProviderCapabilities get capabilities {
    _capabilities ??= ProviderCapabilities(
      supportsChat: true,
      supportsEmbedding: false,
      supportsImageGeneration: true,
      supportsTTS: false,
      supportsSTT: false,
      supportsVideoGeneration: false, // xAI doesn't support video generation
      supportsVideoAnalysis:
          true, // xAI supports video analysis via View X Video Tool
      supportsStreaming: true,
      fallbackModels: _fallbackModels,
      dynamicModels: false, // xAI doesn't support dynamic model fetching yet
    );
    return _capabilities!;
  }

  @override
  Future<void> init(ProviderConfig config) async {
    // Validate that config ID matches provider ID
    if (config.id != id) {
      throw ClientError(
        message:
            'Provider config ID (${config.id}) does not match provider ID ($id)',
        code: 'CONFIG_ID_MISMATCH',
      );
    }

    // Extract API key from authentication
    if (config.auth is! ApiKeyAuth) {
      throw AuthError(
        message:
            'xAI provider requires ApiKeyAuth, got ${config.auth.runtimeType}',
        code: 'INVALID_AUTH_TYPE',
        provider: id,
      );
    }

    final apiKeyAuth = config.auth as ApiKeyAuth;
    _apiKey = apiKeyAuth.apiKey;

    if (_apiKey.isEmpty) {
      throw AuthError(
        message: 'API key cannot be empty',
        code: 'EMPTY_API_KEY',
        provider: id,
      );
    }

    // Extract base URL from settings or use default
    _baseUrl = config.settings['baseUrl'] as String? ?? _defaultBaseUrl;

    // Extract default model from settings
    _defaultModel = config.settings['defaultModel'] as String?;

    // Build authentication headers
    final authHeaders = apiKeyAuth.buildHeaders();

    // Initialize HTTP client wrapper with authentication headers
    // Allow injecting custom client for testing via settings
    final customClient = config.settings['httpClient'] as http.Client?;

    // Create rate limiter for this provider
    final rateLimiter = RateLimiterFactory.create(id, config.settings);

    _http = HttpClientWrapper(
      client: customClient ?? http.Client(),
      defaultHeaders: {
        ...authHeaders,
        'Content-Type': 'application/json',
      },
      rateLimiter: rateLimiter,
    );
  }

  @override
  Future<ChatResponse> chat(ChatRequest request) async {
    // Validate that chat is supported
    validateCapability('chat');

    // Map SDK request to xAI format
    final xaiRequest = _mapper.mapChatRequest(
      request,
      defaultModel: _defaultModel,
    ) as XAIChatRequest;

    // Make HTTP POST request to chat/completions endpoint
    final response = await _http.post(
      '$_baseUrl/chat/completions',
      body: jsonEncode(xaiRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final xaiResponse = XAIChatResponse.fromJson(responseJson);

    // Map xAI response to SDK format
    return _mapper.mapChatResponse(xaiResponse);
  }

  @override
  Stream<ChatStreamEvent> chatStream(ChatRequest request) async* {
    // Validate that streaming is supported
    validateCapability('streaming');

    // Map SDK request to xAI format
    final xaiRequest = _mapper.mapChatRequest(
      request,
      defaultModel: _defaultModel,
    ) as XAIChatRequest;

    // Create streaming request with stream: true
    final requestJson = xaiRequest.toJson();
    final streamRequestJson = <String, dynamic>{
      ...requestJson,
      'stream': true,
    };

    try {
      // Make streaming HTTP POST request
      final byteStream = _http.postStream(
        '$_baseUrl/chat/completions',
        body: streamRequestJson,
      );

      // Parse SSE (Server-Sent Events) format
      String buffer = '';
      Map<String, dynamic>? finalMetadata;

      await for (final chunk in byteStream) {
        // Convert bytes to string and append to buffer
        buffer += utf8.decode(chunk, allowMalformed: true);

        // Process complete lines (ending with \n)
        final lines = buffer.split('\n');
        // Keep the last incomplete line in buffer
        buffer = lines.removeLast();

        for (final line in lines) {
          // Skip empty lines
          if (line.trim().isEmpty) continue;

          // SSE format: lines starting with "data: "
          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();

            // Check for [DONE] marker
            if (data == '[DONE]') {
              // Yield final event with metadata if available
              yield ChatStreamEvent(
                delta: null,
                done: true,
                metadata: finalMetadata,
              );
              return;
            }

            // Parse JSON chunk
            try {
              final chunkJson = jsonDecode(data) as Map<String, dynamic>;

              // Extract delta content from choices[0].delta.content
              final choices = chunkJson['choices'] as List<dynamic>?;
              if (choices != null && choices.isNotEmpty) {
                final choice = choices[0] as Map<String, dynamic>;
                final delta = choice['delta'] as Map<String, dynamic>?;
                final content = delta?['content'] as String?;

                // Extract usage information if present (usually in final chunk)
                final usage = chunkJson['usage'] as Map<String, dynamic>?;
                if (usage != null) {
                  finalMetadata = {
                    'usage': {
                      'prompt_tokens': usage['prompt_tokens'],
                      'completion_tokens': usage['completion_tokens'],
                      'total_tokens': usage['total_tokens'],
                    },
                  };
                }

                // Extract finish reason if present
                final finishReason = choice['finish_reason'] as String?;
                if (finishReason != null) {
                  finalMetadata ??= <String, dynamic>{};
                  finalMetadata['finish_reason'] = finishReason;
                }

                // Extract model if present
                final model = chunkJson['model'] as String?;
                if (model != null) {
                  finalMetadata ??= <String, dynamic>{};
                  finalMetadata['model'] = model;
                }

                // Yield event with content delta
                if (content != null) {
                  yield ChatStreamEvent(
                    delta: content,
                    done: false,
                  );
                }
              }
            } on FormatException {
              // Skip invalid JSON chunks
              continue;
            }
          }
        }
      }

      // Handle case where stream ends without [DONE] marker
      if (buffer.isNotEmpty) {
        // Try to process remaining buffer
        if (buffer.startsWith('data: ')) {
          final data = buffer.substring(6).trim();
          if (data != '[DONE]' && data.isNotEmpty) {
            try {
              final chunkJson = jsonDecode(data) as Map<String, dynamic>;
              final choices = chunkJson['choices'] as List<dynamic>?;
              if (choices != null && choices.isNotEmpty) {
                final choice = choices[0] as Map<String, dynamic>;
                final delta = choice['delta'] as Map<String, dynamic>?;
                final content = delta?['content'] as String?;
                if (content != null) {
                  yield ChatStreamEvent(
                    delta: content,
                    done: false,
                  );
                }
              }
            } on FormatException {
              // Ignore invalid JSON
            }
          }
        }
      }

      // Always yield final event
      yield ChatStreamEvent(
        delta: null,
        done: true,
        metadata: finalMetadata,
      );
    } catch (e) {
      // Map HTTP/network errors to appropriate exception types
      if (e is Exception) {
        throw ErrorMapper.mapException(e, id);
      }
      rethrow;
    }
  }

  @override
  Future<EmbeddingResponse> embed(EmbeddingRequest request) async {
    // xAI does not support embeddings
    validateCapability('embedding');
    throw CapabilityError(
      message: 'xAI does not support embeddings',
      code: 'EMBEDDING_NOT_SUPPORTED',
      provider: id,
    );
  }

  @override
  Future<ImageResponse> generateImage(ImageRequest request) async {
    // Validate that image generation is supported
    validateCapability('image');

    // Map SDK request to xAI format
    final xaiRequest = _mapper.mapImageRequest(
      request,
      defaultModel: _defaultModel,
    ) as XAIImageRequest;

    // Make HTTP POST request to images/generations endpoint
    // xAI uses /v1/images/generations endpoint (similar to OpenAI)
    final response = await _http.post(
      '$_baseUrl/images/generations',
      body: jsonEncode(xaiRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final xaiResponse = XAIImageResponse.fromJson(responseJson);

    // Map xAI response to SDK format
    // Note: We need to pass the model from the request to the mapper
    // Since xAI may not return the model in the response
    final imageResponse = _mapper.mapImageResponse(xaiResponse);

    // Update the model in the response to match the request
    final model = xaiRequest.model ?? 'grok-2-image-1212';
    return imageResponse.copyWith(
      model: model,
    );
  }

  @override
  Future<AudioResponse> tts(TtsRequest request) async {
    // xAI does not support TTS
    validateCapability('tts');
    throw CapabilityError(
      message: 'xAI does not support text-to-speech',
      code: 'TTS_NOT_SUPPORTED',
      provider: id,
    );
  }

  @override
  Future<TranscriptionResponse> stt(SttRequest request) async {
    // xAI does not support STT
    validateCapability('stt');
    throw CapabilityError(
      message: 'xAI does not support speech-to-text',
      code: 'STT_NOT_SUPPORTED',
      provider: id,
    );
  }

  @override
  Future<VideoResponse> generateVideo(VideoRequest request) async {
    // xAI doesn't support video generation
    throw CapabilityError(
      message: 'xAI API does not support video generation',
      code: 'UNSUPPORTED_CAPABILITY',
      provider: id,
    );
  }

  @override
  Future<VideoAnalysisResponse> analyzeVideo(
      VideoAnalysisRequest request) async {
    // Validate that video analysis is supported
    validateCapability('videoAnalysis');

    // xAI video analysis uses Grok's vision capabilities via chat completions
    // We'll use the chat API with video content in messages
    final xaiRequest = _mapper.mapVideoAnalysisRequest(
      request,
      defaultModel: _defaultModel,
    ) as XAIChatRequest;

    // Make HTTP POST request to chat/completions endpoint
    final response = await _http.post(
      '$_baseUrl/chat/completions',
      body: jsonEncode(xaiRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final xaiResponse = XAIChatResponse.fromJson(responseJson);

    // Map xAI response to SDK format
    return _mapper.mapVideoAnalysisResponse(xaiResponse);
  }

  /// Gets the default model for this provider.
  ///
  /// Returns the default model configured in settings, or null if not set.
  String? get defaultModel => _defaultModel;

  /// Gets the base URL for API requests.
  ///
  /// Returns the configured base URL or the default xAI API URL.
  String get baseUrl => _baseUrl;

  /// Gets the HTTP client wrapper (for testing purposes).
  ///
  /// This is exposed for testing but should not be used in production code.
  @visibleForTesting
  HttpClientWrapper get httpClient => _http;
}
