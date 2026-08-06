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

// Internal flag to signal a cancellation request for realism evaluation.
// This is a file-scope flag to avoid needing to thread state through the
// entire class in this patch, and is reset once the interruption is surfaced
// to the UI.
bool _realismEvalCancelled = false;

// GBNF grammar support for Realism Engine evals (incl. Needs simulation) removed
// in the 0.9.8 clean port. All JSON outputs now rely on regex extraction + stop
// sequences inside _fireLLMEval (no _buildKoboldGrammar, no _kGbnf* consts).

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
  bool _isCheckingCompletion =
      false; // god-side secondary runtime flag for objective_proposal leaf's get/setIsChecking (early guard in check); must be defensively zeroed on *all* reset/new-chat/0-session/group/setActive/load/delete paths (like _activeObjectives + _messagesSinceLastCheck) to prevent permanent skip of future task checks after in-flight reset; see CLAUDE.md "keep reset blocks in sync" + "incomplete zeroing..." (leaves incl fact/evo/verif + needs_impact etc) + " ; no extra mutable scalar; live read from frontPorch under impersonation)" + "needsSimulation. (reason support kept for Director chips) ; cleared via sim initializeFresh/clearVector/resetBuffers on all paths; now complete)").
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

  List<Objective> get activeObjectives => _activeObjectives;
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

  List<Map<String, dynamic>> tasksForObjective(Objective obj) {
    try {
      return (jsonDecode(obj.tasks) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  /// Point this service — and the MemoryService it owns — at [db].
  ///
  /// Used both to wire the database in at startup and to re-point it after a
  /// swap (stable-DB import, storage-root move, backup restore). The
  /// MemoryService caches its own handle, so leaving it out meant RAG memory
  /// kept querying the closed database until the app was restarted; it is null
  /// during startup wiring, which the null-aware call covers.
  void updateDatabase(AppDatabase db) {
    _db = db;
    _memoryService?.updateDatabase(db);
  }

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

  /// The persistent Scene Guests currently in this 1:1 scene (resolved cards).
  List<CharacterCard> get sceneGuestCards =>
      List.unmodifiable(_sceneGuestCards);

  /// Initial filter for a pending `/join` picker, or null when none is pending.
  String? get pendingGuestPickerFilter => _pendingGuestPickerFilter;

  bool _pendingGuestPickerFull = false;

  /// Whether the pending picker should add the picked character as a FULL member
  /// (group member / 1:1->group convert) vs a lite Scene Guest.
  bool get pendingGuestPickerFull => _pendingGuestPickerFull;

  /// Transient Scene Guest create/join status line (null when idle).
  String? get guestActivityStatus => _guestActivityStatus;

  /// Whether [guestActivityStatus] is an error (drives the banner styling).
  bool get guestActivityIsError => _guestActivityIsError;

  /// True while a Scene Guest is being created/entered (input is disabled).
  bool get isGuestBusy => _guestBusy;

  /// True while forked-in character entrances are still playing. Exposed so the
  /// composer can mirror sendMessage's `_entrancesInFlight` early-return and
  /// avoid consuming (saving/clearing) an attached photo for a turn that
  /// sendMessage would silently drop. See _sendCurrentMessage.
  bool get entrancesInFlight => _entrancesInFlight;

  /// True from the start of a photo turn's captioning through the end of its
  /// send flow. Because the offline caption await (and the post-gen vision
  /// caption) run while `_isGenerating` is false, this is the guard that keeps
  /// a second sendMessage from interleaving during those windows — the UI and
  /// sendMessage entry both check it. Photo turns only; text turns are
  /// unaffected (they are covered by `_isGenerating`).
  bool get isPhotoTurnInFlight => _photoTurnInFlight;
  bool _photoTurnInFlight = false;

  /// A guest card image path whose cache the UI should evict (then call
  /// [consumeGuestAvatarEvict]); null when there is nothing to refresh.
  String? get guestAvatarEvictPath => _guestAvatarEvictPath;

  /// Clear the pending avatar-evict signal after the UI has evicted the path.
  void consumeGuestAvatarEvict() => _guestAvatarEvictPath = null;

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

  /// Name to show in the UNDO SnackBar (null = nothing to offer).
  String? get exitUndoOfferName => _exitUndoOfferName;

  /// Consume the one-shot UNDO offer (the SnackBar was shown); the undo itself
  /// stays available via [undoLastExit] until invalidated.
  void consumeExitUndoOffer() => _exitUndoOfferName = null;

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

  /// Append an already-saved generated image to the conversation as a
  /// character message (empty text; the bubble renders the image from
  /// metadata). Shared by the /image slash command, the Image Studio's
  /// "Send to chat", and the web insert-image endpoint. Lives in the class
  /// (not the images extension) so web-facade fakes can override it.
  Future<void> addGeneratedImageMessage(
    String path,
    String prompt, {
    String? senderName,
    String? characterId,
  }) async {
    if (_activeCharacter == null && _activeGroup == null) return;
    _messages.add(
      ChatMessage(
        text: '',
        sender: senderName ?? _activeCharacter?.name ?? 'Narrator',
        isUser: false,
        characterId: characterId,
        metadata: {
          'is_generated_image': true,
          'image_path': path,
          'image_prompt': prompt,
        },
      ),
    );
    await _saveChat();
    notifyListeners();
  }

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

  /// Run a detection scan every this-many primary (user) turns. Small and
  /// constant so the eval is infrequent and turns stay cheap.
  static const int _castScanInterval = 4;

  /// Primary turns since the last cast-detection scan (zeroed at the same
  /// Scene Guest reset sites alongside `_pendingGuestDeparture = null`).
  int _userMessagesSinceLastCastScan = 0;

  /// A detected candidate awaiting the user's accept/ignore choice. Surfaced to
  /// the chat UI exactly like the Chance Time wheel's pending flag: set + clear
  /// here with [notifyListeners]; the page observes it and shows the popup once.
  DetectedCharacter? _pendingGuestDetection;

  /// The candidate the popup should show (null = nothing pending).
  DetectedCharacter? get pendingGuestDetection => _pendingGuestDetection;

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

  /// The honest "this turn is still in motion" predicate — what the mutation
  /// guards should ask, rather than `_isGenerating` alone.
  ///
  /// NOT for the escape hatches: `stopGeneration` and
  /// `_cancelAndWaitForGeneration` must keep testing `_isGenerating` on its
  /// own. The first aborts an in-flight HTTP stream (there is none during
  /// post-gen), and the second SPINS until the flag clears — broadening it
  /// would hang the caller if post-gen ever failed to settle.
  bool get _isTurnBusy => _isGenerating || _isPostGenerating;

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
  // The token loop used to fire notifyListeners() up to twice PER TOKEN
  // (~55-80 full chat-page rebuilds/sec at local speeds), which was the
  // single largest source of "the app feels sluggy while generating".
  // _notifyStreamListeners coalesces those into at most one notify per
  // ~33 ms (≈30 fps — above the eye's text-reading rate) with a guaranteed
  // trailing notify so the final token batch always paints. End-of-turn
  // paths still call plain notifyListeners() directly, so terminal state
  // (isGenerating=false, chips, perf) is never throttled away.
  DateTime _lastStreamNotify = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _streamNotifyTimer;
  static const Duration _kStreamNotifyInterval = Duration(milliseconds: 33);

  void _notifyStreamListeners() {
    if (_streamNotifyTimer != null) return; // trailing notify already queued
    final elapsed = DateTime.now().difference(_lastStreamNotify);
    if (elapsed >= _kStreamNotifyInterval) {
      _lastStreamNotify = DateTime.now();
      notifyListeners();
    } else {
      _streamNotifyTimer = Timer(_kStreamNotifyInterval - elapsed, () {
        _streamNotifyTimer = null;
        _lastStreamNotify = DateTime.now();
        notifyListeners();
      });
    }
  }

  void _cancelStreamNotifyThrottle() {
    _streamNotifyTimer?.cancel();
    _streamNotifyTimer = null;
  }

  // ── Web token broadcast ──
  // External consumers (the web server's StreamHub) listen to this for real-time token streaming.
  final StreamController<String> _tokenBroadcast =
      StreamController<String>.broadcast();
  Stream<String> get tokenStream => _tokenBroadcast.stream;

  /// Emits complete sentences as they're detected during LLM token streaming.
  /// Used by call mode to start TTS on the first sentence immediately.
  final StreamController<String> _sentenceBroadcast =
      StreamController<String>.broadcast();
  Stream<String> get sentenceStream => _sentenceBroadcast.stream;
  String _sentenceBuffer = ''; // accumulates tokens until a sentence boundary

  /// Whether the app is in voice call mode (auto-disables reasoning for lower latency).
  bool _callMode = false;
  bool get callMode => _callMode;
  set callMode(bool value) {
    _callMode = value;
    notifyListeners();
  }

  // ── Group chat state (owned by GroupTurnManager) ──
  GroupTurnManager? _groupManager;

  // Wired for decoupled group member loading (so setActiveGroup works even if caller
  // doesn't explicitly pass groupRepo every time). Set from main.dart provider setup.
  GroupChatRepository? _groupChatRepository;

  // One-shot hidden directive for a forked-in character's custom entrance
  // (Direction mode). Injected into the prompt, consumed on the next generation;
  // the forced-speaker side is handled by GroupTurnManager.setNextSpeaker.
  String? _entranceDirective;

  // ── Clean delegation layer (GroupTurnManager is the real owner) ────────
  // These keep the rest of the (very large) file readable while we finish
  // the migration. All group state now lives in _groupManager.
  GroupChat? get _activeGroup => _groupManager?.activeGroup;
  List<CharacterCard> get _groupCharacters =>
      _groupManager?.characters ?? const <CharacterCard>[];
  bool get _observerMode => _groupManager?.observerMode ?? false;
  set _observerMode(bool value) {
    _groupManager?.setObserverMode(value);
  }

  bool get _autoPlayActive => _groupManager?.autoPlayActive ?? false;
  set _autoPlayActive(bool value) {
    if (value) {
      _groupManager?.startAutoPlay();
    } else {
      _groupManager?.stopAutoPlay();
    }
  }

  double get directorDelaySec => _groupManager?.directorDelaySec ?? 15.0;
  set directorDelaySec(double value) {
    if (_groupManager != null) {
      _groupManager!.directorDelaySec = value;
    }
  }

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

  /// Returns the personal objectives for a specific character when in group mode.
  /// Falls back to the global list for 1:1 or when no per-char data exists yet.
  List<Objective> getObjectivesForGroupCharacter(CharacterCard character) {
    if (_activeGroup == null) return _activeObjectives;
    final id = _getCharacterIdFromCard(character);
    return _groupObjectives[id] ?? const <Objective>[];
  }

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
  bool _summaryPaused =
      false; // secondary runtime flag (like _isSummaryGenerating); must be defensively zeroed on *all* reset/new-chat/0-session/group/setActive/load/delete paths to prevent leak of pause state across contexts (see CLAUDE.md keep-sync + incomplete zeroing (simple authority; sim reason kept)).
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

  // TOMBSTONE: `_moodDecayCounter` lived here. It was captured into every
  // message's realism_state, written to sessions.moodDecayCounter, and dutifully
  // restored on regen — and NO decay logic ever read it. The counter that
  // actually gates short-term bond decay is RelationshipService's
  // (_turnsSinceDecayCheck in 1:1, the per-member 'turnsSinceDecayCheck' map key
  // in a group), and that one was never restored, so the regen revert only
  // looked like it rewound the cadence. Both are now captured and restored for
  // real via captureCadenceAndFeelings / restoreFromMessageState.
  // The sessions.moodDecayCounter COLUMN is deliberately left in place and
  // dormant (it defaults to 0) — dropping it is a schema change, and external
  // tools write this database directly.

  // Emotional state
  String _characterEmotion = '';
  String _emotionIntensity = ''; // mild/moderate/strong

  // Expression images + classification (extracted to ExpressionService in chat/expression_classifier.dart).
  // See CLAUDE.md keep-sync + incomplete zeroing now complete + buffer removal + authority (live ext) at all sites + both startNew. (thins only)

  // Passage of time (core state + advance/nudge/OOC/resolve/reset/seed/load logic extracted to TimeService).
  // See CLAUDE.md keep-sync/incomplete zeroing/buffer removal/authority (live ext). Service owned.
  // god thins to delegation + 5 @Deprecated shims. 0 new private methods added in god for time.
  // time injection only thin wrapper here; full in step8. (cross-ref setActiveCharacter:1572 etc)

  // NSFW cooldown & lust (core state + tier calc + reset/seed/load/restore + group per-char scalars
  // + applyClimax/decrement extracted to NsfwService).
  // See keep reset + zeroing + buffer removal + authority (simple) in CLAUDE.md.
  // cooldown mutations, arousal, and helpers now owned by the service; god thins to delegation
  // + 5 @Deprecated shims. 0 new private methods added in god for nsfw.
  // _runPostGenNeedsChecks thin to needs_impact_evaluator (cross-ref setActiveCharacter:1572 etc; see CLAUDE.md for keep-sync).

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

  // Forwarding for critical threshold (moved to NeedsSimulation after buffer removal; UI + cards still reference the old ChatService surface)
  static int get needCriticalThreshold => NeedsSimulation.needCriticalThreshold;

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

  /// The chat-scoped lorebook: lore that lives and dies with this one
  /// conversation. The sidebar edits it directly (live instance) and calls
  /// [commitChatLorebookEdit] to notify + persist.
  Lorebook get chatLorebook => _loreTimedEffects.chatLorebook;

  Future<void> commitChatLorebookEdit() async {
    notifyListeners();
    await _saveChat();
  }

  late final _lorebookInjector = _buildLorebookInjector();

  /// Names of lore entries dropped by the token budget on the last
  /// generation, plus the meter numbers the sidebar shows.
  List<String> _lastLoreOverflow = const [];
  List<String> get lastLoreOverflow => _lastLoreOverflow;
  int _lastLoreTokens = 0;
  int _lastLoreBudget = 0;
  int get lastLoreTokens => _lastLoreTokens;
  int get lastLoreBudget => _lastLoreBudget;

  /// Read surface for the sidebar's sticky/cooldown countdown pills.
  LorebookTimedEffects get loreTimedEffects => _loreTimedEffects;

  /// Mutation-free "would trigger next" preview for the composer draft.
  Set<LorebookEntry> previewLoreTriggers(String draft) =>
      _lorebookScanner.previewTriggers(draft);

  /// The post-group-filter active lore set — what is ACTUALLY injected this
  /// turn. Sidebar dots and the web facade read this so they never show an
  /// inclusion-group loser as active.
  Set<LorebookEntry> currentlyActiveLoreEntries() => _lorebookInjector
      .activeEntries(sessionSeed: _currentSessionId ?? '')
      .toSet();

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

  /// Public attach surface for chat tools / UI.
  List<String> get chatWorldIds => List.unmodifiable(_chatWorldIds);

  /// Climate active on the current story day (span override or world default).
  Biome get activeChatBiome =>
      _biomeSchedule.biomeAt(_timeService.dayCount);

  /// Central macro resolver for prompt template expansion.
  late final _macroResolver = MacroResolver();

  /// In-memory clock for {{idle_duration}} — set on each user send; null
  /// after a restart (the macro passes through untouched then).
  DateTime? _lastUserMessageAt;

  /// Regex matching any `{{macro}}` or `{{macro::args}}` pattern.
  /// Used to detect stray unresolved macros in chat history.
  static final _macroPattern = RegExp(r'\{\{(\w+)(?:::(.+?))?\}\}');

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

  /// Coarse absence bucket ("a few days"), or null under the threshold /
  /// fresh chat. Words only — never digits (see AbsenceTracker).
  String? get absencePhrase => AbsenceTracker.bucketPhrase(
    _absenceGap,
    thresholdHours: _storageService.absenceThresholdHours,
  );

  /// [absencePhrase] gated by the welcome-back-banner setting — the ONE gate
  /// both the desktop banner and the web facade read, so they can't drift.
  String? get absenceBannerPhrase =>
      _storageService.absenceBannerEnabled ? absencePhrase : null;

  /// Today's story weather, or null when off (living-time-features.md §3).
  /// Pure recompute from existing state — nothing stored, so save/load and
  /// group re-entry agree for free. Gate: realism + passage-of-time + the
  /// global toggle. Consumed by the injection leaf, the needs decay
  /// modifiers, the sidebar TimeStrip, and the web facade — one source.
  DailyWeather? get currentWeather {
    if (!_realismEnabled ||
        !_timeService.passageOfTimeEnabled ||
        !_storageService.weatherEnabled) {
      return null;
    }
    final seed = _currentSessionId;
    if (seed == null) return null;
    return WeatherEngine.weatherFor(
      sessionSeed: seed,
      dayCount: _timeService.dayCount,
      date: _timeService.clock,
      biomeAtDay: _biomeAtDay,
    );
  }

  /// Tomorrow's story weather under the same gate as [currentWeather].
  /// Because the engine is a prefix-stable deterministic walk, this forecast
  /// is exactly what day dayCount+1 will be when the story clock reaches it
  /// (dayCount is derived from the calendar date, so +1 day ⇔ +1 dayCount) —
  /// foreshadowed fronts always arrive (except the first day of a mid-chat
  /// climate switch — see [WeatherInjection.suppressForeshadow]).
  /// Recompute is O(dayCount) integer math, called once per turn by the
  /// injection and once per facade read.
  DailyWeather? get upcomingWeather {
    if (currentWeather == null) return null;
    return WeatherEngine.weatherFor(
      sessionSeed: _currentSessionId!,
      dayCount: _timeService.dayCount + 1,
      date: _timeService.clock.add(const Duration(days: 1)),
      biomeAtDay: _biomeAtDay,
    );
  }

  /// The current DAY-PART's weather (Living Time §3 v3): the day script's
  /// condition for the story-clock hour plus the deterministic °C. Same gate
  /// and recompute contract as [currentWeather] — nothing stored. Consumed
  /// by the injection, the needs decay view below, the sidebar chip, and the
  /// web facade.
  SegmentWeather? get currentSegmentWeather {
    if (currentWeather == null) return null;
    return WeatherSegments.segmentWeatherFor(
      sessionSeed: _currentSessionId!,
      dayCount: _timeService.dayCount,
      date: _timeService.clock,
      hour: _timeService.clock.hour,
      biomeAtDay: _biomeAtDay,
    );
  }

  late final _weatherInjection = _buildWeatherInjection();

  // (previousSegmentWeather / _segmentAt / _worldDefaultBiome / _biomeAtDay
  // moved to chat_service_wiring_injection.dart)

  // ── Ambitions (Living Time §6) — builder in chat_service_wiring_memory.dart ──
  late final _ambitionService = _buildAmbitionService();

  /// Sidebar/web read surface (Living Time §6): [card]'s ambitions with
  /// live progress — triggers the lazy cache warm, so first render may show
  /// "just beginning" and correct itself one notify later. The ONE merge of
  /// card-authored definitions + per-chat progress; desktop and web both
  /// read through it so they can't drift.
  List<({String text, int progress})> ambitionsFor(CharacterCard card) {
    final sessionId = _currentSessionId;
    final list = card.frontPorchExtensions?.ambitions ?? const [];
    if (sessionId == null || list.isEmpty) return const [];
    final cid = _getCharacterIdFromCard(card);
    _ambitionService.ensureCacheWarm(sessionId, cid);
    final progress =
        _ambitionService.cachedProgress(sessionId, cid) ?? const {};
    return [for (final a in list) (text: a, progress: progress[a] ?? 0)];
  }

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

  // ── LLM Eval Engine (step 9: _fireLLMEval + strip + extract + needs impact cb) ──
  // Plain class (not ChangeNotifier). Owns the central eval firing (streaming/retry/cancel, 4000/0.1/no-reasoning),
  // central strip (completed+unclosed), JSON extractors, evaluateNeedsImpactCall (for needs_impact_evaluator).
  // The 5 realism eval prompt builders + calls (rel/emotion/phys/narr w/ proposed_objective, oneShot) moved to
  // sibling leaf realism_evals.dart (step 10); this engine provides fire/strip/extract cbs to it (granular).
  // objective proposal handling + generateObjectiveTasks + _checkTaskCompletionInBackground moved to
  // sibling leaf objective_proposal.dart (step 11); this engine provides strip cb to it (for 2000 paths).
  // Wired with granular cbs for 1:1 vs group (via impersonation for speaker), test overrides,
  // pending/emotion state, capture, + service deps (rel) .
  // (onNotify/onSaveChat removed in step 10 fix round 1 + step11: oneShot populates pending snapshot;
  // god owns the post-eval _saveChat/notify in pre-turn + baseline paths to avoid double + races;
  // on* dead post step11 objective move, cleaned).
  // 0 @Deprecated shims. 0 new god private _ methods beyond the required thin delegates (_fireLLMEval, _stripThinkBlocks, _extractJson*, evaluateNeedsImpactCall; the 5 _evaluate*Call thins now point to realism_evals; generate/check thins now to objective_proposal; the void _ count grep stayed 15; +1 late final only; thins/calls/late final only per plan). (cross-ref setActiveCharacter:1572 etc)
  // Stateless/prompt-only: no reset calls needed. Reset hygiene comments list full set + llm_eval_engine (stateless or prompt-only;
  // no reset calls needed; incomplete zeroing... now complete (see CLAUDE.md)) + realism_evals (stateless or prompt-only; no reset calls needed) + objective_proposal (stateless or prompt-only; no reset calls needed) + journal_maintenance (stateless or prompt-only; no reset calls needed) + cross-refs (e.g. setActiveCharacter:1572). Both startNew branches explicit.
  // 1:1 vs group + oneShot vs normal dispatch/parity preserved exactly (cbs + impersonation temp re-load; qualified).
  // aug exercising only passive/qualified (no llm-eval-specific aug file edits; resets/loads/greetings/post hit by pre-existing
  // startNew/setActive/_loadLast/group in key suites; full eval/JSON/strip + needs impact only in dedicated + manual;
  // objective proposal/gen/check exercised via god thins generate/check ; qualified notes only in dedicated header + god + MD per precedent).
  // ── Eval pipeline (builders in chat_service_wiring_evals.dart) ──
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

  /// The current model's tool-calling verdict (sidebar pill + web facade).
  ToolCallSupport get toolCallSupport => _toolSupportTester.current;
  bool get isTestingToolSupport => _toolSupportTester.isTesting;

  /// Re-probe the current backend+model's tool support (pill tap).
  Future<void> testToolCalling() => _toolSupportTester.test(force: true);

  late final _journalMaintenance = _buildJournalMaintenance();

  /// Public door for the Journal UI (phase 3): the sidebar panel and the
  /// diary dialog read/mutate cards directly on the store (scoped by
  /// [currentSessionId] + the participant's stable id); the injection builder
  /// re-reads the DB every turn, so UI edits reach the prompt with no extra
  /// plumbing. Instance getter (not extension) so FakeChatService can
  /// override it via `implements` (see isGrowthPassRunning precedent).
  JournalStore get journalStore => _journalStore;

  /// "Our Story" timeline read-model (Living Time §7) — pure aggregation
  /// over data already persisted; the journal dialog's timeline tab and the
  /// web facade both read through this one instance.
  late final MilestoneFeed milestoneFeed = MilestoneFeed(
    getDb: () => _db,
    getMessages: () => _messages,
  );

  late final _journalInjection = _buildJournalInjection();

  // ── Growth Rings (docs/design/growth-rings.md) — builders in
  // chat_service_wiring_memory.dart. Per-chat, per-character growth entries;
  // trigger/cache/UI surface live in chat_service_growth.dart (part file). ──
  late final _growthStore = _buildGrowthStore();
  late final _growthReview = _buildGrowthReview();
  late final _growthService = _buildGrowthService();

  // Effective getters (all injection paths route through these).
  String _getEffectivePersonality(CharacterCard card) =>
      _growthService.effectivePersonality(card);
  // Scenario evolution is retired (growth-rings design §3.2): the Journal
  // recap owns "where we are", so every mode uses the card's own scenario.
  String _getEffectiveScenario(CharacterCard card) => card.scenario;

  // Step 15 (refactor remaining `ChatService`): complete. God is now thin
  // coordinator/orchestrator + minimal god-owned state that per-plan stayed
  // (_groupRealism + _loadGroup*IntoScalars / _saveScalarsIntoGroupRealism /
  // _setGroup* / _loadGroupRealismStateFromSession / _sync... / _restore... ;
  // core sendMessage pre/post + _generateResponse (pick/eval dance/impersonation/
  // build* stayed / post-gen finalization) ; _buildChatHistoryWithBudget ;
  // _loadLastSession / _saveChat / _doSaveChat ; _pickNextGroupCharacter ;
  // _evaluateRealismForUpcomingSpeaker ; _waitForTtsThenContinue + drain
  // buffer / _flush / _startDrainTimer ; _applyMoodDecay ; _maybeEmbedMessages ;
  // _runPostGenNeedsChecks thin + periodic thins; all reset keep-sync + "now complete" (see CLAUDE.md); 0 new god priv _ (count=15); thins + coord only. Buffer removal + simple authority complete.
  // (3 vestigial phrases cleaned: 2 briefing + 1 per-thin at _getNsfwCooldownInjection:7742) + thin consistency as part of
  // task (no heroic new splits; smallest change; no bloat/parallel paths).
  // 1:1 vs group parity preserved for all surfaces (dispatch via cbs + god
  // impersonation dance). aug tests: only qualified passive (no step-15 edits).
  // See docs/refactor-god-file-modularization.md Step 15 + CLAUDE Path Map.
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

  /// Default system prompt for group chats, designed to prevent characters
  /// from speaking for each other and maintain turn discipline.
  static const String defaultGroupSystemPrompt =
      'You are roleplaying in a multi-character group conversation. '
      'CRITICAL RULES:\n'
      '1. You MUST only write dialogue and actions for the character whose turn it is (indicated after <START>). '
      'NEVER write dialogue, thoughts, or actions for other characters or {{user}}.\n'
      '2. Stay fully in character \u2014 use the speaking character\'s unique voice, mannerisms, personality, and speech patterns.\n'
      '3. Keep your response focused on ONE character\'s contribution. Do not narrate what other characters do or say.\n'
      '4. React naturally to what other characters and {{user}} have said. Reference their words, but do not put words in their mouths.\n'
      '5. Write in the style of collaborative roleplay: use *asterisks* for actions/narration and regular text for dialogue.\n'
      '6. Keep responses concise and punchy \u2014 leave room for the next character to respond.\n'
      '7. Never break character or reference the fact that you are an AI.';

  /// System prompt for Observer Mode — characters interact with each other, user is not present.
  static const String observerModeSystemPrompt =
      'You are roleplaying in a multi-character group conversation. '
      'The user is NOT a participant in this story — they are an invisible observer/director. '
      'CRITICAL RULES:\n'
      '1. You MUST only write dialogue and actions for the character whose turn it is. '
      'NEVER write for other characters.\n'
      '2. Characters should interact naturally WITH EACH OTHER — address other characters by name, '
      'respond to what they said, react to their actions. Build on the conversation organically.\n'
      '3. Stay fully in character — use the speaking character\'s unique voice and personality.\n'
      '4. If a [Director] note appears, follow its guidance to steer the scene (introduce new topics, '
      'create conflict, have a character enter/leave, etc.) but do NOT acknowledge the director directly.\n'
      '5. Write in collaborative roleplay style: *asterisks* for actions, regular text for dialogue.\n'
      '6. Keep responses concise — leave room for the next character to respond.\n'
      '7. Never break character or reference being an AI.\n'
      '8. Characters may naturally address each other, start side conversations, argue, agree, '
      'tell stories, ask questions, or react emotionally — make the conversation feel alive and dynamic.';

  /// Default system prompt for local KoboldCPP backends (smaller models).
  /// Kept concise so it doesn't eat too much of the limited context window.
  static const String defaultKoboldSystemPrompt =
      'Write {{char}}\'s next reply in this roleplay with {{user}}. '
      'Stay in character as {{char}} at all times. '
      'Use *asterisks* for actions and narration, regular text for dialogue. '
      'Be creative, descriptive, and drive the scene forward. '
      'Never write actions or dialogue for {{user}}. '
      'Never break character or mention being an AI.';

  /// Default system prompt for remote API backends (large cloud models).
  /// Highly detailed to leverage the model's full capabilities.
  static const String defaultApiSystemPrompt =
      'You are an expert collaborative fiction writer and immersive roleplay partner. '
      'You write as {{char}} in an ongoing interactive story with {{user}}.\n\n'
      'CORE IDENTITY:\n'
      '- Embody {{char}} completely. Every response must reflect their unique personality, speech patterns, '
      'vocabulary level, emotional state, and worldview as defined in their character description.\n'
      '- {{char}} is a living, breathing character with their own desires, fears, opinions, and agency \u2014 '
      'not a servant of {{user}}. They can disagree, have bad days, make mistakes, and act according to their own motivations.\n\n'
      'WRITING CRAFT:\n'
      '- Write in a natural, literary style. Vary sentence length and structure. Avoid repetitive sentence openings.\n'
      '- Show emotions through body language, micro-expressions, vocal tone, and subtle actions rather than stating '
      'feelings directly ("she clenched her jaw" not "she felt angry").\n'
      '- Use all five senses \u2014 sight, sound, smell, touch, taste \u2014 to create vivid, immersive scenes.\n'
      '- Dialogue should feel natural and conversational. Characters can interrupt, trail off, use contractions, '
      'stumble over words, or speak in fragments when emotionally charged.\n'
      '- Weave internal thoughts, environmental details, and physical sensations into responses to create depth.\n'
      '- Match the tone and pacing to the scene: tense moments get short, punchy prose; reflective moments get '
      'slower, more lyrical writing.\n\n'
      'ANTI-SLOP RULES \u2014 AVOID THESE CLICH\u00c9S:\n'
      '- Do NOT use: "a symphony of", "a dance of", "sent shivers down", "electricity coursed through", '
      '"breath hitched", "pupils dilated", "orbs" (for eyes), "ministrations", "mewled", '
      '"the air crackled with", "a masterpiece of", "elicited a moan".\n'
      '- Do NOT start responses with: "I", a sigh, a chuckle, or raising an eyebrow.\n'
      '- Do NOT use purple prose or melodramatic narration. Keep descriptions grounded and specific.\n'
      '- Vary your emotional vocabulary \u2014 don\'t repeat the same descriptors across responses.\n\n'
      'RESPONSE GUIDELINES:\n'
      '- Write 2-5 paragraphs per response unless the scene calls for shorter exchanges.\n'
      '- Always advance the scene meaningfully. Each response should move the story forward through action, '
      'revelation, or emotional development.\n'
      '- End responses at natural pause points that invite {{user}} to react \u2014 don\'t resolve conflicts or '
      'answer your own questions.\n'
      '- Never narrate {{user}}\'s actions, thoughts, dialogue, or emotional reactions. Their agency is sacred.\n'
      '- Never break the fourth wall, mention being an AI, or reference the roleplay as fiction.\n'
      '- Maintain continuity with all previously established facts, character history, and world details.\n\n'
      'DIALOGUE FORMAT:\n'
      '- Use regular text for speech: "Like this," she said.\n'
      '- Use *asterisks* for actions and narration: *She leaned against the doorframe, arms crossed.*\n'
      '- Internal thoughts can be written in italics or described through narration.';

  /// Inter-call delay used when staggering the multi-call realism evaluations.
  /// Kept in the class body (not the realism-evals extension) because the
  /// periodic-eval coordinator in this file references it directly; extension
  /// statics aren't visible unqualified to the host type.
  static const _kEvalDispatchStagger = Duration(milliseconds: 50);

  CharacterCard? get activeCharacter => _activeCharacter;
  List<ChatMessage> get messages => List.unmodifiable(_messages);
  /// Token streaming — deliberately the NARROW sense.
  ///
  /// This drives the send button's enabled state, and widening it to include
  /// post-generation was tried and reverted: background work (post-gen evals,
  /// objective completion checks) then held the composer disabled for most of
  /// a turn on a slow machine. CI caught it — the E2E driver could not find a
  /// tappable send button across eight retries on the macOS and Windows
  /// runners, which is exactly what a user on a slow local backend would have
  /// experienced.
  ///
  /// The data-loss hazard that widening was meant to solve is real but belongs
  /// at the composer, not here: what matters is that a composer's own guard
  /// uses the SAME predicate as [sendMessage]. If the composer's check is
  /// narrower than the service's, the composer clears the field for a send the
  /// service then refuses. See [isSettlingTurn] and the mirror in
  /// `_sendCurrentMessage`.
  bool get isGenerating => _isGenerating;

  /// True while the turn's awaited post-generation work is still settling.
  /// Exposed so tests can assert the window opens and — more importantly —
  /// always closes. See [_isPostGenerating].
  bool get isSettlingTurn => _isPostGenerating;
  bool get isLoadingSession => _isLoadingSession;
  String? get currentSessionId => _currentSessionId;

  /// The per-chat gallery look selected for [characterId] in the active session,
  /// or null (no look chosen → the character's library face shows). Keyed by the
  /// character's library id so the same character shares one selection across a
  /// group cast.
  String? selectedLookFor(String characterId) => _selectedLooks[characterId];

  /// Set (or clear, when [lookId] is null) the per-chat gallery look for
  /// [characterId] in the active session, persist the whole map to the session's
  /// selected-look column, and repaint. Never touches `imagePath` — the library
  /// face is independent of which look shows in a given chat.
  Future<void> setLookForCharacter(String characterId, String? lookId) async {
    final sid = _currentSessionId;
    if (sid == null || characterId.isEmpty) return; // never key by a blank id
    // decodeSelectedLooks also drops empty keys, so a blank would silently fail
    // to round-trip; refuse it here so the caller notices instead.
    if (lookId == null) {
      _selectedLooks.remove(characterId);
    } else {
      _selectedLooks[characterId] = lookId;
    }
    notifyListeners();
    await _db.setSelectedLookForSession(
      sid,
      encodeSelectedLooks(_selectedLooks),
    );
  }

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
  bool get autoPlayActive => _groupManager?.autoPlayActive ?? false;
  List<CharacterCard> get groupCharacters =>
      _groupManager?.characters ?? const <CharacterCard>[];

  /// The character who will speak next in group mode.
  /// Fully delegated to GroupTurnManager (supports forced override + both turn orders + Director Mode).
  CharacterCard? get nextCharacter => _groupManager?.nextSpeaker;

  /// The unified ordered cast of speakers for the active chat, regardless of
  /// mode. This is the single roster the UI reads instead of branching on
  /// `isGroupMode` between `activeCharacter`, `groupCharacters`, and
  /// `sceneGuestCards`:
  ///   - Group chat → each group member, in turn order (no distinct host).
  ///   - 1:1 / NPC chat → the host (`cast[0]`, realism-bearing) followed by any
  ///     present Scene Guests (lite NPCs, realism off).
  /// Empty only when no chat is loaded.
  List<ChatParticipant> get cast {
    if (isGroupMode) {
      return [
        for (final c in groupCharacters)
          ChatParticipant(card: c, isHost: false),
      ];
    }
    final host = _activeCharacter;
    return [
      if (host != null) ChatParticipant(card: host, isHost: true),
      for (final g in _sceneGuestCards) ChatParticipant(card: g, isHost: false),
    ];
  }

  /// True only for regular (non-Director) group chats where the Realism Engine
  /// is enabled. Used by the group sidebar to decide whether to show per-character
  /// emotion / needs indicators.
  bool get isGroupRealismActive =>
      _realismEnabled && isGroupMode && !observerMode;

  /// Phase 3: Hard cap for inter-character relationship tracking.
  /// Per the approved plan, full hidden inter-character dynamics (seeding,
  /// decay, injection, and updates) are **only** performed when the group has
  /// 4 or fewer members. This prevents combinatorial explosion and prompt bloat.
  ///
  /// When the group has 5+ members:
  /// - Inter-character 'relationships' maps remain empty / are ignored.
  /// - All characters still receive full per-speaker realism evaluations for
  ///   their feelings **toward the user** (visible bars continue to work).
  bool get _shouldTrackInterCharacterRelationships {
    if (_activeGroup == null) return false;
    return _groupCharacters.length <= 4;
  }

  double get tokensPerSecond {
    if (_tokenTimestamps.length < 2) return 0.0;
    // Use rolling window: tokens in the last 3 seconds
    final now = DateTime.now();
    final cutoff = now.subtract(const Duration(seconds: 3));
    final recent = _tokenTimestamps.where((t) => t.isAfter(cutoff)).length;
    if (recent < 2) {
      // Fallback to overall average
      if (_generationStartTime == null || _tokensGenerated == 0) return 0.0;
      final elapsed =
          now.difference(_generationStartTime!).inMilliseconds / 1000.0;
      return elapsed > 0 ? _tokensGenerated / elapsed : 0.0;
    }
    final windowStart = _tokenTimestamps.where((t) => t.isAfter(cutoff)).first;
    final windowElapsed = now.difference(windowStart).inMilliseconds / 1000.0;
    return windowElapsed > 0 ? recent / windowElapsed : 0.0;
  }

  int _greetingIndex = 0;
  int get greetingIndex => _greetingIndex;

  ChatService(
    this._koboldService,
    this._userPersonaService,
    this._storageService,
    this._worldRepository,
  ) {
    // Probe verdicts land from background passes and the manual test alike —
    // rebroadcast so the sidebar's tool-calling pill repaints live.
    _toolProbe.addListener(notifyListeners);
    // Local model path / remote model name changes alter the eval identity —
    // retest tool support for the new model (sidebar pill contract).
    _storageService.addListener(_onBackendIdentityMaybeChanged);
  }

  void _onBackendIdentityMaybeChanged() {
    if (_disposed) return;
    _toolSupportTester.onBackendMaybeChanged();
  }

  /// Set the database instance after construction. Alias of [updateDatabase]
  /// so startup wiring and post-swap rebinding can never drift apart.
  void setDatabase(AppDatabase db) => updateDatabase(db);

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
  set sessionGenSettings(ChatGenerationSettings value) {
    _sessionGenSettings = value;
    _saveChat();
    notifyListeners();
  }

  /// Per-chat theme overrides (preset + customized colors/font/background/border).
  ChatThemeOverrides get sessionThemeOverrides => _sessionThemeOverrides;
  set sessionThemeOverrides(ChatThemeOverrides value) {
    _sessionThemeOverrides = value;
    // Persist only when a chat is actually open. The web facade already guards
    // this, but a bare `_currentSessionId!` would crash any other caller that
    // sets the theme with no active session (session close mid-save, tests).
    final sid = _currentSessionId;
    if (sid != null) {
      _db.setThemeOverrides(sid, value.toJsonString());
    }
    notifyListeners();
  }

  String? get parentSessionId => _parentSessionId;
  int? get forkIndex => _forkIndex;
  String? get sessionName => _sessionName;
  String? get sessionDescription => _sessionDescription;
  String get summary => _summary;
  bool get summaryPaused => _summaryPaused;
  int get summaryLastIndex => _summaryLastIndex;
  bool get isSummaryGenerating => _isSummaryGenerating;
  // Public access to extracted domain services (final shim migration + cleanup).
  // Callers (UI sidebars, tests, chance overlay, group settings, etc.) now use direct:
  //   chat.relationshipService.affectionScore / .trustLevel / shortTermTierName etc.
  //   chat.timeService.timeOfDay / .dayCount / .setPassageOfTimeEnabled(...)
  //   chat.nsfwService.nsfwCooldownEnabled / .arousalLevel / .setNsfwCooldownEnabled
  //   chat.chaosModeService.chaosModeEnabled / .chaosPressure / .hasPendingChaosEvent
  //   chat.needsSimulation.vector / .pendingCatastrophe
  //   chat.expressionService.currentExpressionLabel / .resolveExpressionAvatar / .setManualExpression
  // God owns the late finals (for 1:1+group dispatch, _groupRealism load/save, cbs, notify, reset hygiene).
  // Barrel not updated (internal; <3 public cross locations precedent).
  RelationshipService get relationshipService => _relationshipService;
  ExpressionService get expressionService => _expressionService;
  TimeService get timeService => _timeService;
  NsfwService get nsfwService => _nsfwService;
  ChaosModeService get chaosModeService => _chaosModeService;
  NeedsSimulation get needsSimulation => _needsSimulation;

  // Thin public surface for flat members still read/written by UI/pages/dialogs
  // (chat.chaosPressure, chat.activeFixation, chat.pendingTrustRepair, chat.currentExpressionLabel,
  // chat.resolveExpressionAvatar, per "thin delegation here; full XXX in the leaf" + 0 new god _ privates).
  // Full impl in the respective *Service (chaos_mode_service, relationship_service, expression_classifier in chat/).
  // 1:1 vs group parity via the services' cbs + god impersonation dance (unchanged).
  int get chaosPressure => _chaosModeService.chaosPressure;
  String get activeFixation => _relationshipService.activeFixation;
  bool get pendingTrustRepair => _relationshipService.pendingTrustRepair;
  String? get currentExpressionLabel =>
      _expressionService.currentExpressionLabel;
  AvatarImage? resolveExpressionAvatar(
    CharacterCard character, {
    bool rerollIfSame = false,
  }) => _expressionService.resolveExpressionAvatar(
    character,
    rerollIfSame: rerollIfSame,
  );

  bool get realismEnabled => _realismEnabled;

  /// True when the Realism Engine (and Needs) should actually run for the
  /// current chat mode. In group chats this is only true when *not* in
  /// Director/observerMode (per design — Director is narrative control,
  /// not simulation).
  bool get _realismActiveThisMode =>
      _realismEnabled &&
      !_autoResponseInProgress &&
      (_activeGroup == null || !_observerMode);

  bool get isEvaluatingRealism => _isEvaluatingRealism;
  bool get isCancellingRealismEval => _isCancellingRealismEval;
  bool get isProcessingGreeting => _isProcessingGreeting;

  // Verifier phase (for overlay header "🕵️ Verifying Realism output" + pass progress, and bubble chip data source).
  // God coordination only; leaf drives via cb thins (no new god void _).
  bool get isVerifyingRealism => _isVerifyingRealism;
  int get verificationPass => _verificationPass;
  int get verificationMaxPasses => _verificationMaxPasses;

  /// Stream text with think blocks stripped (for display) — memoized on
  /// string identity (the overlay + web broadcast read it every notify).
  /// Class member, not extension: FakeChatService overrides it in goldens.
  String? _evalCleanSrc, _evalCleanOut;
  String get realismEvalStreamTextClean =>
      identical(_realismEvalStreamText, _evalCleanSrc)
      ? _evalCleanOut!
      : _evalCleanOut = _stripThinkBlocks(
          _evalCleanSrc = _realismEvalStreamText,
        );
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

  /// Returns whether the currently active character enjoys low hygiene.
  /// We always prefer the live value from the character's FrontPorchExtensions
  /// so that toggling the setting on the character immediately affects any
  /// already-loaded chats (no database change required).
  bool get enjoysLowHygiene {
    // Group chats have no single "active character" hygiene preference — it is
    // strictly per-speaker (the injection builders resolve it from each
    // member's own card). Never fall through to the 1:1 scalar in a group, or a
    // preference carried in from a previous 1:1 (e.g. a "enjoys being dirty"
    // character) would stay stale and invert every group member's hygiene.
    if (_activeGroup != null) {
      return _activeCharacter?.frontPorchExtensions?.enjoysLowHygiene ?? false;
    }
    return _activeCharacter?.frontPorchExtensions?.enjoysLowHygiene ??
        _enjoysLowHygiene;
  }

  /// Re-reads the "Enjoys low hygiene" preference from the currently active
  /// character's FrontPorchExtensions. Call this after editing the character
  /// so that existing chats immediately pick up the new setting without a
  /// database change.
  void refreshEnjoysLowHygieneFromActiveCharacter() {
    if (_activeCharacter != null) {
      _enjoysLowHygiene =
          _activeCharacter!.frontPorchExtensions?.enjoysLowHygiene ?? false;
      notifyListeners();
    }
  }

  bool get chaosNsfwEnabled => _chaosModeService.chaosNsfwEnabled;

  // (chanceTimePendingTrigger / hasPendingChaosEvent / consumeChanceTimeTrigger /
  // the web/mobile Chance Time surface moved to chat_service_turn_flow.dart)

  // (nsfw/relationship long list of @Dep shims excised in final cleanup; use nsfwService / relationshipService)

  /// Human-readable mood label containing exact emotion string and valence direction.
  String get moodLabel {
    if (_characterEmotion.isEmpty) return 'Neutral';
    final capEmotion =
        _characterEmotion.substring(0, 1).toUpperCase() +
        _characterEmotion.substring(1);
    final intensity = _emotionIntensity.isNotEmpty
        ? ' ($_emotionIntensity)'
        : '';
    return '$capEmotion$intensity';
  }

  /// Returns the standard expression label for the current emotion.
  ///
  /// If a manual expression is set via [setManualExpression], returns that.
  /// When classification mode is 'onnx', uses the ONNX classifier result.
  /// Otherwise maps the nuanced emotion to a standard label
  /// using [EmotionLabels.nuancedToStandard].
  // NOTE: an earlier version of this comment claimed currentExpressionLabel,
  // resolveExpressionAvatar, setManualExpression and setExpressionClassifierService
  // had been "excised". They had not. All four still exist and are live:
  // chat_page.dart calls currentExpressionLabel and resolveExpressionAvatar, and
  // main.dart calls setExpressionClassifierService during startup wiring. A
  // cleanup that trusted the old comment would have deleted working code.
  // They delegate to _expressionService; prefer calling that directly in new code.

  /// Set the CharacterRepository so group mode can look up characters.
  void setCharacterRepository(CharacterRepository repo) {
    if (identical(_characterRepository, repo)) return;
    _characterRepository?.removeListener(_onCharacterLibraryChanged);
    _characterRepository = repo;
    _characterRepository!.addListener(_onCharacterLibraryChanged);
  }

  /// Silently prune Scene Guests whose library card no longer exists. Deleting a
  /// character PNG is a deliberate user action, so a deleted guest is dropped
  /// from the open scene with NO `/exit` narration — `_resolveSceneGuestCards`
  /// removes any id that no longer resolves. Self-heals the "deleted card but
  /// still treated as present" case (e.g. cast detection skipping a re-narrated
  /// character because the stale guest was still in the scene list).
  void _onCharacterLibraryChanged() {
    if (_disposed || _guestBusy || _sceneGuestIds.isEmpty) return;
    // Defer out of the repository's notify callback so we never start a DB read
    // from inside its in-progress write/transaction; re-check guards (and that
    // the chat hasn't switched) on the microtask. _resolveSceneGuestCards also
    // self-guards on the token, so a stale resolve can't write the wrong chat.
    final token = _currentSessionId;
    scheduleMicrotask(() {
      if (_sceneChanged(token) || _guestBusy || _sceneGuestIds.isEmpty) return;
      _resolveSceneGuestCards();
    });
  }

  /// Wired by main.dart so that group member loading works for all call sites
  /// (creation, home taps, fork, etc.) without every caller having to pass the repo.
  void setGroupChatRepository(GroupChatRepository repo) {
    _groupChatRepository = repo;
  }

  /// Set the LLMProvider after construction (to break circular dependency in provider tree).
  void setLLMProvider(LLMProvider provider) {
    _llmProvider = provider;
    // Backend switches and local-engine ready transitions flow through the
    // provider — retest tool support when the identity changes and is ready.
    provider.addListener(_onBackendIdentityMaybeChanged);
  }

  /// Set the TtsService after construction (for TTS-aware auto-play delay).
  void setTtsService(TtsService service) {
    _ttsService = service;
  }

  /// Set the MemoryService after construction (for RAG memory retrieval).
  void setMemoryService(MemoryService service) {
    _memoryService = service;
  }

  /// Set the ImageGenService after construction (for background Scene Guest
  /// portraits). Optional — when absent or unconfigured, guests just keep their
  /// initials avatar.
  void setImageGenService(ImageGenService service) {
    _imageGenService = service;
  }

  /// Set the ExpressionClassifierService after construction (for ONNX emotion classification).
  void setExpressionClassifierService(ExpressionClassifierService service) =>
      _expressionService.setExpressionClassifierService(service);

  /// Returns a stable ID string for a character card.
  /// Delegates to the canonical stable ID for group contexts.
  /// See [StableGroupId.stableGroupId] in lib/utils/character_id.dart
  String _getCharacterIdFromCard(CharacterCard card) => card.stableGroupId;

  String _getCharacterId() {
    if (_activeGroup != null) {
      return 'group_${_activeGroup!.id}';
    }
    if (_activeCharacter == null) return "unknown";
    return _getCharacterIdFromCard(_activeCharacter!);
  }

  /// Helper used when constructing messages.
  String? _getCharacterIdForCard(CharacterCard card) {
    return _getCharacterIdFromCard(card);
  }

  /// Safely parse a JSON string into a mutable `Map<String, String>`.
  /// Returns an empty map if [json] is null, empty, or invalid.
  Map<String, String> _tryParseJsonMap(String? json) {
    if (json == null || json.isEmpty || json == '{}') return {};
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map) {
        return decoded.map(
          (k, v) => MapEntry(k.toString(), v?.toString() ?? ''),
        );
      }
    } catch (_) {}
    return {};
  }


  /// Index of the most recent host (main character) message that is buried only
  /// under Scene Guest (Lite NPC) chime-in replies — i.e. the tail of the chat
  /// is one or more guest messages sitting directly on top of it. Returns null
  /// when the last message is already the host's (use the normal last-message
  /// regen), when a user/System message breaks the guest tail, or outside a 1:1
  /// scene. The UI uses this to offer "regenerate the main character" on a host
  /// bubble that the last-message-only regen button can no longer reach.
  int? get regenerableHostBelowGuestsIndex {
    if (_activeGroup != null || _messages.isEmpty) return null;
    if (!_isGuestAuthoredMessage(_messages.last)) return null;
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.isUser || m.sender == 'System') return null;
      if (!_isGuestAuthoredMessage(m)) return i;
    }
    return null;
  }



  // ensureInterCharacterRelationshipsSeeded / updateInterCharacterFeelingsFromRecentExchange
  // moved verbatim to RelationshipService (with callbacks for group/messages). Old bodies deleted.



  void editMessage(int index, String newText) async {
    if (index >= 0 && index < _messages.length) {
      final msg = _messages[index];
      // Use the text setter so we only update the current swipe's text
      // while preserving all realism metadata, swipes, swipeMetadata, durations, etc.
      // This prevents chips (needs_deltas, bond/trust deltas, emotion, etc.) from disappearing on edit.
      msg.text = newText;
      // Timeline integrity: an edit at a journaled position rewrites what
      // the diary already read (smoke-test bug 2026-07-21).
      _invalidateJournalFrom(index);
      await _saveChat();
      notifyListeners();
    }
  }




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

  /// Loads the active objectives for the given character in the current session.
  /// Safe to call from group objective UIs — does not mutate global _activeObjectives.
  ///
  /// Kept in the class body (not an extension) because [FakeChatService]
  /// overrides it in golden tests — extension members are statically dispatched
  /// and cannot be overridden.
  Future<List<Objective>> getActiveObjectivesFor(
    CharacterCard character,
  ) async {
    if (_currentSessionId == null) return const [];
    final charId = _getCharacterIdFromCard(character);
    try {
      return await _db.getActiveObjectives(charId, chatId: _currentSessionId!);
    } catch (e) {
      debugPrint('[Objective] Failed to load for ${character.name}: $e');
      return const [];
    }
  }

  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelIdleTimer();
    _cancelStreamNotifyThrottle();
    _guestStatusClearTimer?.cancel();
    _characterRepository?.removeListener(_onCharacterLibraryChanged);
    _storageService.removeListener(_onBackendIdentityMaybeChanged);
    _llmProvider?.removeListener(_onBackendIdentityMaybeChanged);
    _toolProbe.removeListener(notifyListeners);
    super.dispose();
  }
}
