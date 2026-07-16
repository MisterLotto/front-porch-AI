# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.

## Recent improvements (unreleased — ships in the next build)

- 🎨 **Draw Things integration rebuilt — faster and far more reliable** — the app now talks to Draw Things directly instead of going through a bundled Python helper (the main reason Draw Things sometimes worked from source but broke in releases). Connection tests, model lists, and generations run in-process with live step progress; if anything goes wrong it automatically falls back to the old path, so nothing regresses while the new path proves itself.
- 🎭 **Expression detection rebuilt the same way — and more accurate** — the ONNX emotion classifier now runs inside the app (no Python helper needed, including for the model download), and a long-standing labeling bug was fixed: about a third of the emotion labels were being reported as the wrong emotion (e.g. disapproval showing up as disgust). Your already-downloaded model is reused as-is.
- 🎤 **Voice input (speech-to-text) rebuilt too — faster and Python-free** — Whisper now runs inside the app with no helper process to break. Heads up: the new engine uses a different model format, so your Whisper model will **re-download once** the first time you use voice input (Tiny ~105MB / Base ~155MB / Small ~360MB); your size choice is kept. If anything goes wrong it automatically falls back to the old path.
- 🔧 Under-the-hood fixes and polish.
