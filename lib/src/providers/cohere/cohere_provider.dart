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
import '../../models/responses/embedding_response.dart';
import '../../models/responses/image_response.dart';
import '../../models/responses/transcription_response.dart';
import '../../models/responses/video_analysis_response.dart';
import '../../models/responses/video_response.dart';
import '../../models/responses/chat_stream_event.dart';
import '../../error/error_mapper.dart';
import '../../network/http_client_wrapper.dart';
import '../base/ai_provider.dart';
import '../base/model_fetcher.dart';
import '../base/provider_mapper.dart';
import '../base/rate_limiter_factory.dart';
import 'cohere_mapper.dart';
import 'cohere_models.dart';

/// Cohere provider implementation for the Unified AI SDK.
///
/// This provider integrates with Cohere's v2 API to provide:
/// - Chat completions (Command R, Command R+, Command A, etc.)
/// - Streaming chat responses
/// - Text embeddings (embed-english-v3.0, embed-multilingual-v3.0, etc.)
/// - Tokenization and detokenization
///
/// **Key Features:**
/// - Uses Cohere's v2 Chat API (`/v2/chat`) with full streaming support
/// - Uses Cohere's v2 Embed API (`/v2/embed`) with required embedding_types
/// - Supports tokenize/detokenize via v1 endpoints (`/v1/tokenize`, `/v1/detokenize`)
/// - Supports input_type parameter for optimized embeddings
/// - Supports multiple embedding types (float, int8, uint8, binary, ubinary)
/// - Uses API key authentication with Bearer token
/// - Supports v2 features: response_format, safety_mode, tool_choice, strict_tools, thinking, priority
///
/// **Example usage - Chat:**
/// ```dart
/// final config = ProviderConfig(
///   id: 'cohere',
///   auth: ApiKeyAuth(apiKey: 'co-...'),
///   settings: {
///     'defaultModel': 'command-r-plus',
///   },
/// );
///
/// final provider = CohereProvider();
/// await provider.init(config);
///
/// final response = await provider.chat(ChatRequest(
///   messages: [
///     Message(role: Role.user, content: 'Hello!'),
///   ],
/// ));
/// ```
///
/// **Example usage - Streaming:**
/// ```dart
/// final stream = provider.chatStream(ChatRequest(
///   messages: [
///     Message(role: Role.user, content: 'Tell me a story'),
///   ],
/// ));
///
/// await for (final event in stream) {
///   if (event.delta != null) {
///     print(event.delta);
///   }
///   if (event.done) {
///     print('Stream completed');
///   }
/// }
/// ```
///
/// **Example usage - Embeddings:**
/// ```dart
/// final response = await provider.embed(EmbeddingRequest(
///   inputs: ['Hello, world!', 'How are you?'],
///   providerOptions: {
///     'cohere': {
///       'input_type': 'search_document',
///       'embedding_types': ['float'],
///     },
///   },
/// ));
/// ```
///
/// **Example usage - Tokenization:**
/// ```dart
/// // Tokenize text
/// final tokenizeResponse = await provider.tokenize('Hello, world!');
/// print('Tokens: ${tokenizeResponse.tokens}');
///
/// // Detokenize tokens
/// final detokenizeResponse = await provider.detokenize(tokenizeResponse.tokens);
/// print('Text: ${detokenizeResponse.text}');
/// ```
class CohereProvider extends AiProvider implements ModelFetcher {
  /// Default base URL for Cohere API.
  static const String _defaultBaseUrl = 'https://api.cohere.com/v2';

  /// API key for authenticating requests.
  late final String _apiKey;

  /// HTTP client wrapper for making API requests.
  late final HttpClientWrapper _http;

  /// Base URL for API requests (can be overridden in settings).
  late final String _baseUrl;

  /// Default model to use when not specified in requests.
  String? _defaultModel;

  /// Mapper for converting between SDK and Cohere models.
  final ProviderMapper _mapper = CohereMapper.instance;

  /// Fallback models used when dynamic fetch is not available.
  ///
  /// These models are always available as a backup, ensuring the SDK works
  /// even when the API is unreachable or model fetching fails.
  ///
  /// **Chat Models (v2 compatible):**
  /// - command-a-03-2025: Latest Command A model
  /// - command-r-plus: High-performance chat model
  /// - command-r: Standard chat model
  ///
  /// **Embedding Models:**
  /// - embed-english-v3.0: High-quality English embeddings
  /// - embed-multilingual-v3.0: Multilingual embeddings
  /// - embed-english-light-v3.0: Faster, lighter English embeddings
  ///
  /// **Reference:**
  /// - Chat: https://docs.cohere.com/reference/chat
  /// - Embed: https://docs.cohere.com/reference/embed
  static const List<String> _fallbackModels = [
    'command-a-03-2025',
    'command-r-plus',
    'command-r',
    'embed-english-v3.0',
    'embed-multilingual-v3.0',
    'embed-english-light-v3.0',
    'embed-english-v2.0',
    'embed-multilingual-v2.0',
  ];

  /// Cached capabilities instance.
  ProviderCapabilities? _capabilities;

  @override
  String get id => 'cohere';

  @override
  String get name => 'Cohere';

  @override
  ProviderCapabilities get capabilities {
    _capabilities ??= ProviderCapabilities(
      supportsChat: true, // Cohere v2 supports chat via Command models
      supportsEmbedding: true, // Cohere's primary capability via v2 API
      supportsImageGeneration: false, // Cohere doesn't support image generation
      supportsTTS: false, // Not yet supported
      supportsSTT: false, // Not yet supported
      supportsStreaming: true, // Cohere v2 chat supports streaming
      fallbackModels: _fallbackModels,
      dynamicModels:
          true, // Cohere supports dynamic model fetching via /v1/models
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
            'Cohere provider requires ApiKeyAuth, got ${config.auth.runtimeType}',
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
    // Cohere uses Authorization: Bearer <api_key>
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

    // Fetch models dynamically during initialization
    // This ensures models are available immediately after init
    try {
      await fetchAvailableModels();
    } on Exception {
      // Silently fail - fallback models will be used
      // This allows the provider to work even if the models endpoint is unavailable
    }
  }

  // ModelFetcher implementation

  @override
  Future<List<String>> fetchAvailableModels() async {
    try {
      // Cohere models endpoint is on v1, not v2
      final v1BaseUrl = _baseUrl.replaceAll('/v2', '/v1');
      final response = await _http.get(
        '$v1BaseUrl/models',
        headers: {
          'accept': 'application/json',
        },
      );

      if (response.statusCode != 200) {
        // Return fallback models on error
        return _fallbackModels;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      // Cohere API returns models in a 'models' array
      final modelsList = data['models'] as List<dynamic>?;

      if (modelsList == null || modelsList.isEmpty) {
        return _fallbackModels;
      }

      // Extract model names/IDs
      final models = modelsList
          .map((m) {
            // Cohere models can be objects with 'name' field or just strings
            if (m is Map<String, dynamic>) {
              return m['name'] as String? ?? m['id'] as String?;
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

      // Return fetched models or fallback if empty
      return models.isEmpty ? _fallbackModels : models;
    } on Exception {
      // On any error, return fallback models
      return _fallbackModels;
    }
  }

  @override
  String inferModelType(String modelId) {
    // Cohere model naming patterns:
    // - Chat models: command-*, command-r*, command-a*
    // - Embedding models: embed-*

    final lowerId = modelId.toLowerCase();

    if (lowerId.contains('command')) {
      return 'text';
    }

    if (lowerId.contains('embed')) {
      return 'embedding';
    }

    // Default to text for unknown models (most Cohere models are text)
    return 'text';
  }

  /// Checks if a model ID is supported by this provider.
  ///
  /// Filters out deprecated or unsupported models.
  bool _isSupportedModel(String modelId) {
    final lowerId = modelId.toLowerCase();

    // Filter out deprecated models
    if (lowerId.contains('deprecated') || lowerId.contains('legacy')) {
      return false;
    }

    // Accept known model patterns
    if (lowerId.startsWith('command-') || lowerId.startsWith('embed-')) {
      return true;
    }

    // Accept any model that looks valid (alphanumeric, hyphens, underscores)
    return RegExp(r'^[a-z0-9_-]+$').hasMatch(lowerId);
  }

  @override
  Future<ChatResponse> chat(ChatRequest request) async {
    // Validate that chat is supported
    validateCapability('chat');

    // Map SDK request to Cohere format
    final cohereRequest = _mapper.mapChatRequest(
      request,
      defaultModel: _defaultModel,
    ) as CohereChatRequest;

    // Make HTTP POST request to chat endpoint
    final response = await _http.post(
      '$_baseUrl/chat',
      body: jsonEncode(cohereRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final cohereResponse = CohereChatResponse.fromJson(responseJson);

    // Map Cohere response to SDK format
    return _mapper.mapChatResponse(cohereResponse);
  }

  @override
  Stream<ChatStreamEvent> chatStream(ChatRequest request) async* {
    // Validate that streaming is supported
    validateCapability('streaming');

    // Map SDK request to Cohere format
    final cohereRequest = _mapper.mapChatRequest(
      request,
      defaultModel: _defaultModel,
    ) as CohereChatRequest;

    // Create streaming request with stream: true
    final requestJson = cohereRequest.toJson();
    final streamRequestJson = <String, dynamic>{
      ...requestJson,
      'stream': true,
    };

    try {
      // Make streaming HTTP POST request to v2/chat endpoint
      final byteStream = _http.postStream(
        '$_baseUrl/chat',
        body: streamRequestJson,
      );

      // Parse SSE (Server-Sent Events) format
      // Cohere v2 uses event types: message-start, content-start, content-delta, content-end, message-end
      // Format: "event: <type>\ndata: <json>"
      String buffer = '';
      Map<String, dynamic>? finalMetadata;
      String? messageId;
      String? currentEventType;

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

          // SSE format: "event: <type>" or "data: <json>"
          if (line.startsWith('event: ')) {
            currentEventType = line.substring(7).trim();
          } else if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();

            // Parse JSON data
            try {
              final eventJson = jsonDecode(data) as Map<String, dynamic>;

              // Get event type from JSON or from event line
              final eventType =
                  eventJson['type'] as String? ?? currentEventType;

              switch (eventType) {
                case 'message-start':
                  // Extract message ID
                  messageId = eventJson['id'] as String?;
                  if (messageId != null) {
                    finalMetadata ??= <String, dynamic>{};
                    finalMetadata['id'] = messageId;
                  }
                  break;

                case 'content-start':
                  // Content block starting - no delta yet, just initialization
                  break;

                case 'content-delta':
                  // Extract text delta from delta.message.content.text
                  final delta = eventJson['delta'] as Map<String, dynamic>?;
                  if (delta != null) {
                    final message = delta['message'] as Map<String, dynamic>?;
                    if (message != null) {
                      final content =
                          message['content'] as Map<String, dynamic>?;
                      if (content != null) {
                        final text = content['text'] as String?;
                        if (text != null && text.isNotEmpty) {
                          // Yield incremental text delta
                          yield ChatStreamEvent(
                            delta: text,
                            done: false,
                          );
                        }
                      }
                    }
                  }
                  break;

                case 'content-end':
                  // Content block ended - no action needed
                  break;

                case 'message-end':
                  // Final event with finish_reason and usage
                  final delta = eventJson['delta'] as Map<String, dynamic>?;
                  if (delta != null) {
                    // Extract finish_reason
                    final finishReason = delta['finish_reason'] as String?;
                    if (finishReason != null) {
                      finalMetadata ??= <String, dynamic>{};
                      finalMetadata['finish_reason'] = finishReason;
                    }

                    // Extract usage information
                    final usage = delta['usage'] as Map<String, dynamic>?;
                    if (usage != null) {
                      final tokens = usage['tokens'] as Map<String, dynamic>?;
                      final billedUnits =
                          usage['billed_units'] as Map<String, dynamic>?;

                      // Use tokens if available, otherwise use billed_units
                      final inputTokens = tokens?['input_tokens'] as int? ??
                          billedUnits?['input_tokens'] as int? ??
                          0;
                      final outputTokens = tokens?['output_tokens'] as int? ??
                          billedUnits?['output_tokens'] as int? ??
                          0;

                      finalMetadata ??= <String, dynamic>{};
                      finalMetadata['usage'] = {
                        'input_tokens': inputTokens,
                        'output_tokens': outputTokens,
                        'total_tokens': inputTokens + outputTokens,
                      };
                    }
                  }

                  // Yield final event
                  yield ChatStreamEvent(
                    delta: null,
                    done: true,
                    metadata: finalMetadata,
                  );
                  return;
              }
            } on Exception catch (_) {
              // Skip invalid JSON chunks (may be empty or malformed)
              continue;
            } finally {
              // Reset event type after processing
              currentEventType = null;
            }
          }
        }
      }

      // Yield final event if stream ends without message-end
      yield ChatStreamEvent(
        delta: null,
        done: true,
        metadata: finalMetadata,
      );
    } catch (e) {
      // Re-throw as appropriate error type
      if (e is Exception) {
        throw ErrorMapper.mapException(e, id);
      }
      rethrow;
    }
  }

  @override
  Future<EmbeddingResponse> embed(EmbeddingRequest request) async {
    // Validate that embedding is supported
    validateCapability('embed');

    // Map SDK request to Cohere format
    final cohereRequest = _mapper.mapEmbeddingRequest(
      request,
      defaultModel: _defaultModel,
    ) as CohereEmbeddingRequest;

    // Make HTTP POST request to embed endpoint
    final response = await _http.post(
      '$_baseUrl/embed',
      body: jsonEncode(cohereRequest.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    final cohereResponse = CohereEmbeddingResponse.fromJson(responseJson);

    // Map Cohere response to SDK format
    return _mapper.mapEmbeddingResponse(cohereResponse);
  }

  @override
  Future<ImageResponse> generateImage(ImageRequest request) async {
    // Cohere doesn't support image generation
    throw CapabilityError(
      message: 'Cohere API does not support image generation',
      code: 'UNSUPPORTED_CAPABILITY',
      provider: id,
    );
  }

  @override
  Future<AudioResponse> tts(TtsRequest request) async {
    // Not yet implemented
    throw UnimplementedError('tts() is not yet implemented for Cohere');
  }

  @override
  Future<TranscriptionResponse> stt(SttRequest request) async {
    // Not yet implemented
    throw UnimplementedError('stt() is not yet implemented for Cohere');
  }

  @override
  Future<VideoResponse> generateVideo(VideoRequest request) async {
    // Cohere doesn't support video generation
    throw CapabilityError(
      message: 'Cohere API does not support video generation',
      code: 'UNSUPPORTED_CAPABILITY',
      provider: id,
    );
  }

  @override
  Future<VideoAnalysisResponse> analyzeVideo(
      VideoAnalysisRequest request) async {
    // Cohere doesn't support video analysis
    throw CapabilityError(
      message: 'Cohere API does not support video analysis',
      code: 'UNSUPPORTED_CAPABILITY',
      provider: id,
    );
  }

  /// Gets the default model for this provider.
  ///
  /// Returns the default model configured in settings, or null if not set.
  String? get defaultModel => _defaultModel;

  /// Gets the base URL for API requests.
  ///
  /// Returns the configured base URL or the default Cohere API URL.
  String get baseUrl => _baseUrl;

  /// Tokenizes the input text into tokens using byte-pair encoding (BPE).
  ///
  /// Splits input text into smaller units called tokens. This is useful for
  /// understanding how text is processed by the model.
  ///
  /// **Parameters:**
  /// - [text]: The text to tokenize
  /// - [model]: Optional model identifier (uses default if not specified)
  ///
  /// **Returns:**
  /// A [CohereTokenizeResponse] containing the token IDs and optional token strings
  ///
  /// **Example:**
  /// ```dart
  /// final response = await provider.tokenize('Hello, world!');
  /// print('Tokens: ${response.tokens}');
  /// ```
  ///
  /// **Note:** This uses the v1 tokenize endpoint.
  Future<CohereTokenizeResponse> tokenize(String text, {String? model}) async {
    if (text.isEmpty) {
      throw ClientError(
        message: 'Text cannot be empty',
        code: 'INVALID_REQUEST',
      );
    }

    final request = CohereTokenizeRequest(
      text: text,
      model: model ?? _defaultModel,
    );

    // Tokenize endpoint is on v1, not v2
    final v1BaseUrl = _baseUrl.replaceAll('/v2', '/v1');
    final response = await _http.post(
      '$v1BaseUrl/tokenize',
      body: jsonEncode(request.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    return CohereTokenizeResponse.fromJson(responseJson);
  }

  /// Detokenizes a list of token IDs back into text.
  ///
  /// Converts tokens back into their text representation. This is the inverse
  /// operation of tokenize.
  ///
  /// **Parameters:**
  /// - [tokens]: List of token IDs to detokenize
  /// - [model]: Optional model identifier (uses default if not specified)
  ///
  /// **Returns:**
  /// A [CohereDetokenizeResponse] containing the detokenized text
  ///
  /// **Example:**
  /// ```dart
  /// final response = await provider.detokenize([1234, 5678, 9012]);
  /// print('Text: ${response.text}');
  /// ```
  ///
  /// **Note:** This uses the v1 detokenize endpoint.
  Future<CohereDetokenizeResponse> detokenize(List<int> tokens,
      {String? model}) async {
    if (tokens.isEmpty) {
      throw ClientError(
        message: 'Tokens cannot be empty',
        code: 'INVALID_REQUEST',
      );
    }

    final request = CohereDetokenizeRequest(
      tokens: tokens,
      model: model ?? _defaultModel,
    );

    // Detokenize endpoint is on v1, not v2
    final v1BaseUrl = _baseUrl.replaceAll('/v2', '/v1');
    final response = await _http.post(
      '$v1BaseUrl/detokenize',
      body: jsonEncode(request.toJson()),
    );

    // Check for HTTP errors
    if (response.statusCode != 200) {
      throw ErrorMapper.mapHttpError(response, id);
    }

    // Parse response JSON
    final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
    return CohereDetokenizeResponse.fromJson(responseJson);
  }

  /// Gets the HTTP client wrapper (for testing purposes).
  ///
  /// This is exposed for testing but should not be used in production code.
  @visibleForTesting
  HttpClientWrapper get httpClient => _http;
}
