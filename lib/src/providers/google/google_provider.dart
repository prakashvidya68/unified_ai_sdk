import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import '../../core/authentication.dart';
import '../../core/provider_config.dart';
import '../../error/ai_exception.dart';
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
import 'google_mapper.dart';
import 'google_models.dart';

/// Google Gemini provider implementation for the Unified AI SDK.
///
/// This provider integrates with Google's Gemini API to provide:
/// - Chat completions (Gemini 2.5 Pro, Gemini 2.5 Flash, etc.)
/// - Text embeddings (Gemini Embeddings)
/// - Image generation (Gemini 2.5 Flash Image, Imagen)
/// - Video generation (Veo 3.1)
/// - Video analysis (multimodal input)
/// - Streaming support for chat completions
///
/// **Key Features:**
/// - Supports both v1 and v1beta API versions
/// - Automatically fetches available models on initialization
/// - Uses Google's GenerateContent API (`/v1/models/{model}:generateContent`)
/// - Supports multimodal inputs (text, images, video) via message.meta
/// - Handles system instructions as separate field
/// - Uses API key authentication
/// - Supports Vertex AI integration (via baseUrl configuration)
///
/// **Example usage:**
/// ```dart
/// final config = ProviderConfig(
///   id: 'google',
///   auth: ApiKeyAuth(apiKey: 'AIza...'),
///   settings: {
///     'defaultModel': 'gemini-2.5-flash',
///     'baseUrl': 'https://generativelanguage.googleapis.com/v1beta', // Optional
///   },
/// );
///
/// final provider = GoogleProvider();
/// await provider.init(config);
///
/// final response = await provider.chat(ChatRequest(
///   messages: [
///     Message(role: Role.system, content: 'You are helpful.'),
///     Message(
///       role: Role.user,
///       content: 'What is in this image?',
///       meta: {
///         'images': [
///           {'mime_type': 'image/jpeg', 'data': 'base64...'},
///         ],
///       },
///     ),
///   ],
///   maxTokens: 1024,
/// ));
/// ```
class GoogleProvider extends AiProvider implements ModelFetcher {
  /// Default base URL for Google Gemini API (v1beta for latest features).
  static const String _defaultBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  /// API key for authenticating requests.
  late final String _apiKey;

  /// HTTP client wrapper for making API requests.
  late final HttpClientWrapper _http;

  /// Underlying HTTP client for multipart requests.
  late final http.Client _httpClient;

  /// Base URL for API requests (can be overridden in settings).
  late final String _baseUrl;

  /// API version detected from base URL ('v1' or 'v1beta').
  late final String _apiVersion;

  /// Default model to use when not specified in requests.
  String? _defaultModel;

  /// Google Cloud region for Vertex AI (if configured).
  /// Currently stored for potential future Vertex AI integration enhancements.
  // ignore: unused_field
  String? _region;

  /// Google Cloud project ID (if configured).
  /// Currently stored for potential future Vertex AI integration enhancements.
  // ignore: unused_field
  String? _project;

  /// Mapper for converting between SDK and Google models.
  final ProviderMapper _mapper = GoogleMapper.instance;

  /// Fallback models used when dynamic fetch is not available.
  ///
  /// These models are always available as a backup, ensuring the SDK works
  /// even when the API is unreachable or model fetching fails.
  ///
  /// **Latest Models (as of 2025):**
  /// - gemini-2.5-pro: Most powerful reasoning model
  /// - gemini-2.5-flash: Balanced model with 1M token context
  /// - gemini-2.5-flash-lite: Fastest and most cost-efficient
  /// - gemini-2.5-flash-image: Image generation model
  ///
  /// **Reference:**
  /// https://ai.google.dev/models/gemini
  static const List<String> _fallbackModels = [
    // Chat models - Latest Gemini 2.5 series
    'gemini-2.5-pro',
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    // Legacy chat models (for backward compatibility)
    'gemini-2.0-flash-exp',
    'gemini-1.5-pro',
    'gemini-1.5-flash',
    'gemini-pro',
    'gemini-pro-vision',
    // Embedding models
    'text-embedding-004',
    'text-embedding-3',
    'gemini-embedding-001',
    'textembedding-gecko@003',
    'textembedding-gecko@002',
    'textembedding-gecko-multilingual@001',
    // Image generation models
    'gemini-2.5-flash-image', // Native Gemini image generation
    // Imagen models (Vertex AI)
    'imagen-4.0-generate-001',
    'imagen-4.0-ultra-generate-001',
    'imagen-4.0-fast-generate-001',
    'imagen-3.0-generate-002',
    // Legacy Imagen models (Vertex AI format)
    'imagegeneration@006',
    'imagegeneration@005',
    // Video generation models (Veo)
    'veo-3.1',
    'veo-3',
    'video-generate@001',
  ];

  /// Cached capabilities instance.
  ProviderCapabilities? _capabilities;

  @override
  String get id => 'google';

  @override
  String get name => 'Google Gemini';

  @override
  ProviderCapabilities get capabilities {
    _capabilities ??= ProviderCapabilities(
      supportsChat: true,
      supportsEmbedding: true, // gemini-embedding-001
      supportsImageGeneration: true, // Imagen API
      supportsTTS: true, // Google TTS API
      supportsSTT: true, // Google STT API
      supportsVideoGeneration: true, // Veo 3.1
      supportsVideoAnalysis: true, // Multimodal input
      supportsStreaming: true, // Gemini supports streaming
      fallbackModels: _fallbackModels,
      dynamicModels: true, // Google supports model fetching via /v1beta/models
    );
    return _capabilities!;
  }

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

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
            'Google provider requires ApiKeyAuth, got ${config.auth.runtimeType}',
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
    // Supports both standard API and Vertex AI
    _baseUrl = config.settings['baseUrl'] as String? ?? _defaultBaseUrl;

    // Detect API version from base URL (v1 or v1beta)
    // This is used to adjust request/response structures if needed
    if (_baseUrl.contains('/v1beta')) {
      _apiVersion = 'v1beta';
    } else if (_baseUrl.contains('/v1')) {
      _apiVersion = 'v1';
    } else {
      // Default to v1beta if version cannot be determined
      _apiVersion = 'v1beta';
    }

    // Extract default model from settings
    _defaultModel = config.settings['defaultModel'] as String?;

    // Extract region and project for Vertex AI (if provided)
    _region = config.settings['region'] as String? ?? 'asia-east1';
    _project = config.settings['project'] as String?;

    // Build authentication headers
    // Google requires 'x-goog-api-key' header with the API key (no Bearer prefix)
    // We also support query parameter (?key=...) as a fallback
    // Always use x-goog-api-key header regardless of what user configured
    final authHeaders = {
      'x-goog-api-key': _apiKey,
      // Some Google endpoints require one of: Origin or X-Requested-With.
      // Adding X-Requested-With avoids CORS-related rejections in certain environments.
      'x-requested-with': 'unified_ai_sdk',
    };

    // Initialize HTTP client wrapper with authentication headers
    // Allow injecting custom client for testing via settings
    final customClient = config.settings['httpClient'] as http.Client?;
    _httpClient = customClient ?? http.Client();

    // Create rate limiter for this provider
    final rateLimiter = RateLimiterFactory.create(id, config.settings);

    _http = HttpClientWrapper(
      client: _httpClient,
      defaultHeaders: {
        ...authHeaders,
        'Content-Type': 'application/json',
      },
      rateLimiter: rateLimiter,
    );

    // Always fetch models during initialization
    // This ensures we have the latest available models
    try {
      await refreshModels();
    } on Exception {
      // If model fetching fails, log but don't fail initialization
      // Fallback models will be used instead
      // In production, you might want to log this to telemetry
      // For now, we silently continue with fallback models
    }
  }

  // ============================================================================
  // CHAT / TEXT COMPLETION
  // ============================================================================

  @override
  Future<ChatResponse> chat(ChatRequest request) async {
    // Validate that chat is supported
    validateCapability('chat');

    try {
      // Map SDK request to Google format
      final googleRequest = _mapper.mapChatRequest(
        request,
        defaultModel: _defaultModel,
      ) as GoogleChatRequest;

      // Determine model from request
      // Default to latest Gemini 2.5 Flash if not specified
      final model = googleRequest.model ??
          _defaultModel ??
          (_apiVersion == 'v1beta' ? 'gemini-2.5-flash' : 'gemini-1.5-flash');

      if (model.isEmpty) {
        throw ClientError(
          message:
              'Model is required. Either specify model in ChatRequest or provide defaultModel.',
          code: 'MISSING_MODEL',
          provider: id,
        );
      }

      // Validate that contents array is not empty
      if (googleRequest.contents.isEmpty) {
        throw ClientError(
          message: 'Chat request must contain at least one message',
          code: 'EMPTY_CONTENTS',
          provider: id,
        );
      }

      // Build request body (remove model from body, it goes in URL)
      final requestBody = googleRequest.toJson();
      requestBody.remove('model');

      // Build URL with model
      // Both v1 and v1beta use the same endpoint structure
      // API key is sent via header (x-goog-api-key) - do not include in query string
      final url = '$_baseUrl/models/$model:generateContent';

      // Make HTTP POST request
      final response = await _http.post(
        url,
        body: jsonEncode(requestBody),
      );

      // Check for HTTP errors
      if (response.statusCode != 200) {
        // Provide helpful error messages for 404 errors
        if (response.statusCode == 404) {
          throw ClientError(
            message: 'Model "$model" not found (404). This could mean:\n'
                '1. The model name is incorrect or deprecated\n'
                '2. The model is not available in your region\n'
                '3. The model requires billing to be enabled\n'
                '4. The API version ($_apiVersion) does not support this model\n\n'
                'Try using a different model like "gemini-2.5-flash" or "gemini-1.5-flash".\n'
                'Check available models: https://ai.google.dev/models/gemini',
            code: 'MODEL_NOT_FOUND',
            provider: id,
          );
        }
        throw ErrorMapper.mapHttpError(response, id);
      }

      // Parse response JSON
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final googleResponse = GoogleChatResponse.fromJson(responseJson);

      // Map Google response to SDK format
      final chatResponse = _mapper.mapChatResponse(googleResponse);

      // Update model name in response
      return ChatResponse(
        id: chatResponse.id,
        choices: chatResponse.choices,
        usage: chatResponse.usage,
        model: model, // Use the model from request
        provider: chatResponse.provider,
        timestamp: chatResponse.timestamp,
        metadata: chatResponse.metadata,
      );
    } on AiException {
      rethrow;
    } catch (e) {
      // Catch any unexpected errors and wrap them
      throw ClientError(
        message: 'Failed to generate chat response: ${e.toString()}',
        code: 'CHAT_ERROR',
        provider: id,
      );
    }
  }

  @override
  Stream<ChatStreamEvent> chatStream(ChatRequest request) async* {
    // Validate that streaming is supported
    validateCapability('streaming');

    try {
      // Map SDK request to Google format
      final googleRequest = _mapper.mapChatRequest(
        request,
        defaultModel: _defaultModel,
      ) as GoogleChatRequest;

      // Determine model from request
      // Default to latest Gemini 2.5 Flash if not specified
      final model = googleRequest.model ??
          _defaultModel ??
          (_apiVersion == 'v1beta' ? 'gemini-2.5-flash' : 'gemini-1.5-flash');

      if (model.isEmpty) {
        throw ClientError(
          message:
              'Model is required. Either specify model in ChatRequest or provide defaultModel.',
          code: 'MISSING_MODEL',
          provider: id,
        );
      }

      // Build request body (remove model from body, it goes in URL)
      final requestBody = googleRequest.toJson();
      requestBody.remove('model');

      // Enable streaming for Google Gemini API
      // Use Server-Sent Events via the alt=sse query parameter
      // Both v1 and v1beta use the same streaming endpoint structure
      // API key is sent via header (x-goog-api-key) - do not include in query string
      final url = '$_baseUrl/models/$model:streamGenerateContent?alt=sse';

      // Make streaming HTTP POST request
      final byteStream = _http.postStream(
        url,
        body: requestBody,
      );

      // --- SSE Parsing Logic ---
      String buffer = '';
      Map<String, dynamic>? finalMetadata;

      await for (final chunk in byteStream) {
        // Convert bytes to string and append to buffer
        buffer += utf8.decode(chunk, allowMalformed: true);

        // Process complete lines (ending with \n)
        while (true) {
          final newlineIndex = buffer.indexOf('\n');
          if (newlineIndex == -1) {
            // No complete line yet, wait for more data
            break;
          }

          // Extract the line
          final line = buffer.substring(0, newlineIndex);
          buffer = buffer.substring(newlineIndex + 1);

          final trimmedLine = line.trim();

          // SSE format: ignore comments (starting with ':'), 'event:', 'id:'
          // We only care about 'data:' lines and the final blank line.

          // 1. Process 'data:' line
          if (trimmedLine.startsWith('data:')) {
            final int colonIndex = trimmedLine.indexOf(':');
            var payload = trimmedLine.substring(colonIndex + 1);
            if (payload.startsWith(' ')) payload = payload.substring(1);

            // Payload '[DONE]' signifies stream end (sometimes sent as data)
            if (payload == '[DONE]') {
              continue; // Will be handled by the empty line/stream end
            }

            try {
              // Gemini chunks can be a single object or an array of objects
              final parsed = jsonDecode(payload);
              List<Map<String, dynamic>> chunks;

              if (parsed is List) {
                chunks = parsed.cast<Map<String, dynamic>>();
              } else if (parsed is Map<String, dynamic>) {
                chunks = [parsed];
              } else {
                continue; // Skip if it's not a recognizable format
              }

              for (final chunkJson in chunks) {
                final result = _processChunk(chunkJson, model, finalMetadata);
                final events = result.key;
                final metadataResult = result.value;
                finalMetadata = metadataResult.value;

                for (final event in events) {
                  yield event;
                }

                // If _processChunk detected a final chunk (finishReason), we return
                if (metadataResult.key) {
                  return;
                }
              }
            } on FormatException {
              // This is the source of the common error. If it fails to parse,
              // it means the 'data' payload was incomplete or malformed.
              // In standard Gemini SSE, each 'data' line is a complete chunk JSON.
              // If we suspect multi-line data, we would need to buffer.
              // For now, we stick to the single-line-per-data-event pattern.
              continue; // Skip malformed JSON line
            }
            continue;
          }

          // 2. Process final blank line (end of an SSE event, though Gemini often
          // sends one JSON object per 'data:' line anyway)
          if (trimmedLine.isEmpty) {
            // In the Google Gemini stream, a single `data:` line is usually a complete
            // GenerateContentResponse chunk, so we don't need the sseEventBuffer
            // accumulation logic for multi-line data: events typically found in
            // other SSE standards. We rely on the processing inside the 'data:' block.
            continue;
          }

          // 3. Handle [DONE] if sent as a standalone event or comment
          if (trimmedLine == '[DONE]' || trimmedLine == 'data: [DONE]') {
            // Final explicit done signal
            yield ChatStreamEvent(
              delta: null,
              done: true,
              metadata: finalMetadata,
            );
            return;
          }

          // Ignore other SSE fields (event:, id:, etc.) or comments (:)
        }
      }

      // After stream ends (e.g., connection closed), check buffer for any remaining data
      if (buffer.trim().isNotEmpty) {
        // If there is unparsed data remaining in the buffer, it's likely incomplete
        // and we cannot rely on it being a final chunk. We ignore it and yield the final event.
      }

      // If the stream ends without an explicit finishReason/done=true event,
      // we yield the final event to close the stream for the consumer.
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

  /// Extracts complete JSON objects from an incomplete array string.
  ///
  /// This method tries to find and extract complete JSON objects from a string
  /// that might be an incomplete JSON array. It uses bracket/brace counting to
  /// identify complete objects.
  ///
  /// **Note:** Currently unused but kept for potential future streaming improvements.
  // ignore: unused_element
  List<String> _extractCompleteObjectsFromArray(String arrayString) {
    final List<String> objects = [];
    int depth = 0;
    int objectStart = -1;
    bool inString = false;
    bool escapeNext = false;

    // Skip the opening bracket
    int start = 0;
    if (arrayString.trim().startsWith('[')) {
      start = arrayString.indexOf('[') + 1;
    }

    for (int i = start; i < arrayString.length; i++) {
      final char = arrayString[i];

      if (escapeNext) {
        escapeNext = false;
        continue;
      }

      if (char == '\\') {
        escapeNext = true;
        continue;
      }

      if (char == '"' && !escapeNext) {
        inString = !inString;
        continue;
      }

      if (inString) continue;

      if (char == '{') {
        if (depth == 0) {
          objectStart = i;
        }
        depth++;
      } else if (char == '}') {
        depth--;
        if (depth == 0 && objectStart != -1) {
          // Found a complete object
          final objectJson = arrayString.substring(objectStart, i + 1);
          objects.add(objectJson);
          objectStart = -1;
        }
      }
    }

    return objects;
  }

  /// Gets the remaining incomplete array data after extracting complete objects.
  ///
  /// Returns the remaining string that should be kept in the buffer.
  ///
  /// **Note:** Currently unused but kept for potential future streaming improvements.
  // ignore: unused_element
  String _getRemainingArrayData(String arrayString, List<String> extracted) {
    if (extracted.isEmpty) {
      return arrayString;
    }

    // Find where the last extracted object ends
    int lastEnd = -1;
    for (final obj in extracted) {
      final index = arrayString.indexOf(obj, lastEnd + 1);
      if (index != -1) {
        lastEnd = index + obj.length;
      }
    }

    if (lastEnd == -1) {
      return arrayString;
    }

    // Get everything after the last complete object
    String remaining = arrayString.substring(lastEnd).trim();

    // Remove trailing comma if present
    if (remaining.startsWith(',')) {
      remaining = remaining.substring(1).trim();
    }

    // If we have remaining data, wrap it back in array brackets if needed
    if (remaining.isNotEmpty && !remaining.startsWith('[')) {
      remaining = '[' + remaining;
    }
    if (remaining.isNotEmpty && !remaining.endsWith(']')) {
      // Don't add closing bracket yet - it might be incomplete
    }

    return remaining;
  }

  /// Processes a single chunk and returns events to yield.
  ///
  /// Returns a tuple: (eventsToYield, shouldReturn, updatedMetadata)
  /// - eventsToYield: list of events to yield (may be empty)
  /// - shouldReturn: true if the stream should end (finishReason was found)
  /// - updatedMetadata: the updated metadata (or null if unchanged)
  MapEntry<List<ChatStreamEvent>, MapEntry<bool, Map<String, dynamic>?>>
      _processChunk(
    Map<String, dynamic> chunkJson,
    String model,
    Map<String, dynamic>? currentMetadata,
  ) {
    String? contentDelta;
    bool isDone = false;
    Map<String, dynamic>? updatedMetadata = currentMetadata;
    final List<ChatStreamEvent> events = [];

    // Extract candidates array
    final candidates = chunkJson['candidates'] as List<dynamic>?;
    if (candidates != null && candidates.isNotEmpty) {
      final candidate = candidates[0] as Map<String, dynamic>;
      final content = candidate['content'] as Map<String, dynamic>?;

      if (content != null) {
        final parts = content['parts'] as List<dynamic>?;
        if (parts != null && parts.isNotEmpty) {
          final part = parts[0] as Map<String, dynamic>;
          contentDelta = part['text'] as String?;
        }
      }

      // Check finish reason to determine if stream is done
      // Google uses finishReason values: STOP, MAX_TOKENS, SAFETY, RECITATION, etc.
      final finishReason = candidate['finishReason'] as String?;
      if (finishReason != null) {
        // If finishReason is present, this is the final chunk
        isDone = true;
      }
    }

    // Extract usage metadata if present (may be in each chunk or final chunk)
    final usageMetadata = chunkJson['usageMetadata'] as Map<String, dynamic>?;
    if (usageMetadata != null) {
      // Update metadata
      updatedMetadata = {
        'usage': {
          'prompt_tokens': usageMetadata['promptTokenCount'] as int?,
          'completion_tokens': usageMetadata['candidatesTokenCount'] as int?,
          'total_tokens': usageMetadata['totalTokenCount'] as int?,
        },
        'model': chunkJson['modelVersion'] as String? ?? model,
        'response_id': chunkJson['responseId'] as String?,
      };
    }

    // Create event with content delta if there's text
    if (contentDelta != null) {
      events.add(ChatStreamEvent(
        delta: contentDelta,
        done: false,
      ));
    }

    // If this is the final chunk, add done event
    if (isDone) {
      events.add(ChatStreamEvent(
        delta: null,
        done: true,
        metadata: updatedMetadata,
      ));
    }

    return MapEntry(events, MapEntry(isDone, updatedMetadata));
  }

  // ============================================================================
  // EMBEDDINGS / TEXT TO VECTOR
  // ============================================================================

  @override
  Future<EmbeddingResponse> embed(EmbeddingRequest request) async {
    // Validate that embedding is supported
    validateCapability('embed');

    try {
      // Map SDK request to Google format
      final googleRequest = _mapper.mapEmbeddingRequest(
        request,
        defaultModel: _defaultModel,
      ) as GoogleEmbeddingRequest;

      // Determine model from request
      // Default to text-embedding-004 (latest) or gemini-embedding-001
      final model = googleRequest.model ??
          _defaultModel ??
          (_apiVersion == 'v1beta'
              ? 'text-embedding-004'
              : 'text-embedding-004');

      if (model.isEmpty) {
        throw ClientError(
          message:
              'Model is required. Either specify model in EmbeddingRequest or provide defaultModel.',
          code: 'MISSING_MODEL',
          provider: id,
        );
      }

      // Build URL with model
      // Both v1 and v1beta use the same embedContent endpoint structure
      // API key is sent via header (x-goog-api-key) - do not include in query string
      final url = '$_baseUrl/models/$model:embedContent';

      // Build request body (remove model from body, it goes in URL)
      final requestBody = googleRequest.toJson();
      requestBody.remove('model');

      // Make HTTP POST request
      final response = await _http.post(
        url,
        body: jsonEncode(requestBody),
      );

      // Check for HTTP errors
      if (response.statusCode != 200) {
        throw ErrorMapper.mapHttpError(response, id);
      }

      // Parse response JSON
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final googleResponse = GoogleEmbeddingResponse.fromJson(responseJson);

      // Map Google response to SDK format
      return _mapper.mapEmbeddingResponse(googleResponse);
    } on AiException {
      rethrow;
    } catch (e) {
      // Catch any unexpected errors and wrap them
      throw ClientError(
        message: 'Failed to generate embeddings: ${e.toString()}',
        code: 'EMBEDDING_ERROR',
        provider: id,
      );
    }
  }

  // ============================================================================
  // IMAGE GENERATION / TEXT TO IMAGE
  // ============================================================================

  @override
  Future<ImageResponse> generateImage(ImageRequest request) async {
    // Validate that image generation is supported
    validateCapability('image');

    try {
      // Map SDK request to Google format
      final googleRequest = _mapper.mapImageRequest(
        request,
        defaultModel: _defaultModel,
      ) as GoogleImageRequest;

      // Determine model from request
      // Default to Gemini 2.5 Flash Image (native Gemini image generation)
      final model = googleRequest.model ??
          _defaultModel ??
          (_apiVersion == 'v1beta'
              ? 'gemini-2.5-flash-image'
              : 'imagen-4.0-generate-001');

      if (model.isEmpty) {
        throw ClientError(
          message:
              'Model is required. Either specify model in ImageRequest or provide defaultModel.',
          code: 'MISSING_MODEL',
          provider: id,
        );
      }

      // --- Model Classification ---
      final lowerModel = model.toLowerCase();
      // Models like 'gemini-2.5-flash-image', 'gemini-2.0-flash-exp-image-generation'
      final isGeminiImageModel =
          lowerModel.contains('image') && lowerModel.startsWith('gemini-');
      // Models like 'imagen-4.0-generate-001', 'imagegeneration@006'
      final isImagenModel = lowerModel.startsWith('imagen-') ||
          lowerModel.startsWith('imagegeneration@');

      String url;
      Map<String, dynamic> requestBody;

      // --- Endpoint Selection Logic ---
      if (isGeminiImageModel) {
        // 1. Use the :generateContent endpoint for native Gemini image models
        // Reference: https://ai.google.dev/gemini-api/docs/image-generation
        // Models like 'gemini-2.5-flash-image' use this endpoint
        // Both v1 and v1beta support this endpoint
        // API key is sent via header (x-goog-api-key) - do not include in query string
        url = '$_baseUrl/models/$model:generateContent';

        // Build request body according to official Gemini API documentation
        // Format: { "contents": [...], "generationConfig": { "imageConfig": {...}, "responseModalities": ["Image"] } }
        // Reference: https://ai.google.dev/gemini-api/docs/image-generation
        final Map<String, dynamic> generationConfig = {};

        // Add imageConfig with aspectRatio if provided
        if (googleRequest.aspectRatio != null) {
          generationConfig['imageConfig'] = {
            'aspectRatio': googleRequest.aspectRatio,
          };
        }

        // Explicitly request image output modality
        generationConfig['responseModalities'] = ['Image'];

        requestBody = {
          'contents': [
            {
              'parts': [
                {
                  'text': googleRequest.prompt,
                }
              ]
            }
          ],
          if (generationConfig.isNotEmpty) 'generationConfig': generationConfig,
        };
      } else if (isImagenModel) {
        // 2. Imagen models use the :predict endpoint
        // They work with both standard Gemini API base URL and Vertex AI base URL
        // Format: https://generativelanguage.googleapis.com/v1beta/models/{model}:predict
        // Request format: { "instances": [{"prompt": "..."}], "parameters": {...} }
        // API key is sent via header (x-goog-api-key) - do not include in query string
        url = '$_baseUrl/models/$model:predict';

        // Build request body in Imagen format
        // The GoogleImageRequest.toJson() already returns the correct format:
        // { "instances": [{"prompt": "..."}], "parameters": {...} }
        requestBody = googleRequest.toJson();
        requestBody.remove('model');
      } else {
        // 3. Fallback for unexpected or legacy image models
        throw ClientError(
          message:
              'Model $model is not a recognized Gemini Image or Imagen model '
              'and cannot be used for image generation on this endpoint.',
          code: 'UNSUPPORTED_IMAGE_MODEL',
          provider: id,
        );
      }

      // Make HTTP POST request
      final response = await _http.post(
        url,
        body: jsonEncode(requestBody),
      );

      // Check for HTTP errors
      if (response.statusCode != 200) {
        // Provide specific error messages for Gemini image models
        if (isGeminiImageModel) {
          if (response.statusCode == 404) {
            throw ClientError(
              message: 'Model $model returned HTTP 404. This may indicate:\n'
                  '1. The model is not available in your region\n'
                  '2. The model name is incorrect\n'
                  '3. Your API key does not have access to this model\n\n'
                  'For Gemini image generation, ensure you are using models like:\n'
                  '- gemini-2.5-flash-image\n'
                  '- gemini-2.0-flash-exp-image-generation\n\n'
                  'Alternatively, consider using Imagen models (e.g., imagen-4.0-generate-001) '
                  'which are accessed via the :predict endpoint.\n\n'
                  'Reference: https://ai.google.dev/gemini-api/docs/image-generation',
              code: 'MODEL_NOT_FOUND',
              provider: id,
            );
          } else if (response.statusCode == 400) {
            // 400 errors indicate invalid request format
            final errorBody = response.body;
            throw ClientError(
              message:
                  'Invalid request format for model $model. Please check:\n'
                  '1. The request uses the correct format: {"contents": [...], "generationConfig": {"imageConfig": {...}, "responseModalities": ["Image"]}}\n'
                  '2. The model name is correct and available in your region\n'
                  '3. Your API key has access to image generation models\n\n'
                  'For reference, see: https://ai.google.dev/gemini-api/docs/image-generation\n\n'
                  'If issues persist, consider using Imagen models (e.g., imagen-4.0-generate-001) '
                  'which use the :predict endpoint.\n\n'
                  'Error details: ${errorBody.length > 200 ? errorBody.substring(0, 200) + "..." : errorBody}',
              code: 'INVALID_IMAGE_GENERATION_REQUEST',
              provider: id,
            );
          }
        }
        throw ErrorMapper.mapHttpError(response, id);
      }

      // Parse response JSON
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;

      // Map Google response to SDK format
      // Handle both :generateContent (Gemini native) and :predict (Imagen) formats
      // Reference: https://ai.google.dev/gemini-api/docs/image-generation
      if (isGeminiImageModel) {
        // Gemini image models return responses in the same format as chat responses
        // with image data in candidates[].content.parts[].inline_data.data
        if (responseJson['candidates'] != null) {
          return (_mapper as GoogleMapper).mapGeminiImageResponse(
            responseJson,
            model,
          );
        }
        // If no candidates, throw an error
        throw ClientError(
          message: 'Invalid response format from Gemini image model $model. '
              'Expected response with "candidates" array containing image data.',
          code: 'INVALID_RESPONSE_FORMAT',
          provider: id,
        );
      } else {
        final googleResponse = GoogleImageResponse.fromJson(responseJson);
        return _mapper.mapImageResponse(googleResponse);
      }
    } on AiException {
      rethrow;
    } catch (e) {
      // Catch any unexpected errors and wrap them
      throw ClientError(
        message: 'Failed to generate image: ${e.toString()}',
        code: 'IMAGE_GENERATION_ERROR',
        provider: id,
      );
    }
  }

  // ============================================================================
  // TEXT TO SPEECH (TTS)
  // ============================================================================

  @override
  Future<AudioResponse> tts(TtsRequest request) async {
    // Validate that TTS is supported
    validateCapability('tts');

    try {
      // Map SDK request to Google format
      final googleRequest = _mapper.mapTtsRequest(
        request,
        defaultModel: _defaultModel,
      ) as GoogleTtsRequest;

      // Note: Gemini API does not have native TTS support
      // This implementation uses Google Cloud Text-to-Speech API endpoint
      // The endpoint structure is compatible with both v1 and v1beta base URLs
      // For Gemini API base URLs, this may not work - users should use Google Cloud TTS API directly
      // API key is sent via header (x-goog-api-key) - do not include in query string
      final url = '$_baseUrl/text:synthesize';

      // Make HTTP POST request
      final response = await _http.post(
        url,
        body: jsonEncode(googleRequest.toJson()),
      );

      // Check for HTTP errors
      if (response.statusCode != 200) {
        throw ErrorMapper.mapHttpError(response, id);
      }

      // Parse response JSON (Google TTS returns JSON with base64 audio)
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final audioBase64 = responseJson['audioContent'] as String?;

      if (audioBase64 == null) {
        throw ClientError(
          message: 'Invalid TTS response: missing audioContent',
          code: 'INVALID_RESPONSE',
          provider: id,
        );
      }

      // Decode base64 audio
      final audioBytes = base64Decode(audioBase64);

      // Map Google response to SDK format
      return _mapper.mapTtsResponse(response, audioBytes, request);
    } on AiException {
      rethrow;
    } catch (e) {
      // Catch any unexpected errors and wrap them
      throw ClientError(
        message: 'Failed to generate speech: ${e.toString()}',
        code: 'TTS_ERROR',
        provider: id,
      );
    }
  }

  // ============================================================================
  // SPEECH TO TEXT (STT)
  // ============================================================================

  @override
  Future<TranscriptionResponse> stt(SttRequest request) async {
    // Validate that STT is supported
    validateCapability('stt');

    try {
      // Map SDK request to Google format
      final googleRequest = _mapper.mapSttRequest(
        request,
        defaultModel: _defaultModel,
      ) as GoogleSttRequest;

      // Note: Gemini API does not have native STT support
      // This implementation uses Google Cloud Speech-to-Text API endpoint
      // The endpoint structure is compatible with both v1 and v1beta base URLs
      // For Gemini API base URLs, this may not work - users should use Google Cloud Speech API directly
      // API key is sent via header (x-goog-api-key) - do not include in query string
      final url = '$_baseUrl/speech:recognize';

      // Google STT requires multipart/form-data for audio
      final multipartRequest = http.MultipartRequest('POST', Uri.parse(url));

      // Add authentication headers
      final authHeaders = _http.defaultHeaders;
      multipartRequest.headers.addAll(authHeaders);

      // Add form fields
      final formFields = googleRequest.toFormFields();
      multipartRequest.fields.addAll(
        formFields.map((key, value) => MapEntry(key, value.toString())),
      );

      // Add audio file
      multipartRequest.files.add(
        http.MultipartFile.fromBytes(
          'audio',
          googleRequest.audio,
          filename: 'audio.wav',
        ),
      );

      // Send the request using the underlying client
      final streamedResponse = await _httpClient.send(multipartRequest);
      final response = await http.Response.fromStream(streamedResponse);

      // Check for HTTP errors
      if (response.statusCode != 200) {
        throw ErrorMapper.mapHttpError(response, id);
      }

      // Parse response JSON
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;

      // Map Google response to SDK format
      return _mapper.mapSttResponse(responseJson, request);
    } on AiException {
      rethrow;
    } catch (e) {
      // Catch any unexpected errors and wrap them
      throw ClientError(
        message: 'Failed to transcribe speech: ${e.toString()}',
        code: 'STT_ERROR',
        provider: id,
      );
    }
  }

  // ============================================================================
  // VIDEO GENERATION / TEXT TO VIDEO
  // ============================================================================

  @override
  Future<VideoResponse> generateVideo(VideoRequest request) async {
    // Validate that video generation is supported
    validateCapability('video');

    try {
      // Map SDK request to Google format
      final googleRequest = _mapper.mapVideoRequest(
        request,
        defaultModel: _defaultModel,
      ) as GoogleVideoRequest;

      // Determine model from request
      // Default to Veo 3.1 (latest video generation model)
      final model = googleRequest.model ??
          _defaultModel ??
          (_apiVersion == 'v1beta' ? 'veo-3.1' : 'veo-3');

      if (model.isEmpty) {
        throw ClientError(
          message:
              'Model is required. Either specify model in VideoRequest or provide defaultModel.',
          code: 'MISSING_MODEL',
          provider: id,
        );
      }

      // Build URL with model
      // Both v1 and v1beta use the same generateVideo endpoint structure
      // API key is sent via header (x-goog-api-key) - do not include in query string
      final url = '$_baseUrl/models/$model:generateVideo';

      // Build request body (remove model from body, it goes in URL)
      final requestBody = googleRequest.toJson();
      requestBody.remove('model');

      // Make HTTP POST request
      final response = await _http.post(
        url,
        body: jsonEncode(requestBody),
      );

      // Check for HTTP errors
      if (response.statusCode != 200) {
        throw ErrorMapper.mapHttpError(response, id);
      }

      // Parse response JSON
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final googleResponse = GoogleVideoResponse.fromJson(responseJson);

      // Map Google response to SDK format
      return _mapper.mapVideoResponse(googleResponse);
    } on AiException {
      rethrow;
    } catch (e) {
      // Catch any unexpected errors and wrap them
      throw ClientError(
        message: 'Failed to generate video: ${e.toString()}',
        code: 'VIDEO_GENERATION_ERROR',
        provider: id,
      );
    }
  }

  // ============================================================================
  // VIDEO ANALYSIS
  // ============================================================================

  @override
  Future<VideoAnalysisResponse> analyzeVideo(
      VideoAnalysisRequest request) async {
    // Validate that video analysis is supported
    validateCapability('videoAnalysis');

    try {
      // Google video analysis uses Gemini's multimodal capabilities
      // We'll use the chat API with video content (inline_data or file_data)
      final googleRequest = _mapper.mapVideoAnalysisRequest(
        request,
        defaultModel: _defaultModel,
      ) as GoogleVideoAnalysisRequest;

      // Determine model from request (use vision-capable model)
      // Default to Gemini 2.5 Pro or Gemini 1.5 Pro for video analysis
      final model = googleRequest.model ??
          _defaultModel ??
          (_apiVersion == 'v1beta' ? 'gemini-2.5-pro' : 'gemini-1.5-pro');

      if (model.isEmpty) {
        throw ClientError(
          message:
              'Model is required. Either specify model in VideoAnalysisRequest or provide defaultModel.',
          code: 'MISSING_MODEL',
          provider: id,
        );
      }

      // Build URL with model
      // Both v1 and v1beta use the same generateContent endpoint for multimodal input
      // API key is sent via header (x-goog-api-key) - do not include in query string
      final url = '$_baseUrl/models/$model:generateContent';

      // Build request body (remove model from body, it goes in URL)
      final requestBody = googleRequest.toJson();
      requestBody.remove('model');

      // Make HTTP POST request
      final response = await _http.post(
        url,
        body: jsonEncode(requestBody),
      );

      // Check for HTTP errors
      if (response.statusCode != 200) {
        throw ErrorMapper.mapHttpError(response, id);
      }

      // Parse response JSON
      final responseJson = jsonDecode(response.body) as Map<String, dynamic>;
      final googleResponse = GoogleVideoAnalysisResponse.fromJson(responseJson);

      // Map Google response to SDK format
      return _mapper.mapVideoAnalysisResponse(googleResponse);
    } on AiException {
      rethrow;
    } catch (e) {
      // Catch any unexpected errors and wrap them
      throw ClientError(
        message: 'Failed to analyze video: ${e.toString()}',
        code: 'VIDEO_ANALYSIS_ERROR',
        provider: id,
      );
    }
  }

  /// Gets the default model for this provider.
  ///
  /// Returns the default model configured in settings, or null if not set.
  String? get defaultModel => _defaultModel;

  /// Gets the base URL for API requests.
  ///
  /// Returns the configured base URL or the default Google API URL.
  String get baseUrl => _baseUrl;

  /// Gets the HTTP client wrapper (for testing purposes).
  ///
  /// This is exposed for testing but should not be used in production code.
  @visibleForTesting
  HttpClientWrapper get httpClient => _http;

  // ============================================================================
  // MODEL FETCHING
  // ============================================================================

  @override
  Future<List<String>> fetchAvailableModels() async {
    try {
      // Google's models endpoint: /v1beta/models or /v1/models
      // Both v1 and v1beta support the same models endpoint structure
      final baseModelsUrl = '$_baseUrl/models';

      final List<String> allModels = [];
      String? nextPageToken;

      do {
        // Build URL with pagination token if available
        // Note: API key is sent via x-goog-api-key header (already configured in _http)
        // Do not include in query string
        final url = nextPageToken != null
            ? '$baseModelsUrl?pageToken=$nextPageToken'
            : baseModelsUrl;

        final response = await _http.get(url);

        // Check for HTTP errors
        if (response.statusCode != 200) {
          // If authentication fails, throw error instead of silently falling back
          if (response.statusCode == 401 || response.statusCode == 403) {
            throw AuthError(
              message: 'Failed to fetch models: Authentication failed',
              code: 'AUTH_FAILED',
              provider: id,
            );
          }
          // For other errors, return fallback models
          return _fallbackModels;
        }

        // Parse response JSON
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final modelsList = data['models'] as List<dynamic>?;

        if (modelsList == null || modelsList.isEmpty) {
          // If no models returned, use fallback
          return _fallbackModels;
        }

        // Extract model names and clean them up
        // Google returns names like "models/gemini-pro", we want just "gemini-pro"
        final models = modelsList
            .map((m) {
              final modelData = m as Map<String, dynamic>;
              final name = modelData['name'] as String?;
              if (name == null) return null;

              // Remove "models/" prefix if present
              if (name.startsWith('models/')) {
                return name.substring(7);
              }
              return name;
            })
            .whereType<String>()
            .where((id) => _isSupportedModel(id))
            .toList();

        allModels.addAll(models);

        // Check for pagination
        nextPageToken = data['nextPageToken'] as String?;
      } while (nextPageToken != null);

      // Update capabilities cache if we got models
      // Access capabilities getter to ensure it's initialized, then update
      if (allModels.isNotEmpty) {
        capabilities.updateModels(allModels);
      }

      // Return fetched models or fallback if empty
      return allModels.isEmpty ? _fallbackModels : allModels;
    } on AuthError {
      // Re-throw auth errors
      rethrow;
    } on Exception {
      // On any other error, return fallback models
      // In production, you might want to log this error
      return _fallbackModels;
    }
  }

  @override
  String inferModelType(String modelId) {
    final lowerId = modelId.toLowerCase();

    // Chat/text models - Gemini series (including Gemini 2.5)
    if (lowerId.startsWith('gemini-')) {
      // Exclude embedding models
      if (lowerId.contains('embedding')) {
        return 'embedding';
      }
      // Gemini image models (e.g., gemini-2.5-flash-image)
      if (lowerId.contains('image')) {
        return 'image';
      }
      // Vision models are still text models (multimodal)
      if (lowerId.contains('vision') || lowerId.contains('pro-vision')) {
        return 'text';
      }
      // All other Gemini models are text/chat models
      return 'text';
    }

    // Embedding models
    if (lowerId.contains('embedding') ||
        lowerId.startsWith('text-embedding') ||
        lowerId.startsWith('textembedding-gecko')) {
      return 'embedding';
    }

    // Image generation models (Imagen)
    if (lowerId.startsWith('imagegeneration@') ||
        lowerId.startsWith('imagen-')) {
      return 'image';
    }

    // Video generation models (Veo)
    if (lowerId.startsWith('veo-') || lowerId.startsWith('video-generate@')) {
      return 'video';
    }

    // TTS models
    if (lowerId.contains('tts') || lowerId.startsWith('tts-')) {
      return 'tts';
    }

    // STT models
    if (lowerId.contains('stt') ||
        lowerId.contains('speech') ||
        lowerId.startsWith('whisper-')) {
      return 'stt';
    }

    return 'other';
  }

  /// Checks if a model ID should be included in the supported models list.
  ///
  /// Filters out deprecated, internal, or unsupported models.
  bool _isSupportedModel(String modelId) {
    final lowerId = modelId.toLowerCase();

    // Filter out:
    // - Models with @latest or @001 suffixes (these are versioned, prefer base name)
    // - Internal or test models
    // - Deprecated models
    if (lowerId.contains('@latest')) {
      // Prefer the base model name over @latest
      return false;
    }

    // Include known model patterns
    // Gemini models (including 2.5 series)
    if (lowerId.startsWith('gemini-')) {
      return true;
    }
    // Embedding models
    if (lowerId.startsWith('text-embedding') ||
        lowerId.startsWith('textembedding-gecko')) {
      return true;
    }
    // Image generation models (Imagen)
    if (lowerId.startsWith('imagegeneration@') ||
        lowerId.startsWith('imagen-')) {
      return true;
    }
    // Video generation models (Veo)
    if (lowerId.startsWith('veo-') || lowerId.startsWith('video-generate@')) {
      return true;
    }

    // Exclude unknown patterns
    return false;
  }

  /// Refreshes the list of available models from the API.
  ///
  /// This method fetches the latest models from Google's API and updates
  /// the capabilities cache. If the fetch fails, fallback models are used.
  ///
  /// **Returns:**
  /// The list of available model IDs (either from API or fallback)
  ///
  /// **Example:**
  /// ```dart
  /// final models = await provider.refreshModels();
  /// print('Available models: ${models.length}');
  /// ```
  Future<List<String>> refreshModels() async {
    return await fetchAvailableModels();
  }
}
