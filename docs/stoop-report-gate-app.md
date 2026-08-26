# Stoop Report gate — desktop + web_ui

**Status:** Hub + API + desktop + web_ui shipped 2026-08-16.
Unverified accounts never get a Report button; reason is required.

**Why it exists:** throwaway / unverified reports were extra mod workload.
`POST /reports` rejects guests, unverified accounts, and blank reasons. The
app UI must match — do not leave a Report button that only fails at the API.

Owner rule to match the hub:

1. **Anonymous / signed-out** — no Report control (nudge to sign in).
2. **Signed in, email not verified** — **no Report at all.** Do not open the
   dialog. Swap the button for “Confirm email to report” (or hide it and point
   at the existing verify banner / account sheet).
3. **Signed in + verified** — Report stays. **Reason is required** (trim,
   non-empty, max 500). Category alone is not a reason.

The unverified block is not optional polish. Throwaway signups were the
workload. Hiding the button only for guests and leaving unverified accounts
able to click Report **misses the point**.

---

## Already live (do not re-ship)

API `~/dev/backporch-server/src/routes/reports.ts`:

| Caller | `POST /reports` |
|---|---|
| No token | `401 unauthorized` |
| Signed in, `emailVerified === false` | `403 email_not_verified` |
| Blank / whitespace / omitted `reason` | `400 reason_required` |
| Verified + trimmed reason 1–500 | 201 as before |

Hub (`website/src/stoop/views-browse.js`) already matches the table above.
Recipe: Hermes skill **stoop-review-ops** `references/hub-report-gate.md`.

---

## What is still wrong in the app

### Desktop — `lib/ui/pages/repository/stoop_card_detail_page.dart`

- `_reportButton()` always paints **Report Character** and always calls `_report`.
- `_ReportDialog` comment: “category + **optional** reason.” Placeholder is
  `Anything else? (optional)`. Submit pops with `reason: _reason.text.trim()`
  even when empty.
- `_report` catch-all: `'Couldn’t file that report. Try again.'` — does not
  map `email_not_verified` or `reason_required`.
- File is **~932 lines** (over the 500-line ratchet). **Extract** the report
  dialog / button into a new leaf under `lib/ui/pages/repository/` if you
  touch this. Do not grow the god file.

`AuthState.user` is `BackporchUser?`. `emailVerified` is already on the model
(`lib/services/backporch/backporch_user.dart`). **Default is `true`** when the
server omits the field (older payload / grandfathered) — same as the hub:
**only block when the field is explicitly `false`.**

`stoop_verify_banner.dart` already exists for unverified users. Reuse it; do
not invent a second verify flow. Update its copy: confirming email also
unlocks **reporting**, not just sharing / profile photo.

`BackporchApi.reportCharacter` still defaults `reason = ''`. After the UI
gate, keep the API helper honest (required non-blank, or let the server 400
and map it).

### PWA — `web_ui/` (CLAUDE.md: desktop **and** web_ui)

- `web_ui/src/pages/stoop/StoopCardPage.tsx` — Report button is always shown;
  `setReporting(true)` with no `emailVerified` check.
- `ReportDialog` label is **Details (optional)**; submit does not refuse blank.
- `stoop.report` → desktop facade `lib/services/web/routes/stoop_routes.dart`
  `_report`, which already forwards `reason` (default `''`) to `/reports`.
- `stoopErrorText` maps `email_not_verified` to *profile photos* only
  (`web_ui/src/stoop/stoopApi.ts`). Broaden it (hub already did).
  Add `reason_required` → “Please add a reason.”
- User type already has `emailVerified?: boolean`
  (`web_ui/src/stoop/stoopTypes.ts`). Treat missing as verified; block only
  `=== false` (same as `StoopAccountPage` avatar gate).

Desktop Stoop is reached while signed into Backporch. Guests are rarer than
on the public hub, but unverified signed-in accounts are common — **that** is
the app-side hole.

---

## Implement (when asked)

Branch: **Rawhide** unless they say otherwise.

### Desktop

1. `canReport = token present && user?.emailVerified != false`.
2. If signed out: no Report button (or sign-in nudge). Do **not** open the
   dialog.
3. If signed in and `emailVerified == false`: **no Report button.** Link /
   text: “Confirm email to report” → existing verify / account UI. Do **not**
   open `_ReportDialog`.
4. Dialog: placeholder “What’s wrong? (required)”. Submit disabled or
   snackbar + stay open when `trim().isEmpty`.
5. Map `BackporchApiException.code`:
   - `email_not_verified` → confirm-email copy
   - `reason_required` → “Please add a reason.”
   - keep a generic fallback
6. Extract report UI out of `stoop_card_detail_page.dart`.
7. `dart format` **only** the files you touch. `flutter analyze` on those
   paths. Add a small widget/unit test: unverified user has no Report;
   empty reason does not pop a submit.

### web_ui

Same three states on `StoopCardPage`. Block submit in `ReportDialog` when
`reason.trim()` is empty. Update `stoopErrorText`. `npm run lint && npm test`
in `web_ui/`, then **`npm run build`** (writes `assets/web_app` — no build =
the Flutter app still serves the old PWA).

### Copy

Match the hub, keep it short:

- Unverified control: `Confirm email to report`
- Blank reason: `Please add a reason.`
- Verify banner: confirming unlocks **sharing, reporting, and a profile photo**

Do not lecture. Do not mention Rayne / Misty.

### Do not

- Re-deploy the API or hub (already live).
- Issue reports from a guest/unverified path “just to test” against prod.
- Change AUP / warn / ban.
- Touch `dev` unless asked.

---

## Done when

- Unverified desktop + PWA user **cannot click Report** (button gone / replaced).
- Verified user cannot send a whitespace reason (dialog stays, toast shown).
- `email_not_verified` / `reason_required` from the server show a real sentence,
  not “Try again.”
- Hub behavior unchanged.

Owner: implement only when they say to do the app side.
