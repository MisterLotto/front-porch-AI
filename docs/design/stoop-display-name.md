# Stoop Display Names — hub/server work handoff

*Written 2026-07-30 for the agent doing the hub.frontporchai.app / backend
side. The Dart app's half already shipped on Rawhide (see "What the app
already ships" below). The backend source is private and NOT in this repo —
this doc describes only the contract and the tasks.*

## The concept (read this first)

A Stoop post has **two names that are allowed to differ**:

| Field | Lives where | Shown where | Purpose |
|---|---|---|---|
| **Display name** | The post's top-level `name` (form field on upload) | Tiles, hero, detail title, search, mod queue — every listing surface | The shelf title. Free-form: `Misty Meadows, Misguided Meteorologist` |
| **In-chat name** | `name` INSIDE the card payload (the PNG-embedded / JSON V2 card) | Chat itself, after download | What `{{char}}` maps to: `Misty` |

Nothing is ever rewritten inside the card/PNG. Downloads hand back the
original card untouched, so the character imports and chats under her
in-chat name. **The API schema does not change** — the post `name` field has
always been a free-form string sent alongside the card; we are just letting
it diverge on purpose. V3 `nickname` is explicitly NOT supported (maintainer
decision 2026-07-30) — the split lives at the post level, never inside the
card.

## Hub website tasks (the actual work)

1. **Submit form — make the split visible.** The dropzone parses the PNG and
   seeds the name field from the embedded card name. Verify the field is
   editable before submit (it should be — the API takes `name` as a form
   value). Add helper text under it, matching the app's wording:
   > *Just the listing title — add flair if you like. In chat they'll still
   > be "<card name>" ({{char}} is unchanged).*
   Interpolate the parsed card's actual name. Same on the hub's
   update/new-version form if it re-seeds the name from a re-uploaded file:
   the form must default to the POST's stored name, not the card's, so a
   custom title survives updates. (The app had this exact clobber bug —
   fixed there 2026-07-30; mirror the fix.)

2. **`{{char}}` previews must use the card's name, not the post's.** If any
   hub view (detail sections, greeting previews) resolves `{{char}}` /
   `{{user}}` macros in card text, resolve `{{char}}` against the *embedded
   card's* `name`, falling back to the post name only when the card has
   none. Otherwise previews read "Misty Meadows, Misguided Meteorologist
   smiles" where chat will say "Misty smiles". (If the hub renders macros
   raw and unresolved, skip this task.)

3. **Server — nothing required.** Zero API/schema/moderation changes for
   this version. Mods already review the post name; a fancier string there
   changes nothing mechanically.

## Optional later phase (do NOT build unless maintainer asks)

- **`tagline` column** — if we ever want "Misguided Meteorologist" as a
  separately-styled second line instead of a comma string: nullable column,
  optional on upload/version endpoints, echoed in every card-shaped
  response (browse items, detail, mine, downloads), rendered on hub + app
  tiles/detail, visible in mod review. Strictly additive per the
  mixed-fleet rules in CLAUDE.md ("The Stoop & Its Backend"): old apps
  never send it and ignore it in responses. Comma-string posts must keep
  rendering fine forever.
- **`chatName` in browse/list responses** — optional additive echo of the
  embedded card's name on list items, so tile-level summary previews can
  resolve `{{char}}` correctly without shipping the whole card. Today only
  the detail view (which has the full card) resolves macros with the right
  name; tiles fall back to the post name. Minor cosmetic gap, fine to leave.

## What the app already ships (Rawhide, 2026-07-30)

- Share wizard: the field is labeled **"Display name on The Stoop"** with
  the helper text quoted above (shows the selected card's real in-chat
  name).
- Update mode: the wizard now receives the post's stored `name` + `summary`
  and preserves them instead of re-seeding from the local card — custom
  titles survive version publishes.
- Detail panel: `{{char}}` in previews resolves against the embedded card's
  `name` (post-name fallback).
- Web UI (`web_ui/`): no changes needed — its Share tab is the approved
  coming-soon deferral, and its detail view renders macros raw.

## Acceptance check (end-to-end)

1. In the app, share a card named `Misty` with display name
   `Misty Meadows, Misguided Meteorologist`.
2. Hub + app browse/tiles/detail/search all show the long title; mod queue
   shows it for review.
3. Preview text containing `{{char}}` reads "Misty …" on the app detail
   panel (and hub detail, if it resolves macros).
4. Download her: library shows `Misty`, chat says `Misty`.
5. Publish an update from app AND from hub: the long title survives both.
