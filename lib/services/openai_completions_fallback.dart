// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/utils/reasoning_markers.dart';

/// oMLX (and some local MLX servers) register VLMs as completions-only:
/// `POST /v1/chat/completions` returns
/// "Model X is not supported on /v1/chat/completions" while
/// `/v1/completions` answers. Qwen3.8-27B-MLX-8bit is that class.
bool isChatCompletionsUnsupportedError(String msg) {
  final m = msg.toLowerCase();
  return m.contains('not supported') &&
      (m.contains('chat/completions') || m.contains('chat completions'));
}

final Set<String> _completionsOnlyModels = <String>{};

void rememberCompletionsOnlyModel(String modelName) {
  if (modelName.isEmpty) return;
  _completionsOnlyModels.add(modelName);
}

bool isRememberedCompletionsOnlyModel(String modelName) =>
    _completionsOnlyModels.contains(modelName);

/// Test seam — do not call from product code.
void debugResetCompletionsOnlyModels() => _completionsOnlyModels.clear();

Map<String, dynamic> openAiCompletionsPayload(
  GenerationParams params, {
  required String modelName,
  required bool stream,
}) {
  final system = params.systemPrompt?.trim();
  final prompt = (system != null && system.isNotEmpty)
      ? '$system\n\n${params.prompt}'
      : params.prompt;
  return <String, dynamic>{
    'model': modelName,
    'stream': stream,
    'prompt': prompt,
    'max_tokens': params.maxLength,
    'temperature': params.temperature,
    'top_p': params.topP,
    if (params.stopSequences != null && params.stopSequences!.isNotEmpty)
      'stop': params.stopSequences!.take(4).toList(),
  };
}

/// Yields `choices[0].text` chunks from an OpenAI completions SSE stream.
Stream<String> parseCompletionsSse(Stream<List<int>> byteStream) async* {
  var buffer = '';
  final markers = ReasoningMarkerRewriter();
  await for (final chunk in byteStream.transform(utf8.decoder)) {
    buffer += chunk;
    while (buffer.contains('\n')) {
      final idx = buffer.indexOf('\n');
      final line = buffer.substring(0, idx).trim();
      buffer = buffer.substring(idx + 1);
      final piece = _textFromSseLine(line);
      if (piece == _kDone) {
        final rest = markers.finish();
        if (rest.isNotEmpty) yield rest;
        return;
      }
      if (piece != null && piece.isNotEmpty) {
        final out = markers.push(piece);
        if (out.isNotEmpty) yield out;
      }
    }
  }
  final tail = _textFromSseLine(buffer.trim());
  if (tail != null && tail.isNotEmpty && tail != _kDone) {
    final out = markers.push(tail);
    if (out.isNotEmpty) yield out;
  }
  final rest = markers.finish();
  if (rest.isNotEmpty) yield rest;
}

const _kDone = '__DONE__';

String? _textFromSseLine(String line) {
  if (line.isEmpty) return null;
  if (line == 'data: [DONE]' || line == 'data:[DONE]') return _kDone;
  if (!line.startsWith('data:')) return null;
  final data = line.startsWith('data: ')
      ? line.substring(6)
      : line.substring(5);
  if (data == '[DONE]') return _kDone;
  try {
    final json = jsonDecode(data);
    final choice = json['choices']?[0];
    if (choice is! Map) return null;
    final text = choice['text'];
    return text is String ? text : null;
  } catch (_) {
    return null;
  }
}

/// POST `/completions` (base already includes `/v1`).
Future<http.StreamedResponse> postOpenAiCompletions({
  required String apiUrl,
  required Map<String, String> headers,
  required Map<String, dynamic> payload,
  required http.Client client,
}) {
  final base = apiUrl.endsWith('/')
      ? apiUrl.substring(0, apiUrl.length - 1)
      : apiUrl;
  final request = http.Request('POST', Uri.parse('$base/completions'));
  request.headers.addAll(headers);
  request.body = jsonEncode(payload);
  return client.send(request);
}
