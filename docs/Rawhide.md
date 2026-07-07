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

Last pruned: 2026-07-07 — removed every bullet already published through
nightly-rawhide.20260707.5ae33f4 (verified against the live release body); only the
unreleased delta (committed since that build) remains below.
-->

## Recent improvements (unreleased — ships in the next build)

- 🌱 **Growth Rings: settled characters keep visibly growing** — in very long chats, a character who had built up eight or more strong permanent rings could quietly stop *showing* new growth: fresh habits and stances were still recorded on the timeline, but the strongest old rings hogged all the character's attention, forever. Two of those attention slots are now always saved for the newest in-progress growth, so even a set-in-their-ways character keeps evolving on screen. Also fixed: the AI could retire a ring you had pinned — pinned now truly means permanent (only you can retire a pinned ring, from the Growth timeline). Applies to 1:1, groups, and the web/mobile app alike.
