---
name: path-complete-chat
description: >
  Enforce path-complete chat/realism/memory work: Continue vs regen, 1:1 vs group,
  Journal vs Growth twins, desktop vs web. Use whenever fixing or adding chat
  generation, Continue, regen/swipe/delete, Realism, Needs, Journal, Growth,
  Pockets, RAG, or group orchestration — or when the maintainer pastes a
  path-complete / poke-script style request.
---

# Path-complete chat work

The maintainer cannot read Dart. Green unit tests are not enough. This skill
exists because agents repeatedly fix one path and leave the sibling broken.

## Before writing code

1. Read `docs/design/path-complete-chat-work.md`.
2. List every **event** your change can hit: send, Continue, regen, swipe, delete, edit.
3. List **twins**: Journal↔Growth, history think-strip↔Continue partial, pockets 1:1↔group speaker, desktop↔web.

## While implementing

- Prefer one shared helper over a second path for 1:1 vs group.
- Continue is its own product: finalize must keep pre-continue + new; partial must use history-safe / think-stripped text; state-zone strips must include porch_night if other state is stripped.
- Group restore keys by **message speaker id**, never “whoever is active after post-gen.”
- If Journal invalidates on rewrite, Growth must too (or document an explicit product exception from the maintainer).

## Before claiming done

1. Fill the **Path-complete checklist** paste block from the design doc in your summary.
2. Add a test that was **proven red** then green (project testing law).
3. Web parity shipped or maintainer deferred **in this conversation**.
4. End with a **2–5 step poke script** for a non-developer.
5. If you cannot launch the app, say so — never imply manual verification.

## Push-back phrases (if tempted to skip)

- “Unit tests pass” without path matrix → incomplete.
- “Continue is rare” → still mandatory if generation text/state is involved.
- “Web later” without explicit maintainer deferral → parity violation.
