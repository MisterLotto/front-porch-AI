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
import 'package:front_porch_ai/ui/pages/repository/stoop_glass.dart';

/// Open the change-email dialog (from the account sheet).
Future<void> showStoopChangeEmail(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _ChangeEmailDialog(),
  );
}

/// Change the sign-in email. The server re-authenticates (current password,
/// plus the 2FA code when enabled — revealed only when it asks) and mails a
/// confirmation link to the NEW address; nothing changes until it's clicked.
class _ChangeEmailDialog extends StatefulWidget {
  const _ChangeEmailDialog();

  @override
  State<_ChangeEmailDialog> createState() => _ChangeEmailDialogState();
}

class _ChangeEmailDialogState extends State<_ChangeEmailDialog> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _totp = TextEditingController();
  bool _needTotp = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _totp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await context.read<AuthState>().changeEmail(
        newEmail: email,
        password: _password.text.isEmpty ? null : _password.text,
        totp: _needTotp ? _totp.text.trim() : null,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Confirmation sent to $email — the change lands when that '
              'inbox opens the link.',
            ),
          ),
        );
      }
    } on BackporchApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (e.code == 'two_factor_required') {
          _needTotp = true;
          _error = _totp.text.isEmpty
              ? 'Enter the 6-digit code from your authenticator app.'
              : 'That code didn’t match — try again.';
        } else {
          _error = switch (e.code) {
            'email_taken' => 'That address already has a Stoop account.',
            'disposable_email' =>
              'Please use a permanent email address — throwaway addresses '
                  "aren't accepted.",
            'undeliverable_email' =>
              "That domain can't receive email. Check the address.",
            'same_email' => 'That’s already your sign-in email.',
            'wrong_password' => 'That password didn’t match.',
            'resend_too_soon' =>
              'A confirmation just went out — give it a couple of minutes.',
            _ => 'Couldn’t start the change. Try again.',
          };
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Couldn’t start the change. Check your connection.';
        });
      }
    }
  }

  Future<void> _cancelPending() async {
    setState(() => _busy = true);
    try {
      await context.read<AuthState>().cancelEmailChange();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Couldn’t cancel that. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthState>().user;
    final pending = user?.pendingEmail;
    return AlertDialog(
      backgroundColor: stoopCard2(context),
      title: Text('Change email', style: TextStyle(color: stoopCream(context))),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We’ll send a confirmation link to the new address; your '
              'account keeps ${user?.email ?? 'its current email'} until '
              'that link is opened. This also counts as proving the new '
              'address for sharing and profile photos.',
              style: TextStyle(color: stoopCream2(context), fontSize: 13),
            ),
            if (pending != null) ...[
              const SizedBox(height: 10),
              Text(
                'Currently waiting on $pending to confirm.',
                style: TextStyle(color: stoopAmberText(context), fontSize: 13),
              ),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _email,
              autofocus: true,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: stoopCream(context)),
              decoration: stoopInput(context, 'new@example.com'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              style: TextStyle(color: stoopCream(context)),
              decoration: stoopInput(context, 'Current password'),
            ),
            if (_needTotp) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _totp,
                enabled: !_busy,
                style: TextStyle(color: stoopCream(context)),
                decoration: stoopInput(context, 'Authenticator code'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: TextStyle(
                  color: stoopEmberText(context),
                  fontSize: 12.5,
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (pending != null)
          TextButton(
            onPressed: _busy ? null : _cancelPending,
            child: Text(
              'Cancel pending change',
              style: TextStyle(color: stoopEmberText(context)),
            ),
          ),
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Close'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Send confirmation'),
        ),
      ],
    );
  }
}
