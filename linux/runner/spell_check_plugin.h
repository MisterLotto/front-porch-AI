// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

#ifndef RUNNER_SPELL_CHECK_PLUGIN_H_
#define RUNNER_SPELL_CHECK_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

// Registers the `front_porch_ai/spell_check` method channel on |registrar|.
//
// Called from my_application.cc rather than the generated plugin registrant,
// which is a generated file and must not be edited. This mirrors how the
// Windows runner registers its own SpellCheckPlugin from flutter_window.cpp.
void spell_check_plugin_register_with_registrar(FlPluginRegistrar* registrar);

G_END_DECLS

#endif  // RUNNER_SPELL_CHECK_PLUGIN_H_
