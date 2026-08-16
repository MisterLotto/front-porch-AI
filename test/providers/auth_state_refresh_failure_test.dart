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

// A SERVER HICCUP MUST NOT SIGN THE USER OUT OF THE STOOP FOR GOOD.
//
// Restoring a saved session on the first visit to The Stoop normally goes
// /auth/me → 401 (access tokens live ~15 min) → /auth/refresh. That second
// request used to destroy the tokens on ANY failure — a timeout on hotel
// wifi, a 502 from a backend redeploy, a 429 — which meant re-entering email,
// password and a TOTP code even though the saved session was perfectly good.
// The sibling /auth/me branch has always been careful about exactly this, and
// `_clearSession`'s own doc promises "the on-disk tokens are left untouched".
//
// Red-proved: restoring the blanket `catch (_) { await _store.clear(); }`
// makes both "tokens survive" tests fail (the store comes back empty).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/providers/auth_state.dart';
import 'package:front_porch_ai/services/backporch/backporch.dart';

class _FakeApi extends BackporchApi {
  _FakeApi({required this.refreshFailure});

  /// Thrown by [refresh]; [me] always answers a genuine 401 so init falls
  /// through to the refresh branch — the only way to reach the bug.
  final Object refreshFailure;
  int refreshCalls = 0;

  @override
  Future<({BackporchUser user, String policyVersion})> me(
    String accessToken,
  ) async {
    throw const BackporchApiException(401, 'token_expired');
  }

  @override
  Future<AuthResult> refresh(String refreshToken) async {
    refreshCalls++;
    throw refreshFailure;
  }
}

Future<AuthState> _restoreWith(Object refreshFailure) async {
  SharedPreferences.setMockInitialValues({});
  final store = BackporchAuthStore();
  await store.save(accessToken: 'stale-access', refreshToken: 'good-refresh');
  final state = AuthState(api: _FakeApi(refreshFailure: refreshFailure), store: store);
  await state.init();
  return state;
}

Future<StoredTokens> _tokensOnDisk() => BackporchAuthStore().read();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a timed-out /auth/refresh leaves the saved session on disk', () async {
    final state = await _restoreWith(TimeoutException('no answer'));
    expect(state.status, AuthStatus.loggedOut);
    final tokens = await _tokensOnDisk();
    expect(
      tokens.refresh,
      'good-refresh',
      reason: 'the server never answered — the token is not known to be bad',
    );
    state.dispose();
  });

  test('a 502 from /auth/refresh leaves the saved session on disk', () async {
    final state = await _restoreWith(
      const BackporchApiException(502, 'bad_gateway'),
    );
    expect(state.status, AuthStatus.loggedOut);
    final tokens = await _tokensOnDisk();
    expect(tokens.refresh, 'good-refresh');
    expect(tokens.access, 'stale-access');
    state.dispose();
  });

  test('a 401 from /auth/refresh really does clear the dead session', () async {
    final state = await _restoreWith(
      const BackporchApiException(401, 'invalid_refresh_token'),
    );
    expect(state.status, AuthStatus.loggedOut);
    final tokens = await _tokensOnDisk();
    expect(tokens.hasRefresh, isFalse);
    expect(tokens.access, isNull);
    state.dispose();
  });
}
