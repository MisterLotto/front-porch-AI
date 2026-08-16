# Contributing to Front Porch AI

Thanks for your interest in contributing! Contributions are welcome from developers of all skill levels.

## Table of Contents

- [Licensing](#licensing)
- [Code of Conduct](#code-of-conduct)
- [Which Branch Do I Target?](#which-branch-do-i-target)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Required Checks](#required-checks)
- [Project Rules That Trip People Up](#project-rules-that-trip-people-up)
- [Testing](#testing)
- [Building](#building)
- [Reporting Issues](#reporting-issues)

## Licensing

Front Porch AI is licensed under the **GNU Affero General Public License, version 3
or (at your option) any later version** (`AGPL-3.0-or-later`). Releases before
v0.9.0 were GPLv3.

**By submitting a contribution — code, documentation, assets or anything else —
you agree that it is licensed under AGPL-3.0-or-later**, and you confirm that you
have the right to submit it under that license. If you are contributing work you
do not personally own (employer-owned code, or code copied from another project),
it is your responsibility to make sure that is permitted and compatible before
opening a pull request.

There is no Contributor License Agreement and no copyright assignment. You keep
the copyright in your own work.

Practical notes:

- **New source files need the AGPL header.** Copy it from any existing file in
  `lib/`.
- **Mind what your dependencies drag in.** A package with an incompatible license
  cannot be merged, and one that quietly downgrades existing packages will fail the
  dependency-floor guard (see [Required Checks](#required-checks)).
- **Model weights are not code.** Anything the app downloads at runtime (TTS
  voices, embeddings, engines) is fetched by the user from a third party and is
  covered by that third party's terms, not by this license. If you add a new
  downloaded model, say in your PR where it comes from and what it is licensed
  under — several TTS voices carry non-commercial dataset terms.

If you are not familiar with what the AGPL requires, read it before contributing,
and get your own legal advice if you need it.

## Code of Conduct

Be respectful and constructive. That's the whole rule.

## Which Branch Do I Target?

This matters — PRs opened against the wrong branch will be asked to move.

| Change type | Target branch |
|---|---|
| All work (features, fixes, experiments) | `Rawhide` |
| Tagged stable releases | `main` |

Two branches. There is no `dev` line and no beta series. Direct PRs to `main`
are almost never accepted.

## Development Setup

### Prerequisites

- **Flutter 3.44.8** (what CI uses). The Dart SDK constraint is `^3.10.8`.
- [Git](https://git-scm.com/)
- Windows 10+, macOS 12+, or Linux
- **Linux only**, for desktop builds:
  `libgtk-3-dev ninja-build libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev`
- **Node 20+**, only if you are touching the web/mobile UI in `web_ui/`

There is **no Rust toolchain, no Python, and no `pip install` step.** Every engine
runs in-process: TTS (Kokoro/Piper via sherpa-onnx), STT (Whisper via sherpa-onnx),
expression classification and RAG embeddings (onnxruntime), and Draw Things
(pure-Dart gRPC). The app spawns no helper processes. See
`docs/design/sidecar-retirement.md` before touching any engine — **do not
reintroduce sidecars.**

### Setup

```bash
git clone https://github.com/<your-username>/front-porch-AI.git
cd front-porch-AI
flutter pub get

# Only if you are working on the web/mobile UI
cd web_ui && npm install
```

Database schema changes additionally need:

```bash
dart run build_runner build   # regenerates lib/database/database.g.dart
```

## Pull Request Process

1. Branch from the correct target branch (see the table above)
2. Make your change, and keep it scoped to one thing
3. Run the [required checks](#required-checks) locally
4. Write a commit message that explains **why**, not just what — see the
   "Commit Messages" section of [CLAUDE.md](CLAUDE.md) for the standard
5. Open the PR against the same branch you started from — GitHub will fill in the
   PR template automatically; delete any section that doesn't apply to your change
6. Say what you tested, and on which platforms

**Draft PRs are welcome.** If a feature is half-built and you want direction on
the approach, open it as a draft — that gets you useful feedback instead of a list
of unfinished pieces.

## Required Checks

CI runs these on every PR to `main` and `Rawhide`. Run them locally first.

```bash
flutter analyze                       # must be clean — the project is at 0 warnings
flutter test                          # unit + integration
flutter test --tags golden            # pixel goldens (Linux/CI-authored)
cd web_ui && npm run lint && npm test  # only if you touched web_ui/
```

The CI jobs are:

| Job | What fails it |
|---|---|
| `analyze` | Any analyzer issue in the Dart files your PR changed |
| `test` | Any failing test, including the dependency-floor guard |
| E2E smoke | The app failing to start on Linux/macOS/Windows |
| `web-tests` | `tsc` type errors or failing vitest specs in `web_ui/` |
| `theme-lint` | Adding a raw `Colors.blueAccent` under `lib/` |
| `io-lint` | Adding synchronous I/O (`existsSync`, `readAs*Sync`, …) under `lib/ui/` |
| `golden` | A pixel golden that changed without being intentionally updated |

Two of these surprise people:

- **The dependency-floor guard** (`test/deps/dependency_floor_test.dart`) fails if
  any package in `pubspec.lock` moves *backwards*. It exists because a silent
  `sqlite3` downgrade once shipped a release with no database engine on Linux.
  **Do not fix a failure by regenerating `test/deps/dependency_floors.json`** — find
  out what pulled the version back, and explain it in the PR.
- **`io-lint`** exists because a single `existsSync` in a widget `build()` was
  invisible on macOS and 10–100× slower on Windows under Defender. A line that
  genuinely cannot run in a build path can carry a trailing `// io-ok: <reason>`.

### Do NOT run `dart format` over whole files

The codebase is mid-migration to the Dart 3.11 "tall style" formatter. Running the
new formatter on a not-yet-migrated file rewraps hundreds of unrelated lines and
buries your actual change. Match the surrounding style by hand in the regions you
edit. A whole-file reformat is its own separate, intentional commit.

## Project Rules That Trip People Up

[CLAUDE.md](CLAUDE.md) is the full guide. These are the ones that most often send
a PR back:

- **Files stay under 500 lines.** If the file you are editing is already over,
  don't grow it — extract a focused class instead.
- **Web/mobile parity is required.** Any user-visible feature or UX change shipped
  in the Flutter desktop app must also land in `web_ui/` in the same body of work —
  including its settings and toggles. Adaptation to each form factor is expected;
  omission is not. Ask if you think a deferral is warranted.
- **Realism/Needs parity is required.** Observable behaviour must be identical
  whether a character is in a 1:1 chat or a group.
- **Use the theme system.** `AppColors` only — no hard-coded `Color(0xFF…)` and no
  raw `Colors.whiteXX`/`Colors.blackXX` in new or refactored UI. New chrome accents
  use `AppColors.formMasterAccent` or `AppColors.porchAmberOf(context)`.
- **Use the barrel imports** (`models/models.dart`, `utils/utils.dart`,
  `services/services.dart`, `ui/widgets/widgets.dart`, …) rather than
  single-file imports where a barrel covers the file.
- **Don't edit `pubspec.yaml` version** — CI/CD normalizes the release version.
- **Database schema changes need discussion first.** An external community tool
  (Character Card Forge) writes to this database with raw SQL, so a removed or
  renamed column can break it.
- **Never silently swallow errors.** Log them or surface them.

## Testing

```bash
flutter test                          # everything except pixel goldens
flutter test --coverage
flutter test test/path/to/file.dart   # one file
flutter test -n "test name"           # one test
flutter test --tags golden            # pixel goldens
```

Aim for 80%+ coverage on new code, and test error paths, not just happy paths.
Mock external dependencies.

For anything that cannot be unit-tested, build and run the app and say in the PR
what you exercised and on which platform. "It compiles" is not testing.

## Building

```bash
flutter build linux
flutter build windows
./scripts/build-macos.sh   # signs, packages and notarizes
```

No post-build copy steps are needed — native libraries ship inside their pub
packages.

## Reporting Issues

1. Check existing issues first
2. Include: steps to reproduce, expected vs actual behaviour, your OS and app
   version, and logs or screenshots where relevant
3. Minimal reproduction cases get fixed fastest

## Additional Resources

- [CLAUDE.md](CLAUDE.md) — the full contributor/agent guide (AGENTS.md points here)
- [Flutter docs](https://docs.flutter.dev/) · [Effective Dart](https://dart.dev/effective-dart/style)
- [Discord](https://discord.gg/e4tET6rpdv)

Thanks for contributing to Front Porch AI! 🎭
