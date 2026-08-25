// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Compact opening-state editor for one alternate greeting. Off (null) =
// reading-the-room; on = authored seed (blank fields inherit card defaults).

import { Slider, SelectRow, ToggleRow } from './realism/controls';
import { ChipList } from './realism/ChipList';
import {
  type GreetingSeed,
  INTENSITY_OPTIONS,
  TIME_OPTIONS,
  chipsToInventory,
  inventoryToChips,
  titleCase,
} from './realism/realismTypes';

export function GreetingSeedForm({
  seed,
  onChange,
  showNeeds = false,
  showInventory = false,
}: {
  seed: GreetingSeed | null;
  onChange: (next: GreetingSeed | null) => void;
  showNeeds?: boolean;
  showInventory?: boolean;
}) {
  const enabled = seed != null;
  const s = seed ?? {};
  const patch = (p: Partial<GreetingSeed>) => onChange({ ...s, ...p });
  const wardrobe = inventoryToChips(s.inventory ?? {});
  return (
    <div className="greeting-seed">
      <ToggleRow
        label="Custom opening state"
        hint={
          enabled
            ? 'Blank fields inherit the card. This alt will not read the room.'
            : 'No seed — the engine reads the room from this greeting.'
        }
        value={enabled}
        onChange={(on) => onChange(on ? {} : null)}
      />
      {enabled && (
        <>
          <label>
            Emotion
            <input
              value={s.characterEmotion ?? ''}
              placeholder="e.g. furious, warm, guarded"
              onChange={(e) =>
                patch({ characterEmotion: e.target.value.trim() || undefined })
              }
            />
          </label>
          <SelectRow
            label="Intensity"
            value={s.emotionIntensity ?? 'moderate'}
            options={INTENSITY_OPTIONS.map((i) => ({ value: i, label: titleCase(i) }))}
            onChange={(v) => patch({ emotionIntensity: v })}
          />
          <Slider
            label="Short-term bond"
            min={-300}
            max={300}
            value={s.shortTermBond ?? 0}
            onChange={(n) => patch({ shortTermBond: n })}
          />
          <Slider
            label="Long-term bond"
            min={-300}
            max={300}
            value={s.longTermBond ?? 0}
            onChange={(n) => patch({ longTermBond: n })}
          />
          <Slider
            label="Trust"
            min={-100}
            max={100}
            value={s.trustLevel ?? 0}
            onChange={(n) => patch({ trustLevel: n })}
          />
          <SelectRow
            label="Time of day"
            value={s.timeOfDay ?? 'morning'}
            options={TIME_OPTIONS.map((t) => ({ value: t, label: titleCase(t) }))}
            onChange={(v) => patch({ timeOfDay: v })}
          />
          <label>
            Day number
            <input
              type="number"
              min={1}
              value={s.dayCount ?? 1}
              onChange={(e) =>
                patch({ dayCount: Math.max(1, parseInt(e.target.value, 10) || 1) })
              }
            />
          </label>
          <label>
            Starting task
            <input
              value={s.currentTask ?? ''}
              placeholder="Optional in-voice objective"
              onChange={(e) =>
                patch({ currentTask: e.target.value.trim() || undefined })
              }
            />
          </label>
          {showNeeds && (
            <>
              <p className="muted small">Needs baselines (0–100). Default 80 inherits the card slider rest.</p>
              {NEEDS.map(([key, label]) => (
                <Slider
                  key={key}
                  label={label}
                  min={0}
                  max={100}
                  value={(s[key] as number | undefined) ?? 80}
                  onChange={(n) => patch({ [key]: n })}
                />
              ))}
            </>
          )}
          {showInventory && (
            <>
              <ChipList
                label="Wearing (this opening)"
                values={wardrobe.worn}
                onChange={(worn) =>
                  patch({ inventory: chipsToInventory(worn, wardrobe.carrying) })
                }
              />
              <ChipList
                label="Carrying (this opening)"
                values={wardrobe.carrying}
                onChange={(carrying) =>
                  patch({ inventory: chipsToInventory(wardrobe.worn, carrying) })
                }
              />
            </>
          )}
        </>
      )}
    </div>
  );
}

const NEEDS: [keyof GreetingSeed & string, string][] = [
  ['needsBaselineHunger', 'Hunger'],
  ['needsBaselineBladder', 'Bladder'],
  ['needsBaselineEnergy', 'Energy'],
  ['needsBaselineSocial', 'Social'],
  ['needsBaselineFun', 'Fun'],
  ['needsBaselineHygiene', 'Hygiene'],
  ['needsBaselineComfort', 'Comfort'],
];
