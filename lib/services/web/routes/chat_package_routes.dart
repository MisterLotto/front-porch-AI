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
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';

import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/services/web/facade/chat_package_facade.dart';
import 'package:front_porch_ai/services/web/util/util.dart';

/// Web twin of desktop Import / Export Chat. The host runs the same
/// [ChatService] package I/O; the browser only downloads or uploads bytes.
class WebChatPackageRoutes {
  WebChatPackageRoutes(this._facade, Router router) {
    router.get('/api/chat/export.fpchat', _exportFpchat);
    router.get('/api/chat/export.jsonl', _exportJsonl);
    router.post('/api/chat/import', _import);
  }

  final ChatPackageFacade _facade;

  Future<shelf.Response> _exportFpchat(shelf.Request request) async {
    final bytes = await _facade.exportFpchat();
    if (bytes == null) {
      return JsonResponse.error(404, 'No chat to export');
    }
    return shelf.Response.ok(
      bytes,
      headers: {
        'Content-Type': 'application/zip',
        'Content-Disposition': 'attachment',
        'Cache-Control': 'no-store',
      },
    );
  }

  shelf.Response _exportJsonl(shelf.Request request) {
    final text = _facade.exportJsonl();
    if (text == null) {
      return JsonResponse.error(404, 'No chat to export');
    }
    return shelf.Response.ok(
      text,
      headers: {
        'Content-Type': 'application/x-ndjson; charset=utf-8',
        'Content-Disposition': 'attachment',
        'Cache-Control': 'no-store',
      },
    );
  }

  Future<shelf.Response> _import(shelf.Request request) async {
    final mismatch = request.url.queryParameters['mismatch'];
    if (mismatch != null && mismatch != 'full' && mismatch != 'dialogue') {
      return JsonResponse.badRequest('mismatch must be full or dialogue');
    }
    late final List<int> bytes;
    try {
      bytes = await RequestBody.readBytes(
        request,
        maxBytes: RequestBody.packageMaxBytes,
      );
    } on BodyTooLarge {
      return JsonResponse.error(
        413,
        'Chat file is too large (limit 256 MB). Import on desktop instead.',
      );
    }
    if (bytes.isEmpty) return JsonResponse.badRequest('Empty upload');
    try {
      final outcome = await _facade.importBytes(
        bytes,
        mismatch: mismatch,
      );
      return JsonResponse.ok({
        'fullRestore': outcome.fullRestore,
        if (outcome.warning != null) 'warning': outcome.warning,
      });
    } on ChatPackageMismatch catch (e) {
      return JsonResponse.error(
        409,
        'character_mismatch',
        extra: {
          'packageName': e.packageName,
          'activeName': e.activeName,
        },
      );
    } on ChatImportBusy catch (e) {
      return JsonResponse.error(409, e.toString());
    } catch (e) {
      final mapped = _importError(e);
      if (mapped != null) return JsonResponse.badRequest(mapped);
      return JsonResponse.error(
        500,
        'Import failed. Try again, or import on desktop.',
      );
    }
  }
}

String? _importError(Object e) {
  final s = e.toString();
  debugPrint('[chat-import] $s');
  if (s.contains('No active character or group')) {
    return 'Open a character or group first, then import.';
  }
  if (s.contains('unpacks larger than')) {
    return 'Chat file is too large once unpacked. Import on desktop instead.';
  }
  if (s.contains('Unrecognized chat file format') ||
      s.contains('ArchiveException') ||
      s.contains('FormatException') ||
      e is FormatException) {
    return 'That file is not a Front Porch or SillyTavern chat.';
  }
  return null;
}
