# Scenario fade (automatic opening-premise soft-out)

## Intent

Long roleplay outgrows the card **Scenario** field. Keeping full-force
`Scenario: …` in the system prompt forever can yank the model back to the
opening beat. Users should not have to clear or edit the card.

## Decision

- **Card/group scenario text stays permanent** (user/chargen only). No silent
  rewrite of the stored field (scenario evolution stays retired).
- **Prompt injection only** fades automatically with chat length:
  - strength **10** at open → steps to **1** → **0** = omitted
  - cadence: `kUserMessagesPerStrengthStep = 6` → gone after **60 user messages**
  - **no settings UI** — background behavior only
- Wording bands:
  - 8–10: `Scenario: …` (legacy shape)
  - 4–7: background / story may have moved on
  - 1–3: opening premise only; prefer recent history + Where we are
  - 0: empty injection

## What carries "now" after fade

| Layer | Needs Realism? |
|---|---|
| Journal cards + "Where we are" recap | **No** — `memorySettings.journalEnabled` |
| Growth Rings | **No** — `memorySettings.characterEvolutionEnabled` |
| RAG embeddings | **No** — `memorySettings.ragEnabled` |
| Recent chat history | Always (budgeted) |

Realism is separate (mood/bond/needs/time). Journal/Growth/RAG keep working
with Realism off as long as their own memory toggles stay on.

## Wiring

- `lib/services/chat/scenario_fade.dart`
- Main generation + impersonate `PromptPlan` scenario sections
- Guest speakers still blank scenario before wrap (existing guest rule)
