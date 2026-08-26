// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Disk copy of per-model thinking menus (poke + catalog + 400 learn) so
// a second launch does not re-ask Nano for Kimi 2.6's chalkboard.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:front_porch_ai/app_version.dart';
import 'package:front_porch_ai/services/reasoning_effort.dart';
import 'package:front_porch_ai/services/reasoning_effort_probe.dart';

const _kMenusKey = 'reasoning_effort_menus_v1';

SharedPreferences? _prefs;

String _prefKey() => isPreRelease ? 'beta_$_kMenusKey' : _kMenusKey;

/// Load saved menus into the process maps. Call once after prefs exist.
void attachReasoningEffortMenuStore(SharedPreferences? prefs) {
  _prefs = prefs;
  persistReasoningEffortMenuHook = persistReasoningEffortMenu;
  persistReasoningEffortMenusFlushHook = persistAllReasoningEffortMenus;
  final raw = prefs?.getString(_prefKey());
  if (raw == null || raw.isEmpty) return;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return;
    beginReasoningEffortCatalogBatch();
    try {
      decoded.forEach((key, value) {
        if (key is! String || value is! Map) return;
        final efforts =
            (value['efforts'] as List?)
                ?.map((e) => e.toString())
                .where(kReasoningEffortRank.containsKey)
                .toSet() ??
            <String>{};
        if (efforts.isNotEmpty) {
          // A previous poke that stored the host enum (Gemma-on-Nano,
          // 2026-08-25) must not keep showing Minimal…Max after this fix.
          rememberReasoningEffortsForModel(
            key,
            isGenericProviderEffortSchema(efforts) ? const {'none'} : efforts,
            persist: false,
          );
        }
        if (value['mandatory'] == true) {
          rememberMandatoryReasoning(key, persist: false);
        }
        if (value['probed'] == true) {
          rememberReasoningEffortProbed(key);
        }
      });
    } finally {
      endReasoningEffortCatalogBatch();
    }
  } catch (_) {
    // Corrupt blob — ignore; next poke rewrites it.
  }
}

/// Write [model]'s current in-memory menu (and probed flag) to prefs.
void persistAllReasoningEffortMenus() {
  if (_prefs == null) return;
  Map<String, dynamic> all = {};
  try {
    final raw = _prefs!.getString(_prefKey());
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        all = decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    }
  } catch (_) {}
  for (final e in kLearnedReasoningEffortsByModel.entries) {
    final prev = all[e.key] is Map
        ? Map<String, dynamic>.from(all[e.key] as Map)
        : <String, dynamic>{};
    prev['efforts'] = e.value.toList();
    if (kMandatoryReasoningModels.contains(e.key)) prev['mandatory'] = true;
    all[e.key] = prev;
  }
  for (final m in kMandatoryReasoningModels) {
    final prev = all[m] is Map
        ? Map<String, dynamic>.from(all[m] as Map)
        : <String, dynamic>{};
    prev['mandatory'] = true;
    all[m] = prev;
  }
  for (final m in reasoningEffortProbedModels()) {
    final prev = all[m] is Map
        ? Map<String, dynamic>.from(all[m] as Map)
        : <String, dynamic>{};
    prev['probed'] = true;
    all[m] = prev;
  }
  _prefs!.setString(_prefKey(), jsonEncode(all));
}

void persistReasoningEffortMenu(String model, {required bool probed}) {
  if (_prefs == null || model.isEmpty) return;
  if (reasoningEffortCatalogIsBatching) return;
  Map<String, dynamic> all = {};
  try {
    final raw = _prefs!.getString(_prefKey());
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        all = decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    }
  } catch (_) {}
  final efforts = kLearnedReasoningEffortsByModel[model];
  all[model] = {
    if (efforts != null && efforts.isNotEmpty) 'efforts': efforts.toList(),
    if (kMandatoryReasoningModels.contains(model)) 'mandatory': true,
    if (probed) 'probed': true,
  };
  _prefs!.setString(_prefKey(), jsonEncode(all));
}
