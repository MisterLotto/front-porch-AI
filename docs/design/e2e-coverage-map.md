# E2E Coverage Map

The living inventory of what the `integration_test/` suite actually exercises,
what it deliberately cannot, and the priority order for closing the rest.
Maintainer directive (2026-08-03): interaction coverage of the full app is the
goal — this file is the plan and the honest scoreboard, updated whenever a
suite is added or a surface ships.

Ground rules (from the suites themselves — see `app_smoke_test.dart`'s header):
every suite boots the REAL app sandboxed (SandboxPathProvider + mock prefs +
fake OpenAI-compatible backend), runs one invocation per file on all three
desktop OSes, and every wait rides `ChatDriver`/`e2e_sandbox` (CI scaling +
Chance Time immunity). A new `*_test.dart` in `integration_test/` is picked up
by CI automatically.

## Covered today

| Surface | Suite | What is actually asserted |
|---|---|---|
| Cold boot, service init order, window | every suite | real `main()`, no red startup |
| 1:1 chat send → stream → bubble | `app_smoke` | request assembled, reply streams |
| Realism evals (bond/trust/emotion/posture) | `app_smoke` | chip metadata deltas land |
| Needs impact + chips | `app_smoke` | needs deltas as metadata |
| Chaos pressure / Chance Time wheel | `app_smoke` + driver | wheel spun like a user |
| Objectives (proposal + task gen) | `app_smoke` | proposal accepted, tasks exist |
| Journal pass + sidebar + Our Story dialog | `app_smoke` | memory op renders, tab resolves |
| Worlds + lorebook injection into prompt | `app_smoke` | injected content in outbound body |
| Backend-failure resilience | `app_smoke` | graceful, no wedge |
| Realism OFF path (engine fully disabled) | `realism_off` | no evals fire, chat still works |
| Group chat: per-speaker isolation | `group_smoke` | one speaker scored per turn |
| Group chat: reload persistence | `group_smoke` | bond/trust/needs survive reload (settle-guarded) |
| Group realism wiring across reload turns | `group_realism_wiring` | post-reload turns keep scoring |
| Theme presets keep controls tappable | `theme_interaction` | hit-tests under all 10 presets |
| Settings persistence (the "Stays Put" class) | `settings_persistence` | context via real input; reopen ×3 + settings-layer reload, zero drift |
| Message actions: edit → dialog → sticks | `message_actions` | real Edit button, Save, text replaced |
| Message actions: regenerate in place | `message_actions` | real Regenerate button, count coherent |
| Message actions: delete + needs refund | `message_actions` | real delete button + confirm; chips subtracted |
| Web server launch + PWA + auth loop | `web_server` | real HTTP: health, shell served, anon 401, setup→cookie→state 200, clean stop |
| Story clock: per-turn advance + reload | `story_time` | canned scene-time eval moves clock forward ≥5min; ISO identical after reload |
| Weather: live + seed-stable across reload | `app_smoke` | currentWeather/upcomingWeather non-null; no re-roll on reload |
| Backups: create → restore → rebind (v1.2 class) | `backup_restore` | real page + confirm dialog; post-snapshot char gone, portrait PNG kept, full chat turn + folder/persona writes on the rebound DB |
| Personas: create in real form, ride the session | `persona_folder` | New Persona→Save activates it; loadSession re-activates the chatted persona |
| Folders: create, move via context menu, open | `persona_folder` | toolbar dialog; right-click → Move to Folder…; membership survives reload |
| Chat lorebook: author entry, preview, inject | `lorebook_chat` | real Add dialog; WOULD TRIGGER NEXT on draft; content in outbound body; all 4 import dialects decode (wizard's picker step is native — not drivable) |
| Worlds: create place + attach to chat | `worlds_management` | real New World dialog; Places panel attach; climate dropdown present |
| Journal review-first: park → banner → apply | `journal_review` | gear toggle via real UI; salience-kicked batch parks; Apply lands the card |
| Growth Rings: pass → ring renders → receipt jump | `growth_rings` | real panel switch; fake's <ring> branch; tier/category render; #1 receipt seeks the cited bubble |
| Sidebar sweep: every accordion + a live control each | `sidebar_sweep` | note field takes text; sim gear opens flyout; chaos switch truly enables chaos |
| Swipes: regen grafts 2/2; chevrons navigate | `swipe_fork_cancel` | left/right arrows swap swipe + preserved chips; navigation fires NO generation |
| Cancel-mid-regenerate put-back (124b8ff class) | `swipe_fork_cancel` | paced fake (chatChunkDelay) opens a real window; Stop keeps original as swipe 1, partial as new swipe, all guards release |
| Fork: bubble button → confirm → new branch | `swipe_fork_cancel` | session id swaps; parentSessionId/forkIndex recorded; multi-swipe message carried whole |
| Model search + download (fake HF endpoints) | `model_downloader` | ModelManager.hfBaseUrl seam; search → tree → expand card; both files land on disk |
| VRAM oversize-confirm dialog | `model_downloader` | HardwareService.testVramOverrideMb pins 8 GB; Cancel queues nothing, Download Anyway queues; fitting file never warns |
| The Stoop: sign-in → AUP gate → browse → download | `stoop` | BackporchApi.overrideBaseUrl seam + fake backporch server; downloaded V2 card lands in CharacterRepository |
| The Stoop: share wizard upload | `stoop` | pick → details → standards ack → Submit for review posts the multipart upload |
| Story pipeline: concept → bible → acts → prose | `story_pipeline` | real wizard + dashboard + structure page; fake's 5 story-stage branches; stage ORDER asserted; reader opens on finished prose |

Widget-level interaction tests (in `test/ui/`, not full-app):
`create_group_chat_page`, `edit_character_page`, folder drag/drop, expanded
editor dialog, theme goldens, and the border-painter hit-test sweep.

## Not covered — priority order for the next tranches

**P1 + P2 — DONE 2026-08-04** (`backup_restore`, `persona_folder`,
`lorebook_chat`, `worlds_management`, `journal_review`, `growth_rings`,
`sidebar_sweep`).

**P3 — DONE 2026-08-04** (`swipe_fork_cancel`, `model_downloader`, `stoop`,
`story_pipeline`), with the fakes it needed: FakeBackendServer gained
chatChunkDelay (paced chat stream — the cancel window) and five story-stage
branches; new `support/fake_hf.dart` and `support/fake_stoop.dart` servers;
three `@visibleForTesting` seams in lib (ModelManager.hfBaseUrl,
HardwareService.testVramOverrideMb, BackporchApi.overrideBaseUrl — the last
one matters beyond tests: the desktop UI constructs bare BackporchApi()
everywhere and the dart-define override is compile-time only).

Honest residue (still open, low priority):
- The lorebook IMPORT WIZARD's step 0 is a native file picker no test can
  drive; the dialect decode layer it rides is proven programmatically in
  `lorebook_chat`, and steps 1–2 remain uncovered as widgets.
- The custom climate EDITOR (showClimateEditorDialog) is not driven —
  `worlds_management` proves the dropdown offers it; authoring is unit-level
  territory.
- Story: the writer page's Auto-Write leg (Drafter+Editor+Validator+
  Archivist) is not driven — `story_pipeline` covers the generateFullAct
  path the desktop UI uses; the Cancel-Realism overlay path is likewise
  uncovered (the Stop-button cancel is).
- Stoop messaging (inbox thread + typing over the WebSocket) is not driven;
  the fake holds the socket open and serves unread=0.

**Deliberately not coverable offline (documented, not forgotten):**
- RAG/embeddings (consent-gated model download; pre-consent UI IS covered).
- TTS/STT/image generation output (model binaries not in repo; service
  construction at boot IS covered).
- Real network updater (gated off by `update_auto_check: false`; its release
  parsing has unit tests).

## Rules for adding a suite

- One journey per file (CI runs one invocation per file — a second app boot
  in the same process is not supported).
- Copy the isolation preamble from `app_smoke_test.dart` verbatim, including
  the port-5001 preflight. Never weaken a seam.
- Every wait through `ChatDriver`/`pumpUntil*` — no raw `pumpAndSettle`, no
  unscaled timeouts.
- Before trusting or persist-asserting any chat state, `await d.waitSendable()`
  — the settling window (`isSettlingTurn`) is part of the turn.
- Assert `backend.unexpectedPaths` empty at the end when the journey chats.
- Update this file's table in the same PR.

## Running the leg locally on Linux (do this before pushing)

CI is a slow way to find a broken finder — the whole Linux leg runs here in
about twenty minutes, one invocation per file:

```bash
for f in integration_test/*_test.dart; do
  xvfb-run -a flutter test "$f" -d linux
done
```

Two environment facts cost a full CI round each before they were written down:

- **GStreamer is a hard requirement, and its absence looks like nothing at
  all.** `audioplayers_linux` builds its player in the constructor and
  `throw`s a bare `const char*` when `gst_element_factory_make("playbin")`
  returns null. Nothing catches it, so the C++ runtime aborts the process: the
  suite reports `did not complete` about one second in, with no Dart exception,
  no stack, and no hint that audio was involved. Install
  `gstreamer1.0-plugins-base` (plus `-good`) and it simply works. A core dump
  (`ulimit -c unlimited`, then `gdb -batch -ex bt <bundle> core`) is what
  actually named it — worth reaching for the moment a suite dies without a Dart
  error.
- **`xvfb-run` starts a bare `sh`**, so `flutter` must be on PATH there or you
  get an opaque `exit 127`. Use the absolute path when in doubt.
