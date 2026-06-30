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

Last pruned: 2026-06-27 — removed every bullet already published through
nightly-rawhide.20260626.0309c1f (verified against the live release bodies); only the
unreleased delta remains below.
-->

## Recent improvements (unreleased — ships in the next build)

- 🌐 **Front Porch AI now runs in your browser and on your phone** — a brand-new web app brings the full desktop experience anywhere: chat with live-streaming replies, browse and organize your whole library, create and edit characters, manage models and backends, write Porch Stories, and tune the complete Realism & Needs engine — all kept in sync with the desktop app. Open it in any browser on your computer, or set it up on your phone over Tailscale in a couple of taps.
- ⚖️ **Realism Engine no longer assumes anyone's gender** — the behind-the-scenes relationship/trust evaluations had baked-in "he/she/her" wording that could misgender you or your character (e.g. a male persona getting "His eagerness warms me"). Those prompts are now gender-neutral, so the realism notes reflect the actual people in your scene.
