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

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/capability/vision_support_resolver.dart';
import 'package:front_porch_ai/services/caption/local_caption_service.dart';
import 'package:front_porch_ai/services/vision_eval.dart';
import 'package:front_porch_ai/services/llm_provider.dart';
import 'package:front_porch_ai/services/user_persona_service.dart';

import 'package:front_porch_ai/utils/utils.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/image_gen_service.dart';
import 'package:front_porch_ai/services/tts_service.dart';
import 'package:front_porch_ai/services/v2_card_service.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/avatar_gallery.dart';
import 'package:front_porch_ai/services/group_chat_repository.dart';
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/chat/chat.dart';
import 'package:front_porch_ai/services/group_turn_manager.dart';
import 'package:front_porch_ai/services/world_repository.dart';
import 'package:front_porch_ai/services/memory_service.dart';
import 'package:front_porch_ai/database/database.dart' hide AvatarImage, World;
import 'package:front_porch_ai/services/expression_classifier.dart'; // top-level for ExpressionClassifierService type in @Dep shim (pre-existing)
import 'package:front_porch_ai/services/live_gen_progress.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/author_note_builder.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/relationship_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/emotion_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/behavioral_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/time_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/weather_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/world_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/ambition_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/promise_debt_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/nsfw_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/chaos_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/needs_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/realism_state_injection.dart';
import 'package:front_porch_ai/services/chat/prompt_injection/journal_injection.dart';
import 'package:front_porch_ai/services/macro_resolver.dart';
import 'package:drift/drift.dart' as drift;

// Cohesive method groups extracted into part files to keep this file shrinking
// toward the 500-line cap (see CLAUDE.md). Parts share this library's imports and
// private members; behaviour is unchanged.
part 'chat/chat_service_group_read.dart';
part 'chat/chat_service_group_settings.dart';
part 'chat/chat_service_growth.dart';
part 'chat/chat_service_sillytavern.dart';
part 'chat/chat_service_group_realism_helpers.dart';
part 'chat/chat_service_history.dart';
part 'chat/chat_service_group_membership.dart';
part 'chat/chat_service_reprocess.dart';
part 'chat/chat_service_needs_reprocess.dart';
part 'chat/chat_service_chat_entry.dart';
part 'chat/chat_service_group_entry.dart';
part 'chat/chat_service_session_state.dart';
part 'chat/chat_service_session_load.dart';
part 'chat/chat_service_realism_evals.dart';
part 'chat/chat_service_actions.dart';
part 'chat/chat_service_objectives.dart';
part 'chat/chat_service_realism_dance.dart';
part 'chat/chat_service_speaker_objectives.dart';
part 'chat/chat_service_impersonate.dart';
part 'chat/chat_service_session_manage.dart';
part 'chat/chat_service_generation.dart';
part 'chat/chat_service_generation_blocks.dart';
part 'chat/chat_service_generation_plan.dart';
part 'chat/chat_service_generation_rag.dart';
part 'chat/chat_service_generation_request.dart';
part 'chat/chat_service_generation_stream.dart';
part 'chat/chat_service_generation_postgen.dart';
part 'chat/chat_service_cast.dart';
part 'chat/chat_service_images.dart';
part 'chat/chat_service_photo.dart';
part 'chat/chat_service_idle_autonomous.dart';
part 'chat/chat_service_greeting.dart';
part 'chat/chat_service_prompt_blocks.dart';
part 'chat/chat_service_scene_guest.dart';
part 'chat/chat_service_controls.dart';
part 'chat/chat_service_context_budget.dart';
part 'chat/chat_service_wiring_realism.dart';
part 'chat/chat_service_wiring_evals.dart';
part 'chat/chat_service_wiring_memory.dart';
part 'chat/chat_service_wiring_injection.dart';
part 'chat/chat_service_send.dart';
part 'chat/chat_service_turn_flow.dart';
part 'chat/chat_service_message_ops.dart';
part 'chat/chat_service_guest_flow.dart';
part 'chat/chat_service_accessors.dart';
part 'chat/chat_service_defaults.dart';

// (_realismEvalCancelled — the file-scope realism-eval cancel flag — and the
// GBNF grammar-removal historical note both moved to chat_service_defaults.dart;
// both are library top-level, so every part file's access is unaffected.)

class ChatService extends ChangeNotifier {
  final KoboldService _koboldService;
  final UserPersonaService _userPersonaService;
  final StorageService _storageService;
  final WorldRepository _worldRepository;
  late AppDatabase _db;
  LLMProvider? _llmProvider;
  CharacterRepository? _characterRepository;
  TtsService? _ttsService;
  ImageGenService? _imageGenService;
  MemoryService? _memoryService;

  /// Test-only overrides for driving the real LLM paths (realism evals +
  /// chat generation) with canned responses without constructing a full
  /// LLMProvider (heavy deps). Used by chat_service_*_test.dart and
  /// chat_service_realism_engine_test.dart (the new real-engine suite).
  @visibleForTesting
  LLMService? testLlmServiceOverride;
  @visibleForTesting
  bool testIsLocalOverride = false;

  // Action suggestions
  List<String> _suggestedActions = [];
  bool _isGeneratingActions = false;
  List<String> get suggestedActions => _suggestedActions;
  bool get isGeneratingActions => _isGeneratingActions;

  // Objective/quest system
  List<Objective> _activeObjectives = [];

  // Sidebar task-generation prefs, hoisted from ObjectivePanel widget state:
  // the panel's State is recreated on sidebar rebuilds (every realism turn),
  // which reset the NSFW toggle each message (field report). Session-held on
  // purpose — NOT persisted, so NSFW tasks default OFF on a fresh launch.
  bool objectiveNsfwTasks = false;
  int objectiveTaskCount = 5;

  /// Armed only while the TURN-path completion check runs (see
  /// _maybeCheckTaskCompletionSync try/finally): check-driven objective
  /// mutations record regen turn-ops only when armed, so the UI's manual
  /// "Check now" (forceCheckCompletion) never records — a regen must not
  /// undo a user-triggered check. Scoped by try/finally; no reset needed.
  bool _objectiveTurnOpsArmed = false;
  int _messagesSinceLastCheck = 0;
  // God-side runtime flag mirroring objective_proposal's get/setIsChecking
  // (early guard in the completion check). Must be defensively zeroed on
  // *all* reset/new-chat/0-session/group/setActive/load/delete paths — like
  // _activeObjectives and _messagesSinceLastCheck — or an in-flight reset
  // permanently skips future task checks. See CLAUDE.md "keep reset blocks
  // in sync".
  bool _isCheckingCompletion = false;
  bool _isNewChat = false;

  // Central post-dispose guard (re-introduced per PR #47 rec 2 for prod stability + test flake).
  // Protects *all* async-await-DB-then-notifyListeners patterns and any residual
  // fire-and-forget / microtask paths (e.g. unawaited objective loads, realism evals,
  // summary/fact/evo periodic, set* after rapid close/switch). Overrides ensure
  // no "A ChatService was used after being disposed" or channel errors.
  // Complements the "Awaited (was fire-and-forget)" at setActiveCharacter:2205;
  // see also _loadActiveObjectives and keep-reset sites. 0 new god private _ methods.
  bool _disposed = false;

  // ── Dynamic Responses (idle timer / fourth-wall auto-ping) ─────────────
  Timer? _idleTimer;
  String? _pendingIdleCue;
  bool _autoResponseInProgress = false;
  bool _hasCompletedExchange = false;
  int _consecutiveAutoResponses = 0;
  // The consecutive-response cap lives in the persisted
  // generationSettings.dynamicResponseMaxMessages (default 3) so the sidebar
  // flyout, /afk --messages, and the settings all share one source of truth.

  Objective? get primaryObjective =>
      _activeObjectives.where((o) => o.isPrimary).firstOrNull;
  List<Objective> get secondaryObjectives =>
      _activeObjectives.where((o) => !o.isPrimary).toList();

  /// Whether a completion check is currently running.
  ///
  /// Kept in the class body (not the objectives extension) because
  /// [FakeChatService] overrides it in golden tests — extension members are
  /// statically dispatched and cannot be overridden.
  bool get isCheckingCompletion => _isCheckingCompletion;

  // (updateDatabase moved to chat_service_accessors.dart)

  CharacterCard? _activeCharacter;

  // ── Scene Guests (Lite NPCs) ──────────────────────────────────────────────
  // Persistent guest characters added to a 1:1 scene. They are real library
  // characters that speak in their own bubble via the existing generation
  // engine but carry NO Realism Engine / Needs state (parity-safe). Stored as
  // dbIds inside the session's groupRealismState column (always '{}' for plain
  // 1:1 sessions) so no schema change is needed. Group sessions never use these.
  final List<String> _sceneGuestIds = [];
  final List<CharacterCard> _sceneGuestCards = [];

  // Scene Guests grow Growth Rings exactly like members do — rings are keyed
  // by the guest's stable charId in the growth_rings table, so no per-guest
  // evolution state lives here anymore (the growth pass includes 1:1 guests
  // who spoke in the window via resolvePassOwners).

  /// A one-shot departure instruction consumed by the NEXT primary 1:1
  /// generation so the active character narrates the guest leaving. Set by
  /// `/exit`, cleared after a single injection.
  String? _pendingGuestDeparture;

  /// A pending request to open the Scene Guest picker (the `/join` flow). Holds
  /// the initial search filter ('' = show everyone); null = no picker pending.
  /// Surfaced to the chat UI exactly like [pendingGuestDetection] — set + clear
  /// here with [notifyListeners]; the page observes it and shows the picker once.
  String? _pendingGuestPickerFilter;

  /// Transient one-line status for the Scene Guest create/join flow, shown as an
  /// inline banner above the input and NEVER saved to chat history (replaces the
  /// old per-step 'System' chat messages that both littered the scene and were
  /// persisted into it). Updated in place across the steps, then auto-clears.
  String? _guestActivityStatus;
  bool _guestActivityIsError = false;
  Timer? _guestStatusClearTimer;

  /// True while a guest is being created/entered. The mint runs a separate LLM
  /// call that does NOT set `_isGenerating`, so this is the guard that blocks a
  /// user message (or regen/swipe) from racing the in-flight guest creation.
  bool _guestBusy = false;

  /// Set when a guest's background portrait was just written to its card PNG, so
  /// the UI can evict that path from the image cache and show the new art (image
  /// cache lives in the widget layer; this service is foundation-only).
  String? _guestAvatarEvictPath;

  bool _pendingGuestPickerFull = false;
  bool _photoTurnInFlight = false;

  // ── /exit undo ──────────────────────────────────────────────────────────
  // After `/exit`, a brief UNDO is offered: delete the generated departure
  // message (reverting its host realism via deleteMessage's time-travel
  // rollback) and re-add the guest. Their evolution counts + RAG memory are NOT
  // cleared by exit, so re-adding the id restores full context. The offer is
  // consumed by the UI (one SnackBar) but the undo data stays valid until the
  // user sends a real message / switches chats.
  CharacterCard? _exitUndoGuest;
  ChatMessage? _exitUndoMessage;
  String? _exitUndoOfferName;

  /// Set when a FULL group member's `/exit` is awaiting commit. They have said
  /// goodbye and left the live roster, but their DB row/realism/evolution/quests/
  /// memory are untouched and the real removal (plus any collapse to a 1:1) is
  /// deferred until the user continues — so [undoLastExit] can restore them
  /// losslessly. Committed in `sendMessage` via [_commitPendingMemberExit].
  CharacterCard? _pendingMemberExit;

  ChatCommandHandler? _commandHandler;

  /// `/image` slash-command orchestrator (lazily built in
  /// chat_service_images.dart; callbacks read live state, so it survives
  /// chat switches like [_commandHandler] does).
  ImageCommandService? _imageCommand;

  /// Prompt-review pause for /image (Chance-Time-style pending flag +
  /// completer): when the review setting is on, the crafted prompt parks
  /// here until the UI (desktop dialog / web modal) resolves it via
  /// [resolveImagePromptReview] — see chat_service_images.dart.
  String? _pendingImagePromptReview;
  Completer<String?>? _imageReviewCompleter;

  /// Web-facade fakes override this; body in chat_service_accessors.dart.
  Future<void> addGeneratedImageMessage(
    String path,
    String prompt, {
    String? senderName,
    String? characterId,
  }) => _addGeneratedImageMessageImpl(path, prompt,
      senderName: senderName, characterId: characterId);

  /// Whether Scene Guests automatically chime in after the primary's turn.
  /// Phase 1 keeps this in-memory (default ON) rather than persisted — there is
  /// no settings UI yet; a public setter lets callers toggle it.
  bool autoChimeEnabled = true;

  SceneGuestDirector? _sceneGuestDirector;

  // ── Scene Guest cast detection (Phase 2) ────────────────────────────────
  // Periodically (not every turn) scans the primary's recent narration in a
  // 1:1 chat for a newly-introduced, recurring, named side character and offers
  // to promote it to a Scene Guest. Detection only reads text + triggers the
  // existing parity-safe mint/enter flow, so it adds ZERO Realism/Needs work.

  /// Whether the periodic cast-detection scan runs. In-memory (default ON),
  /// mirroring [autoChimeEnabled].
  bool sceneDetectionEnabled = true;

  // (_castScanInterval moved to chat_service_defaults.dart as a
  // library-top-level const)

  /// Primary turns since the last cast-detection scan (zeroed at the same
  /// Scene Guest reset sites alongside `_pendingGuestDeparture = null`).
  int _userMessagesSinceLastCastScan = 0;

  /// A detected candidate awaiting the user's accept/ignore choice. Surfaced to
  /// the chat UI exactly like the Chance Time wheel's pending flag: set + clear
  /// here with [notifyListeners]; the page observes it and shows the popup once.
  DetectedCharacter? _pendingGuestDetection;

  /// Names already offered (whether accepted or ignored) this session,
  /// lower-cased, so the same character is never re-offered. Cleared at the
  /// Scene Guest reset sites.
  final Set<String> _offeredOrIgnoredGuestNames = {};

  CastDetector? _castDetector;

  bool _resolvingSceneGuests = false;
  bool _sceneGuestsResolvePending = false;

  final List<ChatMessage> _messages = [];
  Future<void> _saveChain = Future.value();
  Map<String, dynamic>?
  _pendingRealismMetadata; // stores deltas for the next generation
  bool _isGenerating = false;

  /// True while the awaited POST-generation work is still running.
  ///
  /// `_isGenerating` is cleared the moment the last token lands, but the turn
  /// is not finished there: the needs-impact eval, the realism-state re-stamp,
  /// the `_saveScalarsIntoGroupRealism` persist and the chip attach all run
  /// afterwards, and in a group they run under an impersonation dance that
  /// reassigns `_activeCharacter` and loads that member's scalars. For those
  /// seconds the app used to report "not generating" while the engine was
  /// still mutating state, so every re-entrancy guard stood open: a delete
  /// could shift the timeline under a running eval, and a new turn could
  /// interleave with the previous one's persist.
  ///
  /// Deliberately NOT held across the fire-and-forget passes (journal, growth,
  /// promise-debt, embed, periodic evals). Those are unawaited by design and
  /// can run indefinitely; blocking input until they finish would trade a race
  /// for a wedged UI, which is the worse bug.
  bool _isPostGenerating = false;

  // (_isTurnBusy — "this turn is still in motion" predicate for mutation
  // guards, NOT for stopGeneration/_cancelAndWaitForGeneration which must
  // keep testing _isGenerating alone — moved to chat_service_generation_stream.dart)

  // True while a forked-in character's custom entrance sequence is running
  // (fire-and-forget after forkToGroupChat). Blocks user-triggered turns so the
  // one-shot _entranceDirective can't be consumed/overwritten by a racing user
  // turn. (Follow-up: pass the directive as a local into _generateResponse to
  // drop the shared field entirely.)
  bool _entrancesInFlight = false;
  bool _isLoadingSession = false;
  bool _cancelRequested = false;
  int _generationEpoch = 0;
  String? _currentSessionId;
  double _generationProgress = 0.0;

  // ── Real-absence awareness (Living Time §2) ──
  // Computed in-memory at session load from the last saved message's
  // updatedAt; nothing is stored or transmitted (privacy-by-design contract
  // in absence_tracker.dart). Story clock untouched.
  Duration _absenceGap = Duration.zero;
  bool _absenceAckPending = false;
  bool _absenceAckConsumed = false;
  int _tokensGenerated = 0;
  int _maxTokens = 0;
  DateTime? _generationStartTime;
  GenerationPhase _generationPhase = GenerationPhase.idle;
  DateTime? _prefillStartTime; // When we entered prefill (for elapsed timer)
  int _prefillPromptTokens =
      0; // Estimated prompt token count for progress display
  Map<String, dynamic>? _lastPerfData; // Cached KoboldCPP perf data
  final List<String> _tokenBuffer = [];
  Timer? _drainTimer;
  int _displayedTokenCount = 0;
  final List<DateTime> _tokenTimestamps =
      []; // Rolling window for TPS measurement

  // ── Streaming rebuild throttle ──
  // _notifyStreamListeners coalesces per-token notifies into at most one per
  // ~33 ms with a guaranteed trailing notify (the final token batch always
  // paints). End-of-turn paths still call plain notifyListeners() directly,
  // so terminal state (isGenerating=false, chips, perf) is never throttled.
  DateTime _lastStreamNotify = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _streamNotifyTimer;
  // (_kStreamNotifyInterval moved to chat_service_defaults.dart;
  // _notifyStreamListeners / _cancelStreamNotifyThrottle moved to
  // chat_service_generation_stream.dart)

  // ── Web token broadcast ──
  // External consumers (the web server's StreamHub) listen to this for real-time token streaming.
  final StreamController<String> _tokenBroadcast =
      StreamController<String>.broadcast();

  /// Emits complete sentences as they're detected during LLM token streaming.
  /// Used by call mode to start TTS on the first sentence immediately.
  final StreamController<String> _sentenceBroadcast =
      StreamController<String>.broadcast();
  String _sentenceBuffer = ''; // accumulates tokens until a sentence boundary

  /// Whether the app is in voice call mode (auto-disables reasoning for lower latency).
  bool _callMode = false;
  // (tokenStream / sentenceStream / callMode moved to
  // chat_service_generation_stream.dart)

  // ── Group chat state (owned by GroupTurnManager) ──
  GroupTurnManager? _groupManager;

  // Wired for decoupled group member loading (so setActiveGroup works even if caller
  // doesn't explicitly pass groupRepo every time). Set from main.dart provider setup.
  GroupChatRepository? _groupChatRepository;

  // One-shot hidden directive for a forked-in character's custom entrance
  // (Direction mode). Injected into the prompt, consumed on the next generation;
  // the forced-speaker side is handled by GroupTurnManager.setNextSpeaker.
  String? _entranceDirective;

  // (Group delegation getters _activeGroup/_groupCharacters/_observerMode/
  // _autoPlayActive/directorDelaySec moved to chat_service_group_read.dart)

  /// Per-character realism / needs / state for group chats.
  /// Keyed by stable charId. Populated from the hidden checkpoint.
  /// Per-member realism state, typed (U7). Keys are runtime member ids
  /// (stableGroupId). The wrapper preserves the legacy wire format exactly —
  /// see group_member_realism.dart for why it is a wrapper and not fields.
  Map<String, GroupMemberRealism> _groupRealism = {};

  /// The group member id (`_getCharacterIdFromCard`) whose realism state is being
  /// processed for the turn currently generating. Set the moment the speaker is
  /// picked in `_generateResponse` and cleared in its `finally`, so every realism
  /// consumer (prompt injection, decay, post-gen) keys on the character actually
  /// speaking — `nextCharacter` points at the *upcoming* speaker and is null for
  /// random turn order, so it cannot be that signal. Null outside a turn (the
  /// pre-pick window keeps its prior nextCharacter-based behaviour).
  String? _turnSpeakerIdForRealism;

  /// Per-character Author's Notes for group chats (independent of group-level _authorNote).
  /// Keyed by stable charId (from _getCharacterIdFromCard). Populated from the
  /// (legacy comment — now persisted via sessions.group_realism_state column)
  Map<String, String> _groupAuthorNotes = {};
  Map<String, int> _groupAuthorNoteStrengths = {};

  /// Per-character system prompts scoped to the *current group only*.
  /// These are completely independent of each character's normal `systemPrompt`
  /// (the one used in 1:1 chats). When present and non-empty for the speaking
  /// character, they take full precedence over the character's card-level prompt
  /// inside this group. Now persisted via the sessions.group_realism_state column.
  Map<String, String> _groupCharacterSystemPrompts = {};

  /// Per-character objectives when in group mode.
  /// Each member carries their own independent personal objectives/tasks.
  /// Keyed by stable charId. Stored inside the group state JSON for now
  /// (consistent with other per-char group data like realism/needs).
  Map<String, List<Objective>> _groupObjectives = {};

  /// Body in chat_service_objectives.dart.
  List<Objective> getObjectivesForGroupCharacter(CharacterCard character) =>
      _getObjectivesForGroupCharacterImpl(character);

  // RAG settings for the active group (stored in the hidden checkpoint, no DB schema change)
  bool _groupRagEnabled = true;
  int _groupRetrievalCount = 4;
  double _groupMemoryBudgetPercent = 10.0;
  Map<String, double> _groupCharacterRAGPriorities = {};

  // Director Mode state is now owned by _groupManager when active.
  // The public getters below delegate to it.
  // ── Author's Note ──
  String _authorNote = '';
  int _authorNoteStrength = 4;

  // ── Per-chat avatar gallery ("looks") selection ──
  // {characterId: selectedLookAvatarId} for THIS session, decoded from the
  // session's selectedLookAvatarId column on load. A map (not one id) so a group
  // chat remembers a look per participant; 1:1 is just a one-entry map. Reset
  // per session in loadSession; empty when no session.
  Map<String, String> _selectedLooks = {};

  // ── Chat Summary ──
  String _summary = '';
  int _summaryLastIndex = 0;
  // Secondary runtime flag (like _isSummaryGenerating); must be defensively
  // zeroed on *all* reset/new-chat/0-session/group/setActive/load/delete
  // paths or pause state leaks across contexts (see CLAUDE.md keep-sync).
  bool _summaryPaused = false;
  bool _isSummaryGenerating = false;

  // ── Realism Mode ──
  bool _realismEnabled = false; // master toggle
  bool _isEvaluatingRealism = false;
  bool _isCancellingRealismEval = false;
  bool _isProcessingGreeting =
      false; // true while post-greeting baseline eval runs
  bool _greetingEvalPending =
      false; // greeting placed but baseline eval not yet run
  String _realismEvalStreamText = '';

  // Verifier phase coordination (god-owned for overlay + chips; leaf is stateless/prompt+rule).
  // Set around verify calls (via thin cb from leaves) so "🕵️ Verifying Realism output (pass X/Y)" shows
  // using the *exact same* overlay widgetry. 0 new void _ privates.
  bool _isVerifyingRealism = false;
  int _verificationPass = 0;
  int _verificationMaxPasses = 1;
  // Debounce timer — batches rapid per-chunk notifyListeners() calls during
  // eval streaming into a single rebuild every 150 ms. Without this, a
  // 40-token JSON response fires 40+ notifyListeners() calls and widgets that
  // are mid-deactivation throw "Looking up a deactivated widget's ancestor".
  Timer? _evalChunkTimer;

  // TOMBSTONE: `_moodDecayCounter` was dead state — nothing ever read it; the
  // real short-term-decay cadence lives in RelationshipService and is
  // captured/restored via captureCadenceAndFeelings / restoreFromMessageState.
  // The sessions.moodDecayCounter DB COLUMN stays (dormant, defaults to 0):
  // dropping it is a schema change, and external tools write this DB directly.

  // Emotional state
  String _characterEmotion = '';
  String _emotionIntensity = ''; // mild/moderate/strong

  // Expression images + classification live in ExpressionService
  // (chat/expression_classifier.dart); god thins to delegation only.

  // Passage of time state/logic lives in TimeService (chat/time_service.dart);
  // god thins to delegation + a few @Deprecated shims.

  // NSFW cooldown & lust state/logic lives in NsfwService
  // (chat/nsfw_service.dart); god thins to delegation + a few @Deprecated
  // shims. _runPostGenNeedsChecks thins to needs_impact_evaluator.

  // ── Chaos Mode / Chance Time (core state extracted) ──────────────────────
  // _chaosModeEnabled / _chaosNsfwEnabled / _chaosPressure / _pendingChaosInjection / _chaosEventDelivered
  // now owned by _chaosModeService. The two UI coordination flags below stay in god
  // (cross widget boundary for overlay + send pause).
  bool _chanceTimePendingTrigger =
      false; // true for one cycle to pop the overlay
  // The single event the web/mobile "reveal your fate" modal shows + accepts
  // while sendMessage is parked on the completer below. The desktop samples its
  // own spinning wheel; a phone has no room for one, so we pre-pick one event
  // from the same pool. Lives only during the park (set at the gate, cleared on
  // resume) — see [isAwaitingChanceTime] / [acceptPendingChanceTime].
  String? _webChanceTimeEvent;

  // ── Sims/Needs Simulation (extracted) + Needs Impact Evaluator ──
  // Straight decay ticks in _needsSimulation; model deltas (+ optional Director review when authority) in _needsImpactEvaluator.
  // See CLAUDE.md for full reset keep-sync + "incomplete zeroing now complete" + buffer removal + authority decision (simple model+Director path).
  bool _needsSimEnabled = false;
  bool _enjoysLowHygiene =
      false; // inversion for hygiene (enjoys being dirty/sweaty/musky)

  // Legacy shared group decay map. No longer the runtime source of truth (that
  // is each member's card ext, via `_activeDecayRates()`); retained only as a
  // load/save + fallback bridge for pre-per-member groups (see session state).
  Map<String, int> _groupDecayRates = {};

  // (needCriticalThreshold moved to chat_service_defaults.dart as a
  // library-top-level getter)

  // ── Passage of time / Chaos Mode / NSFW cooldown (builders in
  // chat_service_wiring_realism.dart) ──
  late final _timeService = _buildTimeService();
  late final _chaosModeService = _buildChaosModeService();
  late final _nsfwService = _buildNsfwService();

  // ── Lorebook scanner / injector (builders in
  // chat_service_wiring_injection.dart) ──
  late final _lorebookScanner = _buildLorebookScanner();

  /// Per-chat lore session state (ST sticky/cooldown timers, macro locals,
  /// chat-scoped lorebook) — persisted inside the session's groupRealismState
  /// blob via additive keys, hydrated on session load, cleared at session
  /// boundaries via the scanner reset.
  final _loreTimedEffects = LorebookTimedEffects();

  // (chatLorebook / commitChatLorebookEdit / lastLoreOverflow / lastLoreTokens
  // / lastLoreBudget / loreTimedEffects / previewLoreTriggers /
  // currentlyActiveLoreEntries moved to chat_service_accessors.dart)
  List<String> _lastLoreOverflow = const [];
  int _lastLoreTokens = 0;
  int _lastLoreBudget = 0;

  late final _lorebookInjector = _buildLorebookInjector();

  // The group lorebook is stored as a JSON string on the group row. Parse it
  // ONCE and keep the live instance — the scanner writes trigger state onto
  // these entry objects, so a fresh parse per read (the pre-Phase-2 behavior)
  // silently discarded every keyword trigger and left group books constant-only.
  // String-compare invalidation: editing the book in group settings replaces
  // the JSON string, which re-parses (and intentionally clears trigger state,
  // same as editing semantics elsewhere).
  Lorebook? _cachedGroupBook;
  String? _cachedGroupBookJson;

  /// Living Worlds: UUIDs of worlds attached to the current session.
  /// Loaded on session open; group template seeds new chats.
  List<String> _chatWorldIds = const [];

  /// Hydrated mid-chat climate spans + world default (Living Worlds phase 1).
  BiomeSchedule _biomeSchedule = const BiomeSchedule();

  // (chatWorldIds moved to chat_service_accessors.dart)

  /// Climate active on the current story day (span override or world default).
  Biome get activeChatBiome =>
      _biomeSchedule.biomeAt(_timeService.dayCount);

  /// Central macro resolver for prompt template expansion.
  late final _macroResolver = MacroResolver();

  /// In-memory clock for {{idle_duration}} — set on each user send; null
  /// after a restart (the macro passes through untouched then).
  DateTime? _lastUserMessageAt;

  // (_macroPattern moved to chat_service_defaults.dart as a library-top-level
  // final)

  late final _needsSimulation = _buildNeedsSimulation();
  late final _relationshipService = _buildRelationshipService();
  // ── Expression label selection / manual / avatar resolve / reclass / ONNX —
  // builder in chat_service_wiring_realism.dart ──
  late final _expressionService = _buildExpressionService();

  // ── Prompt Injection Builders (builders in chat_service_wiring_injection.dart) ──
  late final _authorNoteBuilder = _buildAuthorNoteBuilder();
  late final _relationshipInjection = _buildRelationshipInjection();
  late final _emotionInjection = _buildEmotionInjection();
  late final _behavioralInjection = _buildBehavioralInjection();
  late final _timeInjection = _buildTimeInjection();

  // (absencePhrase / absenceBannerPhrase moved to chat_service_accessors.dart)

  /// Today's story weather, or null when off. Body in chat_service_accessors.dart.
  DailyWeather? get currentWeather => _currentWeatherImpl;

  /// Tomorrow's forecast under the same gate. Body in chat_service_accessors.dart.
  DailyWeather? get upcomingWeather => _upcomingWeatherImpl;

  /// The current DAY-PART's weather. Body in chat_service_accessors.dart.
  SegmentWeather? get currentSegmentWeather => _currentSegmentWeatherImpl;

  late final _weatherInjection = _buildWeatherInjection();

  // (previousSegmentWeather / _segmentAt / _worldDefaultBiome / _biomeAtDay
  // moved to chat_service_wiring_injection.dart)

  // ── Ambitions (Living Time §6) — builder in chat_service_wiring_memory.dart ──
  late final _ambitionService = _buildAmbitionService();

  /// Sidebar/web read surface (Living Time §6). Body in chat_service_accessors.dart.
  List<({String text, int progress})> ambitionsFor(CharacterCard card) =>
      _ambitionsForImpl(card);

  late final _ambitionInjection = _buildAmbitionInjection();

  // ── Promise & debt ledger (Train B) — builder in chat_service_wiring_memory.dart ──
  late final _promiseDebtService = _buildPromiseDebtService();
  late final _promiseDebtInjection = _buildPromiseDebtInjection();

  // ── Dreams (Living Time §1) — builder in chat_service_wiring_memory.dart ──
  late final _dreamService = _buildDreamService();

  late final _nsfwInjection = _buildNsfwInjection();
  late final _chaosInjection = _buildChaosInjection();
  late final _needsInjection = _buildNeedsInjection();

  /// New central composer for the full speaker-internal realism snapshot.
  /// Replaces the previous loose concatenation of the individual builders.
  /// This gives the model one clearly grouped, number-first view of relationship,
  /// emotion, time, needs (with x/100), behavioral anchors, nsfw state, etc.
  /// Builder in chat_service_wiring_injection.dart.
  late final _realismStateInjection = _buildRealismStateInjection();

  // ── LLM Eval Engine (built in chat_service_wiring_evals.dart; the engine's
  // own contract is documented in llm_eval_engine.dart). Stateless — no reset
  // calls needed; 1:1/group + one-shot/normal parity ride the callbacks. ──
  late final _llmEvalEngine = _buildLlmEvalEngine();
  late final _realismVerifier = _buildRealismVerifier();
  late final _needsImpactEvaluator = _buildNeedsImpactEvaluator();
  late final _realismEvals = _buildRealismEvals();
  late final _objectiveProposal = _buildObjectiveProposal();

  // ── The Journal (docs/design/journal-memory.md) — builders in
  // chat_service_wiring_memory.dart. Per-chat, per-character memory cards +
  // "Where we are" recap. Strictly session-scoped — no memory ever crosses
  // chats. 1:1 ↔ group parity by construction (same owner loop). ──
  late final _journalStore = _buildJournalStore();
  late final _porchMemoryImport = _buildPorchMemoryImport();

  // Review-first parking + the ONE proposal applier (both modes go through
  // it). Public via [journalReview] for the sidebar banner + review dialog.
  late final _journalReview = _buildJournalReview();

  JournalReview get journalReview => _journalReview;

  /// Tools-vs-XML probe memory shared by the Journal and Growth passes —
  /// one probe per backend identity per run no matter which pass asks first.
  final _toolProbe = ToolTransportProbe();

  /// Active tool-support prober behind the sidebar's tool-calling pill:
  /// verdicts land on the same [_toolProbe] the passes use, auto-retests on
  /// backend/model switches, and backs the pill's tap-to-retest. Builder in
  /// chat_service_wiring_evals.dart (with `_fireToolEval` / `_evalBackendIdentity`).
  late final _toolSupportTester = _buildToolSupportTester();

  // (toolCallSupport / isTestingToolSupport / testToolCalling moved to
  // chat_service_wiring_evals.dart)

  late final _journalMaintenance = _buildJournalMaintenance();

  /// Public door for the Journal UI (phase 3): the sidebar panel and the
  /// diary dialog read/mutate cards directly on the store (scoped by
  /// [currentSessionId] + the participant's stable id); the injection builder
  /// re-reads the DB every turn, so UI edits reach the prompt with no extra
  /// plumbing. Instance getter (not extension) so FakeChatService can
  /// override it via `implements` (see isGrowthPassRunning precedent).
  JournalStore get journalStore => _journalStore;

  /// "Our Story" timeline read-model (Living Time §7). Builder in
  /// chat_service_wiring_memory.dart.
  late final MilestoneFeed milestoneFeed = _buildMilestoneFeed();

  late final _journalInjection = _buildJournalInjection();

  // ── Growth Rings (docs/design/growth-rings.md) — builders in
  // chat_service_wiring_memory.dart. Per-chat, per-character growth entries;
  // trigger/cache/UI surface live in chat_service_growth.dart (part file). ──
  late final _growthStore = _buildGrowthStore();
  late final _growthReview = _buildGrowthReview();
  late final _growthService = _buildGrowthService();

  // (_getEffectivePersonality / _getEffectiveScenario moved to
  // chat_service_growth.dart)

  // The god file is a thin coordinator: the state that deliberately stays
  // here (rather than in a chat/ leaf) is _groupRealism + its load/save/sync
  // pairs, the sendMessage/_generateResponse turn orchestration (speaker
  // pick, eval dance, impersonation, post-gen finalization), chat history
  // building/saving, and the TTS drain buffer. 1:1 vs group parity is
  // preserved for all of it via callbacks + the impersonation dance. See
  // docs/refactor-god-file-modularization.md for the full extraction history.
  Completer<void>?
  _chanceTimeCompleter; // pauses sendMessage while wheel is active (UI coordination, stays in god)

  // ── Trust Repair ──
  // Armed on each severe trust drop (≥ -20 delta). Consumed on the very
  // next user message, then resets so future drops each get one shot.
  // Backing state + arming logic moved to RelationshipService.applyTrustDelta.
  // (No local field remains; @Deprecated shim on getter only.)

  final ContextBudgetStore _contextBudget = ContextBudgetStore();
  // ── Session Metadata ──
  String? _sessionName;
  String? _sessionDescription;

  // ── Per-session generation overrides ──
  ChatGenerationSettings _sessionGenSettings = ChatGenerationSettings();

  // ── Per-chat theme ──
  ChatThemeOverrides _sessionThemeOverrides = ChatThemeOverrides();

  // ── Chat Branching ──
  String? _parentSessionId;
  int? _forkIndex;

  // (defaultGroupSystemPrompt / observerModeSystemPrompt /
  // defaultKoboldSystemPrompt / defaultApiSystemPrompt / _kEvalDispatchStagger
  // moved to chat_service_defaults.dart as library-top-level consts — see
  // that file's header doc for why.)

  CharacterCard? get activeCharacter => _activeCharacter;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  /// Token streaming — deliberately the NARROW sense. It drives the send
  /// button, and widening it to cover post-generation was tried and REVERTED:
  /// background evals then held the composer disabled for most of a turn on
  /// slow machines (caught by E2E on the CI runners). The real constraint
  /// lives at the composer instead: its guard must use the SAME predicate as
  /// [sendMessage], or it clears the field for a send the service refuses.
  /// See [isSettlingTurn] and the mirror in `_sendCurrentMessage`.
  bool get isGenerating => _isGenerating;

  // (isSettlingTurn moved to chat_service_generation_stream.dart;
  // isLoadingSession / selectedLookFor / setLookForCharacter moved to
  // chat_service_session_state.dart)
  String? get currentSessionId => _currentSessionId;

  double get generationProgress => _generationProgress;
  int get tokensGenerated => _tokensGenerated;
  int get maxTokens => _maxTokens;
  GenerationPhase get generationPhase => _generationPhase;

  /// Seconds elapsed since entering the prefill phase. Returns 0 if not prefilling.
  double get prefillElapsedSeconds => _prefillStartTime != null
      ? DateTime.now().difference(_prefillStartTime!).inMilliseconds / 1000.0
      : 0.0;

  /// Cached KoboldCPP performance data from last /api/extra/perf poll.
  Map<String, dynamic>? get lastPerfData => _lastPerfData;

  /// The active backend's live generation progress (truthful status bar):
  /// Kobold console counts, oMLX admin-stats poll, or LM Studio's runtime
  /// log — null for plain remote APIs, which expose no prefill data. Thin
  /// delegation; source selection lives in LLMProvider.activeLiveProgress.
  LiveGenProgress? get activeLiveProgress =>
      _llmProvider?.activeLiveProgress ?? _koboldService.liveProgress;

  /// Estimated prompt token count for the current generation (for progress display).
  int get prefillPromptTokens => _prefillPromptTokens;
  bool get isGroupMode => _groupManager?.isActive ?? false;
  GroupChat? get activeGroup => _groupManager?.activeGroup;
  bool get observerMode => _groupManager?.observerMode ?? false;
  List<CharacterCard> get groupCharacters =>
      _groupManager?.characters ?? const <CharacterCard>[];
  // (autoPlayActive / nextCharacter moved to chat_service_group_read.dart)

  /// Ordered cast of speakers, group or 1:1+guests. Body in chat_service_accessors.dart.
  List<ChatParticipant> get cast => _castImpl;

  // (isGroupRealismActive / _shouldTrackInterCharacterRelationships moved to
  // chat_service_group_read.dart)

  /// Body in chat_service_generation_stream.dart.
  double get tokensPerSecond => _tokensPerSecondImpl;

  int _greetingIndex = 0;
  int get greetingIndex => _greetingIndex;

  /// Listener wiring lives in [_initImpl] (chat_service_accessors.dart).
  ChatService(
    this._koboldService,
    this._userPersonaService,
    this._storageService,
    this._worldRepository,
  ) {
    _initImpl();
  }

  // (_onBackendIdentityMaybeChanged / setDatabase moved to
  // chat_service_accessors.dart)

  String get authorNote => _authorNote;
  int get authorNoteStrength => _authorNoteStrength;

  Map<String, int> get lastPromptBudget => _contextBudget.budget;
  Map<String, String> get lastPromptSections => _contextBudget.sections;
  ContextBudgetSource get promptBudgetSource => _contextBudget.source;
  DateTime? get promptBudgetAssembledAt => _contextBudget.assembledAt;
  Future<void> estimateContextBudgetNow() => _estimateContextBudgetNow();
  int get contextSize =>
      _sessionGenSettings.resolveContextSize(_storageService);

  /// Per-session generation parameter overrides. The dialog reads/writes this.
  ChatGenerationSettings get sessionGenSettings => _sessionGenSettings;
  set sessionGenSettings(ChatGenerationSettings value) =>
      _setSessionGenSettingsImpl(value);

  /// Per-chat theme overrides (preset + customized colors/font/background/border).
  ChatThemeOverrides get sessionThemeOverrides => _sessionThemeOverrides;
  set sessionThemeOverrides(ChatThemeOverrides value) =>
      _setSessionThemeOverridesImpl(value);

  // (parentSessionId / forkIndex / sessionName / sessionDescription /
  // isLoadingSession / selectedLookFor / setLookForCharacter moved to
  // chat_service_session_state.dart)
  String get summary => _summary;
  bool get summaryPaused => _summaryPaused;
  int get summaryLastIndex => _summaryLastIndex;
  bool get isSummaryGenerating => _isSummaryGenerating;
  // Domain services are read directly by callers (chat.relationshipService /
  // timeService / nsfwService / etc.); the god keeps ONLY the late finals —
  // for 1:1+group dispatch, _groupRealism load/save, callbacks, notify and
  // reset hygiene. Barrel not updated (internal; <3 public cross locations).
  RelationshipService get relationshipService => _relationshipService;
  TimeService get timeService => _timeService;
  NsfwService get nsfwService => _nsfwService;
  ChaosModeService get chaosModeService => _chaosModeService;
  NeedsSimulation get needsSimulation => _needsSimulation;

  // (expressionService / chaosPressure / activeFixation / pendingTrustRepair /
  // currentExpressionLabel / resolveExpressionAvatar / _realismActiveThisMode /
  // isCancellingRealismEval moved to chat_service_accessors.dart — thin
  // delegation to the respective *Service, 1:1 vs group parity via the
  // services' cbs + god impersonation dance, unchanged)
  bool get realismEnabled => _realismEnabled;

  bool get isEvaluatingRealism => _isEvaluatingRealism;
  bool get isProcessingGreeting => _isProcessingGreeting;

  // Verifier phase (for overlay header "🕵️ Verifying Realism output" + pass progress, and bubble chip data source).
  // God coordination only; leaf drives via cb thins (no new god void _).
  bool get isVerifyingRealism => _isVerifyingRealism;
  int get verificationPass => _verificationPass;
  int get verificationMaxPasses => _verificationMaxPasses;

  /// Stream text with think blocks stripped (for display) — memoized on
  /// string identity (the overlay + web broadcast read it every notify).
  /// Class member, not extension: FakeChatService overrides it in goldens.
  /// The memo fields stay here; the getter body is in
  /// chat_service_accessors.dart.
  String? _evalCleanSrc, _evalCleanOut;
  String get realismEvalStreamTextClean => _realismEvalStreamTextCleanImpl;
  String get characterEmotion => _characterEmotion;

  String get emotionIntensity => _emotionIntensity;

  /// Whether the per-session Needs (Sims-style) simulation is active.
  /// When true and `enjoysLowHygiene` is also true, low hygiene becomes desirable.
  ///
  /// When enabled, [needsVector] holds the current 0–100 levels and the engine
  /// performs decay, prompt injection, and LLM-verified fulfillment restores.
  /// New chats seed this from the character's [FrontPorchExtensions.needsSimEnabled].
  /// Disabling mid-chat clears the vector; historical snapshots cannot re-enable it.
  bool get needsSimEnabled => _needsSimEnabled;

  bool get chaosNsfwEnabled => _chaosModeService.chaosNsfwEnabled;

  // (chanceTimePendingTrigger / hasPendingChaosEvent / consumeChanceTimeTrigger /
  // the web/mobile Chance Time surface moved to chat_service_turn_flow.dart)

  // (nsfw/relationship long list of @Dep shims excised in final cleanup; use nsfwService / relationshipService)

  // (Misc accessors, id helpers and the service setters live in
  // chat_service_accessors.dart, which also carries the still-live warning
  // about the expression members a prior comment wrongly called "excised".)

  /// Regenerable host index under Scene Guest chime-ins; body in chat_service_accessors.dart.
  int? get regenerableHostBelowGuestsIndex =>
      _regenerableHostBelowGuestsIndexImpl;

  // ensureInterCharacterRelationshipsSeeded / updateInterCharacterFeelingsFromRecentExchange
  // moved verbatim to RelationshipService (with callbacks for group/messages). Old bodies deleted.

  /// Body in chat_service_accessors.dart.
  void editMessage(int index, String newText) =>
      _editMessageImpl(index, newText);

  // ── Growth Rings runtime state (full feature in growth_service.dart leaf
  // + chat_service_growth.dart part; docs/design/growth-rings.md) ──

  /// Transient re-entrancy/spinner flag for the growth pass. Defensively
  /// zeroed on all reset/new-chat/0-session/group/setActive/load/fork paths
  /// (the same "keep reset blocks in sync" sites the old evolution flag
  /// used). Ring/legacy data itself lives in the session-scoped GrowthStore
  /// cache, invalidated/refreshed at the context-switch sites.
  bool _isGrowthPassRunning = false;

  /// Kept as an instance getter (not in the growth part) because test fakes
  /// (`FakeChatService implements ChatService`) override it — extension
  /// getters are statically dispatched and cannot be overridden via
  /// `implements`.
  bool get isGrowthPassRunning => _isGrowthPassRunning;

  // ── Prompt Injection Builders (thins only; full in lib/services/chat/prompt_injection/* step 8) ──

  // The individual _get* thins for relationship/emotion/time/behavioral/nsfw are no longer used
  // for main prompt assembly — the _realismStateInjection composer owns the words-only
  // "[How <Name> is right now: …]" block (see realism_state_injection.dart + design doc).
  // The sub-builders themselves are still instantiated and passed to the composer.
  // Chance Time remains separate (it is not part of the per-turn realism state bundle).

  /// Active objectives for [character] in the current session; body in chat_service_objectives.dart.
  Future<List<Objective>> getActiveObjectivesFor(CharacterCard character) =>
      _getActiveObjectivesForImpl(character);

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  /// Cleanup body (everything but the mandatory `super.dispose()` call,
  /// which must stay in the class) lives in chat_service_accessors.dart.
  @override
  void dispose() {
    _disposeCleanupImpl();
    super.dispose();
  }
}
