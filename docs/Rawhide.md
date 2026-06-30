# What's new in this release

This release reworks the AFK needs system so characters have room for varied idle activities instead of spending every response survival-firefighting. No new breaking changes.

## 🎯 Dynamic Responses (AFK) — Autonomous Life Simulation

When you step away from the chat, Front Porch AI now keeps the scene alive with realistic, needs-driven character activity.

- **Time passes naturally** — Each auto-response advances the clock by one period (morning → afternoon → evening), so the character's day progresses while you're away.
- **Characters do varied daily activities** — Instead of repeating the same action, AFK responses draw from a wide range of routines: meals, bathroom breaks, showers, reading, phone scrolling, cooking, napping, watching TV, or just relaxing. The idle cue explicitly encourages multi-activity scenes so more needs get addressed per response.
- **Needs respond to what the character actually does** — The needs evaluator reads each AFK response and adjusts hunger, energy, hygiene, bladder, comfort, fun, and social based on the activities described. Eating raises hunger, a shower raises hygiene, sleeping raises energy, and so on.
- **No automatic decay drain** — Needs don't passively tick downward during AFK. The evaluator is the sole source of changes, so characters aren't stuck firefighting survival needs and have room for interesting, varied activities.
- **Smart fallback for weaker models** — If the evaluator model returns no need changes (common on smaller local models toward the third response), a keyword-based system scans the scene for activities and fills in reasonable values — without overwriting anything the model got right.
- **Three-response cap** — The cycle stops after three consecutive auto-responses, preventing runaway generation.
- **Clean visual feedback** — Each AFK message shows a needs-delta chip at the bottom, with per-need tooltips explaining what changed and why.

## 🧹 Internal cleanup

- Removed a previous change that accidentally made the needs evaluator always see the character's needs vector — it is now scoped to AFK-only, keeping normal conversation flow unchanged.
