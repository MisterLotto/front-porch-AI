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

// NO ACCOUNT = NO MODELS (maintainer report, 2026-08-13). With no Remote API
// key configured, fetchImageModels used to return the curated catalog — so
// the Image Studio's Remote API option showed a real-looking model menu to a
// user who had configured nothing, who reasonably concluded remote images
// were free and local, then hit "No API key configured." on Generate (in an
// unreadable banner, at the time). The catalog is a convenience for
// CONFIGURED providers without an image-listing endpoint (Nano-GPT), never a
// stand-in for having an account.
//
// Guard proven to fail before passing: with the empty-key branch restored to
// `List.from(_commonImageModels)`, the no-key case goes red.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/services/services.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_imodels_').path;
        }
        return null;
      });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  test('no API key configured → no models listed', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.initialized;
    final svc = ImageGenService(storage);

    expect(
      await svc.fetchImageModels(),
      isEmpty,
      reason: 'a populated menu with no account is the false affordance that '
          'made Remote API generation look free',
    );
  });

  test('configured non-OpenRouter provider still gets the curated catalog',
      () async {
    SharedPreferences.setMockInitialValues({});
    final storage = StorageService();
    await storage.initialized;
    await storage.backendSettings.setRemoteApiKey('nk-test');
    await storage.backendSettings.setRemoteApiUrl(
      'https://nano-gpt.com/api/v1',
    );
    final svc = ImageGenService(storage);

    final models = await svc.fetchImageModels();
    expect(
      models,
      isNotEmpty,
      reason: 'Nano-GPT has no image-listing endpoint — the curated catalog '
          'is the legitimate fallback ONCE an account exists',
    );
  });
}
