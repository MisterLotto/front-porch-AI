# Front Porch AI

![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)
![Flutter](https://img.shields.io/badge/Made%20with-Flutter-02569B?logo=flutter)
![Platform](https://img.shields.io/badge/Platform-Windows%20%7C%20Linux%20%7C%20macOS-lightgrey)

A powerful, cross-platform desktop application designed to streamline the management of AI character cards and provide a seamless chat experience with **KoboldCPP**. Organize your collection, edit metadata, build worlds, and chat with your favorite characters in a modern, intuitive interface.

## ✨ Features

### 📇 Character Management
- **V2 Spec Support**: Fully compatible with the V2 character card specification (PNG & JSON).
- **Import & Export**: Easily import cards from other frontends or export your creations to share.
- **Metadata Editor**: Edit names, descriptions, personalities, scenarios, and first messages with a clean UI.
- **Lorebooks**: Create and attach extensive lorebooks to characters for deep world-building.

### 💬 Immersive Chat Experience
- **Real-Time Streaming**: Tokens appear instantly as they are generated, eliminating perceived latency.
- **Rich Text Styling**: 
  - **Dialogue** is highlighted in amber for easy reading.
  - *Actions* and narrative text are subtly styled in grey.
- **Advanced Controls**:
  - **Regenerate**: Don't like a response? Roll again.
  - **Continue**: Let the AI keep talking from where it left off.
  - **Impersonate**: Have the AI write a message *as you* (the user).
- **Persistent Sessions**: Your chat history is automatically saved and restored when you switch characters.
- **User Personas**: Define your own persona name and description to influence how characters interact with you.

### ⚙️ KoboldCPP Integration
- **Automated Management**: The app can automatically download and update the KoboldCPP backend for you.
- **Hardware Detection**: Automatically detects your GPU and VRAM to configure optimal settings (layers, context size) for your hardware.
- **Model Hub**: Built-in integration with HuggingFace to search for and download GGUF models directly.
- **Process Management**: Robustly handles the lifecycle of the AI backend, ensuring clean shutdowns.

### 🌍 World Building
- **World Info**: Create shared lore that can be referenced by multiple characters.
- **Dynamic Context**: World info is injected into the context based on keywords, ensuring the AI knows about your world without overloading the context window.

## 🚀 Getting Started

### Prerequisites
- **OS**: Windows (primary support), Linux, or macOS.
- **KoboldCPP**: The app can download this for you, or you can point it to your existing executable.
- **Hardware**: A GPU is recommended for the best experience, but CPU inference is supported.

### Installation

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
    flutter run -d windows
    ```
    *(Replace `windows` with `linux` or `macos` as needed)*

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
