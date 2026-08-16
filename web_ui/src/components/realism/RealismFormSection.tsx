// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shared Realism Engine configuration form — the web mirror of the Flutter
// realism_form_section.dart. Drives the starting relationship/emotion/time
// seeds, the optional NSFW-cooldown / chaos / verifier features and the initial
// task. Reused by the character create wizard and the character edit page so
// both author identical seeds. Needs Simulation is a sibling section
// (NeedsFormSection) rendered alongside this one.

import { Slider, ToggleRow, SelectRow } from './controls';
import { ChipList } from './ChipList';
import {
  type RealismValues,
  chipsToInventory,
  inventoryToChips,
  INTENSITY_OPTIONS,
  TIME_OPTIONS,
  longTermTier,
  shortTermTier,
  titleCase,
  trustTier,
} from './realismTypes';

type Patch = (patch: Partial<RealismValues>) => void;

export function RealismFormSection({
  v,
  set,
  showIntimate = false,
}: {
  v: RealismValues;
  set: Patch;
  /// The install's 18+ master switch, mirroring desktop: the intimate pair is
  /// absent (not disabled) unless the user opted into 18+ themes.
  showIntimate?: boolean;
}) {
  return (
    <div className="realism-section">
      <ToggleRow
        label="Enable Realism Engine"
        hint={
          v.realismEnabled
            ? 'Character starts with the pre-configured state below'
            : 'Wardrobe, likes, time and Chaos still apply. Bond, mood and Needs stay off.'
        }
        value={v.realismEnabled}
        onChange={(b) => set({ realismEnabled: b })}
      />

      {/* Time, Chaos, identity chips are Porch Life — they run without the
          Realism Engine. Bond/emotion/afterglow/verifier stay behind the
          switch (those need the engine). */}
          {/* ── Time & Day ── */}
          <h4 className="realism-head">Time &amp; Day</h4>
          <div className="realism-grid-2">
            <SelectRow
              label="Time of day"
              value={v.timeOfDay}
              options={TIME_OPTIONS.map((t) => ({ value: t, label: titleCase(t) }))}
              onChange={(s) => set({ timeOfDay: s })}
            />
            <label className="realism-field">
              <span>Day number</span>
              <input
                type="number"
                min={1}
                value={v.dayCount}
                onChange={(e) => set({ dayCount: Math.max(1, parseInt(e.target.value, 10) || 1) })}
              />
            </label>
          </div>

          <ToggleRow
            label="Chaos mode (Chance Time)"
            hint="Random narrative events during roleplay — works with the engine off"
            value={v.chaosModeEnabled}
            onChange={(b) => set({ chaosModeEnabled: b })}
          />
          <ToggleRow
            label="Auto passage of time"
            hint="Advance the scene clock automatically — works with the engine off"
            value={v.passageOfTimeEnabled}
            onChange={(b) => set({ passageOfTimeEnabled: b })}
          />

          {v.realismEnabled && (
          <>
          {/* ── Relationship ── */}
          <h4 className="realism-head">Relationship</h4>
          <div className="card realism-card">
            <Slider
              label="Short-term bond"
              min={-300}
              max={300}
              value={v.shortTermBond}
              badge={`${shortTermTier(v.shortTermBond)} (${v.shortTermBond})`}
              onChange={(n) => set({ shortTermBond: n })}
            />
            <Slider
              label="Long-term bond"
              min={-300}
              max={300}
              value={v.longTermBond}
              badge={`${longTermTier(v.longTermBond)} (${v.longTermBond})`}
              onChange={(n) => set({ longTermBond: n })}
            />
            <Slider
              label="Trust level"
              min={-100}
              max={100}
              value={v.trustLevel}
              badge={`${trustTier(v.trustLevel)} (${v.trustLevel})`}
              onChange={(n) => set({ trustLevel: n })}
            />
          </div>

          {/* ── Starting emotion ── */}
          <h4 className="realism-head">Starting emotion</h4>
          <div className="realism-grid-2">
            <label className="realism-field">
              <span>Emotion</span>
              <input
                value={v.characterEmotion}
                placeholder="e.g. curious, guarded, amused"
                onChange={(e) => set({ characterEmotion: e.target.value })}
              />
            </label>
            <SelectRow
              label="Intensity"
              value={v.emotionIntensity}
              options={INTENSITY_OPTIONS.map((i) => ({ value: i, label: titleCase(i) }))}
              onChange={(s) => set({ emotionIntensity: s })}
            />
          </div>

          {/* ── Optional features ── */}
          <h4 className="realism-head">Optional features</h4>
          <div className="card realism-card">
            <ToggleRow
              label="Afterglow (intimacy pacing)"
              hint="Realistic arousal / refractory mechanics"
              value={v.nsfwCooldownEnabled}
              onChange={(b) => set({ nsfwCooldownEnabled: b })}
            />
            <ToggleRow
              label="Realism verification (Director/Verifier)"
              hint="Optional director thread validates realism + needs deltas (extra eval cost; strong models recommended)"
              value={v.realismVerificationEnabled}
              onChange={(b) => set({ realismVerificationEnabled: b })}
            />
            {v.realismVerificationEnabled && (
              <>
                <Slider
                  label="Max reprocess passes"
                  min={1}
                  max={5}
                  value={v.realismVerificationMaxReprocesses}
                  badge={`${v.realismVerificationMaxReprocesses}`}
                  onChange={(n) => set({ realismVerificationMaxReprocesses: n })}
                />
                <Slider
                  label="Strictness (1 lenient … 5 strict)"
                  min={1}
                  max={5}
                  value={v.realismVerificationStrictness}
                  badge={`${v.realismVerificationStrictness}`}
                  onChange={(n) => set({ realismVerificationStrictness: n })}
                />
                <ToggleRow
                  label="Director authority over needs"
                  hint="Verified/corrected needs deltas take authority"
                  value={v.realismNeedsDirectorAuthority}
                  onChange={(b) => set({ realismNeedsDirectorAuthority: b })}
                />
              </>
            )}
          </div>
          </>
          )}

          {/* ── Ambitions (approved sketch §4) ──
              "Ambitions — long-term goals, one per chip (replaces 'Current
              Task / Quest' in this editor)". Mirrors the desktop editor. */}
          <ChipList
            label="Ambitions"
            accent
            values={v.ambitions}
            onChange={(a) => set({ ambitions: a })}
            placeholder="e.g. open a bakery"
            helper="What this character is working toward across the whole story. They colour how the character steers a scene, and they inch forward when objectives complete. Not a to-do list — quests live in the chat sidebar."
          />
          {/* ── Likes & Dislikes ── mirrors identity_chip_lists.dart. Two
              plain (non-accent) chip lists, exactly as the sketch draws them. */}
          <ChipList
            label="Drawn to"
            values={v.likes}
            onChange={(a) => set({ likes: a })}
            placeholder="e.g. thunderstorms"
            helper="Small, specific things this character warms to. They colour how the character reacts to what is already happening — and, with the Realism Engine on, how much a moment moves them."
          />
          <ChipList
            label="Put off by"
            values={v.dislikes}
            onChange={(a) => set({ dislikes: a })}
            placeholder="e.g. being interrupted"
            helper="What makes this character bristle. Phrases, not paragraphs — one thing per chip reads best in a scene."
          />

          {/* ── Pockets & Wardrobe ── mirrors identity_chip_lists.dart. What
              the character already has when a chat opens; the runtime seeds
              its record from exactly this map. */}
          <ChipList
            label="Wearing"
            values={inventoryToChips(v.inventory).worn}
            onChange={(a) =>
              set({ inventory: chipsToInventory(a, inventoryToChips(v.inventory).carrying) })
            }
            placeholder="e.g. flour-dusted apron"
            helper='What this character already has when a chat opens. Add a condition in brackets — "sundress (rain-soaked)" — and it is kept and updated as the story uses the item.'
          />
          <ChipList
            label="Carrying"
            values={inventoryToChips(v.inventory).carrying}
            onChange={(a) =>
              set({ inventory: chipsToInventory(inventoryToChips(v.inventory).worn, a) })
            }
            placeholder="e.g. car keys"
            helper="Tracked once Pockets & Wardrobe is switched on in Settings → Porch Life. Up to 8 of each; the oldest drops off if a character picks up more."
          />

          {/* The 18+ pair, only for an install that asked for it. */}
          {showIntimate && (
            <>
              <ChipList
                label="Warms to"
                values={v.intimateInto}
                onChange={(a) => set({ intimateInto: a })}
                placeholder="e.g. slow mornings"
                helper="Suggestive tastes for 18+ scenes. These stay out of the prompt entirely unless 18+ themes are switched on."
              />
              <ChipList
                label="Not interested in"
                values={v.intimateNotInto}
                onChange={(a) => set({ intimateNotInto: a })}
                placeholder="e.g. an audience"
              />
            </>
          )}

          {/* Ambitions replaced the "Current task / quest" textarea here, exactly
              as on desktop. `currentTask` stays in RealismValues (seeded from
              /detail, sent straight back on save) so a card authored before the
              swap keeps its task on disk — the chat now imports it as a starting
              objective instead of asking the author to maintain it by hand. */}
    </div>
  );
}
