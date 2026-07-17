# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.

## Recent improvements (unreleased — ships in the next build)

- 🧠 **GPU acceleration now just works** — the app picks the right acceleration automatically (CUDA for NVIDIA, Vulkan for AMD/Intel, Metal on Mac); the confusing backend chips moved into an Advanced section for tinkerers. AMD users who explicitly enable ROCm now get the required card-specific setup applied automatically instead of a crash.
- 📞 **Voice calls fixed and rebuilt** — the bug where the call showed "Speaking" for a split second but never actually read the character's reply aloud is gone. The whole call loop was rewritten to be rock-solid: it now always waits for the character to finish speaking before listening again, the mic can no longer "hear" the character's own voice and send it back as your message, and one bad sentence no longer silences the rest of the reply.

- 🖼️ **Draw Things connects in the installed app now** — the new built-in connection had two stacked bugs (a certificate check that could never pass, and Draw Things' compressed replies being rejected), so installed builds couldn't reach Draw Things at all. Both fixed and verified against a live Draw Things server; connection tests and generations show up in the Engine Status panel.
- ⭐ **Starring an avatar now really changes the card — everywhere** — the ★ in the Avatar Gallery updates the character's face across the whole app: library card, folder previews, open chats (sidebar, header, message bubbles, character pickers), the web app, and exports. One face per character. You can also finally delete the original portrait: the starred avatar steps up as the new portrait in its place. Bonus: star clicks no longer repaint the home screen behind the gallery.
- 🚩 **The "NSFW Tasks" switch stays on** — the objectives panel's NSFW toggle (and the task count) quietly reset after every message; they now hold for your whole session. (They still start OFF on each app launch, on purpose.)
- 🔧 Under-the-hood fixes and polish.
