// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

// Portrait promotion is a SWAP, not a destroy (2026-08-14, maintainer-
// approved): the ★/first look's pixels move into the portrait slot AND the
// old portrait's pixels demote into the gallery as a new look — the action
// is fully reversible and no image is ever lost. These drive the real
// promoteLookOverPortrait leaf against real files with captured callbacks.
//
// Red-proven: with the addLook demotion call removed from the leaf, the
// first test's 'old portrait demotes into the gallery' assert fails.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/portrait_promotion.dart';
import 'package:front_porch_ai/services/services.dart';

void _setupPathProviderMock() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        if (call.method == 'getApplicationDocumentsDirectory') {
          return Directory.systemTemp.createTempSync('fpai_swap_').path;
        }
        return null;
      });
}

Uint8List _pngOf(int r, int g, int b) {
  final im = img.Image(width: 4, height: 4);
  img.fill(im, color: img.ColorRgb8(r, g, b));
  return img.encodePng(im);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  _setupPathProviderMock();

  late StorageService storage;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    storage = StorageService();
    await storage.initialized;
  });

  test('promotion swaps: look pixels become the portrait, old portrait '
      'pixels demote into the gallery, promoted look row is removed',
      () async {
    final oldPortrait = _pngOf(10, 20, 30);
    final lookPixels = _pngOf(200, 100, 50);

    await storage.charactersDir.create(recursive: true);
    final portraitFile = File(
      '${storage.charactersDir.path}/Swappy_123.png',
    );
    await portraitFile.writeAsBytes(oldPortrait);

    final card = CharacterCard(name: 'Swappy', description: 'swap test')
      ..dbId = 'char-swap-1'
      ..imagePath = portraitFile.path;

    final look = AvatarImage(
      id: 'look-1',
      characterId: 'char-swap-1',
      filename: 'look1.png',
      label: AvatarImage.lookLabel,
      displayOrder: 0,
      createdAt: DateTime(2026),
    );
    final lookFile = look.resolveFile(
      storage.characterBaseDir(card.name).path,
    );
    await lookFile.create(recursive: true);
    await lookFile.writeAsBytes(lookPixels);
    card.avatarImages = [look];

    final removed = <String>[];
    Uint8List? demoted;
    final promotedId = await promoteLookOverPortrait(
      card: card,
      storage: storage,
      updateCharacter: (_) async {},
      removeAvatar: (_, id) async => removed.add(id),
      addLook: (_, _, bytes) async {
        demoted = bytes;
        return 'demoted-look-id';
      },
    );

    expect(promotedId, 'look-1');
    expect(removed, ['look-1']);
    expect(
      await portraitFile.readAsBytes(),
      lookPixels,
      reason: 'the look\'s pixels now live in the portrait slot (same path)',
    );
    expect(
      demoted,
      isNotNull,
      reason: 'the old portrait demotes into the gallery',
    );
    expect(demoted, oldPortrait, reason: 'byte-for-byte, nothing lost');
  });

  test('an unreadable old portrait skips the demotion (nothing to preserve)',
      () async {
    final card = CharacterCard(name: 'Ghost', description: 'no portrait')
      ..dbId = 'char-swap-2'
      ..imagePath = '${storage.charactersDir.path}/does_not_exist.png';

    final look = AvatarImage(
      id: 'look-9',
      characterId: 'char-swap-2',
      filename: 'look9.png',
      label: AvatarImage.lookLabel,
      displayOrder: 0,
      createdAt: DateTime(2026),
    );
    final lookFile = look.resolveFile(
      storage.characterBaseDir(card.name).path,
    );
    await lookFile.create(recursive: true);
    await lookFile.writeAsBytes(_pngOf(1, 2, 3));
    card.avatarImages = [look];

    var addLookCalls = 0;
    await promoteLookOverPortrait(
      card: card,
      storage: storage,
      updateCharacter: (_) async {},
      removeAvatar: (_, _) async {},
      addLook: (_, _, _) async {
        addLookCalls++;
        return 'x';
      },
    );
    expect(addLookCalls, 0);
  });
}
