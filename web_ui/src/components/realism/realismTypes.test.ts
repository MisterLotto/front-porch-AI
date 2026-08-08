// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The web half of the inventory data-loss fix.
//
// CharacterEditPage sends `...rv` wholesale, where `rv` is whatever
// realismFromDetail built out of the server's `realism` block. That makes this
// model the gate: a field it does not carry is a field every save drops.
//
// The Dart bridge omitted `inventory` in BOTH directions, so editing a
// character from a phone wiped whatever starting Pockets & Wardrobe its author
// had written — with no inventory control on the page to hint that the save had
// touched it. The Dart side is fixed and guarded in
// test/services/web/inventory_bridge_test.dart; this is the other end of the
// same round trip.

import { describe, expect, it } from 'vitest';

import { REALISM_DEFAULTS, realismFromDetail } from './realismTypes';

describe('inventory survives detail -> form -> save body', () => {
  const stored = {
    worn: [{ name: 'flour-dusted apron', state: 'well-worn' }],
    carrying: ['shop keys'],
  };

  it('carries the stored record off the detail block', () => {
    const rv = realismFromDetail({ inventory: stored });

    expect(rv.inventory).toEqual(stored);
  });

  it('keeps item condition, which is half of what Pockets tracks', () => {
    const worn = realismFromDetail({ inventory: stored }).inventory.worn!;

    expect(worn[0]).toEqual({ name: 'flour-dusted apron', state: 'well-worn' });
  });

  it('reaches the save body through the spread the edit page uses', () => {
    // Not a redundant restatement of the first case: the edit page builds its
    // POST as `{...fields, ...rv}`, so what matters is that the key is present
    // on the spread result — which is what breaks if the field is dropped from
    // the interface and TypeScript starts eliding it.
    const rv = realismFromDetail({ inventory: stored });
    const body = { name: 'Jennifer', description: 'edited', ...rv };

    expect(body).toHaveProperty('inventory');
    expect((body as typeof rv).inventory).toEqual(stored);
  });

  it('defaults to an empty record, never undefined', () => {
    // Undefined would reach the Dart side as a missing key. That is survivable
    // there (it falls back to the stored value) but it would mean the web could
    // never deliberately clear an inventory, which an authoring UI has to do.
    expect(REALISM_DEFAULTS.inventory).toEqual({});
    expect(realismFromDetail(null).inventory).toEqual({});
    expect(realismFromDetail(undefined).inventory).toEqual({});
  });

  it('a card with no realism block at all does not crash', () => {
    expect(() => realismFromDetail({}).inventory).not.toThrow();
    expect(realismFromDetail({}).inventory).toEqual({});
  });
});
