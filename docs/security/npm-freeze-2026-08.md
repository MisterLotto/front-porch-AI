# npm dependency freeze — ChainDrop supply-chain attack (2026-08)

**Status: FROZEN.** Dependabot will not open npm PRs for `web_ui/`, and the
lockfile must not be regenerated, until the thaw checklist below is worked
through. This file is the record and the procedure; `.github/dependabot.yml`
points here.

## What happened

A supply-chain campaign ("ChainDrop") compromised maintainer accounts and
published malicious versions of a large number of npm packages — reported at
**868 packages across 1,381 versions**, with a wider count of 1,300+ cited the
same day. Named in early reporting: `keyv`, `cacheable`, `flat-cache`,
`file-entry-cache`.

Mechanism: a `"preinstall": "node setup.mjs"` entry added to `package.json`.
`setup.mjs` downloads the Bun runtime and runs an infostealer
(`Math_Symbol.js` / `math_init.js`) which harvests GitHub PATs and workflow
tokens (`ghp_`/`gho_`/`ghs_`), npm tokens (`npm_`), AWS/Azure/GCP credentials,
Kubernetes secrets, Vault tokens, and Stripe/Slack/Twilio keys, exfiltrating to
`npm-cache[.]com`. Stolen tokens are validated against the registry before use,
which is how the campaign spreads to the next wave of packages.

Source: https://www.bleepingcomputer.com/news/security/massive-chaindrop-npm-supply-chain-attack-infects-hundreds-of-packages/

## Our exposure: NOT AFFECTED (scanned 2026-08-05)

| Check | Result |
|---|---|
| `keyv`, `cacheable`, `flat-cache`, `file-entry-cache` in `package-lock.json` | absent at any version, direct or transitive |
| `setup.mjs` in the installed tree | none |
| `math_init.js` | none |
| `Math_Symbol.js` | one hit, **benign** — see below |
| `npm-cache[.]com` / `Shai-Hulud` strings under `node_modules` | none |
| Packages with `preinstall` / `install` / `postinstall` | **zero** |

The `Math_Symbol.js` hit is
`regenerate-unicode-properties/General_Category/Math_Symbol.js` — a 1,074-byte
Unicode data file listing the codepoints of general category `Sm`, in a package
with no lifecycle scripts. It is legitimate. The attacker's payload almost
certainly uses that name *because* it disappears into trees like ours, so the
next person to scan should expect the same hit and check the contents rather
than the filename.

A `postinstall` on `ljharb-monorepo-symlink-test` appears if you walk every
nested `package.json`; it is a test fixture inside another package and is not in
the lockfile — not installed, never executed.

**Why we were not hit:** the lockfile pins versions published before the
campaign, and none of the affected packages are in the tree at all. Note that
`npm ci` is **not** itself the protection — `npm ci` runs `preinstall`,
`install` and `postinstall` for dependencies. The pinned lockfile is.

## What changed

1. **Dependabot npm updates frozen** — `open-pull-requests-limit: 0` for the
   `/web_ui` ecosystem. `pub` and `github-actions` are untouched.
2. **`npm ci --ignore-scripts`** in all four workflows that install web deps:
   `ci.yml`, `nightly.yml`, `release.yml`, `beta-release.yml`. Zero packages in
   the tree run install scripts today, so this is behaviour-neutral now and
   closes the vector for anything that arrives later. Verified with a clean
   `rm -rf node_modules && npm ci --ignore-scripts`: tsc clean, 34 vitest tests
   pass, `npm run build` produces a **byte-identical** bundle in
   `assets/web_app` (no diff).

## Deferred advisories

Left unpatched on purpose. All are build- or test-time, reachable only from
inputs we control, and none is worth trading a known-good lockfile for an
unaudited one while the compromised-package list is still growing:

| Package | Severity | Note |
|---|---|---|
| `react-router` 7.12.0–8.2.0 | high | RSC-mode CSRF bypass. `web_ui` is a Vite SPA with no RSC and no server actions. Fix downgrades to 7.11.0 — breaking. |
| `brace-expansion` | high | DoS via unbounded expansion; glob paths on our own CI inputs. |
| `fast-uri` | high | Host confusion via backslash authority delimiter. |
| `postcss` ≤8.5.22 | moderate | Needs an attacker-controlled `sourceMappingURL`. |

## Thaw checklist

Do these **in order**. Do not run `npm audit fix` as the first step — it
resolves fresh artifacts and rewrites the lockfile, which is the exact thing
this freeze exists to prevent.

1. **Confirm the incident has stopped moving.** The compromised-package list
   must have stabilised — no new additions for several days from the registry
   and the tracking vendors (Wiz, StepSecurity, Aikido, Socket, Ox Security).
2. **Re-scan the current tree first**, before changing anything, using the same
   checks as the table above plus any package names added since. If the list
   grew to include something we depend on, that is a compromised-tree response
   (rebuild, rotate), not a dependency bump.
3. **Unfreeze deliberately**: restore `open-pull-requests-limit: 5` in
   `.github/dependabot.yml`.
4. **Patch in small, readable steps.** For each upgraded package, check the new
   version's publish date against the campaign window and read the diff. Group
   bumps are how an unaudited version slips in unread — our last three lockfile
   changes before the freeze were all Dependabot group PRs.
5. **Re-verify after every bump**: `npm ci --ignore-scripts`, `npm run lint`,
   `npm test`, `npm run build`, and confirm the `assets/web_app` diff is one you
   expect. That bundle ships inside the desktop app.
6. **Keep `--ignore-scripts`.** If a future dependency genuinely needs an
   install script, that is a decision to make explicitly, not to inherit.

## Not done, and why

**No token rotation was performed.** Nothing in the tree could have executed the
payload, so there is no indication of theft. Rotating the **npm publish token**
is still cheap insurance given how the campaign spreads (stolen publish tokens
poison the next wave) and is the maintainer's call. GitHub PATs are not
indicated absent any other sign.
