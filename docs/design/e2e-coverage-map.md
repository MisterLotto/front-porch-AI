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

Widget-level interaction tests (in `test/ui/`, not full-app):
`create_group_chat_page`, `edit_character_page`, folder drag/drop, expanded
editor dialog, theme goldens, and the border-painter hit-test sweep.

## Not covered — priority order for the next tranches

**P1 — shipped-bug classes with no journey guard yet:**
1. **Message actions**: delete (needs refund must apply), regenerate + cancel
   mid-eval (message must survive), swipes, edit, fork. Three separate shipped
   bugs live here; all invisible to unit tests.
2. **Backups & restore**: restore → every service rebound to the fresh DB
   (the closed-handle class from the v1.2 blocker), backup list renders,
   restore honors no-image-cleanup.
3. **Persona + folder journey**: create persona, start chat as persona,
   persona survives reload; folder create/move/open.

**P2 — feature surfaces with UI-only risk:**
4. Lorebook manager + import wizard (fixture books for each dialect).
5. Worlds management page (create place, climate author, assign to chat).
6. Journal review-first mode (banner → review dialog → apply/discard).
7. Growth Rings dialog + receipts jump.
8. Chat sidebar sweep: every accordion opens, every pill/button hit-tests
   (generalize the theme_interaction approach to one broad sweep).

**P3 — needs new fakes first:**
9. Model manager / downloader (fake HF endpoints on FakeBackendServer;
   oversize-confirm dialog journey).
10. The Stoop (fake backporch API server; browse/upload/download).
11. Story pipeline (long-form generation against the fake).

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
