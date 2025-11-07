/// Interface for providers that support dynamic model discovery.
///
/// Providers implementing this interface can fetch available models from their
/// API endpoints, enabling the SDK to dynamically discover models rather than
/// relying solely on hardcoded lists.
///
/// **Design Pattern:** Strategy Pattern
///
/// This interface allows providers to opt-in to dynamic model discovery while
/// maintaining backward compatibility with static model lists.
///
/// **Example usage:**
/// ```dart
/// class OpenAIProvider extends AiProvider implements ModelFetcher {
///   @override
///   Future<List<String>> fetchAvailableModels() async {
///     final response = await _http.get('$_baseUrl/models');
///     // Parse and return model IDs
///   }
///
///   @override
///   String inferModelType(String modelId) {
///     if (modelId.startsWith('gpt')) return 'text';
///     if (modelId.contains('embedding')) return 'embedding';
///     return 'other';
///   }
/// }
/// ```
abstract class ModelFetcher {
  /// Fetches available models from the provider's API.
  ///
  /// This method should make an HTTP request to the provider's models endpoint
  /// (e.g., `/v1/models` for OpenAI) and return a list of currently available
  /// model identifiers.
  ///
  /// **Returns:**
  /// A list of model IDs (e.g., ['gpt-4', 'gpt-3.5-turbo', 'text-embedding-3-small'])
  ///
  /// **Throws:**
  /// - [AuthError] if authentication fails
  /// - [TransientError] for network or server errors
  /// - [ClientError] for invalid requests
  ///
  /// **Note:**
  /// Implementations should handle errors gracefully and return an empty list
  /// or fallback to static models rather than throwing exceptions in most cases.
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// Future<List<String>> fetchAvailableModels() async {
  ///   try {
  ///     final response = await _http.get('$_baseUrl/models');
  ///     if (response.statusCode != 200) {
  ///       return []; // Return empty list on error, fallback will be used
  ///     }
  ///     final data = jsonDecode(response.body);
  ///     return (data['data'] as List)
  ///         .map((m) => m['id'] as String)
  ///         .toList();
  ///   } catch (e) {
  ///     return []; // Fallback to static models
  ///   }
  /// }
  /// ```
  Future<List<String>> fetchAvailableModels();

  /// Infers the model type from a model identifier.
  ///
  /// This method categorizes models based on their ID, which helps the SDK
  /// understand what operations are supported by each model.
  ///
  /// **Parameters:**
  /// - [modelId]: The model identifier (e.g., 'gpt-4', 'text-embedding-3-small')
  ///
  /// **Returns:**
  /// A string representing the model type:
  /// - `'text'` - Text generation/chat models
  /// - `'embedding'` - Embedding models
  /// - `'image'` - Image generation models
  /// - `'tts'` - Text-to-speech models
  /// - `'stt'` - Speech-to-text models
  /// - `'other'` - Unknown or other types
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// String inferModelType(String modelId) {
  ///   if (modelId.startsWith('gpt')) return 'text';
  ///   if (modelId.contains('embedding')) return 'embedding';
  ///   if (modelId.startsWith('dall-e')) return 'image';
  ///   if (modelId.startsWith('tts-')) return 'tts';
  ///   if (modelId.startsWith('whisper-')) return 'stt';
  ///   return 'other';
  /// }
  /// ```
  String inferModelType(String modelId);
}
