# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.

## Recent improvements (unreleased — ships in the next build)

- 🪶 **The app is dramatically smaller and faster to install** — the old Python-based speech and image helpers are gone for good. Voice, dictation, character expressions, and Draw Things all run on the new built-in engines that you've been soaking — no bundled Python, over a gigabyte lighter, and faster to sign, download, and update.
- 🧹 **One-click "Reclaim Disk Space"** — Settings → Voice & Media now offers to delete the old engines' leftover model files (up to ~2 GB for some setups). It only appears if you actually have old files, and your voices and settings are untouched.
- 🎙️ **Voice input from your phone/browser got lighter too** — the web mic now records in a format the built-in engine reads directly, so uploads are smaller and transcription starts sooner.
- 🗣️ **Piper voice installs are smarter** — installing a voice now downloads the model the app actually plays (no more dead-weight files). Heads up: hand-made custom Piper voices aren't supported by the new engine and will ask you to pick a standard voice instead.
- 🧠 **GPU acceleration now just works** — the app picks the right acceleration automatically (CUDA for NVIDIA, Vulkan for AMD/Intel, Metal on Mac); the confusing backend chips moved into an Advanced section for tinkerers. AMD users who explicitly enable ROCm now get the required card-specific setup applied automatically instead of a crash.
- 🚀 **Smoother chats, especially on Windows** — a recent change made the app re-check avatar images on disk far more often than needed while a reply was streaming in, which could make everything feel sluggish and delay replies showing up on screen. That work is now done once and remembered, so long chats stay fast.
- 📞 **Voice calls fixed and rebuilt** — the bug where the call showed "Speaking" for a split second but never actually read the character's reply aloud is gone. The whole call loop was rewritten to be rock-solid: it now always waits for the character to finish speaking before listening again, the mic can no longer "hear" the character's own voice and send it back as your message, and one bad sentence no longer silences the rest of the reply.
- 🔧 Under-the-hood fixes and polish.
