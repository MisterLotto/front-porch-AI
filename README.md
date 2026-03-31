# Front Porch AI

![License: AGPL v3](https://img.shields.io/badge/License-AGPLv3-blue.svg)
![Flutter](https://img.shields.io/badge/Made%20with-Flutter-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)
![Stable](https://img.shields.io/badge/Status-Stable-brightgreen)

## 📝 Note from the Dev

To the growing community of users who have shown up with kind words, encouragement, and genuine enthusiasm — you've turned what started as a passion project into something worth building every day. Your bug reports, feature ideas, and willingness to test rough edges have made Front Porch AI better in ways no single developer could. Thank you for believing in what this project can become.

— **SosukeAizen** on Discord

## 💬 Join the Community

Have questions, feedback, or just want to hang out? Connect with us:

- **Discord**: [Join our server](https://discord.gg/e4tET6rpdv)
- **Matrix**: [matrix.dreamersai.art](https://matrix.dreamersai.art)

## 🚀 Getting Started

### 📦 For Regular Users

#### 🐧 Linux — Install via Package Manager

**Debian / Ubuntu / Mint / Pop!_OS (APT)**
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

**Fedora / RHEL / openSUSE (DNF)**
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

#### 📥 Manual Downloads (All Platforms)

Head over to the **[Releases](https://github.com/linux4life1/front-porch-ai/releases)** page:

- **Stable releases**: `.exe` installer (Windows), `.dmg` (macOS), `.AppImage` / `.deb` / `.rpm` (Linux)
- **Beta releases**: Standalone `.zip` (Windows/macOS), `.AppImage` / `.tar.gz` (Linux) — no installer required, just extract and run

---

### 🛠️ For Developers & Tinkerers
If you want to modify the code or build from source, follow these steps:

#### Prerequisites
- **Flutter Environment**: You must have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed and configured on your system.
- **Git**: To clone the repository.
- **OS**: Windows, Linux, or macOS.

#### 🐧 Linux Dependencies

If you are on Linux, you'll need a few extra packages to compile the desktop embedding:

**Ubuntu/Debian**:
```bash
sudo apt-get update
sudo apt-get install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev libwpewebkit-1.0-dev
```

**Arch Linux**:
```bash
sudo pacman -S clang cmake ninja pkgconf gtk3 xz wpewebkit
```

**Fedora**:
```bash
sudo dnf install clang cmake ninja-build pkgconf-pkg-config gtk3-devel xz-devel libstdc++-devel wpewebkit-devel
```

> **Note:** `wpewebkit` is required for the built-in browser that allows you to download character cards directly from Chub.ai and AI Character Cards. If you're building from source, you must install this dependency. Pre-built AppImages bundle this library automatically.

#### Installation
1.  **Clone the Repository**:
    ```bash
    git clone https://github.com/linux4life1/front-porch-ai.git
    cd front-porch-ai
    ```

2.  **Install Dependencies**:
    ```bash
    flutter pub get
    ```

3.  **Run the App**:
    ```bash
    flutter run
    ```

### Building for Release
To create a standalone executable:
```bash
flutter build windows
```
The output will be in `build/windows/runner/Release/`.

## 🔓 Why Open Source?

Proprietary software lives and dies at the discretion of its creators. When a company moves on, shuts down, or simply loses interest, the tools you depend on become frozen in time — no updates, no fixes, no future.

Starting with **v0.9.0**, Front Porch AI is licensed under the **GNU Affero General Public License v3 (AGPL-3.0)**. With the addition of a full-featured web UI, the app can now be accessed over a network — and the AGPL ensures that anyone who hosts a modified version as a service must share their changes with their users. This keeps the project truly open, even in a world of cloud-hosted forks.

> **Note:** Versions **0.8.x and earlier** remain licensed under **GPLv3**. The license change applies only to v0.9.0 and all future releases.


## 🆕 What's New in V0.9.6

This release significantly expands Front Porch AI's visual capabilities, natively integrating your favorite local image generation backends, and vastly streamlining the AI Character Creator pipeline.

**🖼️ Local Image Generation Workflows (Beta)**
*   **Full Backend Support:** Natively connect to **A1111**, **Forge**, **SDNext**, and **Draw Things** instances on your local network.
*   **Live Model Switching (A1111/Forge):** Select and load different Checkpoint models directly from the Front Porch UI drop-downs. No need to tab over to your backend console!
*   **Dedicated Unload Controls (A1111/Forge):** Added manual buttons to explicitly force-unload models inside A1111 and Forge. When switching local models mid-generation, Front Porch will now safely swap them via API without needing backend restarts.
*   **LoRA Injection (A1111/Forge/SDNext):** Added a dedicated LoRA dropdown to dynamically inject character concepts or art styles alongside a weight slider directly from the chat UI.

**🧠 AI Character Creator Upgrades**
*   **"Easy Mode" Quick Create:** Brand new to the Character Creator! Just type a character's Name and an optional `Concept` sentence ("A gruff dwarven blacksmith who writes poetry") and the AI will fully invent and flesh out an entire lore-accurate Tavern card for you. No more endless form fields!
*   **World Lore Extraction (RAG-Lite):** You can now paste Wiki URLs (like Fandom or wikia pages) or upload local `.txt` / `.pdf` lore documents directly into both the Quick and Guided generators! The system will read, summarize, and inject this world-building context directly into the character's creation prompt so they fit flawlessly into their fictional universe.
*   **Pipeline Optimization:** We removed the overarching `system_prompt` from the LLM's character generation instructions. This saves massive context token overhead while generating the character's core traits. The desired system prompt is now cleanly appended at the very end when the Tavern card is finalized.

**⚙️ Settings UI Overhaul**
*   **Menu Splitting:** The massive, monolithic Settings screen has been completely overhauled and split into dedicated, categorized pages! It is now vastly easier to configure your backend, image generator, and text-to-speech settings without endless scrolling.

**🗣️ The Prompt Paradigm Engine**
*   **Model Agnostic Prompts:** You can now flip a toggle in Image Settings between **Natural Language** and **Danbooru Tags**.
*   Running a modern FLUX or SD3 model? Use Natural Language so the LLM writes rich, cohesive prose.
*   Running a classic SD 1.5 or Illustrious anime model? Switch to Tags, and the LLM will mathematically output flat, comma-separated Danbooru tags. 
*   **Deep Integration:** This setting applies to *both* in-chat selfie requests and the internal appearance generation inside the Character Creator.

**✂️ Upgraded Avatar Cropping**
*   AI-generated Character portraits now automatically invoke our custom Crop Tool before saving.
*   **"Zoom Out" Padding:** Generated an amazing portrait but it's framed too tightly? We've added a brand-new **Zoom Out (Pad Canvas)** button. This expands the image's canvas with your background color, allowing you to perfectly shrink close-ups to fit into the required 2:3 character card aspect ratio!

**🐛 Bug Fixes & Maintenance**
*   **The "Grey Box" Fix:** Overhauled how character avatars are loaded. Avatars remain cross-platform portable without breaking or corrupting into grey boxes during active chat sessions!
*   Cleaned up blank state messages inside the Review step of the Character Creator.

<details>
<summary><strong>📦 Previous Releases</strong></summary>

### What's New in V0.9.5

- 👥 **Group Chat Enhancements**: Fork any 1:1 conversation into a group chat, preserving full message history. Add or remove characters mid-conversation without losing context. Character Evolution now works per-character within groups.
- 🛡️ **Database Power-Failure Protection**: SQLite now runs with `PRAGMA synchronous = FULL` and performs an integrity check (`PRAGMA quick_check`) on every startup. If corruption is detected, a recovery overlay offers one-tap restore from any available backup.
- 💾 **Automatic Local Backups**: Rolling backups are created every 10 minutes (always on). Up to 10 backups are retained (~1.5 hours of coverage), with older backups pruned automatically.
- ✍️ **Author's Note in Group Chat**: The Author's Note panel is now available in the group chat sidebar, so you can steer the story while chatting as your persona — no need to switch to Director Mode.
- 🌐 **WebUI Group Chat Management**: Fork-to-group, add/remove group members, and tappable sender names for quick character identification — all available in the WebUI.
- 🐛 **Bug Fixes**:
  - Fixed GPU layers being silently overridden when manually configured
  - Allow localhost API connections without requiring an API key
  - Removed outdated "pre-alpha" warning from group chat creation dialog

### What's New in V0.9.3

- ☁️ **Platform-Agnostic Image Paths**: Character avatar paths are now stored as filenames only in the database, resolved to full paths at runtime. Syncing between Linux, macOS, and Windows no longer causes missing avatars or orphaned PNG cleanup.
- 🍎 **macOS Auto-Update Fix**: Fixed DMG mounting and volume detection that caused self-update to silently fail. The update dialog now shows clear error messages if something goes wrong.
- 🔄 **Cloud Sync Upgrade Dialog Fix**: Fixed the "database upgrade required" dialog reappearing on every launch after cloud sync by persisting the upload state across app restarts.
- 🧙 **Character Creator Save Path Fix**: The AI character creator was saving avatar PNGs to the wrong directory (`{root}/characters/` instead of `{root}/KoboldManager/Characters/`), causing them to be invisible to cloud sync and missing on other platforms.
- 🍎 **macOS Gatekeeper Fix**: Re-sign the macOS app bundle after ML engine bundling to prevent the "app is damaged" error from Gatekeeper.
- 🏷️ **Version String Fix**: Four-part version numbers (e.g. `0.9.2.1`) now display correctly instead of being truncated to three parts.


### What's New in V0.9.2

- 🧠 **RAG Memory — The AI Remembers**: Local semantic memory powered by a lightweight ONNX embedding engine. Past conversations are automatically indexed and retrieved when relevant — the AI recalls what happened 50 messages ago, in a different session, or even with a different character. Runs entirely on your CPU, no cloud needed, ~25MB footprint.
  - **Data Bank**: Browse, search, and manage your stored memories with a unified UI showing embedding stats and per-character memory.
  - **RAG-Grounded Summaries**: Rolling chat summaries now pull from the vector store for more accurate, context-aware recaps instead of relying solely on recent messages.
  - **WebUI RAG Menu**: Full RAG configuration (retrieval count, window size, toggle) available directly in the WebUI hamburger menu.
- 🧬 **Character Evolution**: Characters grow through conversation. The Evolve system discovers new traits, relationships, and situation changes — and the AI sees both the original character card and how they've developed, so growth feels natural without losing who the character is.
- 👤 **User Persona Awareness**: Your self-description and facts the AI has learned about you are now woven into every conversation. The AI knows your name, your preferences, and your history — across all characters.
- 🎯 **Objectives / Goals**: Set session-level objectives that steer the AI toward a narrative outcome. Goals persist across messages and subtly shape conversation direction without manual prompt engineering.
- 🔞 **NSFW Content Toggle**: Global on/off switch for NSFW content filtering, with per-character override for granular control.
- 📱 **WebUI Mobile Improvements**:
  - Fixed chat input bar clipped off the bottom in Safari
  - Added back buttons to all Settings sub-sections on mobile
  - Compact modals and responsive layout fixes for small screens
- 🎵 **Greeting Tones in Guided Creator**: The guided character creator now supports greeting tone selection (Romantic, Adventure, Comedy, etc.) — matching the automated creator.
- 🍎 **Intel Mac Detection**: Automatically detects Intel-based Macs and disables KoboldCpp with a warning banner guiding users to Remote API mode.
- 📖 **Lorebook World-Building Focus**: Lorebook generation now produces world lore (locations, factions, magic systems, cultures, creatures) instead of character biography. Expanded categories include Flora/Fauna and History/Events.
- 🐛 **Bug Fixes**:
  - Fixed ElevenLabs voice selection showing raw voice ID instead of friendly name
  - Fixed TTS narration filter not handling multi-line `*action*` blocks
  - Fixed TTS quote filter not matching curly quotes


### What's New in V0.9.1

- 🔊 **ElevenLabs TTS Engine**: Premium cloud TTS with configurable Stability, Similarity, and Style sliders. Supports Flash v2.5 (~75ms latency), Multilingual v2 (29 languages), and v3 (best quality). Available in both the desktop app and WebUI Settings page.
  - **Narration Filters**: SillyTavern-style filters — narrate quoted dialogue only, or ignore asterisked actions. Configurable per-character.
  - **Graceful Error Handling**: Friendly error messages for ElevenLabs quota exhaustion and authentication failures.
- 🖼️ **Inline Image Viewing**: Chat messages containing `![alt](url)` markdown now render images inline in both the Flutter app and WebUI.
  - **Security Consent Dialog**: Warns about IP exposure and potential risks before loading external images. Consent is saved per-character.
  - **Server-Side Proxy**: Images are served through the server's image cache proxy — the WebUI browser never contacts external servers directly.
  - **Shared Cache**: Flutter app and WebUI share the same image cache directory, so images cached by either are immediately available to both. Already-cached images skip the consent dialog automatically.
- 🌐 **WebUI Mobile UX**: Compact character cards, message count badges, overflow menu, and model switcher for a responsive mobile experience.
- ✍️ **Guided Creator Enhancement**: Increased word count targets in the guided character creator for richer, more detailed character field expansions.
- 🎛️ **KoboldCpp Auto-Start Toggle**: New setting to enable/disable automatic model loading on app start, for users with memory constraints.
- 🏗️ **Infrastructure**:
  - Added AGPL-3.0-or-later copyright headers to all source files
  - Fixed 90 dart analyzer warnings (deprecated APIs, unused imports)
- 🐛 **Bug Fixes**:
  - Fixed WebUI avatar face cropping — character cards, chat appbar, and message avatars now anchor to the top of the image
  - Fixed `{{char}}` showing literally in WebUI character card descriptions, chat appbar subtitle, and right panel
  - Fixed banned phrases text field losing focus after every keystroke in WebUI settings
  - Added `<START>` to default stop sequences to prevent models from outputting it at the end of responses
  - Fixed ElevenLabs TTS sending split sentences instead of full text, causing fragmented audio
  - Fixed ElevenLabs hitting 429 rate limit errors by capping concurrency at 3
  - Switched ElevenLabs to MP3 output format to fix audio playback issues with WAV concatenation

### What's New in V0.9.0

- 💾 **Database Optimization**: Converted all delete operations from soft-delete to hard-delete, eliminating massive DB bloat from accumulated "ghost" rows. Existing bloat is automatically purged on upgrade (e.g. 334MB → 2MB).
- ☁️ **Cloud Sync Overhaul**:
  - Cloud sync now waits for database reunification to complete before starting, preventing concurrent access issues
  - Fresh upload after 0.9.0 upgrade bypass prevents version mismatch errors
  - Google Drive folder ID cache is cleared after data purge to prevent stale references
  - Safe download pattern: files download to a temp file first, then rename on success — interrupted syncs no longer corrupt existing local files
- 🔄 **Database Reunification**: Automatic one-time migration that merges beta database data into the stable database on first launch. Progress is shown via a step-by-step overlay.
- 🎛️ **Context Size Slider in Character Creator**: New power-of-2 slider (2K → 128K) on the chargen Setup page lets you set the context window before starting KoboldCpp. Available in both the Flutter app and WebUI.
- ▶️ **Start/Stop KoboldCpp from Character Creator**: Start and stop KoboldCpp directly from the chargen Setup step — no need to switch to Settings. The button shows real-time status (green/red dot) and a loading spinner during model load. Works in both Flutter and WebUI.
- 🔧 **Auto-Configure Fix**: The auto-configure button now respects your chosen context size instead of overwriting it. It adjusts GPU layer offloading to fit the context you want, rather than dictating the context size.
- 🌐 **WebUI Character Creator Parity**: The WebUI chargen Setup page now matches the Flutter app — backend toggle (KoboldCpp / API), local model list with file sizes, context slider, Start/Stop buttons with status polling, and Rescan.
- 🔄 **Truncation Recovery**: Character generation now detects incomplete JSON output and retries missing fields (personality, scenario, system prompt, example dialogue) with focused prompts.
- 📖 **Separate Lorebook Generation**: If the lorebook is missing from the initial generation (due to output truncation), it's now generated in a separate pass so world-building data isn't lost.
- 📚 **Lorebook Sidebar in WebUI**: The chat sidebar in the WebUI now displays lorebook entries with red/green dots indicating active/inactive trigger status — matching the Flutter app.
- 💬 **Greeting Quality Improvements**: Restructured greeting prompts to prioritize character details and narrative flow (scene → character → context → encounter). Added CONTEXT step for self-contained greetings.
- 🐧 **Linux Desktop Fixes**:
  - Fixed `.desktop` file `Exec=` / `Icon=` mismatch with actual binary name
  - Added proper Linux app icon (was missing/empty)
  - Fixed `FlutterEngineRemoveView` segfault on app close
  - Added SIGINT/SIGTERM signal handlers to prevent segfault on terminal exit
  - Linux package repos: APT (Debian/Ubuntu), RPM (Fedora/RHEL), AUR (Arch) — auto-published via CI/CD
- 💾 **Character Data Loss Fix**: Fixed character description fields being wiped after crash-on-shutdown, particularly for characters stored in folders.
- 🗑️ **Removed Local SD**: Cleaned out the local Stable Diffusion image generation feature (remote API image gen remains fully functional).
- 🌍 **World Editor**: Full lorebook entry management UI for creating and editing world info.
- 🚫 **Banned Phrases**: Context shift support, tokenizer integration, and banned token phrases for controlling model output.
- 🔌 **New Backend API Endpoints**: `/api/backend/status`, `/api/backend/local-models`, `/api/backend/start`, `/api/backend/stop` — enabling full KoboldCpp management from the WebUI.
- 🐛 **Bug Fixes**:
  - Fixed KoboldCpp chargen name/description generators hitting premature stop sequences (`` ``` ``)
  - Fixed chargen using the wrong backend (API instead of KoboldCpp) when KoboldCpp was selected
  - Fixed first message formatting — actions now use `*asterisks*`, dialogue uses `"quotation marks"`
  - Fixed AI-generated image prompts containing character names instead of clean visual tags
  - Fixed truncated first messages not being detected or completed by editor passes
  - Fixed avatar prompt generator outputting story-like descriptions instead of comma-separated visual tags
  - Fixed banned_tokens sent as delimited string instead of JSON array
  - Fixed cloud sync hanging on large database uploads (caused by 300MB+ of soft-deleted data)
  - Fixed database reunification re-triggering on every app launch
- 🧙 **AI Character Creator**: Generate complete, ready-to-chat character cards from just a name and a concept. The AI builds a full V2-spec card — personality, backstory, dialogue examples, system prompt, and optional avatar — all in one flow.
  - **Multi-Step Wizard**: Streamlined 4-step process — Setup (backend & model) → Configure (character details) → Generate → Review & Edit.
  - **Dual Backend Support**: Works with both remote API (OpenRouter, Nano-GPT) and local KoboldCpp models.
  - **KoboldCpp Model Manager**: Scan, select, and hot-reload local `.gguf` models directly from the creator with real-time status indicators.
  - **AI Avatar Generation**: Automatic portrait generation via API, or a copyable image prompt for local Stable Diffusion when using KoboldCpp.
  - **Editor Passes**: Optional AI post-processing — Anti-Puppet (removes {{user}} puppeting), Consistency Check, Quality Polish, and Truncation Completion.
  - **Alternate Greetings**: Generate up to 5 unique first messages with configurable tone, length, and art style.
  - **Lorebook Auto-Generation**: Optionally generate world-building lorebook entries alongside the character.
  - **Persona-Aware**: Select a {{user}} persona to tailor greetings, or leave blank for public cards.
- 🌐 **Full-Featured Web UI**: Access Front Porch AI from any device on your local network. A complete browser-based interface served directly from the desktop app — no separate server needed.
- 🎨 **AI Image Generation**: Generate images directly from your chat using your existing API provider.
- 📞 **Voice Call Mode**: Hands-free voice conversation with any character using Whisper STT + TTS.
- 🎙️ **Push-to-Talk (Whisper STT)**: Hold-to-record voice input powered by Faster Whisper.
- 📖 **Chat Summary**: Automatic rolling summary injected into context for long conversations.
- 📱 **Device Identification**: Connected web clients identified by browser and OS.
- 🎛️ **Extended Max Output Tokens**: Increased from 2,048 to 16,384 for thinking models.
- 🛡️ **Pre-Release Safety**: Beta builds use a separate database to prevent schema conflicts.
- 📄 **License Change**: Switched from GPLv3 to **AGPL-3.0** for v0.9.0+.

### What's New in V0.8.1

- 🐛 **Bug Fixes**:
  - Fixed custom installation directory breaking the 0.8.0 database — the DB, character PNGs, and all data files now correctly follow the user-configured install path
  - Changing install directory in Settings now properly relocates all data (database, characters, chats, worlds, models) to the new location and cleans up the old directory
  - Fixed data migration from 0.7.2 JSON format failing when a custom install directory was set — character and folder migrations now respect the custom path
  - Legacy JSON files from pre-0.8.0 (chat sessions, group chats, worlds, folder config) are now automatically cleaned up after migration

### What's New in V0.8.0

- 🔄 **Row-Level Merge Engine**: Cloud sync now performs intelligent per-row merging instead of whole-database replacement. Conflicts are resolved using `updatedAt` timestamps, preserving the most recent changes from either device.
- 🆔 **UUID Primary Keys**: All tables (Characters, Folders, Messages, Sessions, Worlds) now use UUID primary keys instead of auto-increment integers. This eliminates ID collisions when merging data from multiple devices.
- 💾 **Backup Management**: Full backup system with manual and automatic backups before each cloud sync. Restore any backup with one click, or delete individual backups you no longer need. Up to 5 recent backups are kept automatically.
- ☁️ **Dedicated Cloud Sync Page**: Cloud sync settings have been moved from the Settings page to their own dedicated sidebar page for easier access. Includes sync controls, provider configuration, cloud character browser, and backup management.
- 🔼 **Force Upload Database**: New disaster recovery option to overwrite the cloud database with your local copy — useful after restoring a backup.
- 🗑️ **Purge Cloud Data**: Nuclear option to wipe all cloud data (database + character PNGs) when recovery isn't possible. Local data is never affected.
- 🛡️ **Smarter Initial Sync**: First sync after migration now uploads local data as source of truth instead of merging, preventing duplicate entries caused by independent UUID migrations on different devices.
- 🐛 **Bug Fixes**:
  - Fixed KoboldCPP child processes not being killed on app close (Linux) — orphaned processes no longer consume GPU memory after exit
  - Fixed Google Drive cloud sync failing to upload character PNGs due to stale folder ID cache — all characters now sync reliably
  - Individual character upload failures no longer abort the entire sync batch
  - Orphaned character PNGs (from deleted characters or DB sync) are now automatically cleaned up after cloud sync
  - Re-importing a character no longer creates duplicate PNG files on disk


### What's New in V0.8.0-beta4

- 🔄 **Row-Level Merge Engine**: Cloud sync now performs intelligent per-row merging instead of whole-database replacement.
- 🆔 **UUID Primary Keys**: All tables now use UUID primary keys to eliminate ID collisions.
- 💾 **Backup Management**: Full backup system with manual and automatic backups before each cloud sync.
- ☁️ **Dedicated Cloud Sync Page**: Cloud sync settings moved to a dedicated sidebar page.
- 🔼 **Force Upload Database**: Disaster recovery option to overwrite cloud database with local copy.
- 🗑️ **Purge Cloud Data**: Nuclear option to wipe all cloud data when recovery isn't possible.
- 🛡️ **Smarter Initial Sync**: First sync after migration uploads local data as source of truth.

### What's New in V0.8.0-beta3

- 📦 **Backyard AI (.byaf) Importer**: Import characters directly from Backyard AI archive files. Full preview dialog shows persona, lore items, first message, and avatar before import. Optionally import chat history. Automatically converts `{user}` / `{character}` placeholders to V2 spec `{{user}}` / `{{char}}`.
- 📡 **Model Loading Status Bar**: Real-time status bar at the bottom of the home screen shows what KoboldCPP is doing while loading a model (loading, mapping to memory, warming up). A snackbar notification appears when the model is ready to chat.
- 🖱️ **Right-Click Context Menu**: Character card actions (edit, chat, delete, move to folder) are now accessed via a right-click context menu for a cleaner card layout.
- ☁️ **Cloud Sync Reliability**: Rewrote the database sync strategy (close → download → reopen) for better cross-platform reliability. Fixed data loss during path rebasing and improved empty-DB download priority.
- ⏱️ **Buffer Duration Setting**: New slider in Chat Settings to control how many seconds of tokens to buffer before the display starts draining (1–10s). Higher values give smoother output; lower values reduce the initial delay.
- 🛑 **Smarter Stop Sequences**: Added `</END>`, `[END]`, and `<|end|>` as essential stop sequences. Existing users receive them automatically via migration — no manual setup needed.
- 🐛 **Bug Fixes**:
  - Fixed stop generation not always halting the backend
  - Fixed model picker in chat view not updating correctly
  - Fixed session upsert causing duplicate entries
  - Fixed cross-platform character loading after cloud sync
  - Character creation now properly imports into the SQL database
  - Fixed `{{user}}` resolving to "User" instead of the active persona name in the sidebar

### What's New in V0.8.0-beta2

- 🗄️ **SQLite Database Backend**: All data storage has been migrated from scattered JSON files to a fast, reliable SQLite database powered by **Drift ORM**. Characters, chat sessions, messages, groups, folders, personas, and worlds — all in one `front_porch.db` file.
- 📊 **Migration Progress Dialog**: First-time launch after the update shows a polished full-screen overlay with step names, progress bar, and step counter while your existing JSON data is imported into the database.
- ☁️ **Simplified Cloud Sync**: Cloud sync now uploads/downloads a single `.db` file instead of hundreds of individual JSON files. Faster, more reliable, and no more out-of-sync data.
- 🧹 **Cleaner Codebase**: Removed ~200 lines of orphan cleanup, per-file JSON sync, and dual-write code. The database is now the single source of truth.


### What's New in V0.8.0-beta

- ☁️ **Cloud Sync (Alpha)**: Sync your characters, chat sessions, folder layouts, and user personas across devices. An alpha-stage warning now appears when enabling the feature.
  - **Google Drive** — OAuth 2.0 with your personal Google account.
  - **Nextcloud / WebDAV** — Connect to any self-hosted or third-party WebDAV server.
  - **Browse Cloud Characters** — Browse all characters stored in the cloud, see which ones are already on your device, and selectively download new ones with avatar previews.
  - **Bi-Directional Sync** — Characters, folders, and user personas sync both ways automatically. Newer files always win.
  - **User Persona Sync** — Your custom personas (names, descriptions, avatars) are now included in cloud sync for seamless multi-device continuity.
- 🎬 **Director Mode**: A complete overhaul of Group Chat turn management. Take control of multi-character conversations:
  - Manually choose which character speaks next.
  - Guide the flow of group conversations instead of relying solely on automated turn orders.
- 👥 **Group Chat Improvements**: Overhauled group chat experience with better stability, improved turn handling, and responsive card layouts that adapt to all UI scale sizes.
- 🎛️ **XTC Sampler**: New Exclude Top Choices sampler for more creative, less predictable text generation. Two new controls:
  - **XTC Threshold** (0–0.5) — Removes the most obvious word choices to encourage creativity.
  - **XTC Probability** (0–1.0) — How often XTC activates per generation step.
- 💡 **Setting Tooltips**: Every generation setting slider (Temperature, Min-P, Repeat Penalty, XTC, Context Size, and more) now has an ℹ️ tooltip explaining what it does in plain language — perfect for newcomers.
- 🎨 **Responsive UI**: Group chat cards now scale gracefully at all grid sizes — no more overflow at small card sizes.
- 🔒 **Privacy Policy**: PRIVACY.md documenting data handling — no telemetry, no analytics, cloud sync is opt-in and connects only to accounts you own.
- 🏷️ **Beta Prerelease Support**: Beta versions are flagged as prereleases on GitHub so they won't trigger auto-updates for stable users.

### What's New in V0.7.1

- 🔍 **Grid Scale Slider**: Resize character cards on the home screen with a header slider (150–450px). Cards adapt responsively — compact text at medium sizes, image-only with name overlay at tiny sizes.
- 💬 **Message Count Badges**: Each character card shows a chat bubble badge with how many messages you've sent (AI replies excluded).
- 📊 **Sort by Messages Sent**: New sort option to order characters by message count.
- 📂 **Multi-Select Folder Organization**: Dedicated folder selection mode for moving multiple characters into folders at once.
- 📥 **Bulk PNG Import**: Import an entire folder of character card PNGs in one action.
- 🐛 **Folder Rename Fix**: Fixed path separator mismatch that caused characters to disappear from folders on Windows.
- 🐛 **Cross-Chat Message Leak Fix**: Messages from one chat no longer appear in another character's session.
- 🏗️ **CI/CD Cleanup**: Removed the transitional `Front_Porch_AI_Setup_Alpha.exe` duplicate from releases.

### What's New in V0.7.0

- 🔊 **Multi-Engine Text-to-Speech**: Three TTS engines to choose from — all accessible from the new TTS button in the chat sidebar:
  - **Kokoro TTS** (local, default) — High-quality offline TTS powered by kokoro-onnx. 50+ voices across 9 languages. Models auto-download on first use.
  - **OpenAI TTS** (cloud) — Premium cloud-based TTS with 10 voices (alloy, ash, coral, echo, nova, etc.). Supports tts-1 and tts-1-hd models. Requires API key.
  - **Piper TTS** (fallback) — Lightweight local engine with downloadable voice packs.
- ⚡ **Parallel TTS Generation**: Sentences are generated concurrently for dramatically faster audio output. Configurable worker count (1–16) based on your CPU cores.
- 🔁 **TTS Audio Caching**: Replay the same message instantly without regenerating. Cache auto-invalidates on message edits, voice changes, or engine switches.
- ⏹️ **Stop Generation**: Cancel in-progress TTS generation with a stop button next to the progress spinner.
- 🎛️ **TTS Settings in Chat**: Quick-access TTS configuration button in the chat sidebar alongside Chat and Model settings.
- 🔄 **Linux AppImage Self-Update**: AppImage users are automatically notified when a new version is available. Download and install updates with a single click — the app replaces itself and relaunches seamlessly.

### What's New in V0.6.0

- 🎭 **Per-Character System Prompts**: Each character can now carry its own system prompt and post-history instructions. Priority chain: Character → Group → Global → Backend Default. Define character-specific behavior without touching global settings.
- 📝 **Author's Note / Memory**: A per-session note injected into the prompt at a configurable depth (1–20 messages back). Edit it right from the sidebar — automatically saved and restored with each session.
- 📊 **Context / Token Budget Viewer**: See exactly how your context window is being used with a color-coded stacked bar chart, per-section token counts, percentages, and expandable raw prompt text. Access it via the analytics button in the chat input area.
- 🌿 **Chat Branching**: Fork the conversation from any message to explore alternate storylines. Branch metadata is tracked and displayed in the session history dialog.
- 🖥️ **Windows Installer Now Stable**: The Windows `.exe` installer has graduated from alpha — fully tested and production-ready.

### What's New in V0.5.0

- 👥 **Group Chat (Pre-Alpha)**: Create multi-character group chats! Select 2+ characters and watch them interact with each other and with you in a shared conversation. Features round-robin and free-form turn orders, auto-advance mode, and full persistence.
- ✨ **AI-Generated Scenarios & First Messages**: One-tap ✨ Generate buttons in the group creation dialog.
- 🎛️ **Generation Presets**: Quick-access preset chips (Creative, Balanced, Precise, Deterministic) in Generation Settings.
- 🎨 **Improved Chat Colorization**: Fixed multi-line `*action*` block detection.
- 🧠 **Thinking Model Support**: Automatic `<think>` block stripping for thinking models.

### What's New in V0.0.4.2

- 🖥️ **Windows Installer**: Proper `.exe` installer with GPL V3 license acceptance, Start Menu shortcuts, and optional desktop shortcut
- 🍎 **macOS DMG**: Native disk image with drag-to-Applications layout and custom app icon
- 🔄 **Windows Self-Update (Alpha)**: Installer-only feature — checks GitHub Releases for new versions on startup, downloads and installs silently with user consent
- 🏷️ **Persona Titles**: Add a distinct title to personas for easier identification in lists
- 🔁 **Automatic Version Sync**: Version numbers auto-sync from Git branch/tag names via a post-checkout hook
- 🎨 **Custom App Icons**: Replaced default Flutter icons with Front Porch AI branding

### What's New in V0.0.4

- 🚀 **External API Support — Chat with Cloud Models!** Front Porch AI now supports **OpenRouter** and **Nano-GPT** as full backend providers! Seamlessly switch between your local KoboldCPP instance and powerful cloud models like Claude, GPT-4, Gemini, DeepSeek, and more.
- **Swipe Navigation**: Cycle through regenerated message variations with left/right arrows
- **Collapsible Thought Chip**: Model thinking is automatically hidden behind a collapsible "Thought 💡" chip
- **Continue Generation**: Down-arrow button on the last AI message to prompt the model to keep going
- **Chat Import/Export**: Import and export chats in SillyTavern-compatible JSON format
- **Linux Browser Fallback**: Graceful fallback to external browser on Linux
- **User Persona Enhancements**: Improved persona dialog and avatar support

</details>


## 🙏 Thank You

Front Porch AI stands on the shoulders of incredible open-source projects. This app wouldn't be possible without them:

| Project | What It Does | Link |
|---|---|---|
| **KoboldCpp** | The local LLM backend that powers all text generation. A single-file, high-performance inference engine supporting GGUF models with GPU acceleration. | [GitHub](https://github.com/LostRuins/koboldcpp) |
| **Faster Whisper** | Speech-to-text engine powering push-to-talk and voice call mode. A fast, CTranslate2-based reimplementation of OpenAI Whisper. | [GitHub](https://github.com/SYSTRAN/faster-whisper) |
| **Kokoro** | Our default text-to-speech engine. Beautiful, natural-sounding voices that run entirely offline using ONNX. | [GitHub](https://github.com/hexgrad/kokoro) |
| **Piper** | Fallback TTS engine. Fast, lightweight, and privacy-respecting local speech synthesis. | [GitHub](https://github.com/rhasspy/piper) |

If you find Front Porch AI useful, please consider starring these projects too — they're the foundation everything is built on.

> **🎩 Hat tip to [Backyard AI](https://github.com/ahoylabs/byaf)** for open-sourcing the `.byaf` archive format — the one part of their stack they didn't take with them when they killed the desktop app. Your characters deserve to live somewhere they can run offline.

## 🌟 Contributors

A huge thank you to the people who have helped shape Front Porch AI through their testing, feedback, and ideas:

| Contributor | Role |
|---|---|
| **Hakko504** | Bug Testing, UI/Feature Suggestions |
| **PacmanIncarnate** | Bug Testing, UI/Feature Suggestions |
| **SunTzucious** | Beta Testing |


<p align="center">
  <img src="docs/screenshots/home_new.png" width="800" alt="Home Page - Character Grid with Folders">
</p>
<p align="center">
  <em>Organize your collection with virtual folders and comprehensive search</em>
</p>

A powerful, cross-platform desktop application designed to streamline the management of AI character cards and provide a seamless chat experience with **KoboldCPP**. Organize your collection, edit metadata, build worlds, and chat with your favorite characters in a modern, intuitive interface.

## ✨ Features

### 📇 Character Management
<img src="docs/screenshots/editor.png" width="800" alt="Character Editor">

- **V2 Spec Support**: Fully compatible with the V2 character card specification (PNG & JSON).
- **Import & Export**: Easily import cards from other frontends or export your creations to share.
- **Metadata Editor**: Edit names, descriptions, personalities, scenarios, and first messages with a clean UI.
- **Lorebooks**: Create and attach extensive lorebooks to characters for deep world-building.
- **Organization**: Create virtual folders, tag characters, and use global search to manage large collections.
- **Tag Editor**: Manage tags directly from the Edit Character screen.
- **Web-to-Chat Import**: Direct integration with `aicharactercards.com` and `chub.ai` via an internal browser that intercepts downloads for instant auto-import.
- **V2 Smart Parsing**: Advanced V2 tEXt metadata extraction from PNG character cards.

### 🎨 Character Creation
<img src="docs/screenshots/ez_char_creator.png" width="800" alt="Easy Mode Character Creator">

- **AI Character Creator**: Generate a complete character card from just a name and concept — the AI writes the personality, backstory, dialogue examples, system prompt, lorebook, and even an avatar. Multi-step wizard with editor passes for quality control.
- **World Lore Integration (RAG-Lite)**: Paste Wiki URLs or attach local lore documents, and the generator will read and embed world-context into the character's core prompts.
- **Manual Creation**: Build detailed character cards (V2 spec compatible) with a full-form UI — name, description, personality, scenario, first message, alternate greetings, tags, and avatar upload.

### 💬 Immersive Chat Experience
<img src="docs/screenshots/chat.png" width="800" alt="Immersive Chat Interface">

- **Smooth Output Buffer**: An intelligent buffering system that delivers text at a consistent, readable pace — no matter how fast or slow your hardware generates tokens.
  - **Adaptive TPS Measurement**: Continuously monitors generation speed using a rolling 3-second window and calculates the optimal buffer size to start displaying as early as possible without interruptions.
  - **Configurable Display Speed**: Set your preferred reading speed (default: ~250 WPM / 6 tokens/sec) via a slider from 5–60 t/s. Tokens are dripped onto the screen at your pace, not your GPU's pace.
  - **No-Buffer Mode**: Prefer raw streaming? Toggle the buffer off for instant token-by-token display as they arrive.
  - **Auto-Pause & Rebuild**: If generation speed drops mid-response, the buffer automatically pauses display and rebuilds to maintain a seamless flow.
  - **Real-Time TPS Counter**: The generation bar shows live tokens-per-second, buffering status, and progress percentage.
- **Rich Text Styling**: 
  - **Dialogue** is highlighted in amber for easy reading.
  - *Actions* and narrative text are subtly styled in grey.
- **Advanced Controls**:
  - **Regenerate**: Don't like a response? Roll again.
  - **Continue**: Let the AI keep talking from where it left off.
  - **Impersonate**: Have the AI write a message *as you* (the user).
  - **Stop Generation**: Immediately halt AI generation mid-stream with one click.
  - **Message Editing**: Edit any message (User or AI) in-place to polish the narrative or fix typos.
- **Persistent Sessions**: Your chat history is automatically saved and restored when you switch characters.
- **System Prompt Library**: Save and switch between multiple system prompts. Includes a specialized "Immersive Roleplay" default.
- **User Personas**: Define your own persona name and description to influence how characters interact with you.

### 👥 Group Chat & Director Mode
<img src="docs/screenshots/group_chat_new.png" width="800" alt="Group Chat with Director Mode">

- **Multi-Character Conversations**: Create group chats with 2+ characters and watch them interact with each other and with you.
- **Director Mode**: Take control of who speaks next — tap any character to direct the conversation flow.
- **Turn Orders**: Choose between Round Robin and Random turn orders, or go fully manual with Director Mode.
- **AI-Generated Scenarios**: One-tap ✨ Generate buttons for scenarios and first messages.

<img src="docs/screenshots/group_chat_creator.png" width="400" alt="Group Chat Creator">

### 🖼️ Local Image Generation Workflows
<img src="docs/screenshots/local_image_gen.png" width="800" alt="Local Image Generation Interop">

- **Full Backend Support**: Natively connect to Automatic1111, Forge, SDNext, and Draw Things instances.
- **UI First Integration**: Generate character portraits and in-chat selfies directly from the Front Porch UI.
- **Advanced Controls**: Dropdowns for live Model switching, LoRA injection, and a model Unload flush toggle.
- **Prompt Paradigms**: Switch between Natural Language format (for FLUX / SD3) or Danbooru Tags (SD 1.5 / Anime models).

### 📖 Porch Stories — AI Novel Generator
<img src="docs/screenshots/Porch_stories_book.png" width="800" alt="Porch Stories Skeuomorphic Book Reader">

- **Chat Distillation**: Imports character chat logs to distill into a coherent storyline timeline.
- **Novel Generation pipeline**: Operates an autonomous 5-stage pipeline to turn ideas into fully written books.
- **Skeuomorphic Reader**: Stunning page-flip animations, multi-voice audiobook TTS read-alongs, and an interactive Table of Contents.
- **Character Role Assignment**: Cast your chat characters as the Protagonist, Antagonist, or Support.

### 🔊 Text-to-Speech
<img src="docs/screenshots/tts_settings.png" width="400" alt="TTS Settings">

- **Four TTS Engines**: Kokoro (local, high quality), OpenAI (cloud, premium), ElevenLabs (cloud, premium with expressive controls), and Piper (lightweight fallback).
- **ElevenLabs**: Configurable Stability, Similarity, and Style sliders for fine-tuned voice control. Supports Flash v2.5 (~75ms latency), Multilingual v2 (29 languages), and v3 (best quality).
- **50+ Voices**: Kokoro ships with 50+ voices across 9 languages — all running offline.
- **Parallel Generation**: Sentences are generated concurrently for dramatically faster audio output.
- **Per-Character Voices**: Assign unique voices to each character in group chats.
- **Narration Filters**: SillyTavern-style filters — narrate quoted dialogue only, ignore asterisked actions.

### ⚙️ KoboldCPP Integration
<img src="docs/screenshots/model_hub.png" width="800" alt="Model Hub - HuggingFace Search">

- **Automated Management**: The app can automatically download and update the KoboldCPP backend for you.
- **Hardware Detection**: Automatically detects GPU and VRAM. Prefers **Vulkan** on PC and **Metal** on Apple Silicon. Now supports **Intel ARC** and shared memory GPUs.
- **macOS Stability**: Native quarantine management and sandbox-free execution for seamless backend launches.
- **Model Hub**: Built-in integration with HuggingFace to search for and download GGUF models directly.
- **Process Management**: Robustly handles the lifecycle of the AI backend, ensuring clean shutdowns.

### ☁️ Cloud Sync
<img src="docs/screenshots/cloud_sync.png" width="800" alt="Cloud Sync Page">

- **Cross-Device Sync**: Sync your entire database and character PNGs via Google Drive or Nextcloud/WebDAV.
- **Single-File Sync**: All data (chats, folders, personas, groups, worlds) syncs as one database file — no more hundreds of scattered JSON files.
- **Browse Cloud Characters**: View all characters stored in the cloud, see which are already on your device, and selectively download new ones with avatar previews.
- **Backup Management**: Automatic backups before every cloud sync, with one-click restore and manual backup creation.
- **Upload-Only Characters**: Character PNGs upload automatically; downloads are user-initiated to keep you in control.
- **Privacy-First**: Syncs only to accounts you own. No data ever passes through our servers.

### ⚙️ Dedicated Settings Overhaul
<img src="docs/screenshots/new_settings.png" width="800" alt="Advanced Settings Overhaul">

- **Categorized Hub**: Intuitively tab through General, Voice & Media, and Backend Settings. 
- **Hardware Telemetry**: View live readouts of your backend's Context Window sizes and VRAM footprint directly alongside your AI customizations.

### 🌍 World Building
- **World Info**: Create shared lore that can be referenced by multiple characters.
- **Dynamic Context**: World info is injected into the context based on keywords, ensuring the AI knows about your world without overloading the context window.


## 🛠️ Configuration

1.  **Backend Setup**:
    - Navigate to **Settings**.
    - Click **Download Backend** to fetch the latest KoboldCPP.
    - Alternatively, manually select your `koboldcpp.exe` file.

2.  **Model Setup**:
    - Go to **Manage Models** -> **HuggingFace Search**.
    - Search for a model (e.g., "Mistral v0.3", "Llama 3").
    - Download the desired quantization (Recommended: `Q4_K_M` or `Q5_K_M`).

3.  **Optimization**:
    - In **Settings**, click **Auto-Configure** to let the app determine the best GPU layer split and thread count for your system.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1.  Fork the Project
2.  Create your Feature Branch (`git checkout -b feature/AmazingFeature`)
3.  Commit your Changes (`git commit -m 'Add some AmazingFeature'`)
4.  Push to the Branch (`git push origin feature/AmazingFeature`)
5.  Open a Pull Request

## 🔒 Privacy

Front Porch AI does not collect, store, or transmit any personal data. See our full [Privacy Policy](https://app.dreamersai.art/privacy.html).

## 📄 License

**v0.9.0 and later:** Licensed under the **GNU Affero General Public License v3 (AGPL-3.0)** — see the [LICENSE](LICENSE) file for details.

**v0.8.x and earlier:** Licensed under the **GNU General Public License v3 (GPL-3.0)**.

---
*Built with 💙 using [Flutter](https://flutter.dev).*
