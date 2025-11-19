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
import '../base/model_fetcher.dart';
import '../base/provider_mapper.dart';
import '../base/rate_limiter_factory.dart';
import 'mistral_mapper.dart';
import 'mistral_models.dart';

/// Mistral AI provider implementation for the Unified AI SDK.
///
/// This provider integrates with Mistral AI's API to provide:
/// - Chat completions (Magistral, Mistral Medium, Small, Codestral, Pixtral, Devstral)
/// - Embeddings (Mistral Embed, Codestral Embed)
/// - Speech-to-text (Voxtral)
/// - Video analysis (Pixtral)
/// - Streaming support for chat completions
/// - Dynamic model fetching via /v1/models endpoint
///
/// **Key Features:**
/// - Uses Mistral AI's Chat Completions API (`/v1/chat/completions`)
/// - Supports embeddings via `/v1/embeddings`
/// - Supports speech-to-text via Voxtral
/// - Uses `Authorization` header with Bearer token for authentication
///
/// **Example usage:**
/// ```dart
/// final config = ProviderConfig(
///   id: 'mistral',
///   auth: ApiKeyAuth(apiKey: 'mistral-...'),
///   settings: {
///     'defaultModel': 'mistral-large-latest',
///   },
/// );
///
/// final provider = MistralProvider();
/// await provider.init(config);
///
/// final response = await provider.chat(ChatRequest(
///   messages: [
///     Message(role: Role.user, content: 'Hello!'),
///   ],
/// ));
/// ```
class MistralProvider extends AiProvider implements ModelFetcher {
  /// Default base URL for Mistral AI API.
  static const String _defaultBaseUrl = 'https://api.mistral.ai/v1';

  /// API key for authenticating requests.
  late final String _apiKey;

  /// HTTP client wrapper for making API requests.
  late final HttpClientWrapper _http;

  /// Base URL for API requests (can be overridden in settings).
  late final String _baseUrl;

  /// Default model to use when not specified in requests.
  String? _defaultModel;

  /// Mapper for converting between SDK and Mistral models.
  final ProviderMapper _mapper = MistralMapper.instance;

  /// Fallback models used when dynamic fetch is not available.
  ///
  /// These models are always available as a backup, ensuring the SDK works
  /// even when the API is unreachable or model fetching fails.
  ///
  /// Updated based on Mistral AI models documentation:
  /// https://docs.mistral.ai/getting-started/models
  static const List<String> _fallbackModels = [
    // Frontier Models - Chat/Text
    'magistral-medium-2509',
    'mistral-medium-2508',
    'codestral-2508',
    'devstral-medium-2507',
    'mistral-medium-2505',
    'mistral-large-2407',
    'pixtral-large-2411',
    'ministral-8b-2401',
    'ministral-3b-2401',
    // Open Models - Chat/Text
    'magistral-small-2509',
    'mistral-small-2506',
    'devstral-small-2507',
    'pixtral-12b-2409',
    'mistral-nemo-12b-2407',
    // Embedding Models
    'codestral-embed-2505',
    'mistral-embed-2312',
    // Audio/STT Models
    'voxtral-mini-transcribe-2507',
    'voxtral-mini-2507',
    'voxtral-small-2507',
    // Other Services
    'mistral-ocr-2505',
    'mistral-moderation-2411',
    // Latest aliases (for backward compatibility)
    'mistral-large-latest',
    'mistral-medium-latest',
    'mistral-small-latest',
    'codestral-latest',
    'pixtral-latest',
  ];

  /// Cached capabilities instance.
  ProviderCapabilities? _capabilities;

  @override
  String get id => 'mistral';

  @override
  String get name => 'Mistral AI';

  @override
  ProviderCapabilities get capabilities {
    _capabilities ??= ProviderCapabilities(
      supportsChat: true,
      supportsEmbedding: true,
      supportsImageGeneration: false,
      supportsTTS:
          false, // TTS capability mentioned in table but API endpoint unclear - needs verification
      supportsSTT: true,
      supportsVideoGeneration:
          false, // Mistral doesn't support video generation
      supportsVideoAnalysis:
          true, // Pixtral 12B supports video analysis via multimodal input
      supportsStreaming: true,
      fallbackModels: _fallbackModels,
      dynamicModels:
          true, // Mistral supports dynamic model fetching via /v1/models
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
            'Mistral AI provider requires ApiKeyAuth, got ${config.auth.runtimeType}',
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

    // Optionally fetch models during initialization if configured
    if (config.settings['fetchModelsOnInit'] == true) {
      try {
        await fetchAvailableModels();
      } on Exception {
        // Silently fail - fallback models will be used
        // Log error if telemetry is configured
      }
    }
  }

  @override
  Future<ChatResponse> chat(ChatRequest request) async {
    // Validate that chat is supported
    validateCapability('chat');

    // Map SDK request to Mistral format
    final mistralRequest = _mapper.mapChatRequest(
      request,
      defaultModel: _defaultModel,
    ) as MistralChatRequest;

    // Make HTTP POST request to chat/completions endpoint
    final response = await _http.post(
      '$_baseUrl/chat/completions',
      body: jsonEncode(mistralRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final mistralResponse = MistralChatResponse.fromJson(responseJson);

    // Map Mistral response to SDK format
    return _mapper.mapChatResponse(mistralResponse);
  }

  @override
  Stream<ChatStreamEvent> chatStream(ChatRequest request) async* {
    // Validate that streaming is supported
    validateCapability('streaming');

    // Map SDK request to Mistral format
    final mistralRequest = _mapper.mapChatRequest(
      request,
      defaultModel: _defaultModel,
    ) as MistralChatRequest;

    // Create streaming request with stream: true
    final requestJson = mistralRequest.toJson();
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
    // Validate that embedding is supported
    validateCapability('embedding');

    // Map SDK request to Mistral format
    final mistralRequest = _mapper.mapEmbeddingRequest(
      request,
      defaultModel: _defaultModel,
    ) as MistralEmbeddingRequest;

    // Make HTTP POST request to embeddings endpoint
    final response = await _http.post(
      '$_baseUrl/embeddings',
      body: jsonEncode(mistralRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final mistralResponse = MistralEmbeddingResponse.fromJson(responseJson);

    // Map Mistral response to SDK format
    return _mapper.mapEmbeddingResponse(mistralResponse);
  }

  @override
  Future<ImageResponse> generateImage(ImageRequest request) async {
    // Mistral AI does not support image generation
    validateCapability('imageGeneration');
    throw CapabilityError(
      message: 'Mistral AI does not support image generation',
      code: 'IMAGE_GENERATION_NOT_SUPPORTED',
      provider: id,
    );
  }

  @override
  Future<AudioResponse> tts(TtsRequest request) async {
    // Mistral AI does not support TTS
    validateCapability('tts');
    throw CapabilityError(
      message: 'Mistral AI does not support text-to-speech',
      code: 'TTS_NOT_SUPPORTED',
      provider: id,
    );
  }

  @override
  Future<TranscriptionResponse> stt(SttRequest request) async {
    // Validate that STT is supported
    validateCapability('stt');

    // Map SDK request to Mistral format
    final mistralMapper = _mapper as MistralMapper;
    final mistralRequest = mistralMapper.mapSttRequest(
      request,
      defaultModel: _defaultModel,
    );

    // Make HTTP POST request to audio/transcriptions endpoint
    // Note: Mistral's Voxtral endpoint may vary, adjust as needed
    final response = await _http.post(
      '$_baseUrl/audio/transcriptions',
      body: jsonEncode(mistralRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final mistralResponse = MistralSttResponse.fromJson(responseJson);

    // Map Mistral response to SDK format
    return mistralMapper.mapSttResponse(
      mistralResponse,
      request,
    );
  }

  @override
  Future<VideoResponse> generateVideo(VideoRequest request) async {
    // Mistral doesn't support video generation
    throw CapabilityError(
      message: 'Mistral AI does not support video generation',
      code: 'VIDEO_GENERATION_NOT_SUPPORTED',
      provider: id,
    );
  }

  @override
  Future<VideoAnalysisResponse> analyzeVideo(
      VideoAnalysisRequest request) async {
    // Validate that video analysis is supported
    validateCapability('videoAnalysis');

    // Mistral video analysis uses Pixtral's multimodal capabilities via chat completions
    // We'll use the chat API with video content in messages
    final mistralRequest = _mapper.mapVideoAnalysisRequest(
      request,
      defaultModel: _defaultModel,
    ) as MistralChatRequest;

    // Make HTTP POST request to chat/completions endpoint
    final response = await _http.post(
      '$_baseUrl/chat/completions',
      body: jsonEncode(mistralRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final mistralResponse = MistralChatResponse.fromJson(responseJson);

    // Map Mistral response to SDK format
    return _mapper.mapVideoAnalysisResponse(mistralResponse);
  }

  /// Gets the default model for this provider.
  ///
  /// Returns the default model configured in settings, or null if not set.
  String? get defaultModel => _defaultModel;

  /// Gets the base URL for API requests.
  ///
  /// Returns the configured base URL or the default Mistral AI API URL.
  String get baseUrl => _baseUrl;

  /// Gets the HTTP client wrapper (for testing purposes).
  ///
  /// This is exposed for testing but should not be used in production code.
  @visibleForTesting
  HttpClientWrapper get httpClient => _http;

  // ModelFetcher implementation

  @override
  Future<List<String>> fetchAvailableModels() async {
    try {
      final response = await _http.get('$_baseUrl/models');

      if (response.statusCode != 200) {
        // Return fallback models on error
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw AuthError(
            message: 'Failed to fetch models: Authentication failed',
            code: 'AUTH_FAILED',
            provider: id,
          );
        }
        return _fallbackModels;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      // Mistral API returns models in 'data' array (similar to OpenAI)
      final modelsList = data['data'] as List<dynamic>?;

      if (modelsList == null || modelsList.isEmpty) {
        return _fallbackModels;
      }

      // Extract model IDs and filter out unsupported models
      final models = modelsList
          .map((m) {
            // Handle both object format {id: "...", ...} and string format
            if (m is Map<String, dynamic>) {
              return m['id'] as String?;
            } else if (m is String) {
              return m;
            }
            return null;
          })
          .whereType<String>()
          .where((id) => _isSupportedModel(id))
          .toList();

      // Update capabilities cache
      if (models.isNotEmpty) {
        capabilities.updateModels(models);
      }

      return models.isEmpty ? _fallbackModels : models;
    } on AuthError {
      // Re-throw auth errors
      rethrow;
    } on Exception {
      // On any other error, return fallback models
      return _fallbackModels;
    }
  }

  @override
  String inferModelType(String modelId) {
    final lowerId = modelId.toLowerCase();

    // Chat/text models
    if (lowerId.contains('magistral') ||
        lowerId.contains('mistral-medium') ||
        lowerId.contains('mistral-small') ||
        lowerId.contains('mistral-large') ||
        lowerId.contains('codestral') ||
        lowerId.contains('devstral') ||
        lowerId.contains('pixtral') ||
        lowerId.contains('ministral') ||
        lowerId.contains('mistral-nemo')) {
      // Exclude embedding and audio models
      if (lowerId.contains('embed') ||
          lowerId.contains('voxtral') ||
          lowerId.contains('transcribe')) {
        // These are handled below
      } else {
        return 'text';
      }
    }

    // Embedding models
    if (lowerId.contains('embed')) {
      return 'embedding';
    }

    // Audio/STT models
    if (lowerId.contains('voxtral') || lowerId.contains('transcribe')) {
      return 'stt';
    }

    // OCR service
    if (lowerId.contains('ocr')) {
      return 'other';
    }

    // Moderation service
    if (lowerId.contains('moderation')) {
      return 'other';
    }

    // Default to text for unknown models
    return 'text';
  }

  /// Checks if a model ID is supported by this provider.
  ///
  /// Filters out deprecated or unsupported models.
  bool _isSupportedModel(String modelId) {
    final lowerId = modelId.toLowerCase();

    // Exclude deprecated models (based on Mistral docs)
    // These models are marked as deprecated/retired
    final deprecatedPatterns = [
      'mistral-7b-0',
      'mixtral-8x7b-0',
      'mixtral-8x22b-0',
      'mistral-saba',
      'mistral-next',
      'mathstral',
      'codestral-mamba',
    ];

    for (final pattern in deprecatedPatterns) {
      if (lowerId.contains(pattern)) {
        return false;
      }
    }

    // Include all other models that match known patterns
    return lowerId.contains('mistral') ||
        lowerId.contains('magistral') ||
        lowerId.contains('codestral') ||
        lowerId.contains('devstral') ||
        lowerId.contains('pixtral') ||
        lowerId.contains('ministral') ||
        lowerId.contains('voxtral') ||
        lowerId.contains('nemo');
  }
}
