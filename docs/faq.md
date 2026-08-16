# Frequently Asked Questions

Straight answers to the questions I get most often. If yours isn't here, the [Discord community](https://discord.gg/e4tET6rpdv) is friendly and fast.

---

## Table of Contents

### General
- [Is Front Porch AI free?](#is-front-porch-ai-free)
- [Is my data private?](#is-my-data-private)
- [What platforms are supported?](#what-platforms-are-supported)
- [Do I need an internet connection?](#do-i-need-an-internet-connection)
- [What's the difference between Stable and Nightly builds?](#whats-the-difference-between-stable-and-nightly-builds)

### AI & Models
- [What AI models can I use?](#what-ai-models-can-i-use)
- [How do I choose a model?](#how-do-i-choose-a-model)
- [Can I use OpenAI / Claude / Google models?](#can-i-use-openai--claude--google-models)
- [Why is the AI slow?](#why-is-the-ai-slow)
- [Why does the AI repeat itself?](#why-does-the-ai-repeat-itself)

### Characters
- [Where can I find characters?](#where-can-i-find-characters)
- [Can I use my SillyTavern or Backyard AI characters?](#can-i-use-my-sillytavern-or-backyard-ai-characters)
- [Why isn't my character acting right?](#why-isnt-my-character-acting-right)

### The Stoop
- [What is The Stoop?](#what-is-the-stoop)
- [Can I share Worlds too?](#can-i-share-worlds-too)
- [What data does The Stoop collect?](#what-data-does-the-stoop-collect)

### Voice
- [Why isn't the voice (TTS) working?](#why-isnt-the-voice-tts-working)
- [How do I get better-sounding voices?](#how-do-i-get-better-sounding-voices)
- [Why does voice call mode send my message too early?](#why-does-voice-call-mode-send-my-message-too-early)

### Realism Engine
- [What is the Realism Engine?](#what-is-the-realism-engine)
- [Does the Realism Engine slow down my chats?](#does-the-realism-engine-slow-down-my-chats)
- [How do I reset a character's bond and trust?](#how-do-i-reset-a-characters-bond-and-trust)

### Your Data & Devices
- [How do backups work?](#how-do-backups-work)
- [Where is my data stored?](#where-is-my-data-stored)
- [Can I chat from my phone or another computer?](#can-i-chat-from-my-phone-or-another-computer)
- [Can I sync between two computers?](#can-i-sync-between-two-computers)
- [How do updates work?](#how-do-updates-work)
- [How do I report a bug?](#how-do-i-report-a-bug)

---

## General

### Is Front Porch AI free?

Yes — completely free and open-source (AGPL-3.0 license). Download it, use it, modify it, share it. There's no paid tier, no subscription, and no account required for the app itself.

A few *optional* third-party services have their own costs if you choose to use them — for example OpenRouter (remote AI models, pay per use) or ElevenLabs (premium cloud voices). Everything built into the app is free.

### Is my data private?

**Yes.** Front Porch AI is local-first: your characters, chats, memories, and settings live in a folder on your computer, and using the app offline sends nothing anywhere. There are no ads, no trackers, and no crash reporting.

Three optional features involve the internet, and only if you turn them on:

- **Remote AI APIs** (OpenRouter and similar) — your prompts go to that provider. Check their privacy policy.
- **Cloud voices** (ElevenLabs, OpenAI) — the text being spoken goes to that provider.
- **The Stoop** — the community character hub. It's the only part of the app that involves an online account or collects anything at all — see [What data does The Stoop collect?](#what-data-does-the-stoop-collect)

The full details are in the [Privacy Policy](https://github.com/linux4life1/front-porch-AI/blob/main/PRIVACY.md).

### What platforms are supported?

- **Windows** 10 and 11 — a normal `.exe` installer
- **macOS** — a signed, Apple-notarized `.pkg`. Apple Silicon (M-series) runs local models natively; Intel Macs can run the app, but local models are switched off there — the app says so and you switch yourself to **Remote API** in Settings → Backend
- **Linux** — the APT repo, the RPM repo, the AUR, or a standalone `.deb`, `.rpm`, AppImage, or `.tar.gz`

See the [Installation Guide](install.md) for step-by-step instructions.

### Do I need an internet connection?

Only for the initial setup: downloading the app, the AI engine, and a model. After that, everything core works fully offline — chatting, memory, local voices, image generation with a local backend, all of it.

Most of it needs nothing installed alongside it: speech, listening, emotion detection, and memory all run inside the app itself — no Python, no helper programs. There are two exceptions. The first is the AI engine for local models: the app downloads KoboldCpp for you and runs it as a local server, which you start and stop from Settings → Backend. The second is local image generation, which happens in a separate program you install and run yourself — Draw Things, ComfyUI, or an Automatic1111-style server. The app never downloads or launches that one; you just point it at the address the program is listening on.

You need to be online for: remote AI APIs, cloud voices, The Stoop, and downloading new models or voices.

### What's the difference between Stable and Nightly builds?

- **Stable** is the recommended download — tested, polished releases. The current one is **v1.2.0, "Occupy Mars"** (released 2026-08-01). The things that used to be nightly-only are in it, including The Stoop and changing a chat's cast on the fly with `/join`.
- **Nightly** builds come fresh from active development most days. You get new features first, but you may also hit rough edges.

Nightlies keep their data in a completely separate folder (`FrontPorchAI-Beta` — leftover name) with their own settings, so trying one never touches your stable characters and chats.

One thing to know before you switch: on nightlies the Backups & Restore page opens but its contents are replaced by a notice, so there is no way to browse or roll back a snapshot there. The automatic snapshots themselves keep running.

---

## AI & Models

### What AI models can I use?

**Local models (recommended for privacy):** any model in **GGUF format** — the standard file format for AI models that run on your own computer. That covers essentially every popular open model family: Llama, Mistral, Qwen, Gemma, Phi, DeepSeek, and many more. The built-in **Model Manager** (*Manage Models* in the sidebar) lets you search Hugging Face and download them without leaving the app.

**Remote models:** with an API key you can use OpenRouter (which offers hundreds of models including the biggest frontier ones), or any other OpenAI-compatible service.

### How do I choose a model?

The app detects your hardware automatically and suggests sensible settings, but here's the plain-English version:

| Your computer | Good starting point |
|---|---|
| 6–8 GB of GPU memory | A 7–9B model at Q4 quality — great balance of speed and personality |
| 12–16 GB of GPU memory | A 12–24B model — noticeably better writing and consistency |
| 24 GB or more | 32B and up — excellent reasoning and character depth |
| Apple Silicon Mac (16 GB+) | Most 7–13B models run beautifully |
| No dedicated GPU | A small 3–7B model, or use a remote API |

Two terms you'll see everywhere:

- **"7B", "13B" etc.** — the model's size in billions of parameters. Bigger is smarter but needs more memory and runs slower.
- **"Q4", "Q5" etc.** — quantization, i.e. how compressed the model file is. Q4 or Q5 is the sweet spot; quality loss is tiny and the memory savings are huge.

The Model Manager estimates whether a model fits your GPU *before* you download it. When in doubt, start small — modern 8B models are shockingly good at roleplay.

### Can I use OpenAI / Claude / Google models?

Yes. Add an **OpenRouter** key in Settings → Backend and you get access to virtually every major model through one account. You can also point the app at any OpenAI-compatible service (Nano-GPT and self-hosted servers included). Remote models work with everything — the Realism Engine, memory, voices, all of it.

### Why is the AI slow?

Almost always one of these:

- **The model is too big for your GPU**, so part of it spills over to regular RAM, which is much slower. Fix: use a smaller model or a more compressed version (Q4 instead of Q6/Q8), or lower the context size.
- **Too many GPU layers** — lower **GPU Layers** in Settings → Advanced so the model actually fits.
- **The app is running on CPU** without you realizing. Settings → Advanced shows the GPU it detected and a memory gauge; if the name is wrong or missing, see [Troubleshooting → GPU not detected](troubleshooting.md#gpu-not-detected).
- **Very large context sizes** (16k+) cost speed and memory even before the model starts writing.

See [Troubleshooting → Generation is slow](troubleshooting.md#generation-is-extremely-slow) for the full checklist.

### Why does the AI repeat itself?

Usually fixable with settings:

- Raise **Temperature** a little (0.8–1.1 works well for roleplay).
- Raise **Repeat Penalty** slightly (1.05–1.15).
- Try **DRY Strength** at around 0.8 — it catches repeated *phrases*, not just repeated words, which is usually what makes a character feel stuck.
- Check the character card — missing or weak **example dialogue** is the number-one cause of repetitive characters. A few good example exchanges work wonders.
- Some models are simply repetitive, especially at heavy compression. Try a different one — personality varies a lot between model families.

---

## Characters

### Where can I find characters?

- **The Stoop** — the community hub built right into the app: browse, follow creators, and download with one tap. It ships in the stable release.
- **Import a card file** — download a card (PNG or JSON) from any character site in your normal browser, then use **Import Cards** on the home screen and it lands straight in your library.
- **Anywhere character cards are shared** — Front Porch AI reads standard V2/V2.5 character card files (PNG or JSON), the same format the whole community uses.
- **Make your own** — the AI Character Creator goes from a one-line idea to a finished card, or walks you through it trait by trait if you'd rather steer. There's a fully manual step-by-step creator too.
- **The Discord** — people share cards and ideas in the [community Discord](https://discord.gg/e4tET6rpdv).

### Can I use my SillyTavern or Backyard AI characters?

Yes, directly:

- **SillyTavern cards** (PNG or JSON) import perfectly — **Import Cards** on the home screen takes many files at once, and **Import Folder** takes a whole directory.
- **Backyard AI archives** (`.byaf` files) have their own importer (**Import Backyard AI**), so your characters aren't stranded in that format.
- **Lorebooks** from SillyTavern, Chub, NovelAI, AgnAI and RisuAI come in through their own preview wizard.

Everything you create or edit is saved as standard, portable character cards too — no lock-in in either direction.

### Why isn't my character acting right?

In rough order of likelihood:

1. **The card is thin.** A character with no example dialogue and a two-line description gives the AI almost nothing to work with. Add example exchanges and specifics.
2. **The model is too small** for a subtle personality. Try a larger or newer model.
3. **Sampler settings are off.** Extremely low temperature makes characters robotic; extremely high makes them incoherent. Start at 0.85–1.0.
4. **A global system prompt is fighting the card.** If you've customized the system prompt in Settings → General, it can override character instructions.
5. **The Realism Engine is off.** Without it, characters have no persistent emotional state between turns. Turning it on adds bond, trust, mood, and memory of how your story has been going — see the [Realism Engine guide](realism-engine.md).

---

## The Stoop

### What is The Stoop?

The Stoop is a community character hub built into the app, and it ships in the stable release. Browse featured and moderator-picked cards, follow creators you like, vote, and download characters — including entire group casts with their lorebooks and Realism state intact — straight into your library. You can also browse it in any web browser at [hub.frontporchai.app](https://hub.frontporchai.app).

Your name on The Stoop is a real profile page: your picture, when you joined, your followers and lifetime stats, a short bio, up to four links, and your uploads underneath as an art grid. Every other creator gets the same page. A **confirmed email address** is what unlocks the parts of an account other people can see — a profile picture and sharing your own cards — so drive-by accounts can't post pictures at all.

It's opt-in, needs a free account, and is strictly 18+. Suggestive and 18+ cards stay hidden until you turn them on yourself. The rest of the app stays 100% local whether or not you ever open The Stoop.

### Can I share Worlds too?

Yes. A Place you've built — its lore, its cover art, and its climate (your own weather names and emoji, temperature bands, atmosphere and gravity) — can be posted to The Stoop exactly like a character, and downloading one imports it straight into your Worlds list. You can also hand the file to someone directly: the Worlds page has an **Import Place** button, and each place has its own **Export .fpworld** action.

One catch worth knowing before you send a file to a friend: **opening a `.fpworld` needs Front Porch AI 1.2 or newer.** Older installs can't import them, so if a place won't open, updating is the fix.

### What data does The Stoop collect?

Only if you sign in and use it:

- **Your account info** — email, display name, your 18+ confirmation, and a securely hashed password.
- **Your public profile, if you fill one in** — profile picture, bio, and links. All optional.
- **What you upload** — the cards you choose to share, obviously — plus account activity like votes and downloads.
- **Anti-abuse signals** — a salted, one-way *hash* of your IP address (never the raw IP) and an anonymous per-install id, used only to enforce bans and stop ban-evasion. These are automatically deleted after 90 days, and they're a condition of having an account: if you'd rather they weren't collected, don't make one — the rest of Front Porch works fully without it.
- **An anonymous stats ping** — your operating system and app version, your language setting, and your graphics card's name and how much memory it has, so I know what hardware to prioritize. The server sorts the card into a coarse tier (e.g. "NVIDIA · 8–12 GB") and never stores an IP. It's on by default but there's an off switch right on the sign-up screen and in Account settings. It never includes your chats or your characters.

Never collected: your conversations, your characters (unless you upload them), or anything from offline use. You can permanently delete your Stoop account from inside the app at any time, which erases your account, your uploads, your votes, and your messages. Full details: [Privacy Policy](https://github.com/linux4life1/front-porch-AI/blob/main/PRIVACY.md).

---

## Voice

### Why isn't the voice (TTS) working?

- **First use downloads voice files.** The default local engine (Kokoro) fetches its voice bundle (roughly 380 MB once unpacked) the first time you use it. Give it a minute and watch for the progress indicator.
- **Wrong engine selected** — check Settings → Voice & Media. Kokoro is the local default; ElevenLabs and OpenAI need an API key and internet.
- **A character has a voice from a different engine.** If you switched engines, a voice assigned under the old one isn't available anymore and the app quietly substitutes one that is: on Piper it falls back to your global Piper voice, while Kokoro picks the nearest voice it actually has (same language and gender where it can). Either way the character stops sounding like themselves, so pick a voice again for the engine you're on now.

More fixes in [Troubleshooting → Voice](troubleshooting.md#tts-not-producing-sound).

### How do I get better-sounding voices?

- **Best free local:** Kokoro (the default) — over 50 voices, surprisingly natural, fully offline.
- **Best overall (paid):** ElevenLabs — extremely natural and expressive, needs an API key.
- **Lots of distinct voices:** Piper — lightweight and fast, handy for giving every group member their own voice.
- **Bring your own Piper voice:** open the **Voice Model Browser** and hit **Add custom voice** to import a raw Piper `.onnx` file (with its matching `.onnx.json` sitting next to it). No conversion step, and the voice then shows up everywhere the built-in ones do. This importer is desktop-only by design — there's no web equivalent.
- **Per-character voices:** a character can carry its own voice instead of the global one — pick one per member while you're building a group chat, or let it ride along in an imported card. Their own voice always wins over the global default.

### Why does voice call mode send my message too early?

Voice call mode listens for a pause: once you've spoken, about two seconds of silence tells it you're done, and it sends the transcription. It also samples the room's background noise for a moment when the call starts, to learn what "quiet" sounds like on your setup.

If it keeps cutting you off or triggering on background noise:

- Use a headset — laptop microphones pick up fans and keyboards easily.
- Lower your microphone gain in your OS settings.
- End and restart the call — it re-measures the background noise fresh each time.
- You can always press the **Send** button in the call screen to send manually instead of waiting for the pause detection.

---

## Realism Engine

### What is the Realism Engine?

The optional system that makes characters feel *alive* over time instead of resetting every message. With it on, a character:

- carries a **mood** that shifts naturally and lingers between turns
- builds (or loses) **bond** (−300 to +300) and **trust** (−100 to +100) with you, which changes how open they are
- experiences the **passage of time** — the story clock moves forward on every turn, on a real calendar, with its own weather and seasons
- can develop **fixations**, pursue their own **objectives**, and grow in ways you can actually read back (**Growth Rings**) over long stories
- can live with Sims-style **needs** — hunger, energy, social, fun, hygiene, comfort, and more

New characters have it off by default and it's configurable per character; new group chats start with it on. The [Realism Engine guide](realism-engine.md) covers all of it.

### Does the Realism Engine slow down my chats?

Honestly: yes, somewhat — it's not free. After each turn, the engine asks the AI a few short background questions ("how did that land emotionally?", "did time pass?"). On a local model those run one after another and typically add a few seconds per turn; on remote APIs they run in parallel and the cost is smaller.

Ways to reduce it:

- Turn on **One-Shot Eval** in the chat sidebar's **Character State** section, which fuses those background questions into a single call. It's marked experimental because it can be less accurate on very small models.
- Use a fast model — the evaluations are short, so speed matters more than size.
- Turn the Realism Engine off for characters or scenes where you don't need it.

### How do I reset a character's bond and trust?

Start a **new chat** — Realism state (bond, trust, mood, time, needs) belongs to the conversation, and a fresh chat starts from the character's saved starting values. There's currently no reset button inside an ongoing chat.

You can also edit a character's *starting* Realism values in the character editor — but those only apply to chats started after the change; existing conversations keep their history.

---

## Your Data & Devices

### How do backups work?

Automatically, and always on. The app snapshots your database every **30 minutes** and keeps two tiers:

- the **10 most recent** snapshots (fine-grained undo for the last few hours), plus
- **one snapshot per day for the last 7 days** (a rolling week of restore points)

Old ones are pruned automatically so it never grows unbounded. If the database is ever damaged, a restore screen appears on launch and recovery is one click. You can also make one yourself, or restore an older snapshot, from **Backups & Restore** in the sidebar. Since 1.2, restoring doesn't need a relaunch — the app picks the restored database straight back up. If that live reload ever fails, it tells you and asks you to close and reopen Front Porch AI.

Two caveats worth being precise about:

- **A backup is the database and nothing else.** It captures what the database holds — your chats, memories, and Realism history — and not the separate files sitting on disk beside it: character card PNGs, avatar images, or your downloaded AI models. So a restore will *not* undo a deleted character, because deleting one also removes its picture from disk and no backup brings that file back.
- **On nightlies the Backups & Restore page opens but its contents are replaced by a notice**, so there is no way to browse or roll back a snapshot there. The automatic snapshots themselves keep running.

For an extra off-machine copy, just copy your whole `FrontPorchAI` folder somewhere safe — that's everything.

### Where is my data stored?

Everything lives in one folder you control:

- **Windows:** `Documents\FrontPorchAI\`
- **macOS / Linux:** `~/Documents/FrontPorchAI/`

(Nightlies use `FrontPorchAI-Beta` instead — leftover name — so they never touch stable data.)

Inside you'll find your database, character cards, and backups (in `KoboldManager/`), your downloaded AI models (`models/`), plus folders for chats, worlds, and the AI engine itself. Copy the whole folder and you've backed up everything.

### Can I chat from my phone or another computer?

Yes. The app has a built-in **web server**: turn it on in Settings → Advanced, then open `http://<your-computer's-address>:8085` in any browser on the same network — phone, tablet, laptop. You get a full interface for chatting, and on a phone you can add it to your home screen so it behaves like an app.

Three things to know:

- It's password-protected. You create the login the first time you open it in a browser, and two-factor is there if you want it. If you ever lose access, the desktop app can reset the web login for you.
- Your desktop computer does all the actual work (it's running the AI), so it needs to stay on.
- It's designed for your home network. For access away from home, a personal VPN like Tailscale is the safe way to reach it.

### Can I sync between two computers?

No — the old Cloud Sync feature (Google Drive / WebDAV) is **gone**. It could occasionally resurrect deleted data across devices, so I removed it; automatic local backups are the replacement safety net.

To move to another machine: copy your `FrontPorchAI` folder over, or export/import individual character cards. Both are reliable. And if what you actually want is to *use* your library from a second device rather than duplicate it, turn on the built-in web server and reach your desktop from the other machine's browser — see [Can I chat from my phone or another computer?](#can-i-chat-from-my-phone-or-another-computer)

### How do updates work?

- **Windows / macOS:** the app checks for updates and shows a "What's New" dialog when one is available; download and install from there (or grab it from [GitHub Releases](https://github.com/linux4life1/front-porch-AI/releases)).
- **Linux (APT/RPM):** updates arrive through your normal system updates — `apt upgrade` or `dnf upgrade`.
- **Linux (AUR):** `yay -Syu` as usual — but right now the AUR package is a full release behind (it's on 1.1.2 while stable is 1.2.0). Pushes to it are being refused on the AUR side and I don't have an ETA, so this won't fix itself in a day or two. If you want the current release, use the APT or RPM repo, the AppImage, or a standalone `.deb`/`.rpm` from [GitHub Releases](https://github.com/linux4life1/front-porch-AI/releases). It also means an AUR install can't open `.fpworld` place files yet, since those need 1.2 or newer.
- **Linux (AppImage):** the in-app updater works here too, the same way it does on Windows and macOS.

### How do I report a bug?

- [GitHub Issues](https://github.com/linux4life1/front-porch-AI/issues) — best for anything reproducible.
- [Discord](https://discord.gg/e4tET6rpdv) — best for "is it just me?" questions and quick help.

If the app misbehaves, launching it from a terminal shows error messages that make bug reports ten times more useful. See [Troubleshooting](troubleshooting.md) first — your issue may already have a fix.
