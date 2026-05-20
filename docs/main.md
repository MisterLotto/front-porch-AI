# Stable — What's New

These notes feed the in-app "Update Available" dialog for official stable releases.

## Version 0.9.8.1

- 🖼️ **Fixing Character Avatar Changes** — A long-standing crash when replacing a character's avatar image in the full editor has been fixed. This particularly affected users on macOS (and could affect packaged builds on other platforms). Avatar updates now complete reliably without "Read-only file system" errors.

- ☁️ **Cloud Sync Page is Live** — The Cloud Sync settings page now loads the real interface instead of a placeholder. You can manage your sync settings properly.

- 📖 **More Forgiving Story Generation** — The story engine now handles cases where AI models return floating point numbers (e.g. `1.0`) instead of clean integers for beats, scenes, acts, and lore entries. This makes story generation much more stable across different models.

- 🔊 **TTS Improvements** — 
  - Emojis are now stripped from text before sending to the TTS engine.
  - The "Test Voice" button in TTS settings now correctly respects the "Only narrate quotes" setting.

- 🖼️ **Image Generation Patience** — Increased the timeout for local image generation requests, giving slower models more time to respond.

- 🛠️ **Quality of Life & Maintenance** — Several behind-the-scenes improvements to CI, linting, and repository hygiene that make ongoing development smoother and more reliable.

This is a focused point release containing important bug fixes and small quality-of-life improvements while we continue maturing larger features for future releases.