# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.
Keep this list **short and current** — only user-visible work still ahead of the last stable.
When a stable ships, promote the bullets that land into the release body and clear them here.

## Recent improvements (unreleased — ships in the next build)

### Belongings (Pockets & Wardrobe + Journal)

- 🔑 **She remembers where she put things** — Setting something down, handing it over, or changing outfits writes a Belongings memory automatically (no extra AI call). Mention the item later and it resurfaces; one live placement per item.
- 🎒 **Belongings tab** — Placement notes live under Journal → **Belongings** (desktop + web), not buried in a hundred diary lines.
- 👗 **Set aside** — Undressing or setting things down parks them in a greyed **Set aside** row (clothes expire overnight; possessions stay until she picks them up or you ✕ them). Web chips get the same eraser as desktop.
- ⏪ **Regen / swipe / delete rewind her kit** — Rejecting a “hands you the keys” reply restores both inventories (including group gifts) and drops phantom placement cards. Deleting a follow-up user line no longer rewinds the bot’s kit. Eraser also clears the diary note for that item.

### Long chats & thinking models

- 🚀 **Local backends keep their prompt cache on long chats** — The history window no longer flip-flops which old messages drop; once scrolled out, they stay out. Very deep @depth lore stays near recent turns so it doesn’t thrash the same prefix.
- 🔁 **Thinking models stop replaying prior plans** — Hidden reasoning stays in the collapsible “thinking” view only; Continue is plain transcript + partial again (no leftover journal/world blocks).

### Memory, recap & Realism

- 📍 **"Where we are" forgets discarded scenes** — Regen or delete clears a stale recap until the Journal rewrites it from the real timeline.
- 📖 **Recap is written first** on journal passes, so busy updates don’t run out of room and drop “Where we are.”
- 🧠 **Memory receipts + story-day stamps** — Sidebar (and web) show what was retrieved and from which day; old memories no longer read like they just happened.
- ⚡ **Faster background judges** — One-Shot Eval **Auto** default; shared judge prefix; fused post-reply bookkeeping; long replies excerpted for judges; quest checks on schedule; dreams written at end of evening so morning sends don’t wait.

### Fixes that matter in chat

- 🛠️ **Switching chats no longer corrupts the message list** — Bubble keys are page-owned (the stacked-route crash class).
- 🧭 **Position after she moves** — Posture is scored after the reply she just wrote, survives reopen, and grounds the next turn (1:1 and group).
- 📅 **Story date stops following the real calendar** — Opening an old chat no longer renames the weekday; time skips ignore quoted dialogue.
- 🍽️ **Needs no longer crater 35–40 points from describing hunger** — Describing a state isn’t counted as depleting it further.
- 🔌 **Pockets, Ambitions, clock, etc. work with Realism off** — Their prompt block was wrongly gated on the engine.
- 🎭 **Downloaded cards pick up your Porch Life defaults** — Realism / Afterglow / Chaos global defaults apply when the card has no saved Front Porch settings.
- 🎲 **Chaos Mode global default** — Settings → Porch Life; new chats honor it (groups included).
- 🔎 **“Notice new characters” can be turned off** — Settings → Porch Life.

### The Stoop & cards

- 🔞 **Intimate preferences auto-tag 18+** on share (app + hub).
- 🧭 **Hub shows ambitions, likes, and wardrobe** before download.
- 👗 **Wardrobe visible on message 0** and **editor wardrobe actually saves**.
- 🧥 **Group member cards show wardrobe** with tap-to-remove on desktop.
