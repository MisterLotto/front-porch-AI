import 'package:flutter/foundation.dart';

/// Generation parameters shared across all LLM backends.
class GenerationParams {
  final String prompt;
  final int maxLength;
  final int minLength;
  final double temperature;
  final double repeatPenalty;
  final double topP;
  final double minP;
  final int repPenTokens;
  final double? dynatempRange;
  final double xtcThreshold;
  final double xtcProbability;
  final List<String>? stopSequences;
  final bool reasoningEnabled;
  final String reasoningEffort;
  final List<String>? bannedPhrases;

  const GenerationParams({
    required this.prompt,
    this.maxLength = 200,
    this.minLength = 0,
    this.temperature = 0.7,
    this.repeatPenalty = 1.1,
    this.topP = 0.9,
    this.minP = 0.0,
    this.repPenTokens = 64,
    this.dynatempRange,
    this.xtcThreshold = 0.1,
    this.xtcProbability = 0.5,
    this.stopSequences,
    this.reasoningEnabled = false,
    this.reasoningEffort = 'medium',
    this.bannedPhrases,
  });
}

/// Abstract interface for all LLM backends (local KoboldCPP, OpenRouter, etc).
abstract class LLMService extends ChangeNotifier {
  /// Stream tokens one at a time for real-time display.
  Stream<String> generateStream(GenerationParams params);

  /// Abort the current in-flight generation request (closes the HTTP client).
  void abortGeneration() {}

  /// Whether the backend is ready to accept requests.
  bool get isReady;

  /// Human-readable name for this backend (e.g. "KoboldCPP", "OpenRouter").
  String get backendName;
}
