#!/usr/bin/env bash
# Run one (or more) integration_test suites on the local desktop device with a
# clean process environment.
#
# Why this exists
# ---------------
# macOS libmalloc emits a line to stderr for EVERY process when any of the
# MallocStackLogging* environment variables is set — including to the string
# "0". (Setting them to 0 does NOT disable the feature; it still arms the
# diagnostic path.) Flutter's integration_test harness speaks a JSON protocol
# over the child VM's stdio; those MSL lines corrupt the stream and the load
# dies with:
#
#   Unexpected character (at character 1)
#   … MallocStackLogging: could not tag MSL-related memory…
#
# CI macOS runners never set those vars, so the suite is green there and red
# only on a polluted developer shell (commonly from a mistaken
# `export MallocStackLogging=0` in ~/.zshrc).
#
# This wrapper:
#   1. Unsets every Malloc* diagnostic flag (and related DYLD inserts) in THIS
#      shell — absence is the only safe state; do not re-export as 0.
#   2. Prefers the Flutter version pinned by CI when a side-install is present.
#   3. Runs one suite file per invocation (never the directory — CLAUDE.md).
#
# Usage
# -----
#   scripts/e2e-local.sh continue_path_test
#   scripts/e2e-local.sh integration_test/foo.dart
#   scripts/e2e-local.sh continue_path_test climax_refractory_test
#   DEVICE=macos scripts/e2e-local.sh app_smoke_test
#   FLUTTER_BIN=/path/to/flutter scripts/e2e-local.sh …
#
# Host fix (once): remove any `export MallocStackLogging=…` from your shell rc
# and open a new terminal. This script still unsets defensively for polluted
# parent processes (IDE terminals, agent shells).

set -euo pipefail
cd "$(dirname "$0")/.."

# --- scrub MSL / related diagnostics -----------------------------------------
# MUST be unset (not exported as 0). Do this before any child is spawned.
_msl_keys=(
  MallocStackLogging
  MallocStackLoggingNoCompact
  MallocStackLoggingLite
  MallocNanoZone
  MallocGuardEdges
  MallocScribble
  MallocErrorAbort
  MallocCorruptionAbort
  DYLD_INSERT_LIBRARIES
)
for k in "${_msl_keys[@]}"; do
  unset "$k" 2>/dev/null || true
done

# --- pick flutter ------------------------------------------------------------
_flutter_pinned="${FLUTTER_BIN:-}"
if [[ -z "$_flutter_pinned" ]]; then
  for candidate in \
    "${HOME}/dev/flutter-sdks/flutter-3.44.8/bin/flutter" \
    "${HOME}/flutter-sdks/flutter-3.44.8/bin/flutter" \
    "/Users/linux4life/dev/flutter-sdks/flutter-3.44.8/bin/flutter"
  do
    if [[ -x "$candidate" ]]; then
      _flutter_pinned="$candidate"
      break
    fi
  done
fi
if [[ -z "$_flutter_pinned" ]]; then
  _flutter_pinned="$(command -v flutter || true)"
fi
if [[ -z "$_flutter_pinned" || ! -x "$_flutter_pinned" ]]; then
  echo "✗ flutter not found. Set FLUTTER_BIN or install the CI-pinned SDK." >&2
  exit 127
fi

DEVICE="${DEVICE:-macos}"

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <suite> [more suites…]" >&2
  echo "  suite: basename (continue_path_test) or path (integration_test/foo.dart)" >&2
  exit 2
fi

# Preflight: after the scrub, a trivial child must have empty stderr.
# (If this fails, the shell still has MSL armed in a way unset cannot clear —
# rare; open a brand-new terminal that never exported the vars.)
_probe_err="$(/usr/bin/true 2>&1 >/dev/null || true)"
if [[ -n "$_probe_err" ]] && [[ "$_probe_err" == *MallocStackLogging* ]]; then
  echo "✗ MallocStackLogging still reaches child stderr after unset:" >&2
  echo "$_probe_err" >&2
  echo "  Fix your shell rc: DELETE any 'export MallocStackLogging=…' lines" >&2
  echo "  (including =0 — that is what causes the spam). Then open a NEW terminal." >&2
  exit 1
fi

overall=0
for arg in "$@"; do
  suite="$arg"
  if [[ "$suite" != integration_test/* ]]; then
    suite="${suite%.dart}"
    suite="integration_test/${suite}.dart"
  fi
  if [[ ! -f "$suite" ]]; then
    echo "✗ no such suite: $suite" >&2
    overall=1
    continue
  fi
  echo "── e2e-local: $suite  (device=$DEVICE, flutter=$_flutter_pinned)"
  # One file per invocation — never the directory (device hold / loading death).
  if ! "$_flutter_pinned" test "$suite" -d "$DEVICE"; then
    overall=$?
  fi
done

exit "$overall"
