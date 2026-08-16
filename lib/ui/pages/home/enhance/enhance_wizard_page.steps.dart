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

part of 'enhance_wizard_page.dart';

/// Step bodies for [EnhanceWizardPage] (a `part`, same layout convention as
/// settings_page.*.dart): About (the explainer), Chat (which conversation
/// grounds the rewrite), Interview (checklist + inline pipeline run) and
/// Chats (bring the base character's chats along). The Model step is the
/// creator's real [SetupStep] and Review is [EnhanceReviewBody] — both
/// mounted straight from the shell's switcher.
extension _EnhanceWizardSteps on _EnhanceWizardPageState {
  // ── Step 0: About ───────────────────────────────────────────────────────

  Widget _buildAboutStep(BuildContext context) {
    final name = widget.character.name;
    final howItWorks = [
      (
        Icons.memory,
        'Pick a model',
        'Any AI backend works — the one you chat with, or a bigger one just '
            'for this.',
      ),
      (
        Icons.chat_bubble_outline,
        'Pick a chat',
        'One real conversation becomes the source of truth. The story\'s '
            'recap and $name\'s journal memories come along too.',
      ),
      (
        Icons.record_voice_over,
        'The interview',
        'The AI studies the chat and rewrites the parts of the character '
            'card you choose — description, personality, example dialogue '
            'and more — grounded in what actually happened.',
      ),
      (
        Icons.fact_check_outlined,
        'You review everything',
        'Every change is shown next to the original, editable, with a '
            'per-field "use this" switch. Nothing is saved until you say so.',
      ),
      (
        Icons.library_add_outlined,
        'A NEW character is born',
        'Saving creates "$name (Enhanced)" in your library — and you can '
            'bring your existing chats along. The original $name is never '
            'touched.',
      ),
    ];

    return _stepScroll(context, [
      _stepHeading(context, 'What is AI Enhance?'),
      _stepBody(
        context,
        'Character cards are written before the first hello — but after a '
        'few real conversations, $name has become someone more specific '
        'than the card ever described. AI Enhance closes that gap: it reads '
        'a real chat and rewrites the card so the character on paper matches '
        'the character you actually know.',
      ),
      const SizedBox(height: 8),
      _stepHeading(context, 'How it works'),
      for (final (icon, title, body) in howItWorks)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.porchAmberOf(context)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      body,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 8),
      if (_sessions == null)
        _callout(
          context,
          icon: Icons.hourglass_empty,
          text: 'Checking $name\'s chats...',
        )
      else if (_sessions!.isEmpty)
        _callout(
          context,
          icon: Icons.chat_bubble_outline,
          text:
              'AI Enhance grows $name from a real conversation — the chat is '
              'what teaches the AI their true voice. Have a chat with $name '
              'first, then come back.',
          accent: AppColors.porchHoneyOf(context),
        )
      else
        _callout(
          context,
          icon: Icons.check_circle_outline,
          text: _sessions!.length == 1
              ? '$name has 1 chat to learn from — ready when you are.'
              : '$name has ${_sessions!.length} chats to learn from — ready '
                    'when you are.',
        ),
    ]);
  }

  // ── Step 1: Model ───────────────────────────────────────────────────────

  Widget _buildModelStep(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Text(
            'The interview is real AI work, so it needs a backend — the same '
            'choices as chatting. A stronger model writes a sharper card; the '
            'chat itself is untouched either way.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
        // The creator wizard's FULL Backend & Model step (KoboldCpp local
        // with .gguf pick/launch, Remote API, oMLX) — the identical picker,
        // not a cut-down row.
        Expanded(child: SetupStep(state: creatorState)),
      ],
    );
  }

  // ── Step 2: Chat ────────────────────────────────────────────────────────

  Widget _buildChatStep(BuildContext context) {
    final sessions = _sessions ?? const [];
    return _stepScroll(context, [
      _stepHeading(context, 'Which chat should teach the AI?'),
      _stepBody(
        context,
        sessions.length == 1
            ? 'This chat becomes the source of truth for the rewrite — '
                  'it\'s already selected.'
            : 'The conversation you pick becomes the source of truth for '
                  'the rewrite. Pick the one where '
                  '${widget.character.name} felt most like themselves.',
      ),
      for (final s in sessions) _sessionTile(context, s),
    ]);
  }

  Widget _sessionTile(BuildContext context, Map<String, dynamic> s) {
    final id = s['id'] as String;
    final selected = id == _sessionId;
    final date = s['date'] as DateTime?;
    final dateStr = date == null
        ? ''
        : '${date.year}-${date.month.toString().padLeft(2, "0")}-'
              '${date.day.toString().padLeft(2, "0")}';
    final messageCount = s['message_count'] ?? 0;
    final userMessageCount = s['user_message_count'] ?? 0;
    final amber = AppColors.porchAmberOf(context);

    return Card(
      color: selected ? amber.withValues(alpha: 0.12) : AppColors.cardOf(context),
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? amber : AppColors.borderOf(context),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          size: 20,
          color: selected ? amber : AppColors.textTertiary(context),
        ),
        title: Text(
          s['preview'] as String? ?? '',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textPrimary(context),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$dateStr · $messageCount messages · $userMessageCount yours',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary(context),
          ),
        ),
        onTap: () => rebuildState(() => _sessionId = id),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Step 3: Interview ───────────────────────────────────────────────────

  Widget _buildInterviewStep(BuildContext context) {
    if (_running) return _buildInterviewProgress(context);

    Widget row(
      String label,
      String hint,
      bool value,
      ValueChanged<bool> onChanged,
    ) {
      return CheckboxListTile(
        value: value,
        onChanged: (v) => rebuildState(() => onChanged(v ?? false)),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: AppColors.porchAmberOf(context),
        checkColor: AppColors.onChaosAccent,
        contentPadding: EdgeInsets.zero,
        title: Text(
          label,
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
        ),
        subtitle: Text(
          hint,
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary(context)),
        ),
      );
    }

    return _stepScroll(context, [
      _stepHeading(context, 'What should the interview rewrite?'),
      _stepBody(
        context,
        'Tick the parts of the card the AI may rewrite. Everything it '
        'writes is shown to you on the next step before anything is saved.',
      ),
      if ((_chatContext?.userTurnCount ?? 99) < 2) ...[
        _callout(
          context,
          icon: Icons.hourglass_bottom,
          text:
              'Heads up: this chat is very short, so the AI has little to '
              'work with — results may be thin.',
          accent: AppColors.porchHoneyOf(context),
        ),
        const SizedBox(height: 8),
      ],
      row(
        'Description',
        'Physical appearance, rewritten with detail from the story',
        _selDescription,
        (v) => _selDescription = v,
      ),
      row(
        'Personality',
        'Inner traits grounded in how they actually behaved',
        _selPersonality,
        (v) => _selPersonality = v,
      ),
      row(
        'Example dialogue',
        'Teaching lines mined from their real voice in the chat',
        _selExample,
        (v) => _selExample = v,
      ),
      Divider(color: AppColors.borderOf(context)),
      row(
        'Scenario',
        'Re-anchor the opening situation to where the story went',
        _selScenario,
        (v) => _selScenario = v,
      ),
      row(
        'First message + alternates',
        'Fresh openings written in the voice from the chat',
        _selGreetings,
        (v) => _selGreetings = v,
      ),
      row(
        'Lorebook',
        'World entries built from places and facts the story revealed',
        _selLorebook,
        (v) => _selLorebook = v,
      ),
      Divider(color: AppColors.borderOf(context)),
      SwitchListTile(
        value: _nsfw,
        onChanged: (v) => rebuildState(() => _nsfw = v),
        dense: true,
        activeThumbColor: AppColors.porchAmberOf(context),
        contentPadding: EdgeInsets.zero,
        title: Text(
          'Allow 18+ themes',
          style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context)),
        ),
        subtitle: Text(
          'Lets suggestive material from the chat shape the card',
          style: TextStyle(fontSize: 11, color: AppColors.textTertiary(context)),
        ),
      ),
      if (_runError != null) ...[
        const SizedBox(height: 8),
        _callout(
          context,
          icon: Icons.error_outline,
          text: _runError!,
          accent: AppColors.porchTerracottaOf(context),
        ),
      ],
    ]);
  }

  Widget _buildInterviewProgress(BuildContext context) {
    return _stepScroll(context, [
      _stepHeading(context, 'Interviewing ${widget.character.name}...'),
      _stepBody(
        context,
        'The AI is studying the chat and rewriting the card. This takes a '
        'few minutes on local models.',
      ),
      Text(
        _statusText,
        style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)),
      ),
      const SizedBox(height: 10),
      LinearProgressIndicator(
        backgroundColor: AppColors.surfaceContainerOf(context),
        valueColor: AlwaysStoppedAnimation<Color>(
          AppColors.porchAmberOf(context),
        ),
      ),
      const SizedBox(height: 10),
      if (_previewText.isNotEmpty)
        Container(
          constraints: const BoxConstraints(maxHeight: 240),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerOf(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            reverse: true,
            child: Text(
              _previewText,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary(context),
              ),
            ),
          ),
        ),
    ]);
  }

  // ── Step 5: Chats ───────────────────────────────────────────────────────

  Widget _buildChatsStep(BuildContext context) {
    final name = widget.character.name;
    final copyName = _savedCopy?.name ?? '$name (Enhanced)';
    final chatCount = _sessions?.length ?? 0;
    final chatWord = chatCount == 1 ? 'chat' : 'chats';

    return _stepScroll(context, [
      Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 22,
            color: AppColors.porchAmberOf(context),
          ),
          const SizedBox(width: 8),
          Expanded(child: _stepHeading(context, '"$copyName" is saved!')),
        ],
      ),
      _stepBody(
        context,
        'One last thing: $copyName starts with an empty chat list. Want to '
        'bring $name\'s $chatCount $chatWord along? Each one is copied in '
        'full — messages, journal memories, relationship state — so you can '
        'pick up right where you left off with the enhanced version. '
        '$name keeps the originals either way.',
      ),
      if (_copiedCount == null) ...[
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _copying ? null : _copyChats,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.porchAmberOf(context),
              foregroundColor: AppColors.onChaosAccent,
            ),
            icon: _copying
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.copy_all, size: 18),
            label: Text(
              _copying
                  ? 'Copying... $_copyDone of $_copyTotal'
                  : 'Copy my $chatWord over',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Or just hit Finish to skip this.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textTertiary(context),
          ),
        ),
      ] else
        _callout(
          context,
          icon: Icons.check_circle_outline,
          text: _copiedCount == 0
              ? 'Nothing to copy — $name has no chats yet.'
              : 'Copied $_copiedCount $chatWord. You\'ll land in the newest '
                    'one next time you open $copyName.',
        ),
      if (_copyError != null) ...[
        const SizedBox(height: 8),
        _callout(
          context,
          icon: Icons.error_outline,
          text: _copyError!,
          accent: AppColors.porchTerracottaOf(context),
        ),
      ],
    ]);
  }
}
