# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.
**Only list what landed after the last shipped nightly.** Clear or rewrite this section when a new nightly goes out — do not accumulate history since stable.

## Recent improvements (unreleased — ships in the next build)

*Since nightly `20260814` (`cd38e672` — sidebar overflow).*

- 🎭 **Scene Guests answer the line you just sent** — after a long stretch talking to one guest (name first), bringing the narrator back in used to make that guest reply to an older question further up the chat. Regen usually fixed it; eventually it got stuck. The guest turn now pins your most recent line, a squeezed context can no longer drop that line and keep only the narrator's reaction, and guest turns no longer pull Memory search or a stale "Where we are" into the prompt (thinking models were treating those old lines as the live question).

- ▶️ **Continue no longer mashes the last word into the next one** — hitting Continue used to glue the new text straight onto whatever was already there, so "She waved from the steps." plus "Then she sat" became "steps.Then". Models often skip the leading space. Continue now puts a word-break in (same as editing a space onto the end yourself) and will not add a second space if the model already sent one.

- 🔧 **Kimi 2.6 thinking evals work again** — The first Realism judge was 400ing because that model cannot turn thinking off, then the fallback hid the answer inside discarded thought tokens (90 seconds, then a blank line). Judges now keep that channel and parse the JSON out of it. Needs and pockets already worked; bond/trust/emotion/time catch up.

- 🕐 **If she says it is 6am, the clock becomes 6am** — After a night skip the story clock used to park at 8:00 AM even when she wrote dawn. The sidebar now follows a time she actually names in the reply (within a few hours), so the line you just read and the clock agree. Regen that reply on an old chat to heal it.

- 🧠 **Local models stop pretending they can think** — Thinking strength used to show Low · Medium · High for every local model, including the many that have no thinking mode at all, so the setting quietly did nothing. Front Porch now reads the model file itself and tells you the truth: a model with no reasoning says so and the switch is greyed out; one that only does on/off says it has no strength levels instead of showing three that don't work; one that can't stop thinking locks Off; and only models with real levels show the chips. No extra requests and no waiting — the answer comes from the file you already loaded. Same on the web Settings. **KoboldCpp, oMLX, and LM Studio** all do this now. Front Porch never loads a model just to ask — it reads the template off disk.

- 🎁 **Hand her something in the story and she actually has it** — Typing "here, take my keys" and having her pocket them used to leave her record empty: the bookkeeping was told to ignore anything she "was offered", which is exactly what your gift looks like. Now an offer she **accepts** goes into her pockets, while one she ignores or turns down still counts for nothing. This is the only kind of handover a 1:1 chat has, so giving your character things by narration works there now — the same as passing an item between characters in a group. (The sidebar's **Hand it over** button still does it directly if you'd rather not leave it to the story.)

- 🧹 **Scan & Clean no longer wipes group memory or your “remember these characters” lists** — group chat archives and those checkboxes were being treated as leftovers. They stay.
- ▶️ **Continue no longer eats Chance Time / night-porch / “she picked up the keys” / a Needs crash** — those still fire on the next real Send. And if you Stop mid-thought then Continue, the new words show up as spoken text, not a blank bubble.
- 🌙 **A dream cannot land in the wrong chat** if you switch conversations while it is still writing.
- 🎁 **Group gifts survive a fork, and swipe will not duplicate them.** Picking an item up also forgets the old “I set it down” diary note. Forking keeps the diary cards; the “Where we are” recap starts a new chapter until enough new turns land.
- 💾 **Group Settings → General actually saves** (name, scenario, first message, turn rules). Light mode no longer paints those fields — or Create Character’s later headings — as white-on-cream.

- 🖼️ **Web chat asks before loading pictures from the internet** — a `![alt](https://…)` in a message no longer fetches on its own. You get a **Load external image?** button first (same idea as desktop's External Image Detected). Only real `http`/`https` links count; other schemes stay as text.
- 🎯 **Web Objectives stay off when you turn them off** — the sidebar hides the quest details, and Generate tasks / Set a goal are refused until Objectives is on again.
- 📓 **Web Journal edits stay in that character's diary** — pin / edit / retire only touch cards for the focused speaker in this chat.
- 🛡️ **Lore-from-URL and web backend "test connection" ignore private addresses** — localhost, LAN, and cloud-metadata URLs are refused so a logged-in web session cannot poke the host's network.
