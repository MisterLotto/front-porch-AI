# Rawhide — What's New (Nightlies)

These notes feed the in-app "Update Available" dialog for Rawhide / cutting-edge builds.

## Recent improvements (unreleased — ships in the next build)

- 🧹 **Fixed: "Database Cleanup" was throwing away your objectives and chat memory** — The cleanup tool in Settings decided which rows still belonged to a living character by comparing two different kinds of ID, so the answer was always "nobody owns this." On my own library that meant it would have deleted **all 107 objectives and all 68 stored chat memories** — everything, not the leftovers — while reporting it as tidying up. It now matches rows the way the app actually stores them and removes only genuinely abandoned ones (8 of those 107, all belonging to characters that really were deleted). If you ever ran Database Cleanup and your characters' goals vanished, this was why.

- ♻️ **Fixed: cancelling a regenerate could delete the message you were regenerating** — Hitting regenerate and then cancelling while the realism check was still running made the original reply disappear for good, along with all of its swipes. The message is now put back whenever you cancel.

- 🔊 **Fixed: Kokoro was ignoring the voice you picked** — Choosing a male voice could quietly speak in a woman's voice instead. Two things were wrong. The voice list offered three voices — Beta, Santa and Yibo — that aren't in the speech model at all, and *any* voice it couldn't find silently fell back to Heart, a female voice, without a word in the log. The list is now built from the speech model itself, so it can only ever show voices that genuinely exist — including three real ones it had been hiding (Nezumi, Tebukuro and Yunjian) — and anything unrecognised now falls back within the same language *and* gender. One more thing worth knowing: a character with its own assigned voice keeps using that voice, not the one in Settings. That was always true but nothing said so, which is the other half of "I changed the voice and nothing happened" — the Settings screen now spells it out.

- 🏡 **Your Stoop page grew up** — Tapping your name on The Stoop used to show a bare list of uploads. It's now a real profile: your picture (or your amber monogram), when you joined the porch, your followers and lifetime stats (cards · downloads · net votes), a bio, and up to four links — with an **Edit Profile** button to set all of it and a **Share** button that copies your public page link. Your uploads sit underneath as an art grid — status chip on the artwork, compact update/delete, tap a rejected card's ember pill to read the moderator's note — followed by the creators you follow and your download history. Other creators' pages got the same treatment — and all of it on the web app too.

- 🖼️ **Profile pictures came to The Stoop** — Pick a photo and it shows next to your name everywhere — instantly, no waiting for review. Fair warning baked in: avatars appear on pages visitors can see, so keep them porch-front friendly — a moderator can take one down, and that counts as a formal warning. Requires a confirmed email, so drive-by accounts can't post images at all.

- 🔑 **Forgot your password? You can finally get back in** — A "Forgot password?" link now lives on the Stoop sign-in screen (app, web app, and the hub site). Enter your email, click the link that arrives, choose a new password — done. The link works once, expires in 45 minutes, signs out every old session, and still asks for your authenticator code if you have 2FA on.

- 📮 **Moving mailboxes? Change your sign-in email** — Account sheet (and the web app and hub site) now has **Change email**: enter the new address and your password, click the link that lands in the NEW inbox, done. Nothing switches until that link is opened, your old address gets a heads-up so nobody can quietly re-point your account, and confirming also proves the address for sharing and profile photos.

- 🗑️ **Take your own cards off the porch** — Your profile's upload grid now has a Delete button on every tile, so removing something you shared no longer means messaging the mods.

- 🎨 **Fixed: fancy chat themes were eating your buttons** — With any of the 10 community theme presets active (Fantasy, Sakura, Cyberpunk…), the edit, fork, and delete buttons on messages — plus the speak button and thought toggles — silently stopped responding. The decorative border was invisibly sitting on top of them and swallowing every click. All buttons work under every theme now.

- 🍽️ **Deleting a message now gives back what it cost** — If a reply dropped a character's hunger by 20, deleting that message left them 20 hungrier forever — the chip on the timeline said the cost happened, but nothing could undo it. Deleting a message now subtracts its needs changes from the current scores, whether it's the newest message or one buried twenty turns back.

- 💬 **"Start New Chat" right from the card — and it asks who you are** — Right-click any character or group cast on the Home Screen and pick **Start New Chat** for a clean slate, without opening the old conversation first. Because the same character can be met by a different you, it then asks **which persona** you're walking in as (your current one is marked, but nothing is assumed) — and that's the persona the new chat is saved under. On desktop and in the web library.

- 🖱️ **Drag group casts into folders — and dragging starts twice as fast** — Group cards couldn't be dragged onto a folder at all (only characters could); now they drag exactly like characters do. The press-and-hold before a drag begins is also half what it was, so organising your library stops feeling like the app missed your click.

