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

// Public result types for AuthService (kept out of the service file so the
// implementation stays under the 500-line cap).

/// Outcome of a login attempt.
enum LoginStatus {
  success,
  invalidCredentials,
  totpRequired,
  lockedOut,
  rateLimited,
  notSetUp,
}

/// Outcome of first-run account setup (audit P0.5).
enum SetupStatus {
  success,
  alreadyConfigured,
  invalidInput,

  /// Remote/LAN/proxied client must supply the desktop-shown one-time token.
  tokenRequired,
  invalidToken,
  rateLimited,
}

class LoginResult {
  const LoginResult(this.status, {this.token, this.retryAfterSeconds});
  final LoginStatus status;
  final String? token; // raw session cookie token on success
  final int? retryAfterSeconds;
}

/// Result of beginning TOTP enrollment — secret + QR URI for the authenticator.
class TotpEnrollment {
  const TotpEnrollment(this.secret, this.provisioningUri);
  final String secret;
  final String provisioningUri;
}

/// Outcome of a credential change (or another re-authenticated operation).
enum CredentialChangeStatus {
  success,
  invalidCurrentPassword,
  totpRequired,
  invalidInput,
  notSetUp,
  lockedOut,

  /// 2FA is already on — re-enroll is refused; disable first, then enroll.
  alreadyEnabled,
}

/// Outcome of begin TOTP enrollment (password step-up required).
class TotpBeginResult {
  const TotpBeginResult(this.status, {this.enrollment});
  final CredentialChangeStatus status;
  final TotpEnrollment? enrollment;
}

/// Outcome of confirm TOTP enrollment (password step-up required).
class TotpConfirmResult {
  const TotpConfirmResult(this.status, {this.recoveryCodes});
  final CredentialChangeStatus status;
  final List<String>? recoveryCodes;
}
