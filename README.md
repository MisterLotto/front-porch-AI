# Front Porch AI

![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-blue.svg)
![Flutter](https://img.shields.io/badge/Made%20with-Flutter-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)
![Branch](https://img.shields.io/badge/Branch-Rawhide-orange)

**Rawhide is the primary rolling development branch.** All new features, experiments, refactors, and the majority of ongoing work land here. Nightly / cutting-edge builds are produced from Rawhide. Stable releases are tagged on `main`. Beta stabilization branches (e.g. `0.9.x-Beta`) are cut from Rawhide when preparing a release.

**A local-first AI companion for character chat & roleplay — Windows, macOS, and Linux.** Runs fully offline with local LLMs (KoboldCpp, etc.), driven by a living **Realism Engine** (emotion, trust, needs, and memory) with built-in **TTS and image generation** — and supports remote APIs like OpenRouter, Nano-GPT, and OpenAI with no lock-in when you want them. Open-source (**AGPL-3.0**), and built as a home for **Backyard AI refugees**.

> ### 🏡 New — The Stoop: pull up a chair, the neighbours brought characters
> Every porch is really about who shows up to it. **The Stoop** is a community character hub built right into the app — browse, share, and **download character & group cards without ever leaving Front Porch.** No browser, no separate website, no fragile copy-paste imports. Featured & mod-picked cards, follow the creators you love, upvote/downvote, and one-tap download straight into your library. Whole **group casts** travel too — members, avatars, lorebooks, **and** the pre-seeded realism/needs state all survive the round-trip, not just single cards.
> It's **opt-in, account-gated, strictly 18+** (NSFW hidden by default), and **fully open-source (AGPL-3.0)** — while the rest of the app stays 100% local. Other apps have in-app hubs, but the closed ones eventually go paid-SaaS (Backyard AI killed its desktop app to do exactly that); The Stoop is the open, local-first porch that shares living casts, not just cards. **Come sit a while → [The Stoop](#-the-stoop--built-in-community-character-hub).**

💬 **[Join the Discord](https://discord.gg/e4tET6rpdv)** — questions, feedback, and hanging out welcome.

### 🌟 Community Showcase

Front Porch is growing a small companion ecosystem. Big thanks to community members building tools that integrate deeply.

**Character Card Forge** by [@FrozenKangaroo](https://github.com/FrozenKangaroo) — A companion editor with strong integration, including emotion image export and seeding initial Realism Engine state.

[Check it out →](https://github.com/FrozenKangaroo/Character-Card-Forge)  
If you use it, a star would mean a lot to the developer.

> **Note:** This community tool uses direct database access for its advanced features. It can be impacted by future schema changes.

<p align="center">
  <img src="docs/screenshots/home_new.png" width="800" alt="Front Porch AI — Character Library">
</p>

---

## 🆕 What's New on Rawhide (vs main)

The user-facing highlights that have landed on Rawhide since it diverged from `main`. See `docs/Rawhide.md` for the running, concise list that feeds the in-app update dialog.

- 🏡 **The Stoop — a built-in community character hub** *(headline)* — Browse, share, and **download character & group cards from right inside the app** — no browser, no separate website. Featured & mod-picked cards, follow creators, upvote, one-tap download. Full **group casts** round-trip losslessly: members, avatars, lorebooks, **and** the pre-seeded Realism/Needs state. **Now also on the web** at **[hub.frontporchai.app](https://hub.frontporchai.app)** (browse as a guest, no install), with first-class **creator credits** for shared cards. Opt-in, account-gated, strictly 18+, open-source (AGPL-3.0) — the rest of the app stays 100% local. See **[The Stoop](#-the-stoop--built-in-community-character-hub)** below.

- 📔 **The Journal — a living memory that replaces summaries & fact-lists** — Characters now keep a real, per-chat **diary**: the promises made, what they learned about you, the moments that mattered — each stamped with the emotion behind it. Memories carry *heat* (strong ones barely fade, faint ones cool and resurface only when the moment calls them back), so recall feels emotional, not mechanical. **Memory never leaks between chats** — a new conversation truly starts fresh. You can read, edit, and pin entries, and tap a memory's receipt to jump to the exact line it came from.

- 🧭 **Lorebooks got a real engine — full SillyTavern-grade behavior** — Import any lorebook (SillyTavern, Chub, NovelAI, AgnAI, RisuAI) through a proper preview wizard, drop a book into **one chat only**, and edit every setting the engine actually runs — conditional triggers, regex keys, placement, sticky/cooldown timers, chaining, variety groups, and a token budget. Plus a grown-up **macro toolbox** (`{{setvar}}`/`{{getvar}}`, `{{random:…}}`, `{{roll:d20}}`, conversation + time macros) so interactive, stateful cards work the way their authors wrote them.

- 🎭 **One chat, a cast that changes** — 1:1 and group are now the same thing. Turn a solo chat into a group **in place** with `/join --full`, bring characters in/out with `/join` / `/exit` (goodbye narration + one-tap **undo**), force a turn with `/speak`, and set the order with `/turnorder`. Collapse back to a clean 1:1 with the **original** character — no orphan copies. Realism, needs, memory, evolution, objectives, and expressions carry across the conversion **both ways**.

- 🛋️ **The warm-porch redesign** — The sidebar and home screen were rebuilt around one cozy, consistent design language (terracotta/honey/amber instead of the old neon accents), every bar and card unified, and **light mode finally looks right everywhere**. The chat sidebar's nine bolted-on sections became three tidy groups: 🎭 Character State, 📖 Journal & Memory, and 🎲 Story Tools.

- ☕ **Your character keeps living while you're away (AFK)** — Turn on Dynamic Responses and, once you step away, your character quietly gets on with their day — a meal, a nap, a shower — on a timer you set. Time drifts forward and their Needs move to match what they actually did. Type `/afk` to trigger it on demand.

- 🎯 **Self-chosen goals become real quests — with steps** — When the Realism Engine decides a character genuinely wants something, that goal becomes a proper main quest with a 5-step plan they actively pursue, scene by scene (instead of a bare, invisible side goal).

- 🎛️ **Your sampler settings actually reach the model now** — Min-P, Repeat Penalty, XTC, and Dynamic Temperature were being silently dropped on the way to the model; every slider now arrives for real, on local and remote backends alike — plus new **Top-P**, **Top-K**, and **DRY** (modern anti-repetition) controls.

- 💾 **Cloud Sync deprecated → smarter local backups** — Cloud Sync is deprecated (it could occasionally resurrect deleted data). The replacement is two-tier rolling local backups — 30-minute snapshots **plus** one per day for 7 days — with one-click restore.

- 🧹 **Removed the built-in Chub / AI Character Cards browser** — It leaned on a heavy embedded-webview that misbehaved on some systems and opened an unmoderated pipe into the app. Import any card PNG/JSON with the **Import** button, or use **The Stoop** for moderated community cards. (This also slims the app and drops a large dependency.)

- 🐛 **Deep reliability work across Realism, Needs & Group chat** — per-speaker needs chips under *every* message, characters reacting to their *own* state (not a castmate's), no cross-chat bleed of fixation/needs/relationship on new chats, no double-firing climax/daily checks, and full 1:1↔group parity throughout. Plus a large internal modularization of the historic "god files" into focused, tested modules — no behavior change, just a faster and safer codebase.

> **Note for contributors & AI agents:** user-facing notes for the update dialog live in `docs/Rawhide.md` — update it for any user-visible work.

---

## 🆚 How Does Front Porch AI Compare?

If you're evaluating local AI tools, here's an honest breakdown. Every project on this list is doing something right — the goal isn't to trash competitors, it's to help you pick the right tool for *you*.

| Feature | **Front Porch AI** | SillyTavern | Jan.ai | Backyard AI |
|---|---|---|---|---|
| **Native desktop app** | ✅ Flutter (Win/Mac/Linux) | ❌ Web-based (local server) | ✅ Electron | ✅ (abandoned) |
| **Built-in community character hub** | ✅ **The Stoop** — **open-source (AGPL-3.0)**, local-first; browse / share / download in-app, incl. full **group casts** (members + lorebooks + realism/needs state) | ❌ (external sites only) | ❌ | ⚠️ Character Hub — **closed, paid-SaaS**; desktop app killed (2025), web/mobile only; single cards |
| **Fully offline — no cloud required** | ✅ | ✅ | ✅ | ✅ |
| **Remote LLM Endpoints** | ✅ Native multi-provider support (OpenRouter, Nano-GPT, custom, etc.) with deep integration | ✅ Strong native support for custom OpenAI-compatible endpoints | ⚠️ Limited | ❌ (service discontinued) |
| **Built-in TTS (50+ voices)** | ✅ Kokoro + Piper + ElevenLabs + OpenAI | ⚙️ Extension required | ❌ | ❌ |
| **Speech-to-text (push-to-talk)** | ✅ Whisper, built-in | ⚙️ Extension required | ❌ | ❌ |
| **Local image generation** | ✅ A1111, Forge, Draw Things | ⚙️ Extension required | ❌ | ❌ |
| **Realism Engine** | ✅ Time, trust, emotion, chaos, objectives | ❌ | ❌ | ❌ |
| **Character Expressions** | ✅ ONNX + LLM, live avatar swap | ⚙️ Extension required | ❌ | ❌ |
| **RAG memory (local)** | ✅ ONNX embeddings, no cloud | ⚙️ Extension required | ❌ | ❌ |
| **Novel / story generator** | ✅ Porch Stories pipeline | ❌ | ❌ | ❌ |
| **Character card compatibility** | ✅ V2 spec + Backyard .byaf import | ✅ V2 spec | ❌ | .byaf only |
| **Group chat** | ✅ | ✅ | ❌ | ❌ |
| **Extension / plugin ecosystem** | ❌ | ⭐ Very large | Moderate | ❌ |
| **Open source license** | ✅ AGPL-3.0 | ✅ AGPL-3.0 | ✅ MIT | ❌ |
| **Best for** | Polished AI companion + storytelling | Power users / heavy customization | Simple local chat | — |

> SillyTavern's extension ecosystem is genuinely impressive and unmatched for customization depth. If you want maximum flexibility and don't mind configuration work, it's excellent. Front Porch AI prioritises **everything working out of the box** for users who want to chat, not configure.

---

## ✨ Features

### 🏡 The Stoop — Built-In Community Character Hub

A stoop is where the neighbourhood meets — the front step where people swap stories and pass things back and forth. **The Stoop** brings that to Front Porch: a community character hub built right into the app, so you can discover and share characters without ever leaving home, while everything else stays offline. What sets it apart from other in-app hubs (Backyard AI's Character Hub, RisuAI's RisuRealm) is that The Stoop hands over **entire group casts** — not just single character cards — carrying members, lorebooks, **and** the pre-seeded Realism/Needs engine state intact, so a whole living scene arrives ready to play.

- **Browse & discover** — featured and moderator-picked cards, search, tag filters, and a live feed of what the neighbours are sharing.
- **One-tap download** — pull any card straight into your library; it lands ready to chat, exactly as the creator tuned it.
- **Whole casts come over, not just cards** — share a full group and the recipient gets everything: members, avatars, lorebooks, **and** the pre-seeded Realism state, Needs baselines/tick-rates, and intra-group dynamics. Nothing is flattened on the round-trip — no other character hub carries a living cast like this.
- **Share what you made** — a guided upload wizard with member-avatar montages for groups, comma-formed tag pills, and a clean review flow before anything goes live.
- **Follow creators & vote** — follow the people whose characters you love, upvote/downvote, and report anything that breaks the house rules.
- **Open porch, not a walled garden** — The Stoop is **open-source (AGPL-3.0)** and local-first. The for-profit hubs tend to drift closed and paywalled (Backyard killed its desktop app and went subscription-SaaS to do exactly that); AGPL exists precisely so The Stoop can't be fenced off the same way. Your app, your characters, your data stay yours.
- **Safe by design** — **opt-in** and **account-gated**; the rest of the app stays 100% local and offline. Strictly **18+**, with adult content **hidden by default**, optional **two-factor authentication**, and an **opt-out** anonymous device-stats ping (platform / app version / GPU tier — never your chats, characters, or raw IP). See the [Privacy Policy](PRIVACY.md).

### 💬 Chat
- **Immersive roleplay** with V2-spec character cards — full SillyTavern / Backyard AI compatibility
- **Smooth output buffer** — text drips at your reading pace, not your GPU's pace
- **Rich text styling** — dialogue highlighted in amber, actions in grey
- **Regenerate, Continue, Impersonate, Edit** — full message control
- **Persistent sessions** — chat history auto-saved and restored per character
- **Inline image rendering** — `![alt](url)` markdown renders in-chat
- **Chat branching** — fork from any message to explore alternate storylines

### 🧠 Realism Engine
- **Emotion tracking** — character mood evolves naturally across the conversation, carrying inertia between turns
- **Relationship & Trust system** — earn a character's trust over time; it shifts how open and vulnerable they allow themselves to be
- **Autonomous time progression** — scene time advances deterministically every 6 turns; OOC time-skips (`(OOC: we drive for several hours)`) are auto-detected and applied
- **Manual time nudge** — step time forward or back with sidebar chevrons
- **Character Objectives** — self-chosen goals become real main quests with concrete, sequential steps the character actively pursues
- **Fixation Engine** — active emotional obsessions that subtly color every response
- **Character Evolution** — characters organically develop new traits as your story progresses
- **The Journal** — a living, per-chat memory: characters keep a real diary of what mattered (each entry stamped with its emotion), memories carry *heat* so strong ones linger and faint ones resurface only when relevant, and nothing ever leaks between chats
- **RAG Memory** — local semantic memory powered by a lightweight ONNX embedding engine; the AI recalls past conversations without any cloud

### 🎭 Character Management
- **V2 spec support** — fully compatible with the V2 character card specification (PNG & JSON)
- **One-click import** — any V2 character card PNG/JSON, or grab community cards straight from **The Stoop** (the built-in hub) — no browser needed
- **Backyard AI (.byaf) importer** — rescue your characters from the archive format Backyard AI left behind when they killed their desktop app
- **Folder organization**, global search, tag editor, bulk PNG import
- **One-click duplication** — clone any character card for risk-free experiments

### 🧙 AI Character Creator
- **Quick Create** — type a name and concept, the AI builds a complete V2 card from scratch
- **World Lore (RAG-Lite)** — paste a Fandom wiki URL or attach a local `.txt`/`.pdf` and the generator embeds that lore into the character
- **Editor passes** — Anti-Puppet, Consistency Check, Quality Polish, Truncation Completion
- **Alternate greetings** — generate up to 5 unique first messages with configurable tone
- **Lorebook auto-generation** — world-building entries generated alongside the character

### 👥 Group Chat & Director Mode
- **Multi-character conversations** — 2+ characters interacting with each other and with you
- **One chat, a changing cast** — turn a solo chat into a group **in place** with `/join --full`, add/remove characters live with `/join` and `/exit` (goodbye + undo), and collapse back to a clean 1:1 with the **original** character — no forking or orphan copies
- **Macros** — `/turnorder` (set who speaks when, including your own slot), `/speak` (force a character to take a turn now), `/promote` (promote a scene guest to a full member)
- **Director Mode** — let characters chat autonomously, or manually choose who speaks next
- **Per-character everything** — realism, needs, expression images, author notes, and evolution are tracked per member and carried losslessly when converting between 1:1 and group

### 🗣️ Text-to-Speech
- **Four engines**: Kokoro (local, 50+ voices, 9 languages), ElevenLabs (cloud, expressive), OpenAI (cloud, premium), Piper (lightweight fallback)
- **Parallel generation** — sentences generated concurrently for fast audio output
- **Narration filters** — dialogue-only or skip action blocks (SillyTavern-style)
- **Per-character voices** in group chats

### 🖼️ Local Image Generation
- Natively connects to **A1111, Forge, SDNext, and Draw Things**
- Live model switching, LoRA injection, dedicated unload controls
- **Natural Language or Danbooru Tags** prompt mode depending on your model

### 📖 Porch Stories — Novel Generator
- Distill character chats into a coherent storyline timeline
- 5-stage autonomous pipeline: concept → outline → draft → edit → publish
- Skeuomorphic page-flip reader with audiobook TTS read-along

### 💾 Local Backups *(replaced Cloud Sync)*
- Two-tier rolling local backups (30-minute snapshots + one per day for 7 days) with one-click restore. **Cloud Sync was removed** in favor of these.

### 🎭 Character Expressions
- **Emotion-driven avatar swapping** — the character's portrait changes in real time as their mood shifts during the conversation
- **Two classification paths**: a lightweight **ONNX model** (distilbert, fully offline, ~300 ms) or the **LLM path** via the Realism Engine for deeper contextual accuracy
- **One-click model download** — the ONNX classifier downloads in-app with a glassmorphic teal progress overlay; no manual file hunting
- **26 emotion categories** mapped to your character's expression image set (compatible with SillyTavern expression packs)
- **Sidebar and fullscreen display modes** — float the expression portrait or dock it beside the chat

### ⚙️ KoboldCpp Integration
- Automated download and update of the KoboldCpp backend
- Hardware detection — Vulkan on PC, Metal on Apple Silicon, Intel ARC support, **Nvidia Blackwell (RTX 50-series) support**
- Model Hub: search and download GGUF models directly from HuggingFace
- Start/Stop KoboldCpp from inside the Character Creator
- **Advanced Launch Options** — collapsible panel exposing Flash Attention, Context Shift, mlock, GPU ID selector, and prefill batch size with sane auto-selected defaults

---

## 📥 Install

### Linux — Package Manager

**Debian / Ubuntu / Mint / Pop!_OS**
```bash
curl -fsSL https://apt.frontporchai.app/install.sh | bash
sudo apt install front-porch-ai
```
Or manually:
```bash
curl -fsSL https://apt.frontporchai.app/front-porch-ai.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/front-porch-ai.gpg
echo "deb [signed-by=/etc/apt/keyrings/front-porch-ai.gpg] https://apt.frontporchai.app stable main" | sudo tee /etc/apt/sources.list.d/front-porch-ai.list
sudo apt update && sudo apt install front-porch-ai
```

**Fedora / RHEL / openSUSE**
```bash
sudo dnf config-manager --add-repo https://rpm.frontporchai.app/front-porch-ai.repo
sudo dnf install front-porch-ai
```

**Arch Linux (AUR)**
```bash
yay -S front-porch-ai-bin        # Stable (recommended)
yay -S front-porch-ai-beta-bin   # Beta / Early access
```

Future updates arrive through your normal system updates (`apt upgrade`, `dnf upgrade`, `yay -Syu`).

> **Beta builds** are available for early access to new features. They install to a completely separate directory (`~/Documents/FrontPorchAI-Beta/`) and use `beta_` preference keys so they never touch your stable data. See the [Beta Builds](#beta-builds) section below for details.

### All Platforms — Manual Download

Head to the **[Releases](https://github.com/linux4life1/front-porch-ai/releases)** page:

- **Stable**: `.exe` installer (Windows), `.dmg` (macOS), `.AppImage` / `.deb` / `.rpm` (Linux)
- **Beta**: Standalone `.zip` (Windows/macOS), `.AppImage` / `.tar.gz` (Linux) — no installer, just extract and run

---

## Beta Builds

Beta releases (e.g. the `0.9.8-Beta` series) are available for early access to new features. They are completely isolated from your stable installation:

- Data directory: `~/Documents/FrontPorchAI-Beta/`
- All preferences are namespaced with a `beta_` prefix
- Stable builds will never offer a beta update (and vice versa)

This isolation protects your main library while you test new features. Beta builds are recommended only for users comfortable with occasional rough edges.

---

## 🆕 What's New in v0.9.8

v0.9.8 is a substantial release focused on **making the app feel more alive and reliable**. The headline feature is **Character Expressions**, but the release also delivers major maturation of the Realism Engine, a much more robust local TTS experience, .kcpps preset support, custom chat backgrounds, and dozens of quality-of-life and stability improvements.

**🎭 Character Expressions — Live Emotion Portraits**

Your characters now *look* the way they feel. As the conversation evolves, their portrait automatically swaps to match their current emotional state.

- **Dual classification engine:** Toggle between a fast local **ONNX path** (distilbert-based, ~300 ms) and the deeper **LLM path** via the Realism Engine. Both run entirely on-device.
- **One-click model download:** Download the ONNX classifier directly from Settings → Expression Images with a beautiful glassmorphic progress overlay.
- **SillyTavern compatible:** Works with any standard expression pack (26 emotion categories supported).
- **Flexible presentation:** Sidebar mode for focused chats or fullscreen cinematic overlay.
- **Graceful fallback:** Falls back cleanly to neutral if an image is missing.

**🧠 Realism Engine – Major Maturation**

The Realism Engine received its most significant round of refinements to date:

- Bond and Trust ranges expanded to **±300** with updated tier naming to match the character creator.
- Arousal system expanded to **±100** with new tier-based labels.
- Improved spatial awareness logic and better behaviour when "passage of time" is disabled.
- Realism evaluations are now **more reliable** on thinking models (higher token limits, hardened JSON generation parameters).
- **GBNF grammar disabled** for KoboldCpp realism evals (dramatically improves completion rates on many models).
- Much more robust **cancellation handling** — interrupting a response now cleanly aborts in-flight realism evaluations.
- Better one-shot eval behaviour for remote APIs and improved tooltip explanations in the UI.

**🗣️ Voice & Narration (Kokoro TTS)**

Local voice output is now significantly more reliable and pleasant:

- **Persistent Kokoro worker pool** — enables fast, high-quality "read everything" (verbatim) narration without the previous stuttering or slow startup.
- "Only narrate quotes" mode is now much more dependable.
- Improved local bundling of both Kokoro and Piper engines.
- Better concurrency controls and pre-load behaviour.

**⚙️ .kcpps Presets & Context Management**

- Full support for loading **KoboldCpp `.kcpps` launch presets**.
- When a preset is active, context size (and other generation parameters) are driven by the preset — the UI disables editing and shows a clear tooltip.
- All context size logic has been consolidated into `StorageService` for consistency across the app.

**✨ UI Polish & Quality of Life**

- **Custom chat backgrounds** — upload and name your own images per chat.
- **Google Fonts picker** for chat text styling.
- **Per-character chat bubble colours** that persist correctly when exporting to PNG.
- Scenario field is now **expandable** in the character editor.
- UI Settings dialog is now properly scrollable.
- Window size and position are remembered across restarts.
- Many small improvements to tooltips, log copying, preset validation, and widget stability.

**🐛 Stability & Fixes**

- Numerous Realism Engine interruption and regeneration fixes.
- Lorebook improvements: constant entries now persist correctly, better deduplication and wildcard/word-boundary matching.
- macOS build quality: proper bundle naming for Metal, improved DMG packaging.
- Many Tooltip, preset, and widget tree crashes resolved.
- Various packaging and CI improvements for cleaner releases.

This release represents one of the largest cumulative improvements to day-to-day feel and reliability since the Realism Engine was first introduced.

---

## ⚙️ Configuration

1. **Backend** — go to **Settings → Download Backend** to fetch KoboldCpp, or point it at an existing binary.
2. **Model** — go to **Manage Models → HuggingFace Search**, find a GGUF model (recommended: `Q4_K_M` or `Q5_K_M`), download.
3. **Optimize** — hit **Auto-Configure** to let the app pick the best GPU layer split and thread count for your hardware.

---

## 🔓 Why Does This Exist?

Backyard AI built a genuinely good local LLM companion app. Then they killed it — no warning, pivoted to a cloud subscription, and left users with characters stuck in a proprietary `.byaf` archive format with nowhere to go.

Front Porch AI was built directly in response to that. The goal: an open-source, local-first alternative that **cannot** be yanked out from under you by a pivot to SaaS. We even support importing directly from `.byaf` files so your characters can escape.

Starting with **v0.9.0**, this project is licensed under **AGPL-3.0** — meaning anyone who hosts a modified version as a service must open-source their changes too. It stays open, even in a world of cloud-hosted forks.

> **Note:** v0.8.x and earlier are licensed under GPLv3.

> 🎩 Hat tip to the Backyard AI team for at least open-sourcing the `.byaf` format on their way out.

---

## 💬 Community

- **Discord**: [Join our server](https://discord.gg/e4tET6rpdv)

---

## 🤝 Contributing

Pull requests are welcome! If you're a dev reading this far down, here's what you need to know:

- **Branch workflow:** All new features, experiments, and major work target the **`Rawhide`** branch (the primary rolling development line). Bug fixes for the current stable go to `dev`. Beta stabilization branches (e.g. `0.9.x-Beta`) receive only fixes for that release series. `main` is for final tagged stable releases only. See AGENTS.md for the full current model.
- **Nightly / scheduled builds & schedule triggers:** Automatic builds are powered by `.github/workflows/nightly.yml`. GitHub **only** reads `on: schedule:` from the default branch (`main`). A current copy of the workflow (especially the version-patching step) must live on `main`, otherwise nightly compiles will fail. The job typically checks out the active development branch for source, but the workflow definition itself always comes from `main`.
- **Commit conventions:** Follow the guidelines in [AGENTS.md](AGENTS.md) for commit message format, code style, and naming conventions.
- **Full guide:** See [CONTRIBUTING.md](CONTRIBUTING.md) for build instructions, testing requirements, and the PR template.
- **Before you PR:** Run `flutter analyze` and `flutter test` locally. The project is now at 0 warnings on the active rules. CI analyzes only changed `.dart` files on PRs (plus a full scheduled lint job). Introducing new warnings will fail CI.

---

## 📝 Note from the Dev

To everyone who has shown up with kind words, bug reports, feature ideas, and genuine enthusiasm — thank you. You've turned what started as a "screw it, I'll build my own" into something worth building every day.

— **SosukeAizen** on Discord

---

## 🙏 Credits

Front Porch AI stands on the shoulders of these incredible open-source projects:

| Project | What It Does | Link |
|---|---|---|
| **KoboldCpp** | The local LLM backend. Single-file, GGUF-native, GPU-accelerated. | [GitHub](https://github.com/LostRuins/koboldcpp) |
| **Faster Whisper** | Speech-to-text for push-to-talk and voice call mode. | [GitHub](https://github.com/SYSTRAN/faster-whisper) |
| **Kokoro** | Default TTS engine. Beautiful offline voices via ONNX. | [GitHub](https://github.com/hexgrad/kokoro) |
| **Piper** | Fallback TTS engine. Fast, lightweight, privacy-respecting. | [GitHub](https://github.com/rhasspy/piper) |

If Front Porch AI is useful to you, please consider starring these projects too — they're the foundation everything is built on.

### 🌟 Contributors

| Contributor | Role |
|---|---|
| **Hakko504** | Bug Testing, UI/Feature Suggestions |
| **PacmanIncarnate** | Bug Testing, UI/Feature Suggestions |
| **SunTzucious** | Beta Testing |

---

## 🔒 Privacy

The app is **local-first**: using it offline collects nothing and sends us nothing. The **only** part that involves an account or data collection is **The Stoop** — the optional online community hub — and only if you sign in and use it. The Stoop then handles your account info, the cards you choose to upload, a salted **hash** of your IP for anti-abuse (never the raw IP), and an **opt-out** anonymous device-stats ping (no chats, characters, or IP). Full details: [Privacy Policy](PRIVACY.md).

## 📄 License

**v0.9.0+** — [AGPL-3.0](LICENSE)  
**v0.8.x and earlier** — GPL-3.0

---

## 🛠️ Build from Source

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Git
- Windows, Linux, or macOS

That's the whole list — every AI engine (TTS, STT, character expressions, RAG memory embeddings, the Draw Things client) runs **in-process** via ONNX/native libraries that ship with the app's packages. There are no sidecar binaries to build, no Rust, no Python.

### Linux Extra Dependencies

**Ubuntu/Debian**
```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libsecret-1-dev libunwind-dev libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev
```

**Arch Linux**
```bash
sudo pacman -S clang cmake ninja pkgconf gtk3 xz libsecret gstreamer gst-plugins-base
```

**Fedora**
```bash
sudo dnf install clang cmake ninja-build pkgconf-pkg-config gtk3-devel xz-devel libsecret-devel gstreamer1-devel gstreamer1-plugins-base-devel libstdc++-devel
```

### Build & Run

```bash
git clone https://github.com/linux4life1/front-porch-ai.git
cd front-porch-ai
flutter pub get
flutter run
```

**macOS release build** (signs, packages, and notarizes):
```bash
./scripts/build-macos.sh
```

**Linux / Windows release build:**
```bash
flutter build linux    # or windows
```
That's it — the built bundle is self-contained.

---

<details>
<summary><strong>📦 Old Release Notes</strong></summary>

### V0.9.7.5

This release delivers a **complete character editor redesign**, brings **editable Realism Engine settings** to the card editor, and fixes several stability and data integrity bugs.

*(Full notes are in the "What's New in v0.9.8" section above.)*

**🎨 Character Editor — Full Redesign**
- **New 4-tab layout:** Details, Dialogue, Lorebook, and Worlds — dialogue fields (first message, alternate greetings, example conversations) are no longer crammed into the Details tab.
- **Glassmorphic section cards** with icon headers for visual grouping (Identity, Personality & World, Advanced Prompts).
- **160px avatar display** with rounded corners and camera overlay — tap to change.
- **Collapsible Advanced Prompts** — system prompt and post-history instructions hidden by default to reduce visual clutter.
- **Restyled lorebook cards** showing keyword chips, trigger depth badges, and always-active indicators.
- **Restyled worlds tab** with toggle-based linking, visual feedback, and entry count badges.
- **Consistent input styling** and token counter matching the manual character creator.

**🧠 Realism Engine — Editable in Character Editor**
- Characters can now have their Realism Engine settings **configured directly in the character editor** — no longer limited to the character creator.
- Characters without V2.5 extensions can have them **created from scratch** via the editor.
- Full access to all Realism Engine parameters: bond scores, trust level, time of day, starting emotion, recovery mechanics, and Chaos Mode toggle.
- Includes a friendly note reminding users that changes only affect new conversations — existing chats keep their live state.

**🐛 Bug Fixes**
- **Fixed character creator crash on Linux:** The back button was calling `Navigator.pop()` on a tab-embedded page, popping the root navigator and leaving a black screen. Now correctly returns to the Home tab.
- **Fixed V2.5 metadata loss on avatar change:** When editing a character and changing the avatar, the save flow was creating a redundant card copy that omitted Realism Engine extensions. The throwaway card has been eliminated — the editor now passes the live character object directly.
- **Fixed Realism Engine level 10 prompt:** Refined the peak desire state prompt to describe emotional intensity without dictating deterministic narrative outcomes or causing behavioral leakage into subsequent turns.

**⚙️ CI/CD**
- Converted `release.yml` from CRLF to LF line endings.
- Added defensive carriage-return stripping to AUR package generation to prevent future regressions.

### V0.9.7.4

- Documentation update: supplemented missing changelog entries from the v0.9.7.3 release.

### V0.9.7.3

This release overhauls the **Learned Facts** system, adds full **Web UI parity** for the character creator, and delivers phased **Realism Engine** improvements for more natural character behavior.

**🧠 Learned Facts — Quality Overhaul**
- **RP-aware extraction prompt:** The system now distinguishes between roleplay actions and real user information — no more "walked to the door" or "kissed the character" polluting your fact list.
- **Quality gate filter:** Every extracted fact passes through a multi-pattern validation gate that rejects action verbs, vague generics, narrator voice, JSON artifacts, and encoding garbage before saving.
- **50-fact cap with smart consolidation:** When your fact list grows beyond 50 entries, the LLM merges related facts into denser statements (e.g., "Has a cat" + "Cat's name is Luna" → "Has a cat named Luna") while preserving all specific details.
- **Semantic dedup tightened:** Near-duplicate detection threshold lowered from 0.85 → 0.75, catching more "same fact, different words" entries.
- **Startup garbage cleanup:** Existing fact lists are automatically filtered on every app launch, removing historically accumulated junk entries.
- **GBNF grammar constraint:** Local KoboldCpp models now output guaranteed-valid JSON arrays, eliminating most parse failures.

**🧠 Realism Engine — Phased Recovery**
- **Dynamic recovery phases:** The post-climax recovery prompt now phases through three stages — immediate, settling, and late recovery — based on the ratio of remaining to total recovery turns. Characters with short recovery windows move through phases quickly; characters with longer windows linger naturally.
- **Per-character pacing:** Recovery duration varies from 1–8 turns based on personality traits, and the prompt now reflects exactly where in that window the character is.

**🔄 Unified Periodic Evaluations**
- **Synchronized cadence:** Learned Facts extraction and Character Evolution now fire on the same timer (every 10 user messages), running sequentially instead of on separate, overlapping intervals.
- **Reduced LLM contention:** Both evaluations share one window, preventing back-to-back queued requests on local backends.

**🖥️ Web UI — Character Creator Parity**
- **Manual Creator Wizard:** The web UI's manual character creator is now a full 6-step wizard matching the desktop app — Identity → Personality → Dialogue → Lorebook → Realism Engine → Review & Save.
- **AI Creator Realism Step:** The AI character creator now includes a dedicated Realism Engine configuration step with bond/trust sliders, time-of-day selector, and feature toggles.
- **V2.5 character card extensions:** Both creators embed Realism Engine configuration in exported character cards.

### V0.9.7.2

This release brings **community-contributed fixes and features** alongside Realism Engine tuning — primarily focused on API compatibility, macOS packaging, and UI polish.

**🤝 Community Contributions** — thanks to [@willie](https://github.com/willie)
- **System prompt role fix** ([#12](https://github.com/linux4life1/front-porch-AI/pull/12)): The system prompt is now sent with the proper `"system"` role when using chat-completion APIs (OpenRouter, LM Studio, OpenAI-compatible backends). Previously it was incorrectly sent as a `"user"` turn, which caused some models to behave unexpectedly.
- **LM Studio streaming fix** ([#11](https://github.com/linux4life1/front-porch-AI/pull/11)): Fixed SSE streaming compatibility with LM Studio and added support for the `reasoning_content` field returned by reasoning-capable models.
- **macOS RAG embedding server bundling** ([#10](https://github.com/linux4life1/front-porch-AI/pull/10)): The RAG embedding server (`embed_server`) was not being copied into the macOS app bundle during CI builds. RAG Memory now works out of the box on macOS without requiring a manual source build.
- **Settings tab bar styling** ([#13](https://github.com/linux4life1/front-porch-AI/pull/13)): Fixed a dark overlay appearing behind the settings tab bar and corrected low-contrast text on the selected tab label.
- **BYAF importer cache directory** ([#7](https://github.com/linux4life1/front-porch-AI/pull/7)): Fixed a crash when importing `.byaf` character archives if the image cache directory did not yet exist on first launch.
- **pubspec.yaml version format** ([#8](https://github.com/linux4life1/front-porch-AI/pull/8)): Corrected an invalid semver string in `pubspec.yaml` that caused `flutter pub get` to warn on strict tooling setups.

**🧠 Realism Engine — Evaluation Tuning**
- Expanded the short-term emotional delta ranges so the engine can reflect larger mood and relationship shifts in a single turn when the narrative warrants it.
- Strengthened the justification guidance in evaluation prompts, requiring the model to ground large deltas in concrete story evidence rather than general sentiment.

**⚙️ Stability**
- Hardened the realism evaluation pipeline against race conditions during hot restarts and rapid message sequences.
- Improved KoboldCpp process lifecycle management to prevent orphaned processes on app restart.

### V0.9.7.1

**🧠 Realism Engine — Prompt Overhaul**
- **Personality-aware evaluations:** All eval prompts now receive the character's personality traits, relationship tension, and trust level — eliminating "generic NPC" responses.
- **Emotion vocabulary guidance:** Steered away from flat labels toward nuanced textures filtered through the character's personality.
- **Spatial continuity:** Posture evals now receive the character's current position, preventing teleportation between turns.
- **Dramatic event inertia:** Emotions now linger after high-impact narrative events instead of snapping back to neutral.
- **Trust system rebalanced:** Positive trust range expanded from +10 to +50, with guidance for extraordinary trustworthiness. Catastrophic betrayals are now balanced by the ability to earn trust through genuinely remarkable actions.
- **Fixation injection rewritten:** Fixations manifest as subconscious coloring (stray thoughts, loaded pauses) rather than the character awkwardly raising the topic.
- **Relationship delta reframed:** Changed from "tension shift" (negatively primed) to "warmth shift" (neutral framing) to reduce false negatives.
- **Objective/fixation spam reduced:** 90% of turns should produce "none" for proposed objectives; fixations now require persistent intrusive thoughts, not temporary reactions.

**🎰 Chaos Mode — Timing Rework**
- **Integrated event flow:** Chance Time now triggers before the character's response so they react to both the user's message and the chaos event in a single cohesive reply.
- **Regen persistence:** Chaos events persist through regenerations and swipes; cleared only when the user sends their next message.
- **Stacking prevention:** SPIN NOW button disables (shows ⏳ EVENT PENDING) while an event is queued.

**⚙️ KoboldCpp Stability**
- **Thinking model support:** Injected `ban_eos_token` and `trim_stop` into generation payloads for stable streaming with reasoning models.
- **Server idle detection:** Eval pipeline now calls `/api/extra/abort` and waits for server idle before each request, eliminating dropped requests during heavy generation.
- **One-shot eval fix:** Renumbered eval fields sequentially (1–10) to fix field-ordering confusion in local models.

**🐛 Bug Fixes**
- Fixed "Looking up a deactivated widget's ancestor" errors with a 150ms debounce on eval stream rebuilds.
- Fixed trust being penalized when the character (not the user) does something guilt-inducing.
- Fixed broken one-shot eval field numbering (fields 2 and 6 were skipped).

### V0.9.7

**🎰 Chance Time — Chaos Mode**
- **Spinning wheel overlay** — full animated roulette with emoji-themed segments, smooth easing curves, and a haptic-style bounce on landing.
- **175+ era-agnostic events** across four categories: 🟢 Fortune, 🔴 Misfortune, 💛 Chaos, 💜 Wild Card — plus 35 slapstick events.
- **Escalating pressure** — 5% base chance per turn, growing +5% each turn without a trigger. Caps at 100%. After ~19 turns, Chance Time is guaranteed.
- **No escape** — once the overlay fires there is no X button, no back button, no tapping outside. The only exit is **Accept Your Fate 🎲**.
- **Category-specific reveal animations** — confetti burst (Fortune), red skull pulse (Misfortune), lightning strobe (Chaos), purple shimmer (Wild Card).
- **Manual spin** — SPIN NOW button in the sidebar for on-demand chaos.

**🎨 Chance Time UI**
- Gold-themed narration banners in chat history (🎰 centered card, distinct from normal messages).
- Animated wheel shrinks after landing to reveal the full result card without overflow.
- Pressure bar and percentage visible in both the sidebar and the overlay.

### V0.9.6.6

**⏰ Deterministic Time Progression**
- **Fixed: time never moves / time jumps wildly.** Time now advances on a fixed cadence: every 6 AI turns, the clock moves forward exactly one period.
- **LLM veto only.** The model is asked one binary question: is the scene mid-action right now? Hold or advance.

**💬 OOC Time-Skip Detection**
- Writing `(OOC: we drive for several hours)` instantly moves the narrative clock before the AI responds.
- The next AI response shows `⏩ Time skip: Evening` in the delta row alongside Bond/Trust/Mood chips.

**🕐 Manual Time Nudge**
- `‹` and `›` chevrons flank the `Mon · Day 1` sidebar label when Realism is enabled.

**🐛 Bug Fixes**
- Fixed GUI overflow when a cooldown badge appeared in the Enhancements header.
- Fixed realism baseline never being captured when enabling Realism after loading a character.

### V0.9.6.5

**🧠 Realism Engine 2.1**
- **Emotion Inertia:** Moods carry over between turns — small moments produce small drift, big moments require genuine cause.
- **Trust-Based Behavioral Calibration:** Surfaces more of the character's inner self as trust grows, filtered through their unique persona.
- **Narrative Day-of-Week Tracking:** Scene time reads `Wednesday Evening (Day 3)`. Anchored to the real-world day Realism was first enabled.
- **Post-Greeting Baseline Eval:** Engine evaluates emotion and bond from the opening message before the user types anything.

**🖥️ Realism Processing Overlay — Redesigned**
- Animated pulsing orb, spinning halo, eval pill badges, smooth fade-in. Greeting evals use a purple *"Reading the room..."* mode.

**📊 Sidebar**
- Day-of-week visible (`Sun · Day 1`). Active Fixation promoted above Realism. Smarter section expand defaults.

### V0.9.6.4

**🖥️ Realism Engine Streaming UI**
- Live glassmorphic overlay streams LLM eval tokens in real-time during emotional evaluations.
- Fixation Engine prompt priority lowered — active fixations feel ambient, not overriding.

**✍️ Native Desktop Spell Checking**
- macOS: `NSSpellChecker` via native method channel. Windows: `ISpellChecker` via custom C++ plugin. Fixed a plugin registration crash reported by the community.

### V0.9.6.3

**⚙️ Realism Engine 2.0**
- Long-Term Relationship Scaling, Dynamic Trust Mechanics, Character Level-Up System.
- Collapsible sidebar modules, one-click character duplication, fault-tolerant AI generator with auto-retry.

### V0.9.6.2

**🎭 Realism Engine 1.0**
- Relationship & Tension System with visual tracking bars. Nuanced emotion wheel. Autonomous time progression with temporal guardrails.

### V0.9.6.1

- Context-grounded image prompts generated as the final creator step. Avatar art style selector in Quick Create. Linux CI build fixes.

### V0.9.6

- Local image generation (A1111, Forge, SDNext, Draw Things). Easy Mode Quick Create. World Lore RAG. Settings UI overhaul. Natural Language vs Danbooru Tags prompt mode. Avatar crop tool with canvas padding.

### V0.9.5

- Group chat fork from 1:1 conversations. Database power-failure protection (SQLite FULL sync + integrity check). Automatic rolling backups every 10 minutes.

### V0.9.3

- Platform-agnostic image paths. macOS auto-update fix. Cloud sync upgrade dialog fix. macOS Gatekeeper re-signing fix.

### V0.9.2

- **RAG Memory** — local semantic memory, Data Bank UI, RAG-grounded summaries. Character Evolution. User Persona Awareness. Objectives/Goals. Content toggle. Lorebook world-building focus.

### V0.9.1

- ElevenLabs TTS with configurable voice controls. Inline image rendering with security consent. WebUI mobile UX improvements.

### V0.9.0

- Database hard-delete optimization (334MB → 2MB). Cloud Sync overhaul. Database Reunification migration. Full-featured Web UI. Voice Call Mode. Chat Summary. AI Character Creator. Push-to-Talk (Whisper STT). AGPL-3.0 license.

### V0.8.x

- SQLite database backend (migrated from JSON). Row-level cloud sync merge engine with UUID primary keys. Backup management. Backyard AI (.byaf) importer. Director Mode. Cloud sync via Google Drive and Nextcloud/WebDAV.

### V0.7.x and earlier

- Group chat, TTS multi-engine support (Kokoro/OpenAI/Piper), grid scale slider, bulk PNG import, chat branching, per-character system prompts, Author's Note, context/token budget viewer, external API support (OpenRouter, Nano-GPT).

</details>

---

*Built with 💙 using [Flutter](https://flutter.dev)*
