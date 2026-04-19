# Image Generation Fix - Testing Guide

## What Was Fixed

**Problem**: OpenRouter users couldn't generate images. The dropdown showed no models and the API wasn't being called.

**Solution**: The app now detects whether you're using OpenRouter or Nano-GPT and routes image generation differently for each:

- **OpenRouter**: Calls their API to discover available image models (with pricing)
- **Nano-GPT**: Uses the hardcoded list you see now (no API call)

---

## How It Works (Plain English)

Think of this like two different restaurants:

**OpenRouter Restaurant:**
- Has a constantly-updated menu board
- When you open the app, it calls them and says "What image dishes do you have?"
- They tell you back: "We have FLUX Pro ($0.003), Gemini Image ($0.001), DALL-E 3 ($0.004)"
- You see all of them with prices in a dropdown
- When you generate an image, you use their ordering system (chat/completions endpoint)

**Nano-GPT Restaurant:**
- Has a secret menu they don't publish
- The app just uses the printed menu list that's built in
- You pick from that fixed list
- When you generate an image, you use their special ordering system (/images/generations endpoint)

The app now checks which restaurant you picked for text and uses the correct process for images.

---

## Testing Checklist

### ✅ Test 1: Nano-GPT (Should Work Like Before)
1. Go to Settings → Backend
2. Set text backend to Nano-GPT (default)
3. Go to Settings → Image Generation
4. You should see the hardcoded model list (Flux, DALL-E, etc.)
5. Select a model and try generating an image
6. **Expected**: Works exactly as before

### ✅ Test 2: OpenRouter with Valid API Key
1. Get a free OpenRouter account at https://openrouter.ai (they give $5 free credits)
2. Copy your API key
3. Go to Settings → Backend
4. Change text backend to: `https://openrouter.ai/api/v1` with your API key
5. Go to Settings → Image Generation
6. Click the "Refresh models" button
7. **Expected**: Dropdown populates with real OpenRouter image models + pricing
8. Select one and try generating an image
9. **Expected**: Image generates using OpenRouter's chat/completions endpoint

### ✅ Test 3: OpenRouter with Invalid/Missing API Key
1. Go to Settings → Backend
2. Set URL to `https://openrouter.ai/api/v1` but leave API key empty (or wrong key)
3. Go to Settings → Image Generation
4. Click "Refresh models"
5. **Expected**: Dropdown stays empty, no error crash, clean failure
6. Try to generate an image
7. **Expected**: Error message "No API key configured" or similar

### ✅ Test 4: Switch Between Backends
1. Start with Nano-GPT (should show hardcoded list)
2. Switch to OpenRouter (should fetch real list)
3. Switch back to Nano-GPT (should show hardcoded list again)
4. **Expected**: No crashes, smooth transitions

---

## What You'll See

### Nano-GPT Model Dropdown
```
── Included with Pro Subscription ──
✓ HiDream                                   Free
✓ Chroma                                    Free
✓ Z Image Turbo                             Free
✓ Qwen Image                                Free

── Pay Per Prompt ──
💰 DALL-E 3                                 Paid
💰 FLUX.1 Pro                               Paid
💰 Flux Midjourney (MJV6)                   Paid
```
(This list is the same every time - it's hardcoded)

### OpenRouter Model Dropdown
```
── Included with Pro Subscription ──
✓ FLUX.1 Dev                                Free
✓ Stable Image Core                         Free

── Pay Per Prompt ──
💰 black-forest-labs/flux.2-pro             $0.003 / $0.003
💰 google/gemini-3-pro-image                $0.001 / $0.001
💰 black-forest-labs/flux.2-flex            $0.002 / $0.002
```
(This list is fetched from OpenRouter and includes pricing)

---

## Technical Details (If Curious)

- **Detection**: The app checks if your API URL contains "openrouter.ai"
- **API Call**: When using OpenRouter, it calls: `GET /api/v1/models?output_modalities=image`
- **Fallback**: If the API call fails, you get an empty dropdown (not a crash)
- **Generation**: Uses the existing `_generateViaOpenRouter()` function (already works)
- **Nano-GPT**: Completely unchanged from before

---

## Troubleshooting

### "Refresh models" button shows loading spinner forever
- Check your internet connection
- Verify your OpenRouter API key is correct
- OpenRouter might be down - try again in a few minutes

### Dropdown is empty after clicking refresh
- Your API key might be invalid
- You might not have an OpenRouter account
- Get a free one at https://openrouter.ai

### Image generation fails with OpenRouter
- Make sure you have credits (free account gets $5)
- Check that you selected an actual image model
- Try a different model

### Image generation works but looks bad
- That's a quality issue with the model, not the app
- Try a different image model
- Adjust your prompt

---

## Files Changed

- `lib/services/image_gen_service.dart` - Core logic for detecting OpenRouter and fetching models
- `lib/ui/dialogs/image_gen_settings_dialog.dart` - Updated UI to show pricing info
- `.llm_context/user_context.md` - Instructions for AI assistants to explain things without code jargon

## What Stayed the Same

- Nano-GPT behavior (no changes)
- Image generation UI (except pricing display)
- Local backend (A1111/Draw Things)
- All existing image generation features

---

**Questions?** Check the `.llm_context/user_context.md` file for how to ask AI assistants for help understanding the code.
