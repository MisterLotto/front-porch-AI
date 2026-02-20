# Privacy Policy

**Last updated:** February 20, 2026

## Overview

Front Porch AI is a free, open-source desktop application licensed under the GPL v3. It is designed to run entirely on your local machine. **We do not collect, store, transmit, or sell any personal data.**

## Data Storage

All data — including character cards, chat logs, settings, and model files — is stored **locally on your device** in a directory you choose during setup. No data is sent to external servers unless you explicitly enable a feature that requires it (see below).

## Cloud Sync (Optional)

If you enable the optional **Cloud Sync** feature, Front Porch AI will upload your chat session files and character card images to a cloud storage account **that you own and control**. Supported providers include:

- **Nextcloud / WebDAV** — Your self-hosted or third-party WebDAV server
- **Google Drive** — Your personal Google account
- **OneDrive** — Your personal Microsoft account

**Important:**
- Cloud Sync is **disabled by default** and must be explicitly enabled in Settings.
- Data is synced **only to your own account**. The developers have no access to your files.
- Authentication credentials (OAuth tokens, passwords) are stored locally on your device and are never transmitted to us.
- You can disconnect and delete your synced data at any time through your cloud provider's interface.

## AI / Language Models

Front Porch AI supports both local and remote language models:

- **Local models** (KoboldCPP) run entirely on your hardware. No data leaves your machine.
- **Remote APIs** (OpenRouter, etc.) send your chat prompts to the API provider you configure. Please review the privacy policy of your chosen API provider.

## Text-to-Speech

TTS processing occurs locally (Kokoro, Piper) or via an API you configure (OpenAI TTS). No audio data is collected by us.

## Analytics & Telemetry

Front Porch AI does **not** include any analytics, telemetry, crash reporting, or tracking of any kind.

## Contact

If you have questions about this privacy policy, please open an issue on our [GitHub repository](https://github.com/linux4life1/front-porch-AI).
