# What's New

These notes feed the in-app "Update Available" dialog for stable releases on `main`.

## Highlights — v1.1

Your characters got a life of their own. This release brings the **Living Time** wave from the nightlies to stable — plus a smarter creator, per-chat themes, and a long list of quality fixes.

- 🌦️ **Real story weather, hour by hour** — every chat has deterministic weather that changes through the day: fog burns off mid-morning, rain fronts roll in after lunch, storms break in the evening. Characters feel the shift mid-conversation, see fronts coming ("smells like rain tomorrow"), and dress for the cold in words, not numbers. Real temperatures with a daily curve show on the sidebar chip — °C or °F, your pick.

- 💤 **Dreams** — when a story night passes, your character dreams: a short, hazy scene woven from their Journal memories, mood, and the weather outside. Dreams land in the diary too, and can resurface later.

- 📖 **"Our Story" — a milestones timeline** — first bond tier, trust repaired, promises kept and broken, objectives completed: the relationship's real beats collect into a timeline you can browse (desktop and web), with tap-to-jump receipts.

- 🤝 **Promises leave scars now** — commitments your character (or you) make are tracked in a ledger: kept ones warm trust, broken ones crater it, and open ones color the next reply.

- 🗓️ **A real story calendar** — chats run on a genuine calendar date and clock ("Tue, Jul 1 · Day 2 · 9:00 AM"), with seasons that fall out of the actual month — which is what makes the weather and dreams feel anchored.

- 🌱 **Ambitions** — characters carry long-term goals that surface in the sidebar and pull scenes forward — the future axis to the Journal's past.

- 👋 **They notice when you've been gone** — come back after days away and you get a "Previously on…" recap banner; optionally, the character acknowledges the absence in their own voice, once.

- 📚 **Turn any chat into a story** — one tap distills a session into a Porch Stories project, with a faithful mode that forbids inventing or reordering events.

- 🎨 **Per-chat visual themes** — ten presets (Galactic, Noir, Sakura, Steampunk…) plus full color customization per chat, on desktop and web alike. Community-contributed by dazpants1.

- 🧙 **The AI character creator got an overhaul** — a voice-first interview that asks better questions, three-stage "living world" lorebook generation with interconnected entries, optional dynamic dice/pick macros, and a veto gate on the portrait before the expression pack spends your time.

- ✂️ **Output Sanitizer** — automatic find & replace on model output (goodbye, em-dash tics): exact text or lightweight wildcards with capture groups, per-chat overrides, optional retroactive cleanup of saved history, and a plain-language syntax guide. Community-contributed by S-A-M-F.

- 🎲 **Mafia nights come home** — finish a game of LLMerta with your persona and FPA characters at the table, and the night lands in their Journals as real memories they'll bring up in chat.

- 🧠 **Memory got deeper** — memories can hide verbatim recall behind them (expand-memory), retrieval no longer parrots your phrasing back (tuned defaults), and duplicate memories stop crowding the prompt.

- 🩹 **A batch of long-standing bugs went down** — bond scores no longer quietly inflate on re-open; stale per-chat sampler overrides (the "suddenly repeating old messages" bug) are healed automatically; Chaos Mode survives the session history list; the Speech Rate slider actually works for Piper and Kokoro; same-name character imports ask Keep both / Replace instead of clobbering; and The Stoop signs in over plain-HTTP LAN setups.

- 📦 **macOS: one clean installer** — the signed, Apple-notarized `.pkg` is now the only macOS download; the legacy unsigned `.dmg` is retired.

For the complete list, see the GitHub release notes.

## Highlights — v1.0

Front Porch AI hits **1.0** — the biggest update ever. Everything below has been proving itself on the nightly builds for months and lands in stable at once.

- 🏡 **The Stoop — a community character hub, built right in** — browse, share, and download character & group cards without leaving the app (or from any browser at hub.frontporchai.app). Whole group casts travel with their lorebooks and realism state intact. Opt-in, 18+, and the rest of the app stays 100% local.

- 📔 **Characters keep a real diary now (The Journal)** — promises made, things they learned about you, moments that mattered — each memory stamped with the feeling behind it. Strong memories linger; faint ones resurface when the moment calls them back. Read it, edit it, pin the ones that matter. Nothing ever leaks between chats.

- 🌱 **Growth Rings — character growth you can actually see** — instead of silent personality rewrites, every real change becomes a visible "ring" with receipts you can tap to jump to the moment it happened. Recurring growth becomes permanent; stale growth fades into a viewable past.

- 🎭 **One chat, a cast that changes** — turn any solo chat into a group in place with `/join`, wave someone off with `/exit` (undo included), and collapse back to a clean 1:1 — realism, needs, and memory carry across both ways.

- 🧭 **Lorebooks work the way their authors wrote them** — import SillyTavern / Chub / NovelAI / AgnAI / RisuAI books through a preview wizard; conditional triggers, timers, chains, variety groups, and stateful macros (`{{setvar}}`, `{{roll:d20}}`…) all actually run.

- 🖼️ **The Image Studio was rebuilt** — pick a subject and go; generate full **expression packs** from one portrait (with an AI vision quality check), paint the current scene with `/image` right in chat, use reference images with a denoise slider, and connect **ComfyUI** with zero node graphs.

- 📸 **Send your character a photo — they actually see it** — vision models react to your pictures in character; any GGUF can gain sight via its mmproj file; and a fully local Photo Understanding helper covers text-only models. No cloud.

- 📱 **The web & phone app was rebuilt** — a proper installable app in the same warm look: chat, characters, stories, images, and the full Stoop from your phone. Much faster over slow connections, and it heals itself after your phone sleeps.

- 🛋️ **The warm-porch redesign** — the whole app now speaks one cozy design language (goodbye neon accents), and light mode finally looks right everywhere.

- 🧠 **The Realism Engine got deeper and far more reliable** — readings arrive as structured tool calls on capable models (chips stop stalling), characters hear their state as natural language instead of stat dumps, group chats match 1:1 exactly (including genuine hostility and needs catastrophes), intimacy recovery feels human, and self-chosen goals become real quests with steps.

- ☕ **Your character keeps living while you're away** — turn on Dynamic Responses (or type `/afk`) and they'll quietly get on with their day — a meal, a nap, a shower — with time and needs following along.

- ⚡ **Faster, and honest about what it's doing** — long local chats reply dramatically sooner (reading phase ~15s → ~1s), the status bar shows real progress ("Reading prompt — 43%"), your sampler settings and stop strings actually reach the model, and thinking models genuinely think on local KoboldCpp.

- 💾 **Smarter local backups replaced Cloud Sync** — rolling 30-minute + daily snapshots written by the database engine itself, with one-click restore. Old PCs without AVX2 are now supported automatically, too.

For the complete list, see the GitHub release notes.
