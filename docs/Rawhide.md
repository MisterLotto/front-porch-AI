# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.

## Recent improvements (unreleased — ships in the next build)

- 🧠 **GPU acceleration now just works** — the app picks the right acceleration automatically (CUDA for NVIDIA, Vulkan for AMD/Intel, Metal on Mac); the confusing backend chips moved into an Advanced section for tinkerers. AMD users who explicitly enable ROCm now get the required card-specific setup applied automatically instead of a crash.
- 🚀 **Fixed: yesterday's nightly got slow and janky on Windows** — avatar images were being checked on disk for every message bubble, every frame while your character typed. On Windows that made the whole app sluggish and replies could seem to never arrive (they were there — the screen just wasn't keeping up). If you rolled back over this, it's safe to come forward again.
- 📞 **Voice calls fixed and rebuilt** — the bug where the call showed "Speaking" for a split second but never actually read the character's reply aloud is gone. The whole call loop was rewritten to be rock-solid: it now always waits for the character to finish speaking before listening again, the mic can no longer "hear" the character's own voice and send it back as your message, and one bad sentence no longer silences the rest of the reply.
- 🔧 Under-the-hood fixes and polish.
