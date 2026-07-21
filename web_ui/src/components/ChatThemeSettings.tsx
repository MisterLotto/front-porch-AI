// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Per-chat theme settings — the web mirror of the desktop's theme panel in
// ChatSettingsDialog. Lets the user pick a theme preset and customize per-chat
// colors, font, background, and border style. Saves to the active session via
// POST /api/chat/theme-overrides.

import { useState, useEffect } from 'react';
import type { ChatThemeOverrides, ChatThemePreset } from './chatTypes';

// Mirror of the 10 desktop presets (ChatThemePreset.presets).
const PRESETS: ChatThemePreset[] = [
  { id: 'fantasy', displayName: 'Fantasy', description: 'Rich purples and soft gold', defaultUserBubbleColor: 0xFFFFE57F, defaultUserTextColor: 0xFF6D4C41, defaultAiBubbleColor: 0xFFFFE57F, defaultAiTextColor: 0xFF3E2723, defaultBorderColor: 0xFF007E1B, defaultFontFamily: 'serif', defaultBackgroundKey: 'fantasy', defaultBorderStyle: 'vine' },
  { id: 'galactic', displayName: 'Galactic', description: 'Deep space blues and cyan', defaultUserBubbleColor: 0xFF0D1B2A, defaultUserTextColor: 0xFF00D4FF, defaultAiBubbleColor: 0xFF0D1B2A, defaultAiTextColor: 0xFFE0E0FF, defaultBorderColor: 0xFF00D4FF, defaultFontFamily: 'sans-serif', defaultBackgroundKey: 'space_station', defaultBorderStyle: 'dualLine' },
  { id: 'neon_grid', displayName: 'Neon Grid', description: 'Black backdrop with neon glow', defaultUserBubbleColor: 0xFF0A0A0A, defaultUserTextColor: 0xFFFF00FF, defaultAiBubbleColor: 0xFF0A0A0A, defaultAiTextColor: 0xFF00FFFF, defaultBorderColor: 0xFFFF00FF, defaultFontFamily: 'monospace', defaultBackgroundKey: 'grid', defaultBorderStyle: 'glitch' },
  { id: 'sakura', displayName: 'Sakura', description: 'Soft pinks and pale tones', defaultUserBubbleColor: 0xFFFFE4E9, defaultUserTextColor: 0xFF2D5A27, defaultAiBubbleColor: 0xFFFFE4E9, defaultAiTextColor: 0xFF2D5A27, defaultBorderColor: 0xFF2D5A27, defaultFontFamily: 'serif', defaultBackgroundKey: 'cherry_blossom', defaultBorderStyle: 'wavy' },
  { id: 'noir', displayName: 'Noir', description: 'Monochrome shadows', defaultUserBubbleColor: 0xFF2D2D2D, defaultUserTextColor: 0xFFF5F5F5, defaultAiBubbleColor: 0xFF1A1A1A, defaultAiTextColor: 0xFFCCCCCC, defaultBorderColor: 0xFF888888, defaultFontFamily: 'sans-serif', defaultBackgroundKey: 'noir', defaultBorderStyle: 'shadow' },
  { id: 'enchanted_forest', displayName: 'Enchanted Forest', description: 'Deep greens and warm earth', defaultUserBubbleColor: 0xFF2D5A27, defaultUserTextColor: 0xFFF0E6D3, defaultAiBubbleColor: 0xFF4A7C3F, defaultAiTextColor: 0xFFFFF8E7, defaultBorderColor: 0xFF5E3D04, defaultFontFamily: 'serif', defaultBackgroundKey: 'enchanted_wood', defaultBorderStyle: 'vine' },
  { id: 'ocean_depths', displayName: 'Ocean Depths', description: 'Deep blues and teal', defaultUserBubbleColor: 0xFF003049, defaultUserTextColor: 0xFFE0F7FA, defaultAiBubbleColor: 0xFF006D77, defaultAiTextColor: 0xFFE0F7FA, defaultBorderColor: 0xFF00BCD4, defaultFontFamily: 'sans-serif', defaultBackgroundKey: 'ocean_depth', defaultBorderStyle: 'dualLine' },
  { id: 'cyberpunk', displayName: 'Cyberpunk', description: 'Neon on dark', defaultUserBubbleColor: 0xFF0A0A23, defaultUserTextColor: 0xFF00FF41, defaultAiBubbleColor: 0xFF1A0A2E, defaultAiTextColor: 0xFFFF00FF, defaultBorderColor: 0xFF00FF41, defaultFontFamily: 'monospace', defaultBackgroundKey: 'futuristic_city', defaultBorderStyle: 'glitch' },
  { id: 'roman_empire', displayName: 'Roman Empire', description: 'Rich browns and warm cream', defaultUserBubbleColor: 0xFFFDE68A, defaultUserTextColor: 0xFF5D4037, defaultAiBubbleColor: 0xFFFDE68A, defaultAiTextColor: 0xFF451A03, defaultBorderColor: 0xFF451A03, defaultFontFamily: 'serif', defaultBackgroundKey: 'roman_market', defaultBorderStyle: 'greekKey' },
  { id: 'steampunk', displayName: 'Steampunk', description: 'Brass and copper tones', defaultUserBubbleColor: 0xFF3E2723, defaultUserTextColor: 0xFFFFD54F, defaultAiBubbleColor: 0xFF5D4037, defaultAiTextColor: 0xFFE0C9A6, defaultBorderColor: 0xFFFFD54F, defaultFontFamily: 'serif', defaultBackgroundKey: 'steampunk_bg', defaultBorderStyle: 'gear' },
];

const FONT_OPTIONS = ['sans-serif', 'serif', 'monospace'];

const BORDER_STYLES = ['vine', 'dualLine', 'glitch', 'wavy', 'shadow', 'greekKey', 'gear'];

const COLOR_LABELS: { key: keyof ChatThemeOverrides; label: string }[] = [
  { key: 'userBubbleColor', label: 'Your bubble' },
  { key: 'userTextColor', label: 'Your text' },
  { key: 'aiBubbleColor', label: 'AI bubble' },
  { key: 'aiTextColor', label: 'AI text' },
  { key: 'borderColor', label: 'Border' },
];

// Convert a Dart int color (0xAARRGGBB or 0xRRGGBB) to a CSS hex string.
function dartColorToCss(color: number): string {
  const hex = color.toString(16).padStart(8, '0');
  return '#' + hex.substring(2);
}

export function ChatThemeSettings({ overrides, onSave }: {
  overrides: ChatThemeOverrides | null;
  onSave: (o: ChatThemeOverrides) => void;
}) {
  const [local, setLocal] = useState<ChatThemeOverrides>(overrides ?? {});
  useEffect(() => setLocal(overrides ?? {}), [overrides]);

  const selectedPreset = local.themeId
    ? PRESETS.find((p) => p.id === local.themeId) ?? null
    : null;

  const set = (patch: Partial<ChatThemeOverrides>) =>
    setLocal((prev) => ({ ...prev, ...patch }));

  return (
    <section className="card theme-settings">
      <h3>Chat theme</h3>
      <p className="muted small">Pick a visual theme for this chat. Customize individual colors below.</p>

      {/* Preset picker */}
      <div className="theme-presets">
        {/* "None" card */}
        <button
          className={`theme-preset-card${!local.themeId ? ' active' : ''}`}
          onClick={() => setLocal({})}
        >
          <span className="theme-preset-none">—</span>
          <span className="theme-preset-name">None</span>
        </button>
        {PRESETS.map((p) => (
          <button
            key={p.id}
            className={`theme-preset-card${local.themeId === p.id ? ' active' : ''}`}
            onClick={() => set({ themeId: p.id })}
          >
            <span className="theme-preset-swatches">
              <span className="theme-swatch" style={{ backgroundColor: dartColorToCss(p.defaultUserBubbleColor) }} />
              <span className="theme-swatch" style={{ backgroundColor: dartColorToCss(p.defaultAiBubbleColor) }} />
            </span>
            <span className="theme-preset-name">{p.displayName}</span>
            <span className="theme-preset-style">{p.defaultBorderStyle}</span>
          </button>
        ))}
      </div>

      {/* Customization fields (only when a preset is selected) */}
      {selectedPreset && <>
        <h4 className="section-label">Colors</h4>
        <div className="color-rows">
          {COLOR_LABELS.map((c) => {
            const val = local[c.key];
            const defaultVal = c.key === 'borderColor' && selectedPreset.defaultBorderColor
              ? dartColorToCss(selectedPreset.defaultBorderColor)
              : dartColorToCss(
                  c.key === 'userBubbleColor' ? selectedPreset.defaultUserBubbleColor
                  : c.key === 'userTextColor' ? selectedPreset.defaultUserTextColor
                  : c.key === 'aiBubbleColor' ? selectedPreset.defaultAiBubbleColor
                  : selectedPreset.defaultAiTextColor
                );
            return (
              <label key={c.key} className="color-row">
                <span>{c.label}</span>
                <input
                  type="color"
                  value={val ? `#${val}` : defaultVal}
                  onChange={(e) => set({ [c.key]: e.target.value.substring(1).toUpperCase() })}
                />
                <button
                  className="ghost small"
                  onClick={() => set({ [c.key]: null })}
                  disabled={!val}
                  title="Reset to preset default"
                >↺</button>
              </label>
            );
          })}
        </div>

        <h4 className="section-label">Font</h4>
        <select
          className="theme-select"
          value={local.fontFamily ?? selectedPreset.defaultFontFamily}
          onChange={(e) => set({ fontFamily: e.target.value === selectedPreset.defaultFontFamily ? null : e.target.value })}
        >
          {FONT_OPTIONS.map((f) => (
            <option key={f} value={f}>{f}</option>
          ))}
        </select>

        <h4 className="section-label">Border style</h4>
        <select
          className="theme-select"
          value={local.borderStyle ?? selectedPreset.defaultBorderStyle}
          onChange={(e) => set({ borderStyle: e.target.value === selectedPreset.defaultBorderStyle ? null : e.target.value })}
        >
          {BORDER_STYLES.map((s) => (
            <option key={s} value={s}>{s}</option>
          ))}
        </select>
      </>}

      <div className="theme-actions">
        <button className="primary" onClick={() => onSave(local)}>Save theme</button>
        {local.themeId && (
          <button className="ghost" onClick={() => setLocal({})}>Remove theme</button>
        )}
      </div>
    </section>
  );
}
