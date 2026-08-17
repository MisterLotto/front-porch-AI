// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';

import 'package:front_porch_ai/services/backporch/backporch.dart';

BackporchUser _user({bool verified = true}) => BackporchUser(
  id: 'u1',
  email: 'a@b.c',
  displayName: 'Tester',
  role: 'USER',
  ageVerified: true,
  emailVerified: verified,
  nsfwEnabled: false,
  acceptedPolicyVersion: '1.0',
  twoFactorEnabled: false,
);

void main() {
  test('unsigned and unverified accounts cannot report', () {
    expect(stoopCanReport(null), isFalse);
    expect(stoopCanReport(_user(verified: false)), isFalse);
    expect(stoopCanReport(_user()), isTrue);
  });

  test('a written reason is required — category is not enough', () {
    expect(stoopReportReasonOk(''), isFalse);
    expect(stoopReportReasonOk('   '), isFalse);
    expect(stoopReportReasonOk('stolen art from chub'), isTrue);
  });

  test('report API codes map to real sentences', () {
    expect(
      stoopReportFailureMessage(
        const BackporchApiException(403, 'email_not_verified'),
      ),
      contains('Confirm your email'),
    );
    expect(
      stoopReportFailureMessage(
        const BackporchApiException(400, 'reason_required'),
      ),
      'Please add a reason.',
    );
    expect(stoopReportFailureMessage(Exception('nope')), contains('Try again'));
  });
}
