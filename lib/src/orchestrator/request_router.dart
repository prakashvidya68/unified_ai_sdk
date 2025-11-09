import '../error/error_types.dart';
import '../providers/base/ai_provider.dart';
import 'intent_detector.dart';
import 'provider_registry.dart';

/// Routes requests to appropriate AI providers based on explicit provider selection
/// or automatic intent detection.
///
/// The [RequestRouter] is responsible for determining which provider should
/// handle a given request. It supports two routing strategies:
///
/// 1. **Explicit Provider Selection**: When a provider ID is explicitly specified,
///    the router returns that provider directly.
///
/// 2. **Intent-Based Routing**: When no provider is specified, the router uses
///    [IntentDetector] to determine the user's intent, then finds providers that
///    support the required capability.
///
/// **Design Pattern:** Strategy Pattern with automatic fallback
///
/// **Example usage:**
/// ```dart
/// final registry = ProviderRegistry();
/// final detector = IntentDetector();
/// final router = RequestRouter(registry: registry, intentDetector: detector);
///
/// // Explicit provider routing
/// final provider1 = await router.route('openai', chatRequest);
/// // Returns: OpenAIProvider
///
/// // Intent-based routing
/// final provider2 = await router.route(null, imageRequest);
/// // Detects image_generation intent, finds providers with 'image' capability
/// // Returns: First provider that supports image generation
/// ```
class RequestRouter {
  /// Registry for accessing registered providers.
  final ProviderRegistry registry;

  /// Detector for analyzing request intent.
  final IntentDetector intentDetector;

  /// Creates a new [RequestRouter] instance.
  ///
  /// **Parameters:**
  /// - [registry]: The provider registry to query for providers
  /// - [intentDetector]: The intent detector for analyzing requests
  ///
  /// **Example:**
  /// ```dart
  /// final router = RequestRouter(
  ///   registry: providerRegistry,
  ///   intentDetector: IntentDetector(),
  /// );
  /// ```
  RequestRouter({
    required this.registry,
    required this.intentDetector,
  });

  /// Routes a request to an appropriate AI provider.
  ///
  /// This method determines which provider should handle the request using
  /// one of two strategies:
  ///
  /// 1. **Explicit Provider**: If [explicitProvider] is provided, returns
  ///    that provider directly (if registered).
  ///
  /// 2. **Intent-Based Routing**: If [explicitProvider] is null, detects the
  ///    intent from the request, finds providers that support the required
  ///    capability, and returns the first matching provider.
  ///
  /// **Parameters:**
  /// - [explicitProvider]: Optional provider ID to use. If provided, this
  ///   provider will be used regardless of request content.
  /// - [request]: The request object to route. Can be [ChatRequest],
  ///   [ImageRequest], [EmbeddingRequest], etc.
  ///
  /// **Returns:**
  /// An [AiProvider] instance that can handle the request.
  ///
  /// **Throws:**
  /// - [ClientError] if explicit provider is specified but not found in registry
  /// - [CapabilityError] if no providers support the detected capability
  /// - [ArgumentError] if the request type is not supported by IntentDetector
  ///
  /// **Example:**
  /// ```dart
  /// final router = RequestRouter(...);
  ///
  /// // Explicit provider routing
  /// final provider1 = await router.route('openai', chatRequest);
  ///
  /// // Intent-based routing
  /// final imageRequest = ImageRequest(prompt: 'A cat');
  /// final provider2 = await router.route(null, imageRequest);
  /// // Automatically routes to a provider that supports image generation
  /// ```
  Future<AiProvider> route(String? explicitProvider, dynamic request) async {
    // Strategy 1: Explicit provider selection
    if (explicitProvider != null) {
      return _routeToExplicitProvider(explicitProvider);
    }

    // Strategy 2: Intent-based routing
    return _routeByIntent(request);
  }

  /// Routes to an explicitly specified provider.
  ///
  /// **Parameters:**
  /// - [providerId]: The ID of the provider to route to
  ///
  /// **Returns:**
  /// The provider instance if found
  ///
  /// **Throws:**
  /// - [ClientError] if the provider is not found in the registry
  Future<AiProvider> _routeToExplicitProvider(String providerId) async {
    final provider = registry.get(providerId);
    if (provider == null) {
      throw ClientError(
        message: 'Provider "$providerId" is not registered. '
            'Available providers: ${registry.getAllIds().join(", ")}',
        code: 'PROVIDER_NOT_FOUND',
        provider: providerId,
      );
    }
    return provider;
  }

  /// Routes to a provider based on detected intent.
  ///
  /// Detects the intent from the request, finds providers that support
  /// the required capability, and returns the first matching provider.
  ///
  /// **Parameters:**
  /// - [request]: The request object to analyze
  ///
  /// **Returns:**
  /// A provider that supports the detected capability
  ///
  /// **Throws:**
  /// - [CapabilityError] if no providers support the detected capability
  /// - [ArgumentError] if the request type is not supported
  Future<AiProvider> _routeByIntent(dynamic request) async {
    // Detect intent from request
    final intent = intentDetector.detect(request);

    // Find providers that support the required capability
    final candidates = registry.getByCapability(intent.capability);

    if (candidates.isEmpty) {
      throw CapabilityError(
        message: 'No providers support the "${intent.capability}" capability. '
            'Detected intent: ${intent.type} (confidence: ${intent.confidence.toStringAsFixed(2)}). '
            'Registered providers: ${registry.getAllIds().join(", ")}',
        code: 'NO_PROVIDER_WITH_CAPABILITY',
        provider: null,
      );
    }

    // Simple strategy: return the first provider that supports the capability
    // Future enhancements could include:
    // - Provider priority/ranking
    // - Load balancing
    // - Cost optimization
    // - Latency-based selection
    return candidates.first;
  }

  /// Gets the registry used by this router.
  ///
  /// Useful for debugging or advanced use cases where you need to query
  /// the registry directly.
  ProviderRegistry get providerRegistry => registry;

  /// Gets the intent detector used by this router.
  ///
  /// Useful for debugging or advanced use cases where you need to detect
  /// intent manually.
  IntentDetector get detector => intentDetector;
}
