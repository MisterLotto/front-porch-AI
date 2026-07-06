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

- ⏳ **Fixed: pop-up notices that never went away** — some bottom-of-screen notifications that carry a button — the *"So-and-so left the scene"* **Undo** notice after a character exits, a voice/TTS error's **OK**, and the new-moderator-message **View** alert — would sit there forever instead of fading after a few seconds. They now honor their timer and clear on their own again, while the button keeps working the whole time it's shown.
