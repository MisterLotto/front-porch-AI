# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.

## Recent improvements (unreleased — ships in the next build)

- ✏️ **Output Sanitizer: `*` now works, and there's a proper guide** — The find field accepts `*` (zero or more) alongside `?` and `+`, so `\d*` means "any number of digits" like you'd expect. New guide at `docs/output-sanitizer-syntax.md` walks through the whole find/replace syntax in plain language, with worked examples — including two gotchas: write the closing bracket as a bare `)` when it's outside a capture group, and remember the `\a` / `\l` / `\p` wildcards don't work *inside* a capture group (use `[a-zA-Z]` and friends there instead). Thanks to @S-A-M-F for both.

- 🔁 **Fixed characters suddenly repeating old messages after the last update** — A long-standing hidden bug had quietly copied generation settings between chats behind the scenes, and the previous update accidentally switched those stale copies on — pinning old sampler values (like repetition penalty) to your chats and making some characters loop or echo earlier messages no matter what you changed in Settings. This build cleans those stale per-chat overrides out of your existing chats automatically. Your global generation settings apply again everywhere. If you had *intentionally* set custom per-chat generation settings on a specific chat, you'll need to re-apply them once via Chat Settings (your Output Sanitizer per-chat settings are kept).

- 🎭 **Mafia nights come home to The Journal** — Finish a game of LLMerta with your Front Porch persona and FPA characters at the table, then open that character chat: the night lands as multiple diary cards with real table facts (roles, win/loss, bus/defend, day beats). Their **next reply must open with actual post-game talk** (“good game”, “I thought you were Town”, the bus) — not a soft metaphor for the current scene. Regen of that reply keeps the force-ack until you send another message. Toggle under Journal gear → *Import Mafia game nights* (on by default).
