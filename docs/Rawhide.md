# What's new in this release

This release reworks the AFK needs system so characters have room for varied idle activities instead of spending every response survival-firefighting. No new breaking changes.

## 🎯 Dynamic Responses (AFK) improvements

- **Smarter idle pacing** – The second auto-response no longer fires too quickly. The cooldown timer now reliably waits before triggering the next message.
- **Characters stay in narrative mode** – AFK responses now reliably produce story narration rather than dialogue addressed to the user, making the idle simulation feel more natural.
- **Character needs are now visible to the evaluator** – During AFK, the needs impact system (which decides how bladder, hunger, energy, etc. change) now knows the character's current needs state. This means activities like bathroom breaks result in proper bladder refill instead of near-zero changes.
- **Smarter needs evaluation during AFK** – The evaluator now knows how many turns have passed since the last check, so it compensates for decay when estimating need changes from activities like eating or resting.
- **Cleaner delta chips** – The needs delta chip at the bottom of AFK responses now shows per-need reasons (like "Scene action" or "Natural decay") instead of a single scene-level reason that was applied to every need. This means tooltips accurately describe what happened to each need.
- **Narrative instruction formatting** – Changed the solo-scene instruction from `[SCENE: ...]` brackets to `(OOC: ...)` parentheses to prevent the LLM from accidentally including the instruction text in its response.
- **Removed automatic AFK decay** – Needs no longer decay automatically each AFK cycle. The evaluator is now the sole source of need changes, which means:
  - Characters can do interesting activities (reading, napping, relaxing) without needs crashing to zero
  - No more firefighting survival mode — the evaluator adjusts needs based on what the character actually does
  - If the evaluator fails silently, needs stay perfectly stable instead of deteriorating
- **Time-skip cue framing** – AFK responses now use a "a few hours have passed" framing that encourages the LLM to reference multiple daily activities (a meal, bathroom, rest, bath) in each response. This means more needs get addressed per cycle rather than just one activity per response.
- **Better evaluator for solitary comfort** – The needs evaluator now recognizes cozy solitude, lounging, and quiet relaxation as comfort/energy restorers. Previously these scenes got zero credit because "comfort" was only paired with social connection. Now drowsing on a sofa or curling up with a book properly restores comfort.
- **Fixed evaluator decay bleed-through** – The evaluator no longer subtracts baseline drift from every need during AFK. Removed the hardcoded "on top of normal decay" instruction from the evaluator prompt, and added an explicit "no passive decay" context line when `decayTurns=0`. This means cozy scenes with no explicit eating/bathroom/sleeping no longer get penalized (hunger -3, bladder -3, etc.) when the only thing happening is relaxing.
- **Smarter decay compensation** – The needs evaluator still receives explicit magnitude guidance alongside current-needs context, helping it estimate the right deltas for restorative activities.
- **Removed redundant OOC instruction from author's note** – The AFK solo-scene prohibition ("no dialogue, don't address the user") was duplicated in both the system prompt idle cue and the author's note block. The author's note copy (`(OOC: ...)`) leaked into responses with some local models. Removed the duplicate — the system prompt version alone is more authoritative and doesn't get echoed back as narrative text.
- **Keyword safety net for failing evaluations** – When the needs evaluator returns all-zero deltas during AFK (common on weaker local models toward the third response), a keyword-based fallback now scans the scene for activities like "bathroom", "eating", "reading", "coffee", etc. and assigns reasonable positive deltas. This guarantees needs don't stagnate even when the evaluator model gets lazy mid-session.
- **Keyword merge instead of replace** – The fallback now fills only needs the model left at zero rather than replacing all deltas. This means if the model correctly assigned hygiene +15 and comfort +25 but missed bladder and fun, those correct values are preserved and only the gaps are filled. Also adds comfort +10 to showers and baths.
- **Zero-floor for AFK negatives** – The evaluator prompt instructs "Only report positive gains. Do NOT subtract anything" but some models still emit small negative deltas. A post-clamp zero-floor now catches and zeroes any negative during AFK.
- **Wider keyword coverage** – Added `dinner`, `pasta`, `leftover` (singular), `soda`, and `bed` to the keyword fallback to better cover common idle scenes.
- **Further keyword expansion** – Added `sleep`, `dish`, `apple`, and `cheese` to catch more idle scene patterns like "drifts off to sleep", washing dishes, and common snack foods.
- **Wider activity detection for morning routines** – The evaluator prompt now recognizes washing face, brushing teeth, freshening up (hygiene +5 to +20), scrolling social media on phone (fun +5 to +10), and enjoying a view or looking outside (comfort +5 to +15). Previously these common idle activities got zero need credit.

## 🧹 Internal cleanup

- Removed a previous change that accidentally made the needs evaluator always see the character's needs vector — it is now scoped to AFK-only, keeping normal conversation flow unchanged.
