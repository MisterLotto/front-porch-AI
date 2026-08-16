# AI Agent Guidelines for Front Porch AI

**The project's rules live in [CLAUDE.md](CLAUDE.md). Read that file before
writing any code — it is the single source of truth, and it is the one that is
kept current.**

This file exists because `AGENTS.md` is the filename most AI coding tools look for
(Codex, Cursor, Aider, Gemini CLI and others), while Claude Code reads `CLAUDE.md`.
Rather than maintain two copies of the same guidance — which is exactly how this
file rotted last time — it is deliberately a pointer.

## Why this is a stub

Until 2026-08-01 this file carried its own full copy of the guidelines, and it had
drifted badly. It still documented Python TTS/STT sidecars and a Rust embedding
server, all of which were deleted in the 2026-07 sidecar retirement, and it
included a worked example headed *"Good: Python Sidecar Implementation"* —
teaching agents to build the exact architecture the project now forbids. It also
predated the Realism Engine parity rules, the `AppColors` theme system, the
web/mobile parity requirement, the 500-line file cap and the barrel-import policy,
and mentioned none of them even once.

Anything reading it was being actively misled. Keeping one maintained file is the
fix.

## The short version

If you read only one thing before touching this codebase:

- **All engines run in-process.** No Python, no Rust, no sidecars, no helper
  processes. See `docs/design/sidecar-retirement.md`. **Do not reintroduce them.**
- **Every Dart file stays under 500 lines.** If the one you're editing is already
  over, extract — don't grow it.
- **Realism/Needs behaviour must be identical** in 1:1 and group chats.
- **Anything user-visible ships on desktop *and* in `web_ui/`** — including its
  settings and toggles.
- **Path-complete chat work** — Continue ≠ regen; group ≠ 1:1 storage; Growth ≠
  Journal rewrite. Fill
  [`docs/design/path-complete-chat-work.md`](docs/design/path-complete-chat-work.md)
  before claiming chat/realism/memory work is done.
- **Hostile self-review is mandatory** before "done" / ship — green tests are not
  a second look. See CLAUDE.md "Rules When the Human Cannot Review Code".
- **Use `AppColors`** — no hard-coded `Color(0xFF…)`, no raw
  `Colors.whiteXX`/`Colors.blackXX` in new or refactored UI.
- **Use the barrel imports** where a barrel covers the file.
- **Never** run `dart format .` (the whole tree), edit the version in
  `pubspec.yaml`, or use destructive git commands (`git checkout -- <file>`,
  `git restore <file>`) that discard uncommitted work — the maintainer and other
  agents routinely have uncommitted edits in the tree. Per-file `dart format`
  on a file you already touched is required — see CLAUDE.md "Verification".
- **Run `flutter analyze` and `flutter test`** before claiming anything is done.

All of the above, with the reasoning, the exceptions and everything omitted here,
is in [CLAUDE.md](CLAUDE.md). Human contributors should also read
[CONTRIBUTING.md](CONTRIBUTING.md). The maintainer cannot read Dart — see
[`docs/maintainer-agent-playbook.md`](docs/maintainer-agent-playbook.md) for how
to drive agents without code review.
