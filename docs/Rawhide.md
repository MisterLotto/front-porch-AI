# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.

## Recent Improvements

- 💗 **Character starting Bond is no longer doubled on new chats** — if a character card set an initial Short-Term Bond (e.g. 55), starting a fresh chat was silently doubling it (to 110) every time. Cards already store this value on the current scale, so the doubling was a leftover from an old data migration. New chats now seed exactly the Bond the card author intended. (Trust and other seeded values were already correct.)

- 🛡️ **Fixed a rare crash when closing a chat mid-load** — switching characters or closing a chat while it was still loading objectives could throw a "used after disposed" error in the background. The chat service now safely ignores those late updates.

- 📦 **MacOS Notarization Fixed** — Mac builds should actually pass Apple's notarization Gatekeeper now! We've completely overhauled the CI pipeline to generate a proper, fully signed and stapled `.pkg` installer instead of a `.dmg`.
- 🚧 **Auto-Updater Notice** — Please note that the in-app macOS auto-updater is temporarily broken by the `.pkg` switch. It will be fully repaired after the upcoming major refactoring is completed.
