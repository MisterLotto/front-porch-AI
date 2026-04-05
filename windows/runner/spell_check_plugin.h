// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

#ifndef RUNNER_SPELL_CHECK_PLUGIN_H_
#define RUNNER_SPELL_CHECK_PLUGIN_H_

#include <flutter/plugin_registrar_windows.h>

/// Registers the spell-check method-channel plugin with the Flutter engine.
///
/// The plugin handles the `front_porch_ai/spell_check` channel and delegates
/// to the Windows Spell Checking API (ISpellChecker / ISpellCheckerFactory,
/// available on Windows 8+).
class SpellCheckPlugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar);
};

#endif  // RUNNER_SPELL_CHECK_PLUGIN_H_
