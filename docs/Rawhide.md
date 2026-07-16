# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.

## Recent improvements (unreleased — ships in the next build)

- 🖼️ **Draw Things connects in the installed app now** — the new built-in connection had a certificate bug that only showed up outside development, so installed builds couldn't reach Draw Things at all. Fixed and verified against a live Draw Things server; connection tests and generations both show up in the Engine Status panel.
- ⭐ **Starring an avatar now really changes the card — everywhere** — the ★ in the Avatar Gallery updates the character's face across the whole app: library card, folder previews, open chats (sidebar, header, message bubbles, character pickers), the web app, and exports. One face per character. You can also finally delete the original portrait: the starred avatar steps up as the new portrait in its place. Bonus: star clicks no longer repaint the home screen behind the gallery.
- 🚩 **The "NSFW Tasks" switch stays on** — the objectives panel's NSFW toggle (and the task count) quietly reset after every message; they now hold for your whole session. (They still start OFF on each app launch, on purpose.)
- 🔧 Under-the-hood fixes and polish.
