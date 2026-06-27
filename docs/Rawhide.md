# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.

<!--
MAINTAINER NOTE — keep this file lean (read before adding bullets).
"Recent improvements" lists ONLY changes that have NOT yet shipped in a published
nightly/stable release. Each release body is sourced from this section, so the moment a
bullet ships, DELETE it here — otherwise the next release re-announces it (this is exactly
the duplication that built up before the 2026-06-27 prune).

Archive of shipped notes: the GitHub Releases page (every nightly/stable body) is the
permanent record; docs/release-notes.md is the curated long-form history. Do NOT copy
granular nightly bullets into release-notes.md — let the release bodies be their archive.
- 🗣️ **Characters now notice when you go quiet** — flip on **Dynamic Responses** in **Settings → Generation** and your chat characters will gently speak up if you go AFK. After a minute of silence, the character will fill the quiet moment naturally — no fourth-wall breaking, no "Are you still there?" — just an in-character reaction to the stillness between you. The feature pauses when you leave the chat, won't interrupt TTS or an ongoing response, and only kicks in after the first exchange. A double cooldown prevents back-to-back responses. (Disabled by default.)
- 🗣️ **Characters now notice when you go quiet** — flip on **Dynamic Responses** in **Settings → Generation** and your chat characters will gently speak up if you go AFK. After a minute of silence, the character will fill the quiet moment naturally — no fourth-wall breaking, no "Are you still here?" — just an in-character reaction to the stillness between you. The feature pauses when you leave the chat, won't interrupt TTS or an ongoing response, and only kicks in after the first exchange. A double cooldown prevents back-to-back responses. (Disabled by default.) Added a **Max AFK Responses** slider (default 3, range 0–20, 0 = unlimited) as a cost cap for paid API backends. The Realism & Needs engine is now suppressed during auto-responses to save additional LLM calls. Timer continues when the app is in the background so AFK detection works across alt-tabs.

- 🖼️ **Turn on Image Generation right from Settings** — the ✨ Image Studio button only appears in chat once image generation is switched on, but that switch used to be tucked away inside the character creator — so it was easy to never realize the feature existed. There's now a clear **Image Generation** toggle in **Settings → Voice & Media**: flip it on and the Image Studio button shows up in your chat toolbar. (Backend, model and LoRA setup still live inside the Image Studio.)
Archive of shipped notes: the GitHub Releases page (every nightly/stable body) is the
permanent record; docs/release-notes.md is the curated long-form history. Do NOT copy
granular nightly bullets into release-notes.md — let the release bodies be their archive.

Last pruned: 2026-06-27 — removed every bullet already published through
nightly-rawhide.20260626.0309c1f (verified against the live release bodies); only the
unreleased delta remains below.
-->

## Recent improvements (unreleased — ships in the next build)

- 🌐 **Front Porch AI now runs in your browser and on your phone** — a brand-new web app brings the full desktop experience anywhere: chat with live-streaming replies, browse and organize your whole library, create and edit characters, manage models and backends, write Porch Stories, and tune the complete Realism & Needs engine — all kept in sync with the desktop app. Open it in any browser on your computer, or set it up on your phone over Tailscale in a couple of taps.
