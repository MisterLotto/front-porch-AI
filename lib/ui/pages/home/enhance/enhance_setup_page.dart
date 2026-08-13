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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/ui/character_creator/character_creator.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';

/// AI Enhance's Backend & Model step — the creator wizard's REAL [SetupStep]
/// widget (KoboldCpp local with .gguf pick/launch/presets, Remote API, oMLX),
/// hosted standalone so Enhance offers the identical full picker rather than
/// a cut-down row. Pops with the selected remote model id ('' on local — the
/// launched model IS the model) once a backend is actually ready, or null on
/// cancel. Backend/model choices behave exactly as in the creator, including
/// which backend is active — same surface, same semantics.
class EnhanceSetupPage extends StatefulWidget {
  const EnhanceSetupPage({super.key, required this.characterName});

  final String characterName;

  @override
  State<EnhanceSetupPage> createState() => _EnhanceSetupPageState();
}

class _EnhanceSetupPageState extends State<EnhanceSetupPage> {
  late final CreatorState creatorState = CreatorState();

  void _onCreatorStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    // Same init recipe as CharacterCreatorPage: restore the saved backend/
    // model choices (shared prefs with the creator — one consistent answer to
    // "which model does AI generation use"), then scan pickers.
    creatorState.loadSavedState();
    creatorState.addListener(_onCreatorStateChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final storage = Provider.of<StorageService>(context, listen: false);
        creatorState.scanLocalModels(storage);
        creatorState.scanLocalPresets(storage);
        creatorState.initLocalSettingsControllers(storage);
        Provider.of<ModelManager>(context, listen: false).refreshModels();
        if (creatorState.selectedLocalModelPath.isEmpty &&
            storage.lastUsedModelPath != null &&
            storage.lastUsedModelPath!.isNotEmpty) {
          creatorState.selectedLocalModelPath = storage.lastUsedModelPath!;
          creatorState.notify();
        }
        final llm = Provider.of<LLMProvider>(context, listen: false);
        if (!llm.hasManagedProcess) {
          creatorState.loadAvailableModels(llm);
        }
      } catch (_) {
        // Providers may not be ready in some edge cases; non-fatal.
      }
    });
  }

  @override
  void dispose() {
    creatorState.removeListener(_onCreatorStateChanged);
    creatorState.disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch the pieces whose changes flip readiness (Kobold finishing its
    // model load, a backend switch) so the Continue button updates live.
    final llmProvider = context.watch<LLMProvider>();
    context.watch<KoboldService>();
    final ready =
        llmProvider.serviceForModel(creatorState.selectedModelId) != null;

    return Scaffold(
      backgroundColor: AppColors.backgroundOf(context),
      appBar: AppBar(
        backgroundColor: AppColors.surfaceOf(context),
        foregroundColor: AppColors.textPrimary(context),
        title: Row(
          children: [
            Icon(Icons.auto_awesome,
                color: AppColors.porchAmberOf(context), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'AI Enhance ${widget.characterName}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: SetupStep(state: creatorState),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceOf(context),
            border:
                Border(top: BorderSide(color: AppColors.borderOf(context))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary(context),
                    side: BorderSide(color: AppColors.borderOf(context)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: ready
                      ? () => Navigator.of(context)
                          .pop(creatorState.selectedModelId)
                      : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.porchAmberOf(context),
                    foregroundColor: AppColors.onChaosAccent,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.arrow_forward, size: 18),
                  label: Text(
                    ready ? 'Continue' : 'Waiting for a ready backend...',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
