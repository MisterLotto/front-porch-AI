// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

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
  /// Optional GBNF grammar string for constrained JSON output (KoboldCPP local only).
  /// Never set this when reasoning/thinking mode is active — the <think> block
  /// tokens would be illegal under the grammar and break generation.
  final String? grammar;

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
    this.grammar,
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
