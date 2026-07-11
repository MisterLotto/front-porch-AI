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
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import 'package:path/path.dart' as p;

import 'package:front_porch_ai/services/caption/smolvlm_preprocess.dart';
import 'package:front_porch_ai/services/caption/smolvlm_prompt.dart';

/// The raw SmolVLM-500M ONNX inference pipeline: vision encode → embed →
/// feature splice → prefill → greedy KV-cache decode with a repetition
/// penalty. Stateless besides the three sessions it opens per call — sessions
/// are released before returning so the ~600MB of weights never linger in
/// RAM between captions (they co-exist with a running KoboldCpp).
///
/// Native calls go through the plugin's persistent-isolate `runAsync`, so the
/// UI isolate never blocks. Two perf-critical choices, both deliberate:
///  - the prefill is split so the big [1, N, vocab] logits tensor is never
///    materialized on the Dart side (`.value` is lazy; only [1, 1, vocab]
///    step logits ever cross the FFI boundary), and
///  - present-KV outputs are fed straight back as next-step inputs by native
///    pointer — zero host copies for the cache.
class SmolVlmEngine {
  /// Hidden width / KV layout of the pinned SmolVLM-500M decoder graph.
  static const int _hidden = 960;
  static const int _kvHeads = 5;
  static const int _headDim = 64;

  static const _timeout = Duration(minutes: 10);

  /// Caption preprocessed [frames]. [modelDir] must contain the three int8
  /// graphs + tokenizer.json (LocalCaptionService verifies before calling).
  /// Returns null on any pipeline failure — callers fall back gracefully.
  static Future<String?> caption({
    required Directory modelDir,
    required SmolVlmFrames frames,
    required SmolVlmVocabDecoder vocab,
    int maxNewTokens = 140,
    double repetitionPenalty = 1.25,
  }) async {
    OrtEnv.instance.init();
    final opts = OrtSessionOptions()
      ..setIntraOpNumThreads(math.max(1, Platform.numberOfProcessors - 1));
    OrtSession? vision, embed, decoder;
    final ro = OrtRunOptions();
    try {
      vision = OrtSession.fromFile(
        File(p.join(modelDir.path, 'vision_encoder_quantized.onnx')),
        opts,
      );
      embed = OrtSession.fromFile(
        File(p.join(modelDir.path, 'embed_tokens_int8.onnx')),
        opts,
      );
      decoder = OrtSession.fromFile(
        File(p.join(modelDir.path, 'decoder_model_merged_int8.onnx')),
        opts,
      );
      return await _run(
        vision,
        embed,
        decoder,
        ro,
        frames,
        vocab,
        maxNewTokens,
        repetitionPenalty,
      );
    } finally {
      ro.release();
      vision?.release();
      embed?.release();
      decoder?.release();
      opts.release();
    }
  }

  static Future<String?> _run(
    OrtSession vision,
    OrtSession embed,
    OrtSession decoder,
    OrtRunOptions ro,
    SmolVlmFrames frames,
    SmolVlmVocabDecoder vocab,
    int maxNewTokens,
    double repetitionPenalty,
  ) async {
    // ── Vision encode: frames → [F, 64, 960] features ──────────────────
    final pvT = OrtValueTensor.createTensorWithDataList(frames.pixelValues, [
      1,
      frames.frameCount,
      3,
      512,
      512,
    ]);
    final pmT = OrtValueTensor.createTensorWithDataList(frames.pixelMask, [
      1,
      frames.frameCount,
      512,
      512,
    ]);
    final vOut = await vision.runAsyncWithTimeout(ro, {
      'pixel_values': pvT,
      'pixel_attention_mask': pmT,
    }, _timeout);
    pvT.release();
    pmT.release();
    if (vOut == null || vOut.isEmpty || vOut[0] == null) return null;
    final feats = _flatten3(vOut[0]!.value as List);
    for (final v in vOut) {
      v?.release();
    }

    // ── Prompt embeddings + feature splice ──────────────────────────────
    final promptIds = buildSmolVlmPromptIds(
      rows: frames.rows,
      cols: frames.cols,
    );
    final n = promptIds.length;
    final idsT = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(promptIds),
      [1, n],
    );
    final eOut = await embed.runAsyncWithTimeout(ro, {
      'input_ids': idsT,
    }, _timeout);
    idsT.release();
    if (eOut == null || eOut.isEmpty || eOut[0] == null) return null;
    final promptEmb = _flatten3(eOut[0]!.value as List);
    for (final v in eOut) {
      v?.release();
    }
    var featRow = 0;
    for (var i = 0; i < n; i++) {
      if (promptIds[i] != kSmolVlmImageToken) continue;
      promptEmb.setRange(i * _hidden, (i + 1) * _hidden, feats, featRow);
      featRow += _hidden;
    }
    if (featRow != feats.length) {
      // Grid/prompt mismatch would silently produce garbage — bail instead.
      return null;
    }

    // ── Prefill chunk 1: tokens [0, n-2] — KV only, big logits untouched ─
    final layers = (decoder.inputNames.length - 3) ~/ 2;
    var past = <String, OrtValue>{
      for (var i = 0; i < layers; i++) ...{
        'past_key_values.$i.key': OrtValueTensor.createTensorWithDataList(
          Float32List(0),
          [1, _kvHeads, 0, _headDim],
        ),
        'past_key_values.$i.value': OrtValueTensor.createTensorWithDataList(
          Float32List(0),
          [1, _kvHeads, 0, _headDim],
        ),
      },
    };
    final chunk1 = OrtValueTensor.createTensorWithDataList(
      promptEmb.sublist(0, (n - 1) * _hidden),
      [1, n - 1, _hidden],
    );
    var outs = await _step(
      decoder,
      ro,
      chunk1,
      seqLen: n - 1,
      pastLen: 0,
      past: past,
    );
    chunk1.release();
    if (outs == null) {
      _releaseAll(past.values);
      return null;
    }
    _releaseAll(past.values);
    outs[0]?.release(); // prefill logits: released without materializing
    past = _presentsToPast(decoder.outputNames, outs);

    // ── Greedy loop: first fed token is the prompt's last one ────────────
    var pastLen = n - 1;
    final generated = <int>[];
    OrtValueTensor? stepEmb = OrtValueTensor.createTensorWithDataList(
      promptEmb.sublist((n - 1) * _hidden, n * _hidden),
      [1, 1, _hidden],
    );
    try {
      for (var step = 0; step <= maxNewTokens; step++) {
        outs = await _step(
          decoder,
          ro,
          stepEmb!,
          seqLen: 1,
          pastLen: pastLen,
          past: past,
        );
        stepEmb.release();
        stepEmb = null;
        if (outs == null) return null;
        _releaseAll(past.values);
        past = _presentsToPast(decoder.outputNames, outs);
        pastLen += 1;

        final logits = _lastLogits(outs[0]!.value as List);
        outs[0]!.release();
        // Penalize each PREVIOUSLY GENERATED id once (set semantics — the
        // reference implementation; per-occurrence stacking over-penalizes
        // repeats and drives the model into rambling drift).
        for (final id in generated.toSet()) {
          logits[id] = logits[id] > 0
              ? logits[id] / repetitionPenalty
              : logits[id] * repetitionPenalty;
        }
        var best = 0;
        for (var i = 1; i < logits.length; i++) {
          if (logits[i] > logits[best]) best = i;
        }
        if (best == kSmolVlmEndOfUtterance || step == maxNewTokens) break;
        generated.add(best);

        // Embed the new token; its output rides directly into the next step.
        final tokT = OrtValueTensor.createTensorWithDataList(
          Int64List.fromList([best]),
          [1, 1],
        );
        final tOut = await embed.runAsyncWithTimeout(ro, {
          'input_ids': tokT,
        }, _timeout);
        tokT.release();
        if (tOut == null || tOut.isEmpty || tOut[0] == null) return null;
        stepEmb = tOut[0] as OrtValueTensor;
      }
    } finally {
      stepEmb?.release();
      _releaseAll(past.values);
    }
    if (generated.isEmpty) return null;
    var text = vocab.decode(generated).replaceAll(RegExp(r'\s+'), ' ').trim();
    // A token-cap cutoff leaves a dangling half-sentence — trim back to the
    // last completed one when there's enough caption to keep.
    if (text.isNotEmpty && !'.!?'.contains(text[text.length - 1])) {
      final lastStop = text.lastIndexOf(RegExp(r'[.!?]'));
      if (lastStop >= 40) text = text.substring(0, lastStop + 1);
    }
    return text.isEmpty ? null : text;
  }

  /// One decoder run: [seqLen] embedded tokens against [pastLen] cached ones.
  static Future<List<OrtValue?>?> _step(
    OrtSession decoder,
    OrtRunOptions ro,
    OrtValueTensor inputsEmbeds, {
    required int seqLen,
    required int pastLen,
    required Map<String, OrtValue> past,
  }) async {
    final total = pastLen + seqLen;
    final attnT = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList(List.filled(total, 1)),
      [1, total],
    );
    final posT = OrtValueTensor.createTensorWithDataList(
      Int64List.fromList([for (var i = pastLen; i < total; i++) i]),
      [1, seqLen],
    );
    try {
      return await decoder.runAsyncWithTimeout(ro, {
        'inputs_embeds': inputsEmbeds,
        'attention_mask': attnT,
        'position_ids': posT,
        ...past,
      }, _timeout);
    } finally {
      attnT.release();
      posT.release();
    }
  }

  /// Rewrap `present.*` outputs (index 1+) as the next `past_key_values.*`
  /// inputs — by native pointer, no host copy.
  static Map<String, OrtValue> _presentsToPast(
    List<String> outputNames,
    List<OrtValue?> outs,
  ) {
    final past = <String, OrtValue>{};
    for (var i = 1; i < outputNames.length; i++) {
      final out = outs[i];
      if (out == null) continue;
      past[outputNames[i].replaceFirst('present', 'past_key_values')] = out;
    }
    return past;
  }

  static void _releaseAll(Iterable<OrtValue> values) {
    for (final v in values) {
      v.release();
    }
  }

  /// Flatten the plugin's nested-list tensor value ([a][b][hidden] or
  /// [1][b][hidden]) into a Float32List.
  static Float32List _flatten3(List nested) {
    final out = <double>[];
    void walk(List l) {
      for (final e in l) {
        if (e is List) {
          walk(e);
        } else {
          out.add((e as num).toDouble());
        }
      }
    }

    walk(nested);
    return Float32List.fromList(out);
  }

  /// Extract the last position's logits row from a [1][s][vocab] value.
  static Float32List _lastLogits(List nested) {
    final batch = nested[0] as List;
    final row = batch[batch.length - 1] as List;
    return Float32List.fromList([for (final v in row) (v as num).toDouble()]);
  }
}
