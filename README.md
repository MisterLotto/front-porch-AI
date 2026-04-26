# Front Porch AI

![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-blue.svg)
![Flutter](https://img.shields.io/badge/Made%20with-Flutter-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)
![Beta](https://img.shields.io/badge/Status-Beta%20Preview-orange)

> [!WARNING]
> **You are on the `beta` branch — v0.9.8-Beta.**  
> This is a public test build. It stores all data in a **completely separate directory** from stable (`FrontPorchAI-Beta/`) so your stable characters, chats, and settings are never touched. That said, expect rough edges and please [report bugs on Discord](https://discord.gg/e4tET6rpdv).  
> The stable branch lives at [linux4life1/front-porch-ai](https://github.com/linux4life1/front-porch-ai/tree/main).

**A privacy-first, fully offline AI companion for Windows, Linux, and macOS.** Chat with AI characters using local LLMs, manage your character library, and keep everything running on your own hardware — no subscriptions, no cloud, no one pulling the rug out from under you.

💬 **[Join the Discord](https://discord.gg/e4tET6rpdv)** — questions, feedback, and hanging out welcome. Also on **[Matrix](https://matrix.dreamersai.art)**.

<p align="center">
  <img src="docs/screenshots/home_new.png" width="800" alt="Front Porch AI — Character Library">
</p>

---

## ✨ Features

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
- **Character Objectives** — autonomous goals the character pursues independently based on story events
- **Fixation Engine** — active emotional obsessions that subtly color every response
- **Character Evolution** — characters organically develop new traits as your story progresses
- **RAG Memory** — local semantic memory powered by a lightweight ONNX embedding engine; the AI recalls past conversations without any cloud

### 🎭 Character Management
- **V2 spec support** — fully compatible with the V2 character card specification (PNG & JSON)
- **One-click import** from `aicharactercards.com` and `chub.ai` via a built-in browser
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
- **Director Mode** — manually choose who speaks next
- **Fork any 1:1 chat** into a group, preserving full message history

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

### ☁️ Cloud Sync
- Sync your entire database and character PNGs via **Google Drive** or **Nextcloud/WebDAV**
- Row-level merge engine with UUID primary keys — no ID collisions across devices
- Automatic backups before every sync, one-click restore
- **Privacy-first**: syncs only to accounts you own, no data touches our servers

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

## 🆚 How Does Front Porch AI Compare?

If you're evaluating local AI tools, here's an honest breakdown. Every project on this list is doing something right — the goal isn't to trash competitors, it's to help you pick the right tool for *you*.

| Feature | **Front Porch AI** | SillyTavern | Jan.ai | Backyard AI |
|---|---|---|---|---|
| **Native desktop app** | ✅ Flutter (Win/Mac/Linux) | ❌ Web-based (local server) | ✅ Electron | ✅ (abandoned) |
| **Fully offline — no cloud required** | ✅ | ✅ | ✅ | ✅ |
| **Built-in TTS (50+ voices)** | ✅ Kokoro + Piper + ElevenLabs + OpenAI | ⚙️ Extension required | ❌ | ❌ |
| **Speech-to-text (push-to-talk)** | ✅ Whisper, built-in | ⚙️ Extension required | ❌ | ❌ |
| **Local image generation** | ✅ A1111, Forge, Draw Things | ⚙️ Extension required | ❌ | ❌ |
| **Realism Engine** | ✅ Time, trust, emotion, chaos, objectives | ❌ | ❌ | ❌ |
| **Character Expressions** | ✅ ONNX + LLM, live avatar swap | ✅ (manual setup) | ❌ | ❌ |
| **RAG memory (local)** | ✅ ONNX embeddings, no cloud | ⚙️ Extension required | ❌ | ❌ |
| **Novel / story generator** | ✅ Porch Stories pipeline | ❌ | ❌ | ❌ |
| **Cloud sync** | ✅ Google Drive / WebDAV | ❌ | ❌ | ☁️ Proprietary |
| **Character card compatibility** | ✅ V2 spec + Backyard .byaf | ✅ V2 spec | ❌ | Proprietary |
| **Group chat** | ✅ | ✅ | ❌ | ❌ |
| **Extension / plugin ecosystem** | 🌱 Growing | ⭐ Very large | Moderate | ❌ |
| **Open source license** | ✅ AGPL-3.0 | ✅ AGPL-3.0 | ✅ MIT | ❌ |
| **Best for** | Polished AI companion + storytelling | Power users / heavy customization | Simple local chat | — |

> SillyTavern's extension ecosystem is genuinely impressive and unmatched for customization depth. If you want maximum flexibility and don't mind configuration work, it's excellent. Front Porch AI prioritises **everything working out of the box** for users who want to chat, not configure.

---

## 📥 Install

### Linux — Package Manager

**Debian / Ubuntu / Mint / Pop!_OS**
```bash
curl -fsSL https://apt.dreamersai.art/install.sh | bash
sudo apt install front-porch-ai
```
Or manually:
```bash
curl -fsSL https://apt.dreamersai.art/front-porch-ai.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/front-porch-ai.gpg
echo "deb [signed-by=/etc/apt/keyrings/front-porch-ai.gpg] https://apt.dreamersai.art stable main" | sudo tee /etc/apt/sources.list.d/front-porch-ai.list
sudo apt update && sudo apt install front-porch-ai
```

**Fedora / RHEL / openSUSE**
```bash
sudo dnf config-manager --add-repo https://rpm.dreamersai.art/front-porch-ai.repo
sudo dnf install front-porch-ai
```

**Arch Linux (AUR)**
```bash
yay -S front-porch-ai-bin        # Stable
yay -S front-porch-ai-beta-bin   # Beta / Pre-release
```

Future updates arrive through your normal system updates (`apt upgrade`, `dnf upgrade`, `yay -Syu`).

### All Platforms — Manual Download

Head to the **[Releases](https://github.com/linux4life1/front-porch-ai/releases)** page:

- **Stable**: `.exe` installer (Windows), `.dmg` (macOS), `.AppImage` / `.deb` / `.rpm` (Linux)
- **Beta**: Standalone `.zip` (Windows/macOS), `.AppImage` / `.tar.gz` (Linux) — no installer, just extract and run

---

## 🆕 What's New in V0.9.8-Beta

This beta introduces **Character Expressions** — the biggest single feature addition in the app's history — alongside significant under-the-hood improvements to GPU performance, beta/stable isolation, and hardware compatibility.

**🎭 Character Expressions — Live Emotion Portraits**

Your characters now *look* the way they feel. As the conversation evolves, their portrait automatically swaps to match their current emotional state.

- **Dual classification engine:** Toggle between a **fast ONNX path** (distilbert, offline, ~300 ms per turn) and the **LLM path** (Realism Engine, highest contextual accuracy). Both work entirely on-device.
- **In-app model download:** Hit the download button in Settings → Expression Images. A glassmorphic teal overlay tracks file-by-file download progress — no command line, no manual file hunting.
- **SillyTavern-compatible expression packs:** Drop in any expression folder from ST and it works. 26 emotion categories supported.
- **Flexible display:** Sidebar portrait mode for focused chats, fullscreen overlay mode for cinematic immersion.
- **Smart fallback chain:** `detected emotion → closest available image → neutral`. The classifier never crashes the chat if an image is missing.

**⚡ KoboldCpp Performance — Six Bugs Fixed**

When you run KoboldCpp through Front Porch, it now launches with the same optimised flags KoboldCpp's own Quick Launch GUI uses — flags we were silently omitting before:

- **Flash Attention enabled by default** for CUDA and Metal backends — roughly **20–40% faster generation** on RTX 30/40/50-series and Apple Silicon, with zero quality loss. Previously this was only applied when KV quantization was also on.
- **Context Shift enabled by default** — when your chat exceeds the context window, the app now gracefully evicts old KV cache instead of hard-truncating the conversation. Matches KoboldCpp standalone behaviour.
- **Explicit GPU ID** — `--usecublas` now always passes the configured GPU index. On systems with both a discrete RTX and an integrated GPU, the old code could silently load the entire model onto the iGPU at 0.5 t/s.
- **mlock enabled by default** (Windows/macOS) — prevents the OS from paging model weights to disk under memory pressure, avoiding catastrophic mid-session slowdowns.
- **Advanced Launch Options panel** — a new collapsible card in Settings → Hardware & GPU exposes Flash Attention, Context Shift, mlock, GPU ID (0/1/2/3 chips), and Prefill Batch Size (256/512/1K/2K). Changes take effect via the **Restart Backend** button built into the panel.
- **RTX 50-series (Blackwell) GPU detection fixed** — `nvidia-smi` is now the authoritative source for GPU name and VRAM on new Blackwell architectures, bypassing the Windows registry and WMI paths that return empty or uint32-overflowed data for the 596.x driver series.

**🔒 Beta / Stable Isolation**

The beta build is genuinely self-contained:

- All data lives in `~/Documents/FrontPorchAI-Beta/` — your stable characters, chats, and database are never touched.
- Every preference key is namespaced with a `beta_` prefix — API keys, TTS config, backend settings — no cross-contamination.
- On first launch, the beta **optionally copies your stable database** so you have your characters to test with immediately.
- Stable builds explicitly refuse to offer a beta update (and vice versa), enforced at both the update-check and version-comparison layers.

**🐛 Bug Fixes (from v0.9.7.5)**
- Fixed character creator crash on Linux (back button popping the root navigator).
- Fixed V2.5 metadata loss when changing a character's avatar.
- Fixed Realism Engine level 10 prompt causing behavioural leakage into subsequent turns.

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
- **Matrix**: [matrix.dreamersai.art](https://matrix.dreamersai.art)

---

## 🤝 Contributing

Pull requests are welcome! If you're a dev reading this far down, here's what you need to know:

- **Branch workflow:** All PRs target the **`dev`** branch — never `main`. The `main` branch is for stable releases only.
- **Commit conventions:** Follow the guidelines in [AGENTS.md](AGENTS.md) for commit message format, code style, and naming conventions.
- **Full guide:** See [CONTRIBUTING.md](CONTRIBUTING.md) for build instructions, testing requirements, and the PR template.
- **Before you PR:** Run `flutter analyze` and `flutter test` locally. CI will check these too, but saving a round-trip is nicer for everyone.

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

Front Porch AI does not collect, store, or transmit any personal data. Full details: [Privacy Policy](https://app.dreamersai.art/privacy.html)

## 📄 License

**v0.9.0+** — [AGPL-3.0](LICENSE)  
**v0.8.x and earlier** — GPL-3.0

---

## 🛠️ Build from Source

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- [Rust toolchain](https://rustup.rs/) (for the RAG embedding server)
- Git
- Windows, Linux, or macOS

### Linux Extra Dependencies

**Ubuntu/Debian**
```bash
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libwpewebkit-1.0-dev
```

**Arch Linux**
```bash
sudo pacman -S clang cmake ninja pkgconf gtk3 xz wpewebkit
```

**Fedora**
```bash
sudo dnf install clang cmake ninja-build pkgconf-pkg-config gtk3-devel xz-devel libstdc++-devel wpewebkit-devel
```

> `wpewebkit` is required for the built-in browser (Chub.ai / aicharactercards.com import). Pre-built AppImages bundle it automatically.

### Build & Run

```bash
git clone https://github.com/linux4life1/front-porch-ai.git
cd front-porch-ai
flutter pub get
flutter run
```

**macOS release build** (includes RAG embedding server):
```bash
./scripts/build-macos.sh
```

**Linux / Windows release build:**
```bash
cargo build --release --manifest-path tools/embed_server/Cargo.toml
flutter build linux    # or windows
```
> On Linux/Windows, copy `tools/embed_server/target/release/embed_server` next to the built executable under `embed_server/embed_server`.

---

<details>
<summary><strong>📦 Old Release Notes</strong></summary>

### V0.9.7.5

This release delivers a **complete character editor redesign**, brings **editable Realism Engine settings** to the card editor, and fixes several stability and data integrity bugs.

*(Full notes now in the What's New section above for beta context.)*

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
