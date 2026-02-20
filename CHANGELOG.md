# Changelog

All notable changes to Front Porch AI will be documented in this file.

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
