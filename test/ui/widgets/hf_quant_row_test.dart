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

// Interaction coverage for the model downloader's per-file row.
//
// Regression guard for the "Too Large" hard block: oversize models used to
// render a disabled download button, so users could never download a model
// that didn't fully fit in VRAM — even though KoboldCpp runs them fine with
// partial CPU offload. The button must now always be tappable; oversize
// files confirm through a dialog first, and a failed VRAM detection
// (availableVramMb <= 0) must show a neutral row, not flag everything red.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/models/hf_model.dart';
import 'package:front_porch_ai/ui/widgets/hf_quant_row.dart';

HFModelFile _file({int sizeBytes = 8 * 1024 * 1024 * 1024}) {
  return HFModelFile(
    filename: 'Test-Model-8B-Q4_K_M.gguf',
    downloadUrl:
        'https://huggingface.co/test/Test-Model-GGUF/resolve/main/'
        'Test-Model-8B-Q4_K_M.gguf',
    sizeBytes: sizeBytes,
    repoId: 'test/Test-Model-GGUF',
    paramCountB: 8.0,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required HFModelFile file,
  required int availableVramMb,
  required ValueChanged<HFModelFile> onDownload,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: HFQuantRow(
          file: file,
          availableVramMb: availableVramMb,
          contextSize: 16384,
          onDownload: onDownload,
        ),
      ),
    ),
  );
}

void main() {
  group('HFQuantRow oversize download flow', () {
    testWidgets('oversize file keeps the download button tappable and '
        'downloads after confirming', (tester) async {
      final downloaded = <HFModelFile>[];
      final file = _file(); // 8 GB file vs 4 GB VRAM → exceeds
      await _pump(
        tester,
        file: file,
        availableVramMb: 4096,
        onDownload: downloaded.add,
      );

      final button = find.widgetWithText(ElevatedButton, 'Download');
      expect(button, findsOneWidget);
      expect(tester.widget<ElevatedButton>(button).enabled, isTrue);

      await tester.tap(button);
      await tester.pumpAndSettle();

      expect(find.text('Larger than your VRAM'), findsOneWidget);
      expect(downloaded, isEmpty);

      await tester.tap(find.text('Download Anyway'));
      await tester.pumpAndSettle();

      expect(downloaded, [file]);
      expect(find.text('Larger than your VRAM'), findsNothing);
    });

    testWidgets('cancelling the oversize dialog does not download', (
      tester,
    ) async {
      final downloaded = <HFModelFile>[];
      await _pump(
        tester,
        file: _file(),
        availableVramMb: 4096,
        onDownload: downloaded.add,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Download'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(downloaded, isEmpty);
      expect(find.text('Larger than your VRAM'), findsNothing);
    });

    testWidgets('fitting file downloads immediately without a dialog', (
      tester,
    ) async {
      final downloaded = <HFModelFile>[];
      final file = _file(sizeBytes: 100 * 1024 * 1024); // 100 MB, 24 GB VRAM
      await _pump(
        tester,
        file: file,
        availableVramMb: 24576,
        onDownload: downloaded.add,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Download'));
      await tester.pumpAndSettle();

      expect(find.text('Larger than your VRAM'), findsNothing);
      expect(downloaded, [file]);
    });

    testWidgets('failed VRAM detection shows a neutral row and downloads '
        'without a dialog', (tester) async {
      final downloaded = <HFModelFile>[];
      final file = _file();
      await _pump(
        tester,
        file: file,
        availableVramMb: 0,
        onDownload: downloaded.add,
      );

      expect(find.textContaining('fit unknown'), findsOneWidget);
      expect(find.textContaining('over your VRAM'), findsNothing);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Download'));
      await tester.pumpAndSettle();

      expect(find.text('Larger than your VRAM'), findsNothing);
      expect(downloaded, [file]);
    });
  });
}
