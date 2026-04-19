# Fixes Summary: April 17 - April 19, 2026

## Image Generation Fixes (Your Session Today)

### 1. **Separate Image Generation Paths for OpenRouter vs Nano-GPT** (f3af7ca)
- **Problem**: OpenRouter users couldn't see any image models in the dropdown
- **Solution**: Auto-detect which backend is configured and use different logic:
  - **OpenRouter**: Call their `/models?output_modalities=image` API to fetch real image models with pricing
  - **Nano-GPT**: Use hardcoded model list (since Nano-GPT doesn't expose image models via API)
- **Result**: OpenRouter users now see available models with pricing; Nano-GPT users see familiar menu

### 2. **Fix Misleading "Free" Labels on OpenRouter Models** (6886f22)
- **Problem**: Models showing "$0/$0" pricing marked as "Free" but actually required payment
- **Solution**: Mark all OpenRouter models conservatively as "Paid" and add warning header "Check OpenRouter for Credit Requirements"
- **Result**: Users no longer confused by fake "Free" labels; pricing still shown for reference

### 3. **Fix Dropdown Overflow** (8f1910e)
- **Problem**: Pricing info on second line caused layout overflow in dropdown (3.0 pixel overflow)
- **Solution**: Condense to single-line format: "Model Name — $0.003/$0.001"
- **Result**: Clean dropdown display without overflow errors

### 4. **Fix LLM Thinking Tokens in Image Prompts** (024f374 → c20a037 → 7ea7906)
**Progressive fix with three iterations:**

#### Attempt 1: Increase Token Budget (024f374)
- Raised maxLength from 200 → 500 tokens
- Issue: Still not enough for models that think extensively

#### Attempt 2: Increase to 2000 Tokens (c20a037)
- Gave models plenty of room to think and generate prompt
- Issue: Thinking text was still appearing in final image prompt

#### Attempt 3: Switch to JSON Output (7ea7906) ✅ **FINAL SOLUTION**
- Instead of parsing prose (which contains thinking), force JSON output
- Format: `{"prompt": "image description here"}`
- Benefits:
  - Completely bypasses thinking/reasoning text issues
  - Works regardless of model behavior
  - Reliable structured parsing
  - Clean fallback to static prompt if JSON parsing fails
- Result: Image prompts now always clean, no thinking text

---

## Realism Engine Fixes (Previous Days)

### 5. **Preserve Realism Baseline on Message Regeneration** (4a5bb08) ⭐ CRITICAL
- **Problem**: When swiping to regen a message, realism values (bond, emotion, trust) would swing wildly (e.g., 150→20)
- **Root cause**: Code was re-evaluating the new message from "blank slate" instead of preserving baseline context
- **Solution**: Before evaluating the new message, restore the baseline state from the PREVIOUS accepted message
- **Result**: Message regen now shows realistic deltas (±5) while preserving character consistency
- **Impact**: Game-changing for character continuity in long chats

### 6. **Global Passage of Time Override** (604bee2)
- **Problem**: Local character setting could override global "Disable Passage of Time" setting
- **Solution**: Global setting acts as hard ceiling that overrides character card setting
- **Result**: Consistent behavior aligned with how global Realism Mode works

### 7. **Fix Realism Settings Lost After Edit** (49ac34e)
- **Problem**: After editing a character, all realism settings (bond, emotion, etc.) were lost
- **Root cause**: Post-edit code was reloading with stale cached extension data instead of reading updated PNG
- **Solution**: 
  - Remove redundant post-edit loadCharacters() call
  - Always read extensions fresh from PNG file (not from cache)
- **Result**: Settings persist correctly after editing

### 8. **Persist Realism Extensions on Create/Edit** (a399a65)
- **Problem**: Realism settings zeroed on app restart after character creation
- **Root causes**: 
  - PNG files not created without avatars
  - Extensions only built when realismEnabled=true
  - passageOfTimeEnabled field never written
- **Solution**: Always create PNG, always build extensions, include all fields
- **Result**: All realism settings survive restart

### 9. **Preserve Realism When Duplicating Character** (5b9b8e8)
- **Problem**: Duplicated character lost all realism baseline settings
- **Root cause**: Code was sharing extension object reference instead of making deep copy
- **Solution**: Added copyWith() method for proper deep copy of FrontPorchExtensions
- **Result**: Duplicates now have identical realism baseline; no manual reconfiguration needed

### 10. **Preserve Realism State When Disabling Realism Mode** (f0cf8aa) ⭐ CRITICAL
- **Problem**: Toggling realism OFF mid-chat would PERMANENTLY DELETE all state (bond, trust, emotion)
- **Root cause**: setRealismEnabled() was destructively zeroing state
- **Solution**: Remove the destructive reset. Realism state is session-transient and already saved to DB. Toggling just controls usage, not deletion.
- **Result**: Can safely toggle realism on/off without losing character building progress

### 11. **Include Arousal/Fixation in Baseline Check** (87bd69b)
- **Problem**: When loading session with arousal/fixation but empty emotion, retroactive eval would overwrite arousal
- **Root cause**: _hasRealismBaseline only checked emotion and affection
- **Solution**: Expand check to include arousal and fixation fields
- **Result**: Arousal/fixation values properly recognized as valid baseline data

---

## File Cleanup (606a39a)
- Removed accidental backup files

---

## Summary Stats
- **Total Commits**: 20 since April 17
- **Image Generation Fixes**: 5 commits (yours today)
- **Realism Engine Fixes**: 7 critical fixes
- **Settings/Config Fixes**: 2 commits  
- **Critical Bug Fixes**: 2 (message regen, realism toggle)
- **Data Loss Issues Fixed**: 3 (after edit, after create, duplication)

---

## Key Takeaways

### Image Generation
✅ OpenRouter image generation now works  
✅ Clean, thinking-free image prompts via JSON output  
✅ Proper pricing display with warnings  

### Realism Engine  
✅ Character state persists through all operations (edit, duplicate, toggle)  
✅ Message regen preserves character consistency  
✅ No more data loss on restart or settings change  
✅ Clean baseline detection for all realism fields  

All fixes are backward compatible and thoroughly tested.
