# Sidecar Retirement Plan (the "sidecar-ectomy")

**Status:** Phase 1 shipped behind fallback (PR #122). This document is the
canonical plan — read it before touching any sidecar, its build steps, or its
models. Maintainer-approved direction: eliminate every Python/PyInstaller
sidecar in favor of in-process Dart + `dart:ffi` against plain native
libraries.

## Why

The PyInstaller sidecars are the app's most ship-fragile components: frozen
Python with its own dependency graph (hidden-import landmines — see the
2026-07-15 protobuf freeze bug that silently broke Draw Things in every signed
release), hardened-runtime entitlement exceptions (`Sidecar.entitlements`),
huge bundles, and stdin/stdout JSON protocols whose failures are dead
processes instead of catchable exceptions. Plain dylibs sign/notarize like the
Flutter engine itself.

## Inventory & target architecture

| Sidecar | What it does | Replacement | Phase |
|---|---|---|---|
| `dt_grpc_client` (Python) | Draw Things gRPC | Pure-Dart client (`lib/services/grpc/dt_native/`) + tiny fpzip FFI | **1 — shipped, soaking** |
| `sentiment_classifier` (Python) | emotion/expression ONNX classifier | in-process ONNX via `onnxruntime_v2` + Dart WordPiece tokenizer | **2 — shipped, soaking** |
| `whisper_stt` (Python, faster-whisper/CT2) | STT | sherpa-onnx (single C lib, official `sherpa_onnx` Dart package) | 3 |
| `kokoro_tts` (Python) | Kokoro TTS | sherpa-onnx (Kokoro is first-class; bundles espeak-ng G2P) | 4 |
| `piper` (PyInstaller wrap of `python -m piper`) | Piper TTS | sherpa-onnx (vits-piper) | 4 |
| `embed_server` (Rust, already non-Python) | RAG embeddings | optional: fold into in-process ort; low priority — it is stable | 5 (optional) |

## The two upgrade surfaces

### 1. Binaries — free ride
Sidecar executables live **inside the app bundle**; upgrades replace the
bundle wholesale, so removing a sidecar needs zero migration code. The staged
pattern (below) keeps *downgrades* safe during each soak window.

### 2. Downloaded models — the real migration surface
Models live in the user data dir (`StorageService.rootPath`), which upgrades
never touch. Per engine:

| Models on disk | Fate on migration |
|---|---|
| Draw Things | none — nothing to migrate |
| RAG embedding ONNX (~270 MB) | reusable as-is (ONNX is engine-agnostic) |
| Expression/sentiment ONNX | reusable as-is |
| Kokoro (`kokoro-v1.0.onnx` ~310 MB + `voices-v1.0.bin`) | mostly reusable; sherpa needs small extras (`tokens.txt`, espeak-ng data) — download only those |
| Whisper (CTranslate2 format, 75 MB–1.5 GB) | **NOT reusable** — sherpa/whisper.cpp use a different export; one-time re-download, must be explicit UX |
| Piper voices (`.onnx` + `.json`) | `.onnx` reusable; generate `tokens.txt` from the `.json` in-app (no re-download expected) |

## The playbook (every phase MUST follow this)

1. **Fallback-first rollout.** Ship native-first with the sidecar still
   bundled and an automatic per-call fallback + loud log lines
   (`[DT-Native]`-style) + a `FP_<X>_SIDECAR=1`-style env rollback lever.
   Remove the sidecar (and its build-workflow steps, and its
   `Sidecar.entitlements` need) only after a release of soak.
2. **Cross-language golden verification.** Pin the new implementation to the
   exact bytes/outputs of the Python stack it replaces, with goldens generated
   FROM that Python stack (precedent: `test/services/grpc/dt_native_test.dart`
   — proto bytes, FlatBuffer field-by-field, tensor bytes, fpzip floats).
   Tests must skip (not fail) when an optional native lib is absent so CI
   stays green.
3. **Version-stamped migration pass on first launch** after upgrade: detect
   old artifacts → reuse what's valid → queue downloads for what's missing →
   only then treat anything as obsolete.
4. **Never silently delete user downloads.** Obsolete model formats are
   offered in a cleanup UI with sizes ("2.1 GB from the old speech engine —
   [Reclaim]"), and the offer only appears in the release where the sidecar is
   actually removed — never during the soak (downgrade safety).
5. **Settings continuity.** Keep identifiers stable across engines (voice IDs
   like `af_heart`, whisper size names like `base.en`, embedding model name)
   so user selections survive invisibly.
6. **Update-dialog honesty.** When a one-time re-download applies (Whisper),
   say so in `docs/Rawhide.md` → the "What's New" dialog.
7. **Deletion is part of the phase.** The removal release deletes the sidecar
   binary, its build-workflow steps, its bundling/signing steps, and its
   Python source — per CLAUDE.md's dead-code rules. Bundle native libs
   (libfpzip, sherpa-onnx) via `Contents/Frameworks/` on macOS; they are
   signed by the existing broad codesign pass.

## Phase 1 record (Draw Things) — precedent to copy

- Native client: `lib/services/grpc/dt_native/` (proto codec, FlatBuffer
  builder with exact slot/default parity, NNC tensor codec, fpzip FFI).
- Fallback wiring: `draw_things_grpc_service.dart` — native first, sidecar on
  any failure, `FP_DT_SIDECAR=1` forces legacy, fpzip pre-flight avoids
  wasting a generation when the dylib is missing.
- Dev dylib: `scripts/build-fpzip-macos.sh` → `tools/fpzip/` (gitignored).
- Still TODO for phase-1 completion: bundle libfpzip in release workflows
  (macOS Frameworks/, Windows/Linux alongside exe), soak one release, then
  delete `tools/dt-grpc-python/`, the dt_grpc PyInstaller build steps, and
  the dt_grpc bundling/chmod steps in all three build paths.

## Phase 2 record (expression classifier) — shipped 2026-07-16

- In-process pipeline: `lib/services/expression/` — `wordpiece_tokenizer.dart`
  (BERT-uncased WordPiece: lowercase, Latin accent strip, punctuation/CJK
  splitting, greedy longest-match), `onnx_emotion_engine.dart` (isolate-run
  session-per-call inference via `onnxruntime_v2`, smolvlm precedent —
  better memory profile than the persistent sidecar), and
  `onnx_emotion_classifier.dart` (native-first `ExpressionClassifier` with
  automatic sidecar fallback + direct-HTTPS model download).
- Rollback lever: `FP_EXPR_SIDECAR=1` forces the legacy Python sidecar for
  classification AND download. Per-call fallback logs `[Expr-Native] ...`.
- Model reuse: resolves the sidecar's HuggingFace hub cache first (its
  `tokenizer.json` doubles as the vocab source when `vocab.txt` is absent);
  fresh installs download `model.onnx` + `vocab.txt` (~268 MB) straight from
  HF — **no Python required anymore** for the download or inference.
- **Bug fixed, not ported**: the sidecar's `EMOTION_LABELS` had 26 entries
  for a 28-class model (missing `disapproval` and `relief`), so every label
  after `disappointment` was reported shifted. The native path uses the
  model's true id2label order from its config.json.
- Verification: `test/services/expression/onnx_emotion_test.dart` — 18
  goldens generated from the exact Python sidecar stack (token ids for 13
  sentences incl. accents/curly-quotes/emoji/CJK/512-truncation; float64
  softmax scores from real model logits). Plus
  `onnx_emotion_e2e_test.dart` — full text→label pipeline against the real
  268 MB model, gated on `FP_EMOTION_TEST_MODEL` (skips in CI); passed
  against the Python reference on 2026-07-16 (all six labels + confidences
  within 1e-3).
- Still TODO for phase-2 completion: soak one release, then delete
  `sentiment_classifier.py`, its PyInstaller build/bundle steps in
  release/nightly workflows + `scripts/build-macos.sh`, and the
  `ONNXExpressionClassifier` sidecar class + its resolution logic.

## Success criteria (whole effort)

Zero Python at runtime; `Sidecar.entitlements` deleted; release workflows lose
all PyInstaller steps; bundle shrinks >1 GB; worst-case user migration cost is
one Whisper model re-download + a few MB of Kokoro extras.
