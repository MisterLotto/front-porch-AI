# Tiered User Persona Persistence

## Summary

Replace the global-only user persona singleton with a three-tier hierarchy:

```
per-chat override  →  character/group default  →  global active persona
```

Session loading no longer switches the global active persona. The effective persona is resolved once at generation start and used throughout the turn. Dynamic responses are the sole exception — they resolve at call time.

---

## Data Model

### Storage additions

| Table | Column | Type | Default | Purpose |
|-------|--------|------|---------|---------|
| `characters` | `defaultPersonaId` | `TEXT` nullable | `NULL` | Per-character default persona. `NULL` = use global. |
| `sessions` | `userPersonaOverrideId` | `TEXT` nullable | `NULL` | Per-chat persona override. `NULL` = use character default or global. |
| `groups` | `defaultPersonaId` | `TEXT` nullable | `NULL` | Per-group default persona. `NULL` = use global. |

Existing `sessions.userPersonaId` is retained for backwards compat during migration period. It continues to be written (set to the effective persona ID) but is no longer read for persona resolution on load.

### Resolution algorithm

```
resolvePersona(session, character):
  if session.userPersonaOverrideId != null → return that persona
  if character.defaultPersonaId != null    → return that persona
  return global active persona
```

For group chats, the "character" in the above is the group entity itself (which has its own `defaultPersonaId`).

### Backwards compatibility

- `NULL` `defaultPersonaId` on characters = use global (preserves current behavior)
- `NULL` `userPersonaOverrideId` on sessions = use character default or global (preserves current behavior)
- Existing sessions have `userPersonaId` set to whatever was active — these work as "no override" since `userPersonaOverrideId` is null
- No data migration needed — old behavior is the default

---

## Resolution Rules by Chat Type

### 1:1 chats

```
per-chat override → character default → global
```

### Group chats

```
per-chat override → group default → global
```

Groups are treated as independent entities with the same three-tier hierarchy. Group defaults are set once at creation and never linked to source characters after that.

---

## Creation Rules

### Freshly created/imported character

`defaultPersonaId` = `NULL`. New chats use the global active persona.

### New 1:1 chat

Uses the character's `defaultPersonaId` (or global if null).

### First persona switch in 1:1 chat

If the character has no `defaultPersonaId` set → set `defaultPersonaId` to the switched-to persona (this becomes the character default for all future chats).

If the character already has `defaultPersonaId` → set `userPersonaOverrideId` on the session to the switched-to persona.

### Subsequent persona switches in 1:1 chat

Set `userPersonaOverrideId` on the session only. Character default is untouched.

### Group chat created from 1:1 conversion

The effective persona at transition time becomes the group's `defaultPersonaId` (snapshot, not live). `userPersonaOverrideId` on the new group session is null.

### Manual group creation (from scratch)

After all characters are added at creation time:
- If all characters share the same `defaultPersonaId` (ignoring nulls and per-chat overrides) → that becomes the group's `defaultPersonaId`
- Otherwise → group `defaultPersonaId` = null (global)

### Forked chats

Inherit `userPersonaOverrideId` from the parent session. If parent had null (using character default), fork also has null.

### Scene Guests (Lite NPCs)

Scene guests are 1:1-only, stored as full `CharacterCard` instances with `tier == 'lite'`. They have no `defaultPersonaId` by definition. Persona resolution falls through to global for scene guest chats. No special handling needed.

When a 1:1 with scene guests becomes a group (lite guests promoted to full members), the effective persona at transition time becomes the group default — same as the standard 1:1→group rule.

---

## Reset Rules

### "Reset all chats to character default" (in character settings)

Clears `userPersonaOverrideId` on all 1:1 sessions belonging to that character. Group chats with that character are **not** affected (groups are independent entities).

### "Reset all chats to group default" (in group settings)

Clears `userPersonaOverrideId` on all sessions belonging to that group.

### "Reset all to global" (in persona screen, nuclear option)

- Sets `defaultPersonaId` = null on all characters
- Sets `defaultPersonaId` = null on all groups
- Sets `userPersonaOverrideId` = null on all sessions

### "Apply character default to all existing chats" (in character settings)

Sets `userPersonaOverrideId` = null on all 1:1 sessions for that character, so they fall back to the character's (possibly newly changed) default.

---

## Deletion Cascade

When a user persona is deleted:

1. Query all characters, sessions, and groups referencing the deleted persona ID
2. Show confirmation dialog listing affected entities
3. On confirm:
   - **Characters** with `defaultPersonaId` = deleted persona → set to null (falls back to global)
   - **Sessions** with `userPersonaOverrideId` = deleted persona → set to null (falls back to character default or global)
   - **Groups** with `defaultPersonaId` = deleted persona → set to null (falls back to global)
4. All affected chats immediately reflect the new resolution on next generation

---

## Generation-Time Behavior

### Persona resolution

Persona is resolved once at the start of `generate()` using the hierarchy above. The resolved persona (`_currentTurnPersona`) is used for all subsequent calls within the same turn:
- Prompt block construction (`user_persona` block)
- Macro resolution (`<user>` tag)
- Stop sequence building (avoid stopping on user name)
- Image generation context
- Action suggestions
- Sender name in message creation
- Promise debt evaluation
- Guest grounding dedup

### Exception: Dynamic responses

Dynamic responses are triggered asynchronously (minutes/hours after the original turn). They resolve the persona at call time using the same hierarchy, not from the cached `_currentTurnPersona`. They have access to the session context needed for resolution.

### Session loading

Loading a session **no longer switches the global active persona**. The effective persona is resolved from the hierarchy at generation time only. The global active persona stays unchanged.

---

## UI Changes

### Chat input persona indicator

The persona avatar in the chat input area shows the **resolved** persona (not the global active). A small tier indicator shows which level is active:
- No indicator = global default
- Small dot = character/group default
- Small dot with ring = chat override

### Chat input persona switcher

When switching persona from within a chat:
- First switch on a character with no default → creates character default
- First switch on a character with existing default → creates chat override
- Subsequent switches → updates chat override

The same `UserPersonaDialog` is used from both the chat input and the main persona page. Context is differentiated by:
- **In-chat context**: switching updates character default or chat override (not global)
- **Main menu context**: switching updates the global active persona (current behavior)

### Character settings (edit character page)

New section in the Details tab: "Default User Persona"
- Dropdown: "Use global default" (null) | list of all personas
- Shows persona name and description preview when selected
- "Reset to global" button

### Chat/group settings dialog

New section: "User Persona" (visible when character/group has a default set)
- Dropdown: "Use character/group default" (null) | list of all personas
- Shows effective persona name and tier indicator
- "Reset to character default" button (clears override)

### Persona page (main menu)

New section: "Override Management"
- "Reset all chats to character defaults" — clears per-chat overrides
- "Reset all to global" — clears character defaults, group defaults, and per-chat overrides
- Shows count of affected entities before executing

---

## Implementation Phases

### Phase 1: Database schema
- Add `defaultPersonaId` to `characters` table
- Add `userPersonaOverrideId` to `sessions` table
- Add `defaultPersonaId` to `groups` table
- New migration step (no data migration needed)

### Phase 2: Model & service layer
- Add `getPersonaById()` to `UserPersonaService`
- Add `defaultPersonaId` field to `CharacterCard` (runtime only, not PNG-serialized)
- Add resolver method to `ChatService`
- Add `getDefaultPersonaId()` / `setDefaultPersonaId()` to `CharacterRepository`

### Phase 3: Generation pipeline
- Resolve persona once at `generate()` start, cache as `_currentTurnPersona`
- Replace all `_userPersonaService.persona` reads within generation context
- Update late-final closures (`getUserName`) to use resolved persona
- Update `MacroContext` construction

### Phase 4: Session save/load
- Save `userPersonaOverrideId` instead of global snapshot
- Remove global persona switch on session load
- Load `userPersonaOverrideId` from session into working state

### Phase 5: First-time switch logic
- On persona switch in chat, check character's `defaultPersonaId`
- If null → create character default
- If not null → create/update chat override

### Phase 6: UI — character settings
- Add default persona selector to edit character page

### Phase 7: UI — chat/group settings
- Add chat override selector to chat settings dialog

### Phase 8: UI — persona page
- Add reset all overrides section

### Phase 9: UI — chat input
- Show resolved persona avatar
- Add tier indicator
- Context-aware switching (chat vs global)

### Phase 10: Group chat integration
- Set group default on 1:1→group transition
- Set group default on manual creation (if all chars share same default)
- Add `defaultPersonaId` to group model

### Phase 11: Deletion cascade
- Check references before deleting persona
- Show affected entities in confirmation dialog
- Reset affected defaults/overrides on confirm

### Phase 12: Forked chats
- Copy `userPersonaOverrideId` from parent to fork

---

## Files Affected

| File | Changes |
|------|---------|
| `lib/database/database.dart` | Add columns, migration |
| `lib/models/character_card.dart` | Add `defaultPersonaId` field |
| `lib/models/group_member.dart` | Add `defaultPersonaId` for group defaults |
| `lib/services/user_persona_service.dart` | Add `getPersonaById()`, deletion cascade |
| `lib/services/character_repository.dart` | Add get/set for `defaultPersonaId` |
| `lib/services/chat_service.dart` | Add resolver, update all persona access (14 sites) |
| `lib/services/chat/chat_service_generation.dart` | Resolve at start, use cached persona |
| `lib/services/chat/chat_service_session_state.dart` | Save override ID |
| `lib/services/chat/chat_service_session_load.dart` | Remove global switch, load override |
| `lib/services/chat/chat_service_prompt_blocks.dart` | Use resolved persona |
| `lib/services/chat/chat_service_images.dart` | Use resolved persona (3 sites) |
| `lib/services/chat/chat_service_actions.dart` | Use resolved persona |
| `lib/services/chat/chat_service_impersonate.dart` | Use resolved persona |
| `lib/services/chat/chat_service_group_membership.dart` | Group default on creation |
| `lib/ui/pages/chat_page.dart` | Show resolved persona + tier indicator |
| `lib/ui/dialogs/user_persona_dialog.dart` | Context-aware switch |
| `lib/ui/pages/edit_character_page.dart` | Default persona selector |
| `lib/ui/dialogs/chat_settings_dialog.dart` | Chat override selector |
| `lib/ui/pages/user_persona_page.dart` | Reset all overrides |
| `lib/services/storage_service.dart` | Bulk reset methods |

---

## Scope Exclusions (for now)

- **Import/export**: Character card import does not carry persona info. Export does not include persona overrides. Per-chat overrides remain contained within chats.
- **Story projects**: `includeUserPersona` flag continues to use the resolved persona at generation time.
- **Web facade**: Persona resolution on the web follows the same hierarchy. Web persona switcher updates the global active persona (same as main menu context).
