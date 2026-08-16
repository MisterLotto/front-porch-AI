# What's New

These notes feed the in-app "Update Available" dialog for stable releases on `main`.

## v1.3

- ✍️ **Impersonate is on the phone too** — the same wand as desktop. A start you already typed is continued as you, not answered as the character.
- 🕐 **If she says it is 6am, the clock becomes 6am** — the sidebar follows a time she actually names in the reply.
- 🧠 **Local models stop pretending they can think** — no thinking switch for models that have none; on/off when that's all they have; strength chips only when they're real.
- 🎁 **Hand her something and she actually has it** — an offer she accepts goes into her pockets. Same on a 1:1 as passing an item in a group.
- 💛 **Long-term bond notices a stretch a little sooner** — every 3 warm turns instead of 5. Existing chats keep the score they already earned.

### Fixed since 1.2.0.1

- 📖 **"Turn this chat into a story" actually creates the project** — it used to save nothing, then error, on desktop and web.
- 🛟 **A failed regenerate can no longer eat the message** — the original reply and its swipes come back if the backend errors or you cancel.
- 💾 **Restoring a backup now really restores the open chat** — it used to write the old conversation back into the snapshot the next time you sent a line.
- 🐧 **Linux self-update can't uninstall the app** — a bad download no longer deletes the running AppImage first.
