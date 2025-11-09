/// Mapper for converting between unified SDK models and Cohere-specific models.
///
/// This class provides bidirectional conversion between the provider-agnostic
/// SDK models ([EmbeddingRequest], [EmbeddingResponse]) and Cohere-specific
/// models ([CohereEmbeddingRequest], [CohereEmbeddingResponse]).
///
/// **Design Pattern:** Adapter/Mapper Pattern
///
/// This mapper allows the SDK to maintain a unified API while supporting
/// provider-specific features and formats. Users interact with unified models,
/// but internally the SDK converts to/from Cohere-specific formats.
///
/// **Key Features:**
/// - Handles Cohere's "texts" array format
/// - Supports input_type parameter (search_document, search_query, etc.)
/// - Maps Cohere's embedding format to SDK format
/// - Converts Cohere usage statistics to SDK format
///
/// **Example usage:**
/// ```dart
/// // SDK → Cohere
/// final embeddingRequest = EmbeddingRequest(
///   inputs: ['Hello, world!', 'How are you?'],
///   model: 'embed-english-v3.0',
/// );
/// final mapper = CohereMapper.instance;
/// final cohereRequest = mapper.mapEmbeddingRequest(embeddingRequest);
///
/// // Cohere → SDK
/// final cohereResponse = CohereEmbeddingResponse.fromJson(apiResponse);
/// final embeddingResponse = mapper.mapEmbeddingResponse(cohereResponse);
/// ```
library;

import '../../error/error_types.dart';
import '../../models/common/usage.dart';
import '../../models/requests/chat_request.dart';
import '../../models/requests/embedding_request.dart';
import '../../models/requests/image_request.dart';
import '../../models/responses/chat_response.dart';
import '../../models/responses/embedding_response.dart';
import '../../models/responses/image_response.dart';
import '../base/provider_mapper.dart';
import 'cohere_models.dart';

/// Mapper for converting between unified SDK models and Cohere-specific models.
///
/// Implements [ProviderMapper] to provide Cohere-specific conversion logic.
/// This class uses a singleton pattern and provides instance methods for
/// converting between unified SDK models and Cohere-specific formats.
///
/// **Usage:**
/// ```dart
/// final mapper = CohereMapper.instance;
/// final request = mapper.mapEmbeddingRequest(embeddingRequest);
/// final response = mapper.mapEmbeddingResponse(cohereResponse);
/// ```
class CohereMapper implements ProviderMapper {
  /// Private constructor to enforce singleton pattern.
  /// Use [CohereMapper.instance] to access the mapper instance.
  CohereMapper._();

  /// Singleton instance for instance-based usage.
  ///
  /// Use this when you need to inject the mapper as a dependency or
  /// when working with the [ProviderMapper] interface.
  static final CohereMapper instance = CohereMapper._();

  // Instance methods implementing ProviderMapper interface

  @override
  dynamic mapChatRequest(ChatRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'Cohere provider does not support chat completions.',
      code: 'UNSUPPORTED_OPERATION',
      provider: 'cohere',
    );
  }

  @override
  ChatResponse mapChatResponse(dynamic response) {
    throw CapabilityError(
      message: 'Cohere provider does not support chat completions.',
      code: 'UNSUPPORTED_OPERATION',
      provider: 'cohere',
    );
  }

  @override
  CohereEmbeddingRequest mapEmbeddingRequest(EmbeddingRequest request,
      {String? defaultModel}) {
    return _mapEmbeddingRequestImpl(request, defaultModel: defaultModel);
  }

  @override
  EmbeddingResponse mapEmbeddingResponse(dynamic response) {
    if (response is! CohereEmbeddingResponse) {
      throw ArgumentError(
          'Expected CohereEmbeddingResponse, got ${response.runtimeType}');
    }
    return _mapEmbeddingResponseImpl(response);
  }

  @override
  dynamic mapImageRequest(ImageRequest request, {String? defaultModel}) {
    throw CapabilityError(
      message: 'Cohere provider does not support image generation.',
      code: 'UNSUPPORTED_OPERATION',
      provider: 'cohere',
    );
  }

  @override
  ImageResponse mapImageResponse(dynamic response) {
    throw CapabilityError(
      message: 'Cohere provider does not support image generation.',
      code: 'UNSUPPORTED_OPERATION',
      provider: 'cohere',
    );
  }

  // Private implementation methods

  CohereEmbeddingRequest _mapEmbeddingRequestImpl(
    EmbeddingRequest request, {
    String? defaultModel,
  }) {
    // Determine model - use request.model, then defaultModel, or throw error
    final model = request.model ?? defaultModel;
    if (model == null || model.isEmpty) {
      throw ClientError(
        message:
            'Model is required. Either specify model in EmbeddingRequest or provide defaultModel.',
        code: 'MISSING_MODEL',
      );
    }

    // Extract Cohere-specific options from providerOptions
    final cohereOptions =
        request.providerOptions?['cohere'] ?? <String, dynamic>{};

    // Build Cohere request
    return CohereEmbeddingRequest(
      texts: request.inputs,
      model: model,
      inputType: cohereOptions['input_type'] as String? ??
          cohereOptions['inputType'] as String?,
      embeddingTypes: cohereOptions['embedding_types'] != null
          ? List<String>.from(cohereOptions['embedding_types'] as List)
          : cohereOptions['embeddingTypes'] != null
              ? List<String>.from(cohereOptions['embeddingTypes'] as List)
              : null,
      truncate: cohereOptions['truncate'] as String?,
    );
  }

  EmbeddingResponse _mapEmbeddingResponseImpl(
      CohereEmbeddingResponse response) {
    // Convert Cohere embeddings to SDK EmbeddingData
    final embeddings = response.embeddings.asMap().entries.map((entry) {
      final index = entry.key;
      final embedding = entry.value;

      return EmbeddingData(
        vector: embedding,
        dimension: embedding.length,
        index: index,
      );
    }).toList();

    // Convert Cohere usage to SDK usage
    // Cohere reports tokens in usage.meta.tokens
    final usage = response.usage != null && response.usage!.tokens != null
        ? Usage(
            promptTokens: response.usage!.tokens!,
            completionTokens: 0, // Embeddings don't have completion tokens
            totalTokens: response.usage!.tokens!,
          )
        : null;

    // Determine model name
    final modelName = response.model ?? 'unknown';

    return EmbeddingResponse(
      embeddings: embeddings,
      model: modelName,
      provider: 'cohere',
      usage: usage,
    );
  }
}
