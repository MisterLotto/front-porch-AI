// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Tests for the oMLX `/admin/api/stats` → LiveGenProgress mapping. Payload
// shapes captured empirically from oMLX v0.5.1 (2026-07-14).

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/live_gen_progress.dart';
import 'package:front_porch_ai/services/omlx_status_poller.dart';

Map<String, dynamic> stats({
  List<Map<String, dynamic>> prefilling = const [],
  List<Map<String, dynamic>> generating = const [],
  List<Map<String, dynamic>> waiting = const [],
  double avgPrefillTps = 1009.7,
}) => {
  'avg_prefill_tps': avgPrefillTps,
  'active_models': {
    'models': [
      {
        'id': 'gemma-4-31b-it-6bit-abliterated-mlx',
        'active_requests': generating.length + prefilling.length,
        'prefilling': prefilling,
        'generating': generating,
        'waiting': waiting,
      },
    ],
  },
};

void main() {
  test('prefilling entry maps to prompt counts + speed hint', () {
    final p = LiveGenProgress();
    applyOmlxStats(
      stats(
        prefilling: [
          {
            'request_id': 'x',
            'processed': 1024,
            'total': 4456,
            'phase': 'prefill',
          },
        ],
      ),
      p,
    );
    expect(p.promptCurrent, 1024);
    expect(p.promptTotal, 4456);
    expect(p.hintTokensPerSecond, closeTo(1009.7, 0.1));
    expect(p.waitingCount, 0);
  });

  test('generating entry marks prompt done and tracks decode', () {
    final p = LiveGenProgress();
    applyOmlxStats(
      stats(
        generating: [
          {
            'request_id': 'x',
            'generated_tokens': 921,
            'tokens_per_second': 6.7,
            'prompt_tokens': 5079,
            'max_tokens': 4000,
          },
        ],
      ),
      p,
    );
    expect(p.promptCurrent, 5079);
    expect(p.promptTotal, 5079);
    expect(p.promptFraction(), 1.0);
    expect(p.genCurrent, 921);
    expect(p.genTotal, 4000);
  });

  test('waiting queue count is reported neutrally and clears', () {
    final p = LiveGenProgress();
    applyOmlxStats(
      stats(waiting: [{'request_id': 'q'}]),
      p,
    );
    expect(p.waitingCount, 1);
    applyOmlxStats(stats(), p);
    expect(p.waitingCount, 0);
  });

  test('malformed payloads are ignored safely', () {
    final p = LiveGenProgress();
    applyOmlxStats(null, p);
    applyOmlxStats({'active_models': 'nope'}, p);
    applyOmlxStats({'active_models': {'models': 42}}, p);
    expect(p.promptTotal, 0);
  });
}
