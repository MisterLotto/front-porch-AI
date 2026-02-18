# Changelog

All notable changes to Front Porch AI will be documented in this file.

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
