# Security Policy

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Report it privately through GitHub:

1. Go to the [Security tab](https://github.com/linux4life1/front-porch-AI/security)
2. Click **Report a vulnerability**
3. Describe the issue, how to reproduce it, and what an attacker could do with it

That opens a private thread visible only to the maintainer. If GitHub private
reporting is unavailable to you, ask in the [Discord](https://discord.gg/e4tET6rpdv)
for a private channel — **do not post the details publicly.**

Expect an acknowledgement within a few days. This project is maintained by one
person, so please be patient; a fix for anything serious will be prioritised over
feature work. You will be credited in the release notes unless you'd rather not be.

## What's in scope

Front Porch AI is a local-first desktop app, but it has a real network surface.
The areas most worth your attention:

- **The built-in web server** (`lib/services/web/`). It serves the web/mobile UI
  and can be exposed to a LAN or a tailnet. Authentication bypass, path traversal,
  or anything that lets an unauthenticated client reach chats, characters or
  settings is in scope.
- **Stored credentials.** The app holds API keys for OpenRouter, OpenAI,
  ElevenLabs and others. Leaking them into logs, exports, character cards, crash
  reports or network requests to the wrong host is in scope.
- **The Stoop client** (`lib/services/backporch/`). Auth handling, token storage,
  and anything that lets one account act as another.
- **Character card import.** Cards are untrusted input from the internet. Parsing
  that can be made to write outside the characters directory, execute code, or
  corrupt the database is in scope.
- **Database and file handling**, including backup/restore and the import paths
  used by external tools.
- **Dependency vulnerabilities** that are actually reachable from this app's code.

## What's out of scope

- **The LLM saying something you don't like.** Model output is not a
  vulnerability. Jailbreaks, refusals and roleplay content are product behaviour,
  not security issues.
- **Attacks requiring an already-compromised machine.** The app stores data
  unencrypted in the user's own documents directory by design; someone with local
  filesystem access has already won.
- **Deliberately exposing the web server to the public internet** without a
  password and then finding it reachable. That's the documented consequence of
  that configuration.
- **The Stoop backend itself.** It is a separate, privately maintained service and
  is not part of this repository. Report backend issues through the same private
  channel and they will be routed appropriately.
- **Vulnerabilities in third-party models** you download (TTS voices, embeddings,
  LLM weights). Report those upstream.

## Supported versions

Fixes land on the current release line. Older versions are not backported —
please update to the latest release before reporting, and confirm the issue still
reproduces there.

| Version | Supported |
|---|---|
| Latest stable release | ✅ |
| Current nightly | ✅ |
| Anything older | ❌ — please update first |

## Disclosure

Please give a reasonable window to ship a fix before disclosing publicly.
Given a single maintainer and three platforms to build and sign, 90 days is a fair
default, and less if the issue is being actively exploited. If you need to move
faster than that, say so in the report and it will be worked out rather than
ignored.
