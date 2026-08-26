# What's New

These notes feed the in-app "Update Available" dialog for stable releases on `main`.

## v1.3.1 — Clock In

- 🕘 **They clock in** — occupation, which weekdays, hours on the job. Skip a turn and the banner says they're at work. A night skip lets them rest. Same on the phone.

- 🕰️ **Time is said first, then they write** — the prompt tells them what time it is; after the reply the clock decides how much passed. Continue does not tick. Same on the phone.

- 👤 **With you is a yes or a no** — scored after they speak, not assumed. If they're at work, they're at work.

- 🛠️ **Built on Flutter 3.47** — current stable Flutter. macOS 12 Monterey is the floor.

### Fixes and improvements

- 🛟 **Renaming a chat from Chat History no longer resets Porch Life** — Realism, Needs, Chaos, and the relationship numbers stay put.

- ▶️ **Continue keeps speaking as whoever started the line** — a Scene Guest or a group member with a shared name is not hijacked by the host.

- 👜 **Taking back a gift from the middle of a group chat returns it on both sides** — unique things no longer exist twice. Swiping a set-down keeps the diary matching the kit.

- 🧹 **Deleting a group takes its diary, growth, and memories with it** — leftover knowledge does not keep showing up. Deleting a character drops their Data Bank too.

- 🌦️ **Places can have their own seasons** — two to eight, with start days you pick. Same on the phone.

- 🧠 **Memory leads with the gist** — recall starts from the summary, then the quotes when they help.

- 🎭 **Alternate greetings seed Realism and Needs** — bond, mood, hunger and the rest, same cards as the editor.

- ⑂ **Fork a chat from the phone** — new branch from this message; the old conversation stays put.

- 🎛️ **Phone Settings has the rest of the sampler row** — Top-P, Top-K, DRY, dynatemp, stops, bans, sanitise-history, the system prompt. Voice & Media can turn speech on.

- 👥 **Stoop groups and places show their real contents on the phone** — members and greetings; climate and lore for worlds. Comments go to the hub.

- 🔐 **Signing Tailscale in from the phone asks for your web password** — a stolen session cannot bind this computer to someone else's tailnet.

- 💡 **Light mode is readable** on Group Settings, Chat History, Database Cleanup, and the Kobold log.

- 🧼 **Filthy means they reek** — the meter stays down until they wash. Characters who enjoy being musky still like it.

- 💛 **Intimate preferences can change the direction of a score**, not only how hard it hits.

## v1.3 — Check Your Pockets

- 🎁 **Pockets & Wardrobe** — she has pockets, clothes, and a set-aside pile. Hand her something, take it back, she can pass it to someone else. Authors can send her into a chat already dressed and carrying things. The Journal keeps a Belongings tab of where things went. Own switch — does not need the Realism Engine.
- ✨ **AI Enhance** — grow a character from a real chat. Walks you through it, and can bring those chats along.
- 🏡 **Porch Life** — one Settings home for every living-character switch, instead of hunting them across the app.
- 🎛️ **À la carte** — Journal, Chaos / Chance Time, the story clock, Pockets, and Objectives each have their own switch. Turn on what you want. Realism Engine is no longer the master key.
- 💛 **Likes & Dislikes** — give her tastes (thunderstorms, being interrupted) and she acts on them. Moments that hit what she actually cares about move the relationship harder.
- 🔥 **Intimate preferences get said** — not just scored in the background. She can ask for what she wants, and she can turn something down.
- 🌱 **Ambitions drive her quests** — her long-term goals pick the next quest instead of sitting unused on the card. You can set them when you create her.
- 🌧️ **A bad day that isn't about you** — optional, off by default, in Porch Life. She can arrive tired, hungry, or weather-beaten from her own life, and the sidebar says why. Nothing is invented.
- 📦 **Take a chat with you** — export a conversation as a Front Porch chat file (history, diary, growth, the lot) or SillyTavern JSONL. Bring it back on desktop or the phone.
- ✍️ **Impersonate on the phone** — the same wand as desktop. A start you already typed is continued as you.

### Fixed since 1.2.0.1

- 📖 **"Turn this chat into a story" actually creates the project.**
- 🛟 **A failed regenerate can no longer eat the message.**
- 💾 **Restoring a backup now really restores the open chat.**
- 🐧 **Linux self-update can't uninstall the app.**
