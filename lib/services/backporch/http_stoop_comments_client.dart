// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Live Stoop comments client. Talks to the hub over the same Bearer session
// as the rest of BackporchApi. MemoryStoopCommentsClient stays for tests.

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:front_porch_ai/services/backporch/backporch_api.dart';
import 'package:front_porch_ai/services/backporch/backporch_user.dart';
import 'package:front_porch_ai/services/backporch/stoop_comment.dart';
import 'package:front_porch_ai/services/backporch/stoop_comments_client.dart';

/// Hub-backed [StoopCommentsClient]. Author identity is the Bearer token —
/// [author] / [actor] on the interface are unused on the wire.
class HttpStoopCommentsClient implements StoopCommentsClient {
  HttpStoopCommentsClient(this._api, this._token);

  final BackporchApi _api;
  final String Function() _token;

  String get _base => _api.baseUrl;

  @override
  Future<List<StoopComment>> list(String cardId) async {
    final json = await _send('GET', '/characters/$cardId/comments');
    final raw = json['items'] ?? json['comments'];
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) StoopComment.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  @override
  Future<StoopComment> create({
    required String cardId,
    required String body,
    required BackporchUser author,
  }) async {
    final json = await _send(
      'POST',
      '/characters/$cardId/comments',
      body: {'body': body},
    );
    return StoopComment.fromJson(json);
  }

  @override
  Future<StoopComment> delete({
    required String cardId,
    required String commentId,
    required BackporchUser actor,
    String? cardOwnerId,
    bool canModerate = false,
  }) async {
    final json = await _send(
      'DELETE',
      '/characters/$cardId/comments/$commentId',
    );
    return StoopComment.fromJson(json);
  }

  @override
  Future<void> report({
    required String cardId,
    required String commentId,
    required BackporchUser actor,
    required String category,
    required String reason,
  }) async {
    await _send(
      'POST',
      '/characters/$cardId/comments/$commentId/report',
      body: {'category': category, 'reason': reason},
    );
  }

  @override
  Future<StoopComment> createReply({
    required String cardId,
    required String commentId,
    required String body,
    required BackporchUser author,
    String? cardOwnerId,
  }) async {
    final json = await _send(
      'POST',
      '/characters/$cardId/comments/$commentId/reply',
      body: {'body': body},
    );
    return StoopComment.fromJson(json);
  }

  @override
  Future<StoopComment> deleteReply({
    required String cardId,
    required String commentId,
    required BackporchUser actor,
    String? cardOwnerId,
    bool canModerate = false,
  }) async {
    final json = await _send(
      'DELETE',
      '/characters/$cardId/comments/$commentId/reply',
    );
    return StoopComment.fromJson(json);
  }

  @override
  Future<void> reportReply({
    required String cardId,
    required String commentId,
    required BackporchUser actor,
    required String category,
    required String reason,
  }) async {
    await _send(
      'POST',
      '/characters/$cardId/comments/$commentId/reply/report',
      body: {'category': category, 'reason': reason},
    );
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final token = _token();
    final client = http.Client();
    try {
      final uri = Uri.parse('$_base$path');
      final headers = <String, String>{
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      };
      final http.Response res;
      if (method == 'GET') {
        res = await client.get(uri, headers: headers).timeout(_timeout);
      } else if (method == 'POST') {
        res = await client
            .post(uri, headers: headers, body: jsonEncode(body ?? const {}))
            .timeout(_timeout);
      } else if (method == 'DELETE') {
        res = await client.delete(uri, headers: headers).timeout(_timeout);
      } else {
        throw ArgumentError.value(method, 'method');
      }
      return _parse(res);
    } finally {
      client.close();
    }
  }

  static const _timeout = Duration(seconds: 30);

  static Map<String, dynamic> _parse(http.Response res) {
    Map<String, dynamic> json = <String, dynamic>{};
    if (res.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) json = decoded;
      } catch (_) {}
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    throw BackporchApiException(
      res.statusCode,
      (json['error'] as String?) ?? 'http_${res.statusCode}',
      (json['detail'] as String?)?.trim().isNotEmpty == true
          ? (json['detail'] as String).trim()
          : null,
    );
  }
}
