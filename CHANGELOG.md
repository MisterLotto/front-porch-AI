# Changelog

All notable changes to Front Porch AI will be documented in this file.

## [V0.9.2] - 2026-03-14

### ✨ New Features
- **Character Evolution Context**: Character personality and scenario now use a layered approach — the original card identity is preserved as ground truth, while evolved traits from the Evolve system are presented as additive growth. Prevents contradictions and preserves core character identity.
- **User Persona in Prompts**: The user's self-description and auto-learned facts (from the persona system) are now injected into the LLM prompt. Layered format prioritizes the user's own description, with discovered facts as secondary observations.
- **Rust Embedding Server**: The RAG embedding sidecar has been rewritten from Python (PyInstaller + sentence-transformers) to Rust (fastembed + ONNX Runtime). ~25MB binary vs ~200MB+ Python bundle. Faster startup, no Python runtime dependency.
- **RAG Auto-Start on Toggle**: Toggling RAG on now immediately starts the embedding engine, with real-time status feedback (Starting... → Ready).
- **Objective / Goals System**: Set session-level objectives that guide AI behavior. Goals persist across messages and shape conversation direction.
- **RAG-Grounded Summaries**: Chat summaries use Retrieval-Augmented Generation with an embedded vector store for context-aware rolling summaries. Configurable retrieval count, window size, and embedding source.
- **Data Bank Dialog**: Unified UI for browsing RAG memory entries, embedding stats, and persona-linked memory.
- **NSFW Content Toggle**: Global on/off switch for NSFW content filtering with per-character override.
- **WebUI RAG / Memory Menu**: New hamburger menu entry for RAG settings — retrieval count, window size, embedding model, toggle on/off.
- **Greeting Tones (Guided Creator)**: Guided character creator now supports greeting tone selection, matching the automated creator.
- **Intel Mac Detection**: Detects Intel Macs and disables KoboldCpp with a warning banner directing users to Remote API. Covers Flutter app, WebUI settings, model modal, and character creator.
- **Lorebook World-Building Focus**: Prompts rewritten to produce world lore (locations, factions, magic, cultures) instead of character biography. Per-category guidance, expanded categories (added Flora/Fauna, renamed History/Lore → History/Events).

### 🐛 Bug Fixes
- **TTS Voice Name Display**: ElevenLabs voice selection in settings now shows the friendly voice name instead of the raw voice ID.
- **TTS Asterisk Filter**: Fixed narration filter to properly ignore multi-line `*action*` blocks (was only matching single-line).
- **TTS Quote Filter**: Fixed narration filter to correctly extract text from both straight (`"..."`) and curly (`\u201c...\u201d`) quotes.

### 📱 WebUI Mobile Fixes
- Fixed chat input bar clipped off bottom in Safari (viewport height + safe area insets)
- Added back buttons to all Settings sub-sections on mobile
- Compact modals and responsive layout fixes for small screens
- Added hamburger menu for RAG/Memory feature settings

### 🏗️ Infrastructure
- **CI/CD Rust Toolchain**: Both `release.yml` and `beta-release.yml` now install the Rust toolchain and build the embedding server with `cargo build --release` instead of PyInstaller. Removed `sentence-transformers` from pip dependencies.

---

## [V0.9.1] - 2026-03-11

### ✨ New Features
- **WebUI: ElevenLabs TTS**: Added ElevenLabs (Premium) engine option to the Settings page TTS section with API key, model selection (Flash v2.5, Multilingual v2, v3), and Stability/Similarity/Style sliders.
- **WebUI: Inline Image Viewing**: Chat messages containing `![alt](url)` markdown now render images inline.
  - Security consent dialog warns about IP exposure and potential risks before loading external images.
  - Images are served through a server-side proxy (`/api/image-cache/serve`) — browser never contacts external servers directly.
  - Shares the same image cache directory as the Flutter desktop app, so images cached by either app are available to both.
  - Consent is remembered per-character in localStorage and automatically skipped for already-cached images.
- **KoboldCpp Auto-Start Toggle**: New setting to enable/disable automatic model loading when the app starts, for users with memory constraints.

### 🐛 Bug Fixes
- **WebUI: Avatar Face Cropping**: Added `object-position: top` to character card avatars, chat appbar avatar, and message sender avatars to prevent faces from being cut off.
- **WebUI: `{{char}}` Placeholder**: Fixed `{{char}}` showing literally in character card descriptions, chat appbar subtitle, and right panel scenario/description fields.
- **WebUI: Banned Phrases Input**: Fixed the textarea losing focus after every keystroke in the Advanced settings tab.
- **`<START>` Token Leakage**: Added `<START>` to default stop sequences to prevent models from outputting it at the end of responses.

---

## [V0.9.0] - 2026-03-08

### ✨ New Features
- **AI Character Creator**: Full-featured wizard with Automated and Guided modes for creating characters with AI assistance.
  - 5-step wizard: Setup → Mode → Configure → Generate → Review.
  - Guided mode expands 20+ character fields individually for fine-tuned control.
  - AI-generated character descriptions, greetings, scenarios, and personality traits.
  - Integrated into both the desktop app and WebUI.
- **ElevenLabs TTS Engine**: Premium cloud TTS with configurable stability, similarity, and style parameters; SillyTavern-style narration filters (narrate quoted-only, ignore asterisks).
- **WebUI Mobile UX**: Compact character cards, message badges, overflow menu, model switcher, and responsive layout improvements.
- **Linux Distribution**: Self-hosted APT (Debian/Ubuntu) and RPM (Fedora/RHEL) repositories with Caddy serving, plus AUR package for Arch Linux. CI/CD automation via GitHub Actions.
- **Context Slider & Auto-Configure**: Exposed context size control and fixed auto-configuration for GPU offloading and context capacity.

### 🏗️ Infrastructure
- **AGPL-3.0 Copyright Headers**: Added license headers to all source files.
- **Dart Analyzer Cleanup**: Fixed 90+ deprecated API warnings and unused imports.

---

## [V0.8.0-beta] - 2026-02-20

### ✨ New Features
- **Cloud Sync (Beta)**: Bi-directional sync of characters and chat sessions across devices.
  - **Google Drive**: OAuth 2.0 authentication, syncs to a dedicated `FrontPorchAI` folder in your Drive.
  - **Nextcloud / WebDAV**: Connect to any self-hosted or third-party WebDAV server.
  - Full bi-directional sync — newer files always win. New sessions on either device are automatically pulled in.
  - Orphan cleanup: deleting a character or group locally removes remote files on next sync.
  - Configurable sync provider in Settings → Cloud Sync section.
- **Privacy Policy**: Added `PRIVACY.md` — documents data handling practices. No telemetry, no analytics, cloud sync is opt-in only.
- **Beta Prerelease Support**: Release workflow flags beta tags as GitHub prereleases so they don't trigger auto-updates for stable users.

### 🏗️ Infrastructure
- Pluggable `CloudStorageProvider` architecture for easily adding new sync backends.
- `CloudSyncService` handles sync orchestration, conflict resolution, orphan cleanup, and progress tracking.

---

## [V0.7.1] - 2026-02-20

### ✨ New Features
- **Grid Scale Slider**: Adjustable slider in the header to resize character card PNGs on the home screen (150–450px). Preference persists across sessions.
  - Cards adapt responsively: compact text at medium sizes, image-only with gradient name overlay at tiny sizes.
- **Message Count Badges**: Each character card displays a 💬 badge showing how many messages you've sent to that character (AI replies are not counted).
- **Sort by Messages Sent**: New sort option in the dropdown to order characters by most messages sent first.
- **Multi-Select Folder Organization**: Dedicated blue folder icon button enables a separate selection mode for moving multiple characters into folders at once, independent of the purple group chat selection mode.
- **Bulk PNG Import**: Import an entire folder of character card PNGs in one action via the import menu.
- **Character Sorting**: Sort characters by Name (A→Z), Recent Activity, or Import Date with persisted preferences.

### 🐛 Bug Fixes
- **Folder Rename Bug**: Fixed path separator mismatch (mixed `/` and `\` on Windows) that caused characters to disappear from folders after renaming or on rebuild.
- **Cross-Chat Message Leak**: Fixed a bug where messages from one chat session could appear in another character's chat.
- **UI Overflow at Small Grid Scales**: Folder cards and character cards now gracefully adapt their layout when shrunk via the grid slider — no more overflow errors.

### 🏗️ Infrastructure
- **Removed Duplicate Windows Installer**: The transitional `Front_Porch_AI_Setup_Alpha.exe` artifact has been retired from CI/CD. Only `Front_Porch_AI_Setup.exe` is produced going forward.

---

## [V0.6.0] - 2026-02-18

### ✨ New Features
- **Per-Character System Prompts**: Characters can now carry their own system prompt and post-history instructions, giving you fine-grained control over how each character behaves without changing global settings.
  - Priority chain: Character → Group → Global → Backend Default.
  - **Post-History Instructions**: Inject character-specific guidance *after* the chat history for powerful steering (e.g., "Always end your reply with an action").
  - New fields available in the character creator, editor, and in-chat edit dialog.
- **Author's Note / Memory**: A per-session note injected into the prompt at a configurable depth (1–20 messages from the bottom).
  - Editable directly from the right sidebar while chatting.
  - Automatically saved and restored with each session.
- **Context / Token Budget Viewer**: Visual breakdown of how your context window is being used.
  - Color-coded stacked bar chart showing each prompt section (System Prompt, Lorebook, Persona, Scenario, Examples, Chat History, Post-History).
  - Section-by-section token counts with percentages.
  - Expandable raw text view for debugging prompts.
  - Accessed via the 📊 analytics button in the chat input area.
- **Chat Branching (Fork)**: Fork the conversation from any message to explore alternate storylines.
  - ↗ Fork button on every message bubble creates a new session with messages up to that point.
  - Branch metadata (parent session, fork index) persisted and displayed in the history dialog with visual indicators.

### 🐛 Bug Fixes
- Fixed context size slider not persisting to `StorageService`, causing the context budget viewer to always show 8192 as the limit.
- Fixed `speakingCharacter` referenced before declaration when using per-character system prompts.

### 🏗️ Infrastructure
- Session save format upgraded to JSON envelope (`{messages, author_note, author_note_depth, parent_session, fork_index}`) with full backward compatibility for older plain-array sessions.

---

## [V0.5.0] - 2026-02-17

### ✨ New Features
- **Group Chat (Pre-Alpha)**: Create multi-character group chats with 2+ characters. Characters interact with each other and with the user in a shared conversation.
  - **Round Robin & Free-Form Turn Order**: Choose between structured round-robin turns or dynamic free-form conversations.
  - **Auto-Advance**: Toggle automatic character responses — characters respond one after another without user input.
  - **AI-Generated Scenarios**: ✨ Generate button produces a concise 1-2 sentence scenario from character personalities.
  - **AI-Generated First Messages**: ✨ Generate button creates a vivid multi-paragraph opening scene based on the scenario and characters, with dialogue, actions, and sensory details.
  - **Pre-Alpha Warning Dialog**: Users are notified about the experimental nature of group chat before creating one.
  - **Group Chat Persistence**: Group chats are saved and restored between sessions via `GroupChatRepository`.
- **Generation Presets**: Quick-access preset chips (Creative, Balanced, Precise, Deterministic) in the Generation Settings dialog for one-tap parameter profiles.
- **Chat Text Colorization Improvements**: Fixed multi-line `*action*` block detection with `dotAll` regex, ensuring correct blue/amber coloring across line breaks.
- **Thinking Model Support**: Automatic `<think>...</think>` block stripping for thinking models (e.g., GLM5) that emit reasoning chains in output.

### 🏗️ Infrastructure
- **Package Rename**: Renamed package from `kobold_character_card_manager` to `front_porch_ai` across the entire codebase.
- **Installer Fix**: Resolved Windows installer exe name mismatch (`front_porch_ai.exe` → `Front Porch AI.exe`).

### 🐛 Bug Fixes
- Stop sequences (`END SCENE`, `---`, `[END]`) added to AI generation to prevent abrupt cutoffs.
- Reasoning/planning text automatically filtered from generated content.
- Fixed `<think>` tag leakage from thinking-enabled models in generated first messages.

---

## [v0.0.3.4] - 2026-02-16

### ✨ New Features
- **Smooth Output Buffer**: Intelligent token buffering system that delivers AI responses at a consistent, readable pace regardless of hardware speed.
  - Adaptive TPS measurement using a rolling 3-second window — responds to speed fluctuations in real-time.
  - Optimal buffer formula (`maxTokens × (1 - genTps / targetTps)`) starts display as early as mathematically possible without interruptions.
  - Auto-pause & rebuild: if generation speed drops mid-response, display pauses briefly and re-buffers to maintain smooth flow.
  - Real-time tokens-per-second counter shown in the generation bar.
- **Configurable Display Speed**: New settings in Chat Settings dialog:
  - Toggle smooth output buffer on/off (no-buffer mode for raw streaming).
  - Slider to set target display speed (5–60 t/s, default 6 t/s ≈ 250 WPM average human reading speed).
- **Alt Greetings in Character Creator**: Add alternate greeting messages when creating new characters.

### 🐛 Bug Fixes
- Fix `{{char}}` placeholder replacement being inconsistent across cards and chat.
- Fix sidebar title truncation on long character names.
- Fix backend auto-start race condition by awaiting StorageService initialization.

### 📝 Documentation
- Added open source philosophy and community links (Discord, Matrix) to README.
- Added screenshots inline with feature sections.
- Added Smooth Output Buffer feature documentation.

---

## [v0.0.3] - 2026-02-14

### ✨ New Features
- **Virtual Folders**: Organize characters into folders for better collection management.
- **Tag System**: Tag characters and filter your collection.
- **Global Search**: Search across all characters by name, tags, or description.
- **Multiple System Prompts**: Save and switch between multiple system prompt presets. Includes built-in "Immersive Roleplay" default.
- **Intel ARC Support**: Hardware detection now supports Intel ARC and shared memory GPUs.

---

## [v0.0.2] - 2026-02-13

### ✨ New Features
- **macOS Stability**: Native quarantine management and sandbox-free backend execution.
- **Stop Generation**: Halt AI generation mid-stream with one click.
- **Message Editing**: Edit any message (User or AI) in-place.
- **Auto-Import**: Web-to-chat import integration with `aicharactercards.com` and `chub.ai` via internal browser.

---

## [v0.0.1] - 2026-02-12

### 🎉 Initial Release
- V2 character card support (PNG & JSON).
- Import/export character cards.
- Metadata editor for character details and lorebooks.
- KoboldCPP integration with automated download and hardware detection.
- Real-time streaming chat with persistent sessions.
- HuggingFace model hub integration.
- World building with dynamic keyword-based context injection.
- Cross-platform support (Windows, macOS, Linux).
