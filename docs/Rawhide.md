# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.
**Only list what landed after the last shipped nightly.** Clear or rewrite this section when a new nightly goes out — do not accumulate history since stable.

## Recent improvements (unreleased — ships in the next build)

*Since nightly `20260811` (`aa66f57` — web eraser).*

- 🧠 **Memory (RAG) sidebar got real setup feedback** — Settings say what they do (“past moments per reply”), and if the local model isn’t there you get Download / a progress bar / a real error + Retry — not a dead “Model not downloaded” dot. Web tools mirror the status (download still runs on the desktop host).
- 🎒 **Belongings get their own Journal tab** — Placement notes (“I set my jacket down by the hot tub”) live under Journal → **Belongings** next to Promises / Our Story (count badge included). Same surface on the web tools sidebar. The diary section for these cards no longer crashes the editor.
- 📍 **"Where we are" forgets discarded scenes** — Regen or delete clears a stale story recap until the Journal rewrites it from the real timeline (better empty than wrong).
- 🧹 **Eraser clears the diary note too** — Striking an item off with ✕ also drops its Belongings memory, so “where are my keys?” doesn’t keep claiming a placement you deleted.
- ⏪ **Group gifts and diary cards rewind cleanly** — Handing Sam the keys then regenerating restores **both** inventories (no phantom gift). Placement cards from a rejected “keys on the table” reply are purged with the rewrite.
- 🔁 **Thinking models stop replaying prior plans** — Hidden reasoning stays in the collapsible thinking view only, on every generation path (including overflow / Continue). Continue is plain transcript + partial again — no leftover journal/world state blocks fighting the line.
- 🚀 **Long chats keep a stable history window** — Once old messages scroll out of context, they stay out, so local backends (oMLX, KoboldCpp, LM Studio) can actually use their prompt cache. Very deep @depth lore stays near recent turns so it doesn’t thrash that prefix.
- 📅 **Memory day stamps work with Realism off** — When Passage of Time runs alone, retrieved memories still get a story-day stamp so old words don’t read like they just happened.
