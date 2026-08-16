// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Nano-GPT (and any OpenAI-compatible host that does not list
// supported_efforts) is asked at model-pick time which reasoning.effort
// values it actually accepts. One tiny completion with a bogus effort
// forces the "Supported values are: …" 400 the Discord DeepSeek report
// already taught us to parse. OpenRouter catalog hits skip this. A
// successful or listing-less poke is remembered on disk so the next
// launch does not ask again.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:front_porch_ai/services/reasoning_effort.dart';

const _kProbeEffort = 'fpai_probe';
const _kRetryAfter = Duration(seconds: 30);

final Set<String> _probed = <String>{};
final Map<String, DateTime> _lastTry = <String, DateTime>{};
final Map<String, Future<bool>> _inFlight = <String, Future<bool>>{};

/// True while we still owe this model a poke (and have no hint/menu yet).
bool reasoningEffortMenuPending(String model, {String apiUrl = ''}) {
  if (model.isEmpty) return false;
  if (kLearnedReasoningEffortsByModel.containsKey(model)) return false;
  if (_probed.contains(model)) return false;
  if (apiUrl.isEmpty || isLocalRemoteUrl(apiUrl)) return false;
  return true;
}

/// Record that we already asked (hydrate from disk, or a listing-less 400).
void rememberReasoningEffortProbed(String model) {
  if (model.isEmpty) return;
  _probed.add(model);
}

Iterable<String> reasoningEffortProbedModels() => _probed;

void _markProbedAndPersist(String model) {
  _probed.add(model);
  persistReasoningEffortMenuHook?.call(model, probed: true);
  if (!reasoningEffortCatalogIsBatching) {
    kReasoningEffortCatalogTick.value++;
  }
}

/// Ask the provider for [model]'s real effort menu. No-ops when we already
/// learned it, already poked it, the URL is local, or a poke ran recently.
Future<bool> probeReasoningEfforts({
  required String model,
  required String apiUrl,
  required String apiKey,
  http.Client? client,
  bool allowLocal = false,
}) {
  if (model.isEmpty || apiUrl.isEmpty) return Future.value(false);
  if (!allowLocal && isLocalRemoteUrl(apiUrl)) return Future.value(false);
  if (_probed.contains(model)) return Future.value(false);
  if (kLearnedReasoningEffortsByModel.containsKey(model)) {
    _markProbedAndPersist(model);
    return Future.value(false);
  }
  final pending = _inFlight[model];
  if (pending != null) return pending;
  final last = _lastTry[model];
  if (last != null && DateTime.now().difference(last) < _kRetryAfter) {
    return Future.value(false);
  }
  final run = _probe(model, apiUrl, apiKey, client);
  _inFlight[model] = run;
  return run.whenComplete(() => _inFlight.remove(model));
}

/// Fire-and-forget wrapper for pickers.
void kickReasoningEffortProbe({
  required String model,
  required String apiUrl,
  required String apiKey,
}) {
  unawaited(
    probeReasoningEfforts(model: model, apiUrl: apiUrl, apiKey: apiKey),
  );
}

Future<bool> _probe(
  String model,
  String apiUrl,
  String apiKey,
  http.Client? existing,
) async {
  _lastTry[model] = DateTime.now();
  final owned = existing == null;
  final http.Client client = existing ?? http.Client();
  try {
    final uri = Uri.parse(_completionsUrl(apiUrl));
    final response = await client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (apiKey.isNotEmpty) 'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'max_tokens': 1,
            'stream': false,
            'messages': [
              {'role': 'user', 'content': 'ok'},
            ],
            'reasoning_effort': _kProbeEffort,
            'reasoning': {
              'enabled': true,
              'effort': _kProbeEffort,
            },
          }),
        )
        .timeout(const Duration(seconds: 8));
    final body = response.body;
    final listing = supportedReasoningEffortsFromError(body) ??
        supportedReasoningEffortsFromError(_messageOf(body));
    if (listing != null) {
      rememberReasoningEffortsForModel(model, listing);
      _probed.add(model);
      return true;
    }
    _markProbedAndPersist(model);
    return false;
  } catch (_) {
    return false;
  } finally {
    if (owned) client.close();
  }
}

String _completionsUrl(String apiUrl) {
  final base = apiUrl.endsWith('/')
      ? apiUrl.substring(0, apiUrl.length - 1)
      : apiUrl;
  return '$base/chat/completions';
}

String _messageOf(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      final err = decoded['error'];
      if (err is Map && err['message'] != null) return err['message'].toString();
      if (err is String) return err;
      if (decoded['message'] != null) return decoded['message'].toString();
    }
  } catch (_) {}
  return body;
}

/// Test helper.
void clearReasoningEffortProbes() {
  _probed.clear();
  _lastTry.clear();
  _inFlight.clear();
}
