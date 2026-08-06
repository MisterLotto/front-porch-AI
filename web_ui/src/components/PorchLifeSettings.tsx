// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// "Porch Life" — the web mirror of the desktop's dedicated settings tab
// (lib/ui/settings/tabs/porch_life_tab.dart + widgets/feature_row.dart).
// Every "what makes characters feel alive" switch in one place, grouped by
// what it is, each saying plainly what it needs. The chips ("works alone" /
// "needs X" / "core") report the verified dependency matrix from
// docs/design/feature-independence.md rather than a guess — a feature that
// used to be hidden inside the Realism Engine's card (like the welcome-back
// recap or Story Weather) now says outright whether it actually needs the
// engine or was just filed under it.
//
// Self-contained and auto-saving, same pattern as PersonaManager: every
// switch applies the instant it's flipped — same feel as the desktop
// Switch — so there is no separate "Save settings" step for this card.
// Rides the same /api/settings `realism` object the app's other
// story-feature flags (ambitions, promises) already live in; a POST here
// only ever sends the one key that changed, so it can't clobber anything
// else queued in the page's big Save button.
//
// Scope note (mirrors the desktop doc comment): this card holds the GLOBAL
// defaults. Needs, Chaos Mode and Growth Rings are per-chat switches and
// live in the chat sidebar (ChatTools) — the closing note points there
// instead of pretending otherwise.

import { useEffect, useState } from 'react';
import type { ReactNode } from 'react';
import { api, ApiError } from '../api/client';

interface PorchLifeState {
  realismDefault: boolean;
  nsfwCooldownDefault: boolean;
  needsSimDefault: boolean;
  passageOfTimeDefault: boolean;
  weatherEnabled: boolean;
  weatherFahrenheit: boolean;
  journalEnabled: boolean;
  dreamsEnabled: boolean;
  promiseLedgerEnabled: boolean;
  ambitionsEnabled: boolean;
  absenceBannerEnabled: boolean;
  absenceAckEnabled: boolean;
  absenceThresholdHours: number;
}

// Same fallbacks as the Dart RealismSettings field defaults, so a field an
// older host build hasn't started returning yet still renders something sane
// rather than a false "off".
const DEFAULTS: PorchLifeState = {
  realismDefault: false,
  nsfwCooldownDefault: false,
  needsSimDefault: true,
  passageOfTimeDefault: true,
  weatherEnabled: true,
  weatherFahrenheit: false,
  journalEnabled: true,
  dreamsEnabled: true,
  promiseLedgerEnabled: true,
  ambitionsEnabled: true,
  absenceBannerEnabled: true,
  absenceAckEnabled: false,
  absenceThresholdHours: 24,
};

type Need = 'alone' | 'needs' | 'core';

function chipText(need: Need, dependsOn?: string): string {
  if (need === 'alone') return 'works alone';
  if (need === 'core') return 'CORE';
  return `needs ${dependsOn ?? ''}`;
}

function FeatureRow({
  icon,
  label,
  blurb,
  need = 'alone',
  dependsOn,
  satisfied = true,
  value,
  onChange,
  children,
}: {
  icon: string;
  label: string;
  blurb: string;
  need?: Need;
  dependsOn?: string;
  satisfied?: boolean;
  value: boolean;
  onChange: (v: boolean) => void;
  children?: ReactNode;
}) {
  // An unmet requirement GATES the row (dead switch + dimmed + indented),
  // matching the desktop widget. The first draft left dependants live and
  // stacked warning banners instead, which read as a wall of nags
  // (maintainer, 2026-08-07).
  const gated = need === 'needs' && !satisfied;
  return (
    <div className={`pl-row${need === 'needs' ? ' pl-row-dependent' : ''}${gated ? ' pl-row-gated' : ''}`}>
      <div className="pl-row-main">
        <span className="pl-row-icon" aria-hidden="true">{icon}</span>
        <div className="pl-row-body">
          <div className="pl-row-label-line">
            <span className="pl-label">{label}</span>
            <span className={`pl-chip pl-chip-${need}`}>{chipText(need, dependsOn)}</span>
          </div>
          <p className="pl-blurb">{blurb}</p>
        </div>
        <label className="pl-switch">
          <input
            type="checkbox"
            checked={value}
            onChange={(e) => onChange(e.target.checked)}
            disabled={gated}
            aria-label={label}
          />
        </label>
      </div>
      {children && value && !gated && <div className="pl-child">{children}</div>}
    </div>
  );
}

function FeatureGroup({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle: string;
  children: ReactNode;
}) {
  return (
    <div className="pl-group">
      <div className="pl-group-head">
        <span className="pl-group-title">{title}</span>
        <span className="pl-group-subtitle">{subtitle}</span>
      </div>
      {children}
    </div>
  );
}

const AWAY_OPTIONS: { value: number; label: string }[] = [
  { value: 12, label: '12 hours' },
  { value: 24, label: 'a day' },
  { value: 72, label: '3 days' },
  { value: 168, label: 'a week' },
];

/** The "away for at least" dropdown riding the absence-acknowledgement row.
 *  Values are clamped to a known option so a hand-edited preference can't
 *  assert the dropdown (carried over from the desktop widget). */
function AwayThreshold({ value, onChange }: { value: number; onChange: (v: number) => void }) {
  const known = AWAY_OPTIONS.some((o) => o.value === value) ? value : 24;
  return (
    <label className="pl-away row-label">
      <span>Away for at least</span>
      <select value={known} onChange={(e) => onChange(Number(e.target.value))}>
        {AWAY_OPTIONS.map((o) => (
          <option key={o.value} value={o.value}>{o.label}</option>
        ))}
      </select>
    </label>
  );
}

export function PorchLifeSettings() {
  const [st, setSt] = useState<PorchLifeState | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    void api
      .get<{ realism?: Partial<PorchLifeState> }>('/api/settings')
      .then((r) => setSt({ ...DEFAULTS, ...r.realism }))
      .catch(() => setSt({ ...DEFAULTS }));
  }, []);

  if (!st) return null;

  const set = <K extends keyof PorchLifeState>(key: K, value: PorchLifeState[K]) => {
    const prev = st;
    setSt({ ...st, [key]: value });
    setError('');
    api.post('/api/settings', { realism: { [key]: value } }).catch((e) => {
      setSt(prev);
      setError(e instanceof ApiError ? e.message : 'Could not save that change');
    });
  };

  const engineOn = st.realismDefault;
  const timeOn = st.passageOfTimeDefault;
  const weatherOn = st.weatherEnabled;
  const journalOn = st.journalEnabled;

  return (
    <section className="card pl-section">
      <h3>Porch Life</h3>
      <p className="muted small pl-intro">
        Everything that makes a character feel like they live somewhere. Each switch says plainly what it needs — many need nothing at all.
      </p>

      <FeatureGroup title="The Engine" subtitle="feelings about what you do">
        <FeatureRow
          icon="🎭"
          label="Realism Engine"
          need="core"
          blurb="Bond and trust, moods that carry between turns, physical state — how the character feels about what you just did. Needs, the story clock and desire all read from it; the rest of Porch Life runs with or without it, and every row says which it is."
          value={engineOn}
          onChange={(v) => set('realismDefault', v)}
        />
        <FeatureRow
          icon="❤️"
          label="Needs"
          need="needs"
          dependsOn="the Realism Engine"
          satisfied={engineOn}
          blurb="Hunger, energy, comfort and the rest, Sims-style — they drift through a scene and colour how the character feels. The engine is what turns a need into a mood, so needs run with it or not at all. Individual chats can still switch them off in the sidebar."
          value={st.needsSimDefault}
          onChange={(v) => set('needsSimDefault', v)}
        />
        <FeatureRow
          icon="🔥"
          label="Afterglow"
          need="needs"
          dependsOn="the Realism Engine"
          satisfied={engineOn}
          blurb="Desire builds through a scene and settles afterwards instead of resetting — so intimacy keeps a believable rhythm and a character is not instantly ready to go again. The engine is what scores desire, so this cannot run without it. (18+ themes only.)"
          value={st.nsfwCooldownDefault}
          onChange={(v) => set('nsfwCooldownDefault', v)}
        />
      </FeatureGroup>

      <FeatureGroup title="Time & World" subtitle="the story's clock and sky">
        <FeatureRow
          icon="⏰"
          label="Passage of Time"
          need="needs"
          dependsOn="the Realism Engine"
          satisfied={engineOn}
          blurb="The story keeps its own clock — dawn to morning to evening to night, day after day. The AI judges how long each exchange actually took, which is part of the Realism Engine, so the clock moves with the engine on and stops with it off."
          value={timeOn}
          onChange={(v) => set('passageOfTimeDefault', v)}
        />
        <FeatureRow
          icon="☁️"
          label="Story Weather"
          need="needs"
          dependsOn="Passage of Time"
          satisfied={timeOn}
          blurb={'Weather rolls through the story\'s days and is felt in mood and comfort. Characters can see fronts coming ("looks like rain tomorrow").'}
          value={weatherOn}
          onChange={(v) => set('weatherEnabled', v)}
        />
        <FeatureRow
          icon="🌡️"
          label="Temperatures in °F"
          need="needs"
          dependsOn="Story Weather"
          satisfied={weatherOn}
          blurb={'Display only — characters always experience weather in words ("coat-and-gloves cold"), never numbers.'}
          value={st.weatherFahrenheit}
          onChange={(v) => set('weatherFahrenheit', v)}
        />
      </FeatureGroup>

      <FeatureGroup title="Memory & Heart" subtitle="what they keep and carry">
        <FeatureRow
          icon="📖"
          label="The Journal"
          blurb={'Memory cards and the "where we are" recap, kept per chat and never shared between chats. With the Realism Engine on, cards also carry the feeling of the moment; without it they are simply remembered.'}
          value={journalOn}
          onChange={(v) => set('journalEnabled', v)}
        />
        <FeatureRow
          icon="🌙"
          label="Dreams"
          need="needs"
          dependsOn="the Journal and Passage of Time"
          satisfied={journalOn && timeOn}
          blurb="When a story night passes, the character dreams — a short, hazy scene woven from their memories, mood and the weather."
          value={st.dreamsEnabled}
          onChange={(v) => set('dreamsEnabled', v)}
        />
        <FeatureRow
          icon="🤝"
          label="Promises"
          need="needs"
          dependsOn="the Journal"
          satisfied={journalOn}
          blurb={"Commitments either of you make are remembered, and kept or broken ones come back later. Uses one extra AI request per reply to spot them, so it is slower and costs more on a paid API. You can settle one yourself in the Journal's Promises tab."}
          value={st.promiseLedgerEnabled}
          onChange={(v) => set('promiseLedgerEnabled', v)}
        />
        <FeatureRow
          icon="🚩"
          label="Ambitions"
          blurb={"Long-term goals written on the character's card colour how they steer a scene, and finishing an objective moves them a little closer. Costs nothing extra — the goals are already on the card."}
          value={st.ambitionsEnabled}
          onChange={(v) => set('ambitionsEnabled', v)}
        />
      </FeatureGroup>

      <FeatureGroup title="Presence" subtitle="noticing you, nothing more">
        <FeatureRow
          icon="🕰️"
          label="Welcome-back recap"
          blurb={'After you have been away a while, opening a chat shows a small "where we left off" banner. Uses the time of your last message, already saved with your chat. Nothing new is collected and nothing leaves your device.'}
          value={st.absenceBannerEnabled}
          onChange={(v) => set('absenceBannerEnabled', v)}
        />
        <FeatureRow
          icon="👋"
          label="Character notices your absence"
          blurb={'The character briefly acknowledges a long gap ("it\'s been a few days") — once, in coarse words, never guessing what you were doing. Same local-only timestamp as the recap banner.'}
          value={st.absenceAckEnabled}
          onChange={(v) => set('absenceAckEnabled', v)}
        >
          <AwayThreshold
            value={st.absenceThresholdHours}
            onChange={(v) => set('absenceThresholdHours', v)}
          />
        </FeatureRow>
      </FeatureGroup>

      {error && <p className="error pl-error">{error}</p>}

      <div className="pl-note">
        Chaos Mode and Growth Rings are set per chat rather than globally — open a chat and use its sidebar to switch them for that story.
      </div>
    </section>
  );
}
