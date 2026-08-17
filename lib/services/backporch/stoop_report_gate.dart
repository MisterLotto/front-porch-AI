// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Who may file a Stoop report, and how API failures read to the user.
// Mirrors the hub + POST /reports gate (2026-08): signed-in, email verified,
// non-blank reason. Guests and unverified accounts must not even open Report.

import 'package:front_porch_ai/services/backporch/backporch_api.dart';
import 'package:front_porch_ai/services/backporch/backporch_user.dart';

/// True only for a signed-in account whose email is confirmed.
///
/// [BackporchUser.emailVerified] defaults **true** when an older server omits
/// the field — same as the hub. Block only when the live user is present and
/// the flag is explicitly false.
bool stoopCanReport(BackporchUser? user) => user != null && user.emailVerified;

/// A written reason is required. Category alone is not a reason.
bool stoopReportReasonOk(String reason) => reason.trim().isNotEmpty;

/// Map `/reports` failures to a short sentence. Unknown codes stay generic.
String stoopReportFailureMessage(Object error) {
  if (error is BackporchApiException) {
    switch (error.code) {
      case 'email_not_verified':
        return 'Confirm your email first — check your inbox, or resend from Account.';
      case 'reason_required':
        return 'Please add a reason.';
      case 'already_reported':
        return 'You already have an open report on this card.';
      case 'too_many_reports':
        return 'You’ve filed a lot of reports recently — please wait a while.';
      case 'cannot_report_own':
        return 'You can’t report your own card.';
      case 'unauthorized':
        return 'Sign in to report a character.';
    }
  }
  return 'Couldn’t file that report. Try again.';
}
