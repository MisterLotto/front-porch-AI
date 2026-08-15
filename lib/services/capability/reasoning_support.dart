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

import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:front_porch_ai/services/reasoning_effort.dart';
import 'package:front_porch_ai/utils/gguf_reader.dart';

/// What a LOCAL model can actually do about thinking, read from the chat
/// template baked into its GGUF (2026-08-15).
///
/// WHY NOT THE REMOTE POKE. The remote probe learns a model's effort menu by
/// sending a bogus `reasoning.effort` and parsing the provider's
/// "Supported values are: …" 400. That works because a hosted provider
/// validates and enumerates. KoboldCpp does neither: it takes its own
/// `chat_template_kwargs.enable_thinking` + `reasoning_effort` fields and
/// simply passes them to the template, so a bogus value is ignored rather
/// than rejected. Poking it would spend a request to learn nothing AND burn
/// the "already probed" flag, so the model would never be asked again.
///
/// The answer is already on disk. In jinja mode (`--jinja`, which the managed
/// backend launches with) Kobold executes the GGUF's own chat template, and
/// that template is the thing that decides whether thinking happens at all —
/// so reading it IS reading the capability. No request, no generation, no
/// backend needed, and the same answer every time.
enum ThinkingSupport {
  /// No thinking machinery in the template — the strength chips would be
  /// decorative and the switch a no-op. Most GGUFs land here.
  none,

  /// `enable_thinking` is honoured: on/off is real, strength is not.
  toggle,

  /// `reasoning_effort` is honoured: the strength levels are real.
  graded,

  /// Thinking is emitted unconditionally with no switch to read (R1-style
  /// templates that hard-code the opening think tag). Off cannot work.
  always,
}

/// Markers that mean "this template emits a reasoning block". Deliberately
/// includes the harmony channel form — gpt-oss does not use `<think>`.
const List<String> _kThinkMarkers = [
  '<think>',
  '</think>',
  '<|channel|>analysis',
  'reasoning_content',
];

/// Read [chatTemplate] and decide what the model supports. PURE, so the whole
/// policy is a truth table over real template text.
///
/// Order is load-bearing. A gpt-oss harmony template carries BOTH
/// `reasoning_effort` and channel markers, and a Qwen3 template carries BOTH
/// `enable_thinking` and `<think>` — in each case the more specific control
/// is the honest answer, so the switches are checked before the markers.
ThinkingSupport detectThinkingFromChatTemplate(String chatTemplate) {
  if (chatTemplate.isEmpty) return ThinkingSupport.none;
  final t = chatTemplate.toLowerCase();
  if (t.contains('reasoning_effort')) return ThinkingSupport.graded;
  if (t.contains('enable_thinking')) return ThinkingSupport.toggle;
  for (final marker in _kThinkMarkers) {
    if (t.contains(marker)) return ThinkingSupport.always;
  }
  return ThinkingSupport.none;
}

/// The effort set [support] implies, in the app's shared vocabulary.
///
/// `toggle` and `always`-without-grading resolve to `{none}` on purpose: the
/// shared [reasoningEffortChipsFor] drops `none` and every unranked entry, so
/// an empty chip row falls out by construction rather than by a second rule
/// somewhere in the UI. A model with no strength levels should show no
/// strength chips.
Set<String> effortsForThinkingSupport(ThinkingSupport support) =>
    switch (support) {
      ThinkingSupport.graded => const {'none', 'low', 'medium', 'high'},
      ThinkingSupport.toggle ||
      ThinkingSupport.always ||
      ThinkingSupport.none => const {'none'},
    };

/// One cached thinking verdict per local model file, mirroring
/// [VisionSupportResolver]'s GGUF half: parse once, cache by path (including
/// the misses, so a torn file is not re-read on every rebuild), and register
/// the result into the SHARED reasoning-effort store so the existing chip and
/// caption machinery applies to local models without a second code path.
///
/// Registrations pass `persist: false`: the on-disk menu store is for remote
/// models learned from a provider, and a local file path is neither portable
/// nor worth persisting — the GGUF is re-read for free next launch.
class ReasoningSupportResolver {
  ReasoningSupportResolver._();
  static final ReasoningSupportResolver instance = ReasoningSupportResolver._();

  final Map<String, ThinkingSupport?> _cache = {};

  // Deliberately NO notifier of its own: registering the verdict below bumps
  // the shared kReasoningEffortCatalogTick, which Settings already listens to.
  // A second notification path would be one more thing to keep in sync.

  /// The verdict for [modelPath] if it has already been resolved. Safe to
  /// call from a build path — it never touches the disk.
  ThinkingSupport? peek(String modelPath) => _cache[modelPath];

  bool isResolved(String modelPath) => _cache.containsKey(modelPath);

  /// Parse (and cache) the thinking capability of a local GGUF.
  ///
  /// Never call this from a build path: it reads the file. Callers kick it
  /// from a lifecycle hook and read [peek] afterwards.
  Future<ThinkingSupport?> resolveLocalGguf(String modelPath) async {
    if (modelPath.isEmpty) return null;
    if (_cache.containsKey(modelPath)) return _cache[modelPath];

    ThinkingSupport? support;
    try {
      final template = await readChatTemplate(modelPath);
      if (template != null) {
        support = detectThinkingFromChatTemplate(template);
      }
    } catch (_) {
      support = null; // unreadable file → unknown, chips stay generic
    }
    _cache[modelPath] = support;
    if (support != null) {
      rememberReasoningEffortsForModel(
        modelPath,
        effortsForThinkingSupport(support),
        persist: false,
      );
      if (support == ThinkingSupport.always) {
        rememberMandatoryReasoning(modelPath, persist: false);
      }
    }
    return support;
  }

  /// Test seam: drop every verdict so a suite can resolve the same path twice.
  @visibleForTesting
  void clearForTest() => _cache.clear();
}

/// Pull `tokenizer.chat_template` out of a GGUF header.
///
/// Reuses [GGUFFileReader.parseMetadataBytes], which already skips the huge
/// token array by length arithmetic instead of decoding it — so this costs one
/// bounded header read and no allocation per token. Returns null when the file
/// is missing, is not a GGUF, or carries no template (llama.cpp then falls back
/// to its built-in adapter, and no template means no thinking machinery we can
/// read).
Future<String?> readChatTemplate(String modelPath) async {
  final file = File(modelPath);
  if (!await file.exists()) return null;
  final raf = await file.open(mode: FileMode.read);
  try {
    // Same bounded window the vision parser uses: the metadata header sits at
    // the very front of the file, well inside this.
    final bytes = await raf.read(4 * 1024 * 1024);
    final meta = GGUFFileReader.parseMetadataBytes(bytes);
    final template = meta?['tokenizer.chat_template'];
    return template is String && template.isNotEmpty ? template : null;
  } catch (_) {
    return null;
  } finally {
    await raf.close();
  }
}
