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

Last pruned: 2026-07-04 — removed every bullet already published through
nightly-rawhide.20260703.e995e6b (verified against the live release body); only the
unreleased delta (committed since that build) remains below.
-->

## Recent improvements (unreleased — ships in the next build)

- ☕ **Your character keeps living while you're away (AFK)** — turn on **Dynamic Responses** (Settings → Generation) and, once you've stepped away from an open chat, your character quietly gets on with their day instead of just waiting: up to three short solitary snapshots — a meal, a nap, a shower, some reading — arrive on a timer you set (30 seconds to 5 minutes apart). Time drifts forward and their Needs move to match what they actually did — a shower lifts hygiene, a nap restores energy, a meal fills hunger — with the usual needs chip on each auto-message so you can see what changed. It never talks *to* you or breaks the scene, waits until you've traded at least one message, stops after three so it can't run away, and resets cleanly the moment you type or switch chats. Prefer to keep the engines off? It still works — you just get the quiet narration, no clock or needs. You can also flip it on straight from the message box: type **/afk** (or **/afk --messages 3 --time 5m** to send three, five minutes apart), and **/afk off** to stop.
- 📔 **Characters actually keep a diary now (especially on "thinking" models)** — The Journal was quietly writing its "Where we are" recap every chat but almost never jotting down the individual memories that make it feel alive, so most chats showed an empty diary. Two things were fixed: (1) the character is now told to capture what mattered — every promise, thing it learned about you, relationship shift, and moment that stood out — first, before the recap; and (2) on reasoning/"thinking" models (e.g. Kimi K2.6:thinking via OpenRouter/Nano-GPT), the journal update now runs with thinking switched off. Previously the model would burn its whole response budget silently "thinking" and get cut off before it ever wrote the entries — so entries appeared only intermittently (you'd have to regenerate two or three times). Now it writes them the first time, faster, and captures more of them.

- 📡 **The Stoop is alive now — upvotes and downloads tick up in real time** — when someone upvotes or downloads a character while you're browsing The Stoop, you see the number change *the moment it happens*: on the browse grid, the featured banner, an open character panel, creator profiles, even your past-downloads row. No more refreshing or hopping out and back in to see how a card is doing. Post a new character on Discord and watch the downloads roll in live.

- 💾 **Fixed: your character's Needs sometimes "rewound" after closing the app** — occasionally, closing and reopening Front Porch AI would snap the Needs bars back to where they were *before* the last reply, as if that message's changes (the little "Bladder +85, Fun +18…" chips) never happened. The app was closing a beat too fast, before that last save finished writing to disk. It now waits for every pending save to fully land before it shuts down, so the state you see when you close is exactly the state you get when you reopen.

- 🪟 **Fixed: app opening as a stuck taskbar icon you couldn't restore (Windows 11)** — if Front Porch AI ever launched to nothing but an icon on the taskbar that wouldn't maximize (and reinstalling didn't help), this is fixed. Closing the app while it was minimized could save a bogus off-screen window position that then got reloaded on the next launch, parking the window where you couldn't reach it. It now refuses to restore a window that wouldn't land on any of your monitors and recenters instead — which also repairs any install that was already stuck, and rescues windows left off-screen after unplugging a second monitor.

- 🎛️ **Your sampler settings actually reach the model now** — if you ever felt like moving Min-P, Repeat Penalty, XTC, or Dynamic Temperature did nothing… you were right. Only Temperature was truly being delivered; the rest were silently dropped on the way to the model (and Repeat Penalty was being translated into a much weaker lookalike). Every slider now arrives for real, on local models and remote APIs alike. And while we were in there, three new knobs joined the panel: **Top-P** and **Top-K** (work everywhere), and **DRY** — the modern anti-repetition sampler that catches repeated *phrases*, not just words (local models; try 0.8 if your character keeps recycling the same lines). Heads-up: because Min-P and the real Repeat Penalty now genuinely apply, replies may feel slightly different — that's the sliders finally doing their job.

- 🛋️ **The chat sidebar got a complete warm-porch makeover** — nine mismatched, bolted-on sections became three tidy groups: **🎭 Character State** (their mood, bond, trust, needs, and the time of day in one card), **📖 Journal & Memory**, and **🎲 Story Tools** (author's note, objectives, chaos, lorebook). The big fix: **Lust is no longer quarantined in its own orange box** — it's a bar right under Bond and Trust, same look, same place, in solo *and* group chats, with the refractory countdown tucked beneath it (NSFW on/off now lives in the little gear next to it). Every bar in the app finally uses one consistent style, the whole sidebar respects light mode properly for the first time, collapsed cards show a one-line vital sign ("Fond · Trusting · Evening" — with a 🧠 when they're fixated), and the sidebar remembers which groups you keep open between launches. **Author's Note sits right at the top** as its own card (with an "active · strength N" hint when one is set), flipping Realism on now pops the stats open so you instantly see what you enabled, and the **Automatic Passage of Time toggle actually works now** — it turns out it was quietly broken before this redesign too: the switch changed a value that was never saved or repainted, which is also why it seemed to snap back on (or get "forced on" after touching One-Shot Eval). It now saves properly from both the sidebar and Group Settings.
