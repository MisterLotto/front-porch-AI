# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.

## Recent improvements (unreleased — ships in the next build)

- 📜 **About & License in Settings** — a new About & License section (in General settings, on both desktop and the web/mobile UI) shows the app version, states that Front Porch AI is free and open-source under the AGPL-3.0, and links straight to the source code so you can always get, study, and rebuild it.
- 🏡 **Moving in from Backyard AI just got a lot more faithful** — importing a .byaf character now keeps its example dialogue (the biggest driver of a character's voice and writing style), so imported characters finally sound like they did in Backyard. The importer also offers a new "Apply Backyard settings" option that carries over the character's original sampler settings (temperature, min-p, repetition penalty, …) into the imported chat, instead of showing them as a read-only preview and throwing them away.
- 🧠 **GPU acceleration now just works** — the app picks the right acceleration automatically (CUDA for NVIDIA, Vulkan for AMD/Intel, Metal on Mac); the confusing backend chips moved into an Advanced section for tinkerers. AMD users who explicitly enable ROCm now get the required card-specific setup applied automatically instead of a crash.
- 🚀 **Smoother chats, especially on Windows** — a recent change made the app re-check avatar images on disk far more often than needed while a reply was streaming in, which could make everything feel sluggish and delay replies showing up on screen. That work is now done once and remembered, so long chats stay fast.
- 📞 **Voice calls fixed and rebuilt** — the bug where the call showed "Speaking" for a split second but never actually read the character's reply aloud is gone. The whole call loop was rewritten to be rock-solid: it now always waits for the character to finish speaking before listening again, the mic can no longer "hear" the character's own voice and send it back as your message, and one bad sentence no longer silences the rest of the reply.
- 📖 **"Read to me" actually stops when you tell it to** — in Porch Stories, the stop button only prevented upcoming pages from being prepared while the current narration played on to the end (and leaving the reader could leave the voice running too). Stop now silences the narration immediately, everywhere.
- 🔧 Under-the-hood fixes and polish.
