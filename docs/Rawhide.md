# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.

<!--
MAINTAINER NOTE — keep this file lean (read before adding bullets).
"Recent improvements" lists ONLY changes that have NOT yet shipped in a published
nightly/stable release. Each release body is sourced from this section, so the moment a
bullet ships, DELETE it here — otherwise the next release re-announces it (this is exactly
the duplication that built up before the 2026-06-27 prune).

PRUNE DAILY, BEFORE CUTTING A BUILD: check the newest nightly-rawhide.* release and remove
every bullet already present in that release body (compare by emoji/title). Only the delta
committed SINCE that build stays here. `gh release view <latest nightly-rawhide tag> --json body`
is the source of truth; `git log <latest tag>..HEAD --oneline` shows what's genuinely new.

Archive of shipped notes: the GitHub Releases page (every nightly/stable body) is the
permanent record; docs/release-notes.md is the curated long-form history. Do NOT copy
granular nightly bullets into release-notes.md — let the release bodies be their archive.

Last pruned: 2026-07-06 — removed every bullet already published through
nightly-rawhide.20260706.87d4c0c (verified against the live release body); only the
unreleased delta (committed since that build) remains below.
-->

## Recent improvements (unreleased — ships in the next build)

- 🚀 **Much faster web/mobile home screen over slow connections** — the character grid used to send the full-resolution card image for every tile (each one often a megabyte or more, with the entire character card tucked inside it), so opening the library from your phone or another device over a slow or remote link could crawl. It now sends tiny, right-sized thumbnails instead — typically a small fraction of the old size — and remembers them so a second visit loads almost instantly. The pictures look the same; they just arrive far quicker. Applies everywhere the web/mobile app shows a grid of avatars (library, character picker, group builder, worlds).
- 🔥 **Fixed: characters would edge forever and never finish on their own** — with the Realism Engine on, a character whose Lust was pegged near the top could stay right on the brink through an entire scene and never actually climax unless you broke immersion to *tell* them to (an `OOC:` "finish" nudge). Peak arousal now lets them tip over naturally, in their own voice, when a scene is actively physical — no stage-directing required. The safety rail that keeps arousal a measure of *desire* rather than an auto-trigger still holds: a character who's just aching and untouched won't spontaneously finish out of nowhere. Applies to 1:1 and group chats and the web/mobile app.
- ⏳ **Fixed: pop-up notices that never went away** — some bottom-of-screen notifications that carry a button — the *"So-and-so left the scene"* **Undo** notice after a character exits, a voice/TTS error's **OK**, and the new-moderator-message **View** alert — would sit there forever instead of fading after a few seconds. They now honor their timer and clear on their own again, while the button keeps working the whole time it's shown.
