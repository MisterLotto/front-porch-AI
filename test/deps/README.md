# Dependency guard — why these tests exist, and why 8 packages are still behind

## The incident (v1.1.0, 2026-07-28)

`da0e49eb` ("migrate Living Time providers to @riverpod codegen") re-resolved
`pubspec.lock` as a side effect. Nine packages moved **backwards**. One was
`sqlite3`, 3.2.0 → 2.9.4.

`sqlite3` 3.x bundles the native SQLite library itself. 2.x does not — it
delegates to `sqlite3_flutter_libs`, which was pinned at `0.6.0+eol`, a
tombstone release whose source reads *"This package does not do anything"*.
The pairing produced a Linux build **with no database engine in it at all**.

It reached users because nothing failed: the build succeeded, the full suite
passed, and macOS and Windows silently fell back to `/usr/lib/libsqlite3.dylib`
and `winsqlite3.dll`. The maintainer's only test machine is a Mac, so the
regression was **structurally invisible**. Fixed in v1.1.1.

## What guards it now

`dependency_floor_test.dart` — pure Dart, no native deps, so it fails on every
platform including the Mac where the bug could never reproduce:

1. **Floor check** — `dependency_floors.json` records all resolved packages.
   Nothing may fall below it. Upgrades pass.
2. **Disappearance check** — a package vanishing is as dangerous as a downgrade.
3. **SQLite pairing invariant** — the rule a version floor cannot express:
   `sqlite3` 3.x ⇒ flutter_libs 0.6.x (self-bundling);
   `sqlite3` 2.x ⇒ flutter_libs 0.5.x (plugin bundles it);
   **2.x + 0.6.x ⇒ no SQLite at all.**

Plus a build-artifact guard in all three Linux release workflows that fails the
job if no library in the bundle exports the SQLite C API.

**If a test here fails, do not regenerate the baseline to make it pass.**
Find out why the resolver moved backwards first.

## Why 8 packages are still below their v1.0.0 versions

Not neglect — **currently unsatisfiable**. Verified 2026-07-28 on the CI-pinned
Flutter 3.41.1 (Dart 3.11.0):

| | |
|---|---|
| Flutter 3.41.1's `flutter_test` | pins `meta` to exactly **1.17.0** |
| `analyzer` 10.2.0+ | needs `meta ^1.18.0` → **analyzer is capped at 10.0.1** |
| `drift_dev` 2.32.0 | needs `analyzer ^10.0.0` → would fit |
| `riverpod_generator` 4.0.3 | needs `analyzer ^9.0.0` |
| `riverpod_generator` 4.0.4 | needs `analyzer ^12.0.0` |

**`riverpod_generator` skipped analyzer 10 and 11 entirely.** There is no
release of it that accepts the only analyzer version drift 2.32 can use. So on
this toolchain, drift 2.32+ and Riverpod codegen are mutually exclusive — which
is exactly why the resolver downgraded drift when codegen was introduced. It
had no other move.

Still behind: `drift`/`drift_dev` (2.31 vs 2.32), `analyzer` (9 vs 10),
`_fe_analyzer_shared`, `sqlparser`, `dart_style`, `matcher`, `test_api`.

### Is that dangerous?

**No, and both risks were checked rather than assumed:**

- **None of the eight ships native code.** Only `sqlite3` could remove a binary
  from the bundle, and that one is fixed. Verified by inspecting every package
  for platform build files.
- **The generated-code mismatch is not real.** `database.g.dart` was generated
  by drift_dev 2.32 and now runs against 2.31, which looked like a latent
  hazard. Re-running `build_runner` under 2.31 produced **byte-identical
  output** (unchanged md5, zero diff), so the two versions emit the same code
  for this schema.

### How to actually clear it

Bump the CI Flutter pin to a release carrying **Dart ≥ 3.12**. Everything
aligns there in one move: `riverpod_generator` 4.0.7 and `drift_dev` 2.34.5
both target `analyzer ^13`, and drift 2.34 requires `sqlite3 ^3.0.0` — which
returns SQLite to the self-bundling 3.x world and lets
`sqlite3_flutter_libs` go back to the `0.6.0+eol` marker pin.

That is a toolchain change, not a dependency bump: it regenerates all 94
goldens and re-baselines the release toolchain. Worth doing deliberately, on
its own, not folded into unrelated work.

**When it happens, update `dependency_floors.json` in the same commit** and say
why in the message — that is the intended workflow for a legitimate move.
