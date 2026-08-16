// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A BAD DOWNLOAD MUST NEVER BECOME "THE INSTALLER" (1.3 sweep, 2026-08-15).
//
// downloadUpdate() used to mark _downloadComplete on whatever bytes arrived —
// no HTTP status check, no length check. On Linux the install path then
// deleted the RUNNING AppImage before copying, so a 404 page or a truncated
// stream could uninstall the app outright. The download now requires
// HTTP 200 + validateInstallerDownload; the AppImage swap is copy-then-
// atomic-rename so a failed copy leaves the old app untouched (that ordering
// is Process.run plumbing, exercised only on a real Linux install — this
// suite pins the validation half).

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/update_service.dart';

void main() {
  test('truncated download is rejected', () {
    expect(
      UpdateService.validateInstallerDownload(
        receivedBytes: 10 * 1024 * 1024,
        expectedBytes: 90 * 1024 * 1024,
      ),
      contains('truncated'),
    );
  });

  test('tiny body (an HTML error page) is rejected even with matching length',
      () {
    expect(
      UpdateService.validateInstallerDownload(
        receivedBytes: 5 * 1024,
        expectedBytes: 5 * 1024,
      ),
      contains('implausibly small'),
    );
  });

  test('a real installer passes', () {
    expect(
      UpdateService.validateInstallerDownload(
        receivedBytes: 90 * 1024 * 1024,
        expectedBytes: 90 * 1024 * 1024,
      ),
      isNull,
    );
    // Servers that omit Content-Length still pass on size alone.
    expect(
      UpdateService.validateInstallerDownload(
        receivedBytes: 90 * 1024 * 1024,
        expectedBytes: 0,
      ),
      isNull,
    );
  });
}
