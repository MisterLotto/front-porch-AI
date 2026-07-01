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

- 🎚️ **Tune a group's Realism, Needs & hidden feelings after you've made it** — the group editor has a new **Realism & Dynamics** tab. For each member you can set their starting bond, trust, mood, and every need (baseline + how fast it drains), and — for small groups — pre-seed how the characters secretly feel about each other on the same −300…+300 scale as the solo creator. These used to be locked in the moment you created the group. This release also fixes a quiet bug where those starting bond/trust/mood/feeling values set in the **Group Creator** weren't actually taking effect in chat — now they do (existing groups pick up the fix the first time you open and save the new tab).
- ✏️ **Edit a group member's character card** — the group editor now has an **Edit** button on each member that opens the full character editor (persona, personality, scenario, greeting, example dialogue, that member's own lorebook & worlds). Members used to be frozen the moment a group was created — now you can fix a typo or tweak one for the group's story anytime. Changes stay **inside that group** and never touch your library copy of the character.
- 🔁 **Update a character *or group* you've shared instead of re-posting it** — the **Mine** tab now has an **Update** button on each character **and group** you've shared (approved *and* pending). It opens the **full editor** you already know — for a group that's the group editor with the new **Realism & Dynamics** tab — and **Next** saves your edits *and* re-publishes the shared card **in place**, keeping the same page, downloads, votes, and links. The detail panel shows a version pill (**v2**, **v3**…) once a card has been updated, and re-sharing no longer creates a duplicate. Groups now carry a permanent ID that travels with the card, so you can even update a group you shared after **switching to a new device**.
- 🔢 **The Stoop now shows how big a character is before you download** — every card in the browser and its detail panel shows an approximate token count (e.g. "~1.2k tokens"), computed with a real tokenizer, so you can tell a lightweight card from a context-hungry one at a glance. Group cards show the total across all members.
- 🔎 **Search when sharing to The Stoop** — the "pick a character" step of the upload flow now has a search bar, so a big library is no longer a long scroll to find the one you want to share.
- ⏳ **Group members now get their own needs "tick rate"** — in a group chat each character can hunger, tire, and get bored at their own pace, exactly like a solo character. The Group Creator's Realism step now shows a Decay / Turn slider under every need for each member, and the in-chat Group Settings let you fine-tune each character individually (the old single "whole group" decay control is gone). Existing groups keep behaving exactly as before. (Also fixed a quiet bug where needs baseline/decay tweaks made in the Group Creator weren't being saved for most characters.)
- 🌐 **Front Porch AI now runs in your browser and on your phone** — a brand-new web app brings the full desktop experience anywhere: chat with live-streaming replies, browse and organize your whole library, create and edit characters, manage models and backends, write Porch Stories, and tune the complete Realism & Needs engine — all kept in sync with the desktop app. Open it in any browser on your computer, or set it up on your phone over Tailscale in a couple of taps.
- ⚖️ **Realism Engine no longer assumes anyone's gender** — the behind-the-scenes relationship/trust evaluations had baked-in "he/she/her" wording that could misgender you or your character (e.g. a male persona getting "His eagerness warms me"). Those prompts are now gender-neutral, so the realism notes reflect the actual people in your scene.
- 💗 **Lust no longer creeps up during innocent conversation** — the arousal eval was nudging Lust upward on ordinary, non-sexual turns (talking about food could add +5) and it never naturally came back down. Arousal now stays at 0 for everyday conversation and gently cools toward neutral when nothing sexual is happening, so the Lust meter actually reflects the scene.
- 🎯 **Auto-generated objective tasks are now the character's to do, not yours** — when you create an objective and have the AI generate its subtasks, the steps were sometimes written as things *you* had to do. Tasks are now clearly framed as actions the character pursues, so quests read from their side of the story (applies to both objectives you create and ones the character sets for themselves).
