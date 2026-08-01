// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/providers/auth_state.dart';
import 'package:front_porch_ai/services/backporch/backporch.dart';
import 'package:front_porch_ai/ui/pages/repository/repository.dart';

/// The Front Porch repository — a full page (opened from the sidebar, like the
/// AI Character Creator). An account is required only here; the rest of the app
/// stays local/offline. Logged out → login/signup; signed in but hasn't agreed
/// to the live AUP → policy gate; fully in → the repository (currently a "signed
/// in" placeholder until the browse UI lands).
class RepositoryPage extends StatelessWidget {
  const RepositoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Bring the (lazy) analytics listener to life now that the hub is open. It
    // self-gates on sign-in + the opt-out flag, so this is a no-op for signed-out
    // or opted-out users; constructing it here keeps non-hub launches network-free.
    context.read<StoopAnalytics>();
    return Consumer<AuthState>(
      builder: (context, auth, _) {
        // The account menu is offered only once the user is fully in (past the
        // gate); the gate carries its own decline/sign-out action.
        final showAccount = auth.isLoggedIn && !auth.needsPolicyAcceptance;
        return Scaffold(
          backgroundColor: stoopBg0(context),
          appBar: AppBar(
            centerTitle: false,
            titleSpacing: 4,
            elevation: 0,
            shape: Border(bottom: BorderSide(color: stoopBorder(context))),
            // Hub nav: lantern glyph + serif wordmark in cream, amber accent.
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('🏡', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text('The Stoop', style: stoopDisplay(context, size: 20)),
              ],
            ),
            backgroundColor: stoopBg0(context),
            foregroundColor: stoopCream(context),
            actions: [
              if (showAccount) const StoopInboxBell(),
              if (showAccount)
                IconButton(
                  tooltip: 'Account',
                  icon: const Icon(Icons.account_circle_outlined),
                  onPressed: () => showStoopAccountSheet(context),
                ),
            ],
          ),
          body: _body(auth),
        );
      },
    );
  }

  Widget _body(AuthState auth) {
    switch (auth.status) {
      case AuthStatus.unknown:
        return const Center(child: CircularProgressIndicator());
      case AuthStatus.loggedOut:
        return const RepositoryAuthView();
      case AuthStatus.loggedIn:
        if (auth.needsPolicyAcceptance) return const StoopPolicyGate();
        return const StoopSignedIn();
    }
  }
}
