# Path-complete chat work (agent law)

**Why this exists:** Front Porch AI is mostly built by AI agents. The maintainer
cannot read Dart. Local fixes routinely leave **sibling paths** broken
(Continue vs regen, 1:1 vs group, Journal vs Growth, desktop vs web). The
2026-08 full-codebase audit found 25 Highs of that shape. This document is the
anti-pattern contract.

Agents MUST fill the matrices below (or mark N/A with a one-line reason) in the
**completion summary** for any change that touches chat generation, Realism,
Needs, Journal, Growth, Pockets, RAG, message ops (regen/swipe/delete/continue),
or group orchestration. Silence = incomplete work.

## 1. Turn-event matrix

For every piece of **non-scalar state** the change creates or mutates
(pockets, inter-char feelings, growth rings, journal cards, recap, needs
vectors, realism scalars, item cards, …), mark what happens on:

| Event | Required behaviour | Done? (yes / n/a + why) |
|-------|--------------------|-------------------------|
| **Normal send** (1:1) | Applies correctly; stamps/receipts if needed for rewind | |
| **Normal send** (group, per speaker) | Same observable result as 1:1 for that character | |
| **Continue** | Extends text; does **not** re-open full state zone; does **not** re-inject raw `<think>`; finalize keeps **pre-continue + new** body | |
| **Regenerate** | Restores pre-turn state for that message, then re-applies from the same inputs | |
| **Swipe** alternate | Each swipe’s non-scalar state matches that swipe | |
| **Delete** (bot tail / user tail) | Inventory/realism/cards match remaining transcript | |
| **Edit** history | Same rewrite integrity as regen for anything that cites positions | |

If the feature injects into the **prompt**, also:

| Prompt path | Must use think-stripped / history-safe text | State-zone / feature gates correct |
|-------------|---------------------------------------------|------------------------------------|
| Full generate | | |
| Continue partial / suffix | | |
| Overflow / tiny-context continuity | | |
| Impersonate | | |

## 2. Twin systems (do not fix only one)

If you change one, **grep and update the twin** or document why not:

| If you touch… | Also check… |
|---------------|-------------|
| Journal card invalidation / cursor on rewrite | Growth rings + growth cursor + growth window caps |
| History `toPromptHistoryLine` / think-strip | Continue partial builder, impersonate, overflow continuity |
| Pockets stamps / restore | Group speaker id (not bare `_activeCharacter` after post-gen) |
| Realism pre-gen judges | Trust-repair branch, one-shot, post-gen fusion |
| Desktop sidebar setting / dialog | `web_ui/` + facade + routes |
| Session delete cleanup | Soft-delete character/group + Database Cleanup |
| RAG receipts / operational | ensureReady failure latch, group Data Bank identity |

## 3. Test law (this project already said it — obey it)

- A new guard **must be proven red** before green (break the fix, see fail, restore).
- Prefer **one broad interaction test** over another pure unit of a helper.
- Pure unit tests of capture→restore **do not** prove group swipe wiring.
- Continue + Output Sanitizer + multi-sentence pre-body is a **required** class
  if you touch finalize, streaming write-back, or sanitizer.

## 4. Web parity law (reminder)

User-visible work is not done until desktop **and** `web_ui/` ship, or the
maintainer explicitly defers **that item** in the **current** conversation.
Silent “desktop only for now” is a parity violation.

## 5. Completion paste (required in the agent’s final summary)

```
### Path-complete checklist
- Turn events: [filled matrix or link to bullets]
- Twins grepped: [list]
- New test: [file + proven red? yes/no]
- Web: [shipped / deferred by maintainer: quote]
- I cannot launch the app: [true/false] → poke script: [2–5 steps]
```
