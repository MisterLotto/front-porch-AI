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

import 'package:front_porch_ai/database/database.dart' hide World;
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';
import 'package:front_porch_ai/services/chargen/chargen.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/widgets/widgets.dart';
import 'package:front_porch_ai/utils/utils.dart';

import 'package:front_porch_ai/ui/pages/home/dialogs/session_picker_dialog.dart';
import 'package:front_porch_ai/ui/pages/home/enhance/enhance_options_dialog.dart';
import 'package:front_porch_ai/ui/pages/home/enhance/enhance_review_page.dart';
import 'package:front_porch_ai/ui/pages/home/enhance/enhance_setup_page.dart';

/// The whole "AI Enhance" journey from the home-screen context menu:
/// pick a chat (auto at one, friendly notice at zero) → field checklist →
/// grounded pipeline behind a progress dialog → review page. Nothing is
/// written anywhere until the review page's Save.
Future<void> runAiEnhanceFlow(
  BuildContext context,
  CharacterCard character,
) async {
  final chat = Provider.of<ChatService>(context, listen: false);
  // getSessionsForId resolves by imagePath basename — passing the dbId UUID
  // silently returns [] (the documented fall-through). 1:1 chats only in v1.
  final sessions = await chat.getSessionsForId(character.stableGroupId);
  if (!context.mounted) return;

  if (sessions.isEmpty) {
    await showWarmDialog<void>(
      context,
      title: 'No chats yet',
      icon: Icons.chat_bubble_outline,
      accent: AppColors.porchAmberOf(context),
      content: Text(
        'AI Enhance grows ${character.name} from a real conversation — the '
        'chat is what teaches the AI their true voice. Have a chat with '
        '${character.name} first, then come back.',
        style: TextStyle(color: AppColors.textSecondary(context)),
      ),
      actions: [warmDialogCancel(context, label: 'Got it')],
    );
    return;
  }

  String? sessionId;
  if (sessions.length == 1) {
    sessionId = sessions.first['id'] as String;
  } else {
    sessionId = await showSessionPickerDialog(
      context,
      sessions,
      character.name,
      allowNew: false,
      title: 'Enhance ${character.name} from which chat?',
    );
    if (sessionId == null || !context.mounted) return;
  }

  // Assemble the grounding material before asking about fields, so the
  // options dialog can warn about a too-short chat.
  final db = Provider.of<AppDatabase>(context, listen: false);
  final enhanceContext = await buildEnhanceContext(
    db: db,
    card: character,
    sessionId: sessionId,
  );
  if (!context.mounted) return;

  // The creator wizard's FULL Backend & Model step (KoboldCpp local with
  // .gguf pick/launch, Remote API, oMLX), hosted as Enhance's model picker.
  // Pops with the remote model id ('' on local) once a backend is ready.
  final pickedModelId = await Navigator.of(context).push<String>(
    MaterialPageRoute(
      builder: (_) => EnhanceSetupPage(characterName: character.name),
    ),
  );
  if (pickedModelId == null || !context.mounted) return;

  final options = await showEnhanceOptionsDialog(
    context,
    characterName: character.name,
    defaultNsfw:
        character.frontPorchExtensions?.nsfwCooldownEnabled ?? false,
    userTurnCount: enhanceContext.userTurnCount,
  );
  if (options == null || !context.mounted) return;

  final llmProvider = Provider.of<LLMProvider>(context, listen: false);
  final storage = Provider.of<StorageService>(context, listen: false);
  // Same resolver the creator wizard uses: active service, or an ad-hoc
  // remote service for the setup page's pick.
  final llm = llmProvider.serviceForModel(pickedModelId);
  if (llm == null) {
    // The backend went away between the setup page and here (e.g. Kobold
    // crashed while the options dialog was open).
    await showWarmDialog<void>(
      context,
      title: 'The AI isn\'t running',
      icon: Icons.power_off,
      destructive: true,
      content: Text(
        'AI Enhance needs your AI backend to be running. Start it from '
        'Settings → Backend (or connect a remote API), then try again.',
        style: TextStyle(color: AppColors.textSecondary(context)),
      ),
      actions: [warmDialogCancel(context, label: 'Got it')],
    );
    return;
  }

  final grounding = buildChatExcerptBlock(
    turns: enhanceContext.turns,
    recap: enhanceContext.recap,
    memoryCards: enhanceContext.memoryCards,
    maxChars: enhanceGroundingCharBudget(
      isLocalKobold: llmProvider.activeBackend == BackendType.kobold &&
          llmProvider.koboldService.isReady,
      contextSize: storage.contextSize,
    ),
  );

  final gen = CharacterGenService(llm);
  final status = ValueNotifier<String>('Getting ready...');
  final preview = ValueNotifier<String>('');
  var cancelled = false;
  String? errorMessage;

  // Progress dialog — not awaited; the pipeline await below owns the flow.
  // ignore: unawaited_futures
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dctx) => PopScope(
      canPop: false,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceOf(dctx),
        title: Row(
          children: [
            Icon(Icons.auto_awesome,
                color: AppColors.porchAmberOf(dctx), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Enhancing ${character.name}',
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary(dctx),
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ValueListenableBuilder<String>(
                valueListenable: status,
                builder: (_, s, _) => Text(
                  s,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(dctx),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                backgroundColor: AppColors.surfaceContainerOf(dctx),
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.porchAmberOf(dctx),
                ),
              ),
              const SizedBox(height: 10),
              ValueListenableBuilder<String>(
                valueListenable: preview,
                builder: (_, p, _) => p.isEmpty
                    ? const SizedBox.shrink()
                    : Container(
                        constraints: const BoxConstraints(maxHeight: 140),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerOf(dctx),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: SingleChildScrollView(
                          reverse: true,
                          child: Text(
                            p,
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiary(dctx),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelled = true;
              gen.abort();
              Navigator.of(dctx).pop();
            },
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary(dctx)),
            ),
          ),
        ],
      ),
    ),
  );

  final enhanced = await gen.enhanceCharacter(
    source: character,
    selection: options.selection,
    chatGrounding: grounding,
    nsfwEnabled: options.nsfw,
    // A home-screen action must not kill evals a background chat may have
    // in flight on the shared backend (Scene Guest precedent).
    abortInFlight: false,
    onStatus: (s) => status.value = s,
    onProgress: (p) => preview.value = p,
    onError: (e) => errorMessage = e,
  );

  if (!context.mounted) return;
  if (!cancelled) Navigator.of(context, rootNavigator: true).pop();
  if (cancelled) return;

  if (enhanced == null) {
    await showWarmDialog<void>(
      context,
      title: 'Enhance didn\'t finish',
      icon: Icons.error_outline,
      destructive: true,
      content: Text(
        errorMessage == null
            ? 'The AI didn\'t produce a usable result. This usually means the '
                'model struggled with the task — try again, or try a '
                'different model.'
            : 'The AI ran into a problem: $errorMessage',
        style: TextStyle(color: AppColors.textSecondary(context)),
      ),
      actions: [warmDialogCancel(context, label: 'Close')],
    );
    return;
  }

  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => EnhanceReviewPage(
        original: character,
        enhanced: enhanced,
        selection: options.selection,
      ),
    ),
  );
}
