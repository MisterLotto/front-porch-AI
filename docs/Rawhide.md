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

- ⚙️ **Sturdier Realism Engine readings** — the behind-the-scenes checks that track bond, trust, mood, and desire used to ask the AI for a very specifically formatted reply and then fish the numbers out of whatever came back — the single most fragile step in the engine, and the root of most "my bond/trust chips stopped moving" reports. On models that support it (including modern local models like Qwen3), those checks now use proper structured tool calls — the same reliable channel the Journal and Growth Rings already use — so the numbers arrive typed and valid instead of parsed out of prose. The same upgrade covers the needs tracker (including climax detection), the scene clock and posture, the expression classifier, and the side-character detector. Models that can't do this are detected automatically (once per session, shared across every system) and keep using the old way. No behavior changes: same scoring rules, same values, in 1:1 and groups alike — the readings just fail less.
- 🌱 **Growth Rings — character growth you can actually see** — Character Evolution has been rebuilt from the ground up. Instead of the AI silently rewriting a character's whole personality every so often (which slowly made them drift and repeat themselves), characters now grow like trees: each small, real change — a new habit, a softened stance toward you, a scar from a painful scene — becomes its own "ring" with receipts you can tap to jump to the exact message that earned it. Rings that keep showing up grow stronger until they become a permanent part of who the character is; ones that stop mattering quietly fade into a viewable past. The new Growth timeline lives in the sidebar (and the web/mobile app) with a pin/edit/retire menu, a "Plant a ring" button to write your own, and a slider for how often growth is checked (default: every 5 of your messages — big emotional moments and finished quests are checked instantly). Prefer to stay in control? Flip on "Review growth before it applies" and approve each change with checkboxes. Existing chats convert automatically: growth already recorded is distilled into starter rings and the original text is archived, never lost. Works in 1:1, groups (every member grows their own rings), and even scene guests.
- 🏆 **Fixed: finished quests now actually complete — and the next one can begin** — when a character finished every step of their quest, the quest and its checked-off steps just sat there forever, and because the "main quest" slot looked occupied, the character could never come up with a new goal to chase. Completing the final step now properly wraps the quest up: it's cleared from the panel, the moment is recorded in the character's Journal, and the character is free to dream up their next big goal on their own. Old chats with a stuck finished quest heal themselves automatically the next time you chat. Works the same in 1:1, group chats, and the web/mobile app.

- 🚀 **Much faster web/mobile home screen over slow connections** — the character grid used to send the full-resolution card image for every tile (each one often a megabyte or more, with the entire character card tucked inside it), so opening the library from your phone or another device over a slow or remote link could crawl. It now sends tiny, right-sized thumbnails instead — typically a small fraction of the old size — and remembers them so a second visit loads almost instantly. The pictures look the same; they just arrive far quicker. Applies everywhere the web/mobile app shows a grid of avatars (library, character picker, group builder, worlds).
- 🔥 **Fixed: characters would edge forever and never finish on their own** — with the Realism Engine on, a character whose Lust was pegged near the top could stay right on the brink through an entire scene and never actually climax unless you broke immersion to *tell* them to (an `OOC:` "finish" nudge). Peak arousal now lets them tip over naturally, in their own voice, when a scene is actively physical — no stage-directing required. The safety rail that keeps arousal a measure of *desire* rather than an auto-trigger still holds: a character who's just aching and untouched won't spontaneously finish out of nowhere. Applies to 1:1 and group chats and the web/mobile app.
- ⏳ **Fixed: pop-up notices that never went away** — some bottom-of-screen notifications that carry a button — the *"So-and-so left the scene"* **Undo** notice after a character exits, a voice/TTS error's **OK**, and the new-moderator-message **View** alert — would sit there forever instead of fading after a few seconds. They now honor their timer and clear on their own again, while the button keeps working the whole time it's shown.
