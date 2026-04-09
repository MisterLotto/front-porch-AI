# Front Porch AI

![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-blue.svg)
![Flutter](https://img.shields.io/badge/Made%20with-Flutter-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)
![Stable](https://img.shields.io/badge/Status-Stable-brightgreen)

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

### ⚙️ KoboldCpp Integration
- Automated download and update of the KoboldCpp backend
- Hardware detection — Vulkan on PC, Metal on Apple Silicon, Intel ARC support
- Model Hub: search and download GGUF models directly from HuggingFace
- Start/Stop KoboldCpp from inside the Character Creator

---

## 🆕 What's New in V0.9.7.1

This is a **stability and quality-of-life** release focused on fixing unnatural AI behavior from the Realism Engine, reworking the Chaos Mode timing, and hardening KoboldCpp integration.

**🧠 Realism Engine — Prompt Overhaul**
- **Personality-aware evaluations:** All eval prompts (emotion, posture, relationship, narrative, one-shot) now receive the character's personality traits, relationship tension, and trust level — eliminating "generic NPC" responses.
- **Emotion vocabulary guidance:** Steered away from flat labels ("happy", "sad") toward nuanced textures ("wistful", "prickly", "flustered") filtered through the character's personality.
- **Spatial continuity:** Posture evals now receive the character's current position; prevents "teleportation" where a character sitting on a couch suddenly appears standing in a doorway.
- **Dramatic event inertia:** Emotions now linger after high-impact narrative events instead of snapping back to neutral the next turn.
- **Trust system rebalanced:** Positive trust range expanded from +10 to +50, with guidance for extraordinary trustworthiness (selfless sacrifice, proving loyalty at personal cost). Catastrophic betrayals are now balanced by the ability to earn trust through genuinely remarkable actions.
- **Fixation injection rewritten:** Fixations manifest as subconscious coloring (stray thoughts, loaded pauses) rather than the character awkwardly bringing up the topic.
- **Relationship delta reframed:** Changed from "tension shift" (negatively primed) to "warmth shift" (neutral framing) to reduce false negatives.
- **Objective/fixation spam reduced:** 90% of turns should produce "none" for proposed objectives; fixations now require persistent intrusive thoughts, not temporary reactions.

**🎰 Chaos Mode — Timing Rework**
- **Integrated event flow:** Chance Time now triggers BEFORE the character's response, not after. The character weaves their reaction to both the user's message AND the chaos event into a single cohesive reply — no more jarring separate reaction messages.
- **Regen persistence:** Chaos events persist through regenerations and swipes; cleared only when the user sends their next message.
- **Stacking prevention:** SPIN NOW button disables (shows ⏳ EVENT PENDING) while an event is queued. Auto-triggers also skip when an event is pending.

**⚙️ KoboldCpp Stability**
- **Thinking model support:** Injected `ban_eos_token` and `trim_stop` into generation payloads for stable streaming with reasoning models.
- **Server idle detection:** Eval pipeline now calls `/api/extra/abort` and waits for server idle before each request, eliminating dropped requests during heavy generation.
- **One-shot eval fix:** Renumbered eval fields sequentially (1–10) — fixes field-ordering confusion in local models caused by skipped numbers.

**🐛 Bug Fixes**
- Fixed "Looking up a deactivated widget's ancestor" errors with a 150ms debounce on eval stream rebuilds.
- Fixed trust being penalized when the CHARACTER (not the user) does something guilt-inducing.
- Fixed broken one-shot eval field numbering (fields 2 and 6 were skipped, confusing local models).

<details>
<summary><strong>📦 Previous Releases</strong></summary>

### V0.9.7

**🎰 Chance Time — Chaos Mode**
- **Spinning wheel overlay** — full animated roulette with emoji-themed segments, smooth easing curves, and a haptic-style bounce on landing.
- **175+ era-agnostic events** across four categories: 🟢 Fortune, 🔴 Misfortune, 💛 Chaos, 💜 Wild Card — plus 35 slapstick events (stink bombs, glitter bombs, pants falling down, chair collapses).
- **🌶️ NSFW toggle** — 30 additional spicy events behind an explicit opt-in switch in the sidebar.
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
- Fixed GUI overflow when the refractory period cooldown badge appeared in the NSFW Enhancements header.
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

- **RAG Memory** — local semantic memory, Data Bank UI, RAG-grounded summaries. Character Evolution. User Persona Awareness. Objectives/Goals. NSFW content toggle. Lorebook world-building focus.

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

## 🤝 Contributing

Pull requests are welcome.

1. Fork the project
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push and open a PR

---

## 🔒 Privacy

Front Porch AI does not collect, store, or transmit any personal data. Full details: [Privacy Policy](https://app.dreamersai.art/privacy.html)

## 📄 License

**v0.9.0+** — [AGPL-3.0](LICENSE)  
**v0.8.x and earlier** — GPL-3.0

---

*Built with 💙 using [Flutter](https://flutter.dev)*
