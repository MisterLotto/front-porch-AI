# What's New

These notes feed the in-app "Update Available" dialog for stable releases on `main`.

## v1.2 — Occupy Mars

- 🌍 **Worlds — build a place, then share it** — Places carry real climates you can author: rename conditions, give them emoji and flavour, set temperature bands, and choose the **atmosphere and gravity**. Mars stops shipping with breathable air, volcano heat and Martian cold are real to the engine, and characters feel them, dress for them and complain about them. Finished a world? **Post it to The Stoop** like a character — full upload and download — and a new chat inherits its character's world automatically.

- 🎙️ **Bring your own Piper voices** — Import raw `.onnx` voice files straight into the app, no conversion step, and they sit alongside the built-in voices everywhere.

- 🗂️ **Folders finally hold group casts** — Groups can be dragged into folders and moved through the hierarchy exactly like characters always could, including from the multi-select toolbar.

- 🏡 **Profiles and avatars on The Stoop** — Your name now opens a real profile: your picture, when you joined, followers and lifetime stats, a bio and up to four links, with your uploads underneath as an art grid. Other creators get the same page. Avatars need a **confirmed email address**, so drive-by accounts can't post pictures at all — and confirming one also unlocks sharing, password reset and changing your sign-in email.

Plus bug fixes and speed improvements ported from nightly Rawhide builds.

## v1.1.2 — Faces That Stick

Portrait and gallery fixes that make avatars behave, plus stability polish from the nightlies (Flutter 3.44.8 under the hood).

- 🖼️ **Avatars actually stick on the character** — Avatar Gallery stars, missing portraits, solid-color placeholders, and first uploads used to fight each other (Edit Character said "No avatar", home kept a blank face, delete made the wrong tile vanish, first upload doubled as portrait + look). The starred face is now the card face everywhere; placeholders get replaced by real art; first upload is portrait-only; gallery delete refreshes the right tile; home updates when you hit Done.

- 📖 **"Our Story" no longer spins forever** — Opening the milestones timeline mid-chat could load forever because background heartbeats kept restarting it. It loads once and stays put, refreshing only when new messages arrive.

- ⚡ **Remote backends skip the KoboldCpp download** — If you're on OpenRouter or another OpenAI-compatible remote server, first launch no longer pulls a large local binary you will not use. Local Kobold users are unchanged.

- 📚 **Hub cards with lorebooks look complete again** — Stoop/hub downloads that carry a V2 `character_book` now show that lore instead of looking loreless after import.

- 🛑 **Stop, time, and needs behave** — Stop truly ends the turn; an OOC time skip owns the clock (no double-advance); needs chips no longer invent full-value deltas when a baseline was missing; live turns are protected from mid-stream sends/deletes.

## v1.1.1 — Linux hotfix

- 🐧 **Fixes Linux installs that couldn't open their database** — v1.1.0 shipped without its bundled SQLite engine, so Linux users saw "libsqlite3.so is missing" and were told their database was corrupted. **Your data was never actually damaged** — the app simply couldn't open it. Updating fixes it, and your chats are exactly where you left them. Affects every Linux package (`.deb`, `.rpm`, AppImage, tarball and the AUR build); macOS and Windows were never affected.

- 🔒 **This can't happen again** — the release pipeline now refuses to publish a Linux build that can't reach its database engine, so a missing library is caught before it ever reaches a download page instead of on your machine.

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
