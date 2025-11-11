// ignore_for_file: avoid_print

import 'dart:io';
import 'dart:math';

import 'package:unified_ai_sdk/unified_ai_sdk.dart';

/// Embeddings Search Example
///
/// Demonstrates semantic search using embeddings.
/// Shows how to:
/// - Generate embeddings for documents
/// - Generate embedding for a query
/// - Calculate cosine similarity
/// - Find most similar documents
///
/// **Prerequisites:**
/// - Set `OPENAI_API_KEY` environment variable
///
/// **Run:**
/// ```bash
/// dart run example/03_embeddings_search/main.dart
/// ```
void main() async {
  final apiKey = Platform.environment['OPENAI_API_KEY'];
  if (apiKey == null || apiKey.isEmpty) {
    print('❌ Error: OPENAI_API_KEY not set');
    exit(1);
  }

  try {
    print('🚀 Initializing SDK...');
    await UnifiedAI.init(
      UnifiedAIConfig(
        defaultProvider: 'openai',
        perProviderConfig: {
          'openai': ProviderConfig(
            id: 'openai',
            auth: ApiKeyAuth(apiKey: apiKey),
          ),
        },
      ),
    );
    print('✅ SDK initialized\n');

    final ai = UnifiedAI.instance;

    // Sample documents to search
    final documents = [
      'Python is a high-level programming language known for its simplicity.',
      'JavaScript is the language of the web, used for frontend and backend development.',
      'Machine learning is a subset of artificial intelligence that learns from data.',
      'Flutter is a UI framework for building cross-platform mobile applications.',
      'Dart is a programming language optimized for building mobile and web apps.',
    ];

    print('📚 Generating embeddings for ${documents.length} documents...');
    final docEmbeddings = await ai.embed(
      request: EmbeddingRequest(
        inputs: documents,
        model: 'text-embedding-3-small',
      ),
    );

    print('✅ Generated ${docEmbeddings.vectors.length} embeddings\n');

    // Query
    final query = 'What is Dart programming language?';
    print('🔍 Query: "$query"\n');
    print('📊 Generating query embedding...');

    final queryEmbedding = await ai.embed(
      request: EmbeddingRequest(
        inputs: [query],
        model: 'text-embedding-3-small',
      ),
    );

    final queryVector = queryEmbedding.vectors.first;
    print('✅ Query embedding generated\n');

    // Calculate similarities
    print('🔎 Calculating similarities...\n');
    final similarities = <MapEntry<int, double>>[];

    for (int i = 0; i < docEmbeddings.vectors.length; i++) {
      final docVector = docEmbeddings.vectors[i];
      final similarity = cosineSimilarity(queryVector, docVector);
      similarities.add(MapEntry(i, similarity));
    }

    // Sort by similarity (descending)
    similarities.sort((a, b) => b.value.compareTo(a.value));

    // Display results
    print('📋 Search Results (sorted by relevance):\n');
    for (int i = 0; i < similarities.length; i++) {
      final entry = similarities[i];
      final rank = i + 1;
      final docIndex = entry.key;
      final similarity = entry.value;

      print('$rank. [Similarity: ${similarity.toStringAsFixed(3)}]');
      print('   "${documents[docIndex]}"\n');
    }

    print('─' * 50);
    print('✅ Most relevant: "${documents[similarities.first.key]}"');
  } on Exception catch (e) {
    print('❌ Error: $e');
    exit(1);
  } finally {
    try {
      await UnifiedAI.instance.dispose();
    } on Object {
      // Ignore
    }
  }
}

/// Calculates cosine similarity between two vectors.
double cosineSimilarity(List<double> a, List<double> b) {
  if (a.length != b.length) {
    throw ArgumentError('Vectors must have the same length');
  }

  double dotProduct = 0.0;
  double normA = 0.0;
  double normB = 0.0;

  for (int i = 0; i < a.length; i++) {
    dotProduct += a[i] * b[i];
    normA += a[i] * a[i];
    normB += b[i] * b[i];
  }

  if (normA == 0.0 || normB == 0.0) {
    return 0.0;
  }

  return dotProduct / (sqrt(normA) * sqrt(normB));
}
