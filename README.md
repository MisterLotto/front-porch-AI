# Front Porch AI

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Flutter](https://img.shields.io/badge/Made%20with-Flutter-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)

## 🔓 Why Open Source?

Proprietary software lives and dies at the discretion of its creators. When a company moves on, shuts down, or simply loses interest, the tools you depend on become frozen in time — no updates, no fixes, no future.

Front Porch AI is proudly licensed under the **GPL v3** because we believe your tools should belong to the community that uses them. If this project is ever abandoned, anyone can fork it, improve it, and keep it alive. Open source isn't just a license — it's a promise that the software will always have a future.

## 🆕 What's New in V0.0.4

- 🚀 **External API Support — Chat with Cloud Models!** Front Porch AI now supports **OpenRouter** and **Nano-GPT** as full backend providers! Seamlessly switch between your local KoboldCPP instance and powerful cloud models like Claude, GPT-4, Gemini, DeepSeek, and more — all from the same interface. Includes a complete provider switching system, per-model configuration, and streaming support. Your local-first workflow just got a whole lot more powerful.
- **Swipe Navigation**: Cycle through regenerated message variations with left/right arrows and a position counter (e.g. 2/3)
- **Collapsible Thought Chip**: Model thinking (`<think>` blocks) is automatically hidden behind a collapsible "Thought 💡" chip — no more raw thinking text cluttering the conversation
- **Continue Generation**: Down-arrow button on the last AI message to prompt the model to keep going
- **Chat Import/Export**: Import and export chats in SillyTavern-compatible JSON format
- **Linux Browser Fallback**: Graceful fallback to external browser for character card downloads on Linux
- **User Persona Enhancements**: Improved persona dialog and avatar support

## 💬 Join the Community

Have questions, feedback, or just want to hang out? Connect with us:

- **Discord**: [Join our server](https://discord.gg/EqJrJPjdT)
- **Matrix**: [matrix.dreamersai.art](https://matrix.dreamersai.art)

<p align="center">
  <img src="docs/screenshots/home.png" width="800" alt="Home Page - Character Grid with Folders">
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
<img src="docs/screenshots/create.png" width="800" alt="Character Creation">

Create detailed character cards (V2 spec compatible) with a user-friendly form UI. Support for:
- Name, Description, Personality, Scenario, First Message
- Alternate Greetings
- Tags
- Avatar image upload

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

### ⚙️ KoboldCPP Integration
- **Automated Management**: The app can automatically download and update the KoboldCPP backend for you.
- **Hardware Detection**: Automatically detects GPU and VRAM. Prefers **Vulkan** on PC and **Metal** on Apple Silicon. Now supports **Intel ARC** and shared memory GPUs.
- **macOS Stability**: Native quarantine management and sandbox-free execution for seamless backend launches.
- **Model Hub**: Built-in integration with HuggingFace to search for and download GGUF models directly.
- **Process Management**: Robustly handles the lifecycle of the AI backend, ensuring clean shutdowns.

### 🌍 World Building
- **World Info**: Create shared lore that can be referenced by multiple characters.
- **Dynamic Context**: World info is injected into the context based on keywords, ensuring the AI knows about your world without overloading the context window.

## 🚀 Getting Started

### 📦 For Regular Users
If you just want to use the app, simply head over to the **[Releases](https://github.com/linux4life1/front-porch-ai/releases)** page and download the installer for your platform:

- **Windows**: `.exe` installer
- **Linux**: `.AppImage` (universal), `.deb` (Debian/Ubuntu), or `.rpm` (Fedora/RHEL)
- **macOS**: `.dmg` disk image

No setup required!

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

## 📄 License

This project is licensed under the **GPLv3 License** - see the [LICENSE](LICENSE) file for details.

---
*Built with 💙 using [Flutter](https://flutter.dev).*
