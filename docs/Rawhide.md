# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.
**Only list what landed after the last shipped nightly.** Clear this section when a new nightly goes out — delete the old bullets; do not accumulate them.

## Recent improvements (unreleased — ships in the next build)

- 🔌 **The chat box says when the AI is disconnected** — if the backend or API is down, the placeholder reads "No API connection" instead of looking ready. When it comes back, the normal hint returns. Same on the phone.

- 📋 **Pick a greet or a regenerated reply from a list** — cards with several greets, and replies you regenerated a bunch of times, get a list button. Each row is a short snippet plus the character count, with Current on the one you are on. Tap one to switch. The greet's regenerate button is gone (greets are on the card, not generated). Same on the phone.

- 📖 **Journal, recap, and memory text use a few lines, then expand on tap** — they no longer cut off with an ellipsis while the sidebar still has room. Tap to read the rest; tap again to fold. Same on the phone.

- 📁 **A folder you pick as the data directory stays that folder** — it is not wrapped in another FrontPorchAI folder after restart. Group portraits and chat backgrounds stay with the rest of the library. The default location is still the same on every OS.

- 📖 **"Where we are" survives a model switch** — changing models and regenerating the last reply no longer blanks the recap. It still clears if you rewrite something the recap had already covered.

- 📂 **Chat History from Home** — right-click a character or group and pick Chat History. Same list as the folder icon in a chat: open, rename, or delete a conversation. Deleting a chat from Home does not start a new one.

- 👜 **Work is a real section** — same card as Ambitions on desktop and phone. Occupation is the title; **What the job is** is the short brief the model uses when they're at work. Leave it blank and today stays today. Start and End show the time you picked.

- 📅 **Pick the days they work** — seven chips under the hours (M T W T F S S). A job with hours and no days saved is **weekdays**. Tap Sat/Sun for weekend shifts. Overnight hours still belong to the day the shift started. A weekday job on Sunday is told it is a day off — they will not invent a shift. A weekday morning before the start is "not at work yet."

- 💼 **Work can stick after they clock out** — sometimes (not most days) a small thing from the shift is still on them, and they may mention it. Old moments can rarely come up the way a person says "that reminds me." No extra switch — the diary and a job plus a moving clock are enough. Chance Time is still the party wheel.

- 🌅 **"We slept through the night" is morning** — the clock jumps to 8am *before* they write, and they wake rested (energy comes with the skip). "Let's go to bed" is still tonight: tired now, rest on the next turn. `(OOC: skip to morning)` does the same jump.

- 💼 **Group chats get the job brief** — when a member is at work in a group, the model now sees their job title and **What the job is**, same as 1:1. Hours still decide whether they are at work.

- 🧥 **Put clothes back on** — if the model strips them, Wearing still shows while empty. Tap Put clothes on (or the plus, then Wearing), type `coat`, They're wearing this. Next reply they're dressed. Add quietly stays for keys in a pocket — it is gone on Wearing. Desktop and phone.

- 🚽 **Hunger and bathroom nag less** — characters don't keep eating and peeing just because a few turns passed. They still will when it's actually time.

- 👗 **Wearing nothing is undressed, not a garment named "nothing"** — if the character takes everything off, the Wearing row is empty. The clothes go to Set aside. A leftover "nothing" chip on an old chat can be tapped off with the X.

- 📅 **Season starts use the calendar** — tap the date on a season card for the same calendar Story begins uses (not a month dropdown). Leap years count; Feb 29 is a real start. Same start twice, or a missing season, blocks save.

- 🕘 **`[6 hours passed]` is six hours** — a skip chip and the clock on the strip now land on the same time. Skip to 2pm still lands on 2pm. "I waited 6 hours" is not a skip.
