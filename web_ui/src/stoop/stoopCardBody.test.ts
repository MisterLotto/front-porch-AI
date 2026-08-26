import { describe, expect, it } from 'vitest';
import {
  stoopCardKind,
  stoopGreetings,
  stoopGroupTurnLabel,
  stoopMembers,
  stoopWorldClimate,
  stoopWorldTraits,
} from './stoopCardBody';

describe('stoopCardBody', () => {
  it('reads group members from raw_member_data or members', () => {
    expect(stoopMembers({ members: [{ name: 'A' }, { data: { name: 'B' } }] }).map((m) => m.name)).toEqual([
      'A',
      'B',
    ]);
  });

  it('joins first_mes plus alternate greetings', () => {
    expect(
      stoopGreetings({
        first_mes: 'Hi',
        alternate_greetings: ['Yo', '  '],
      }),
    ).toEqual(['Hi', 'Yo']);
  });

  it('formats world climate and traits', () => {
    expect(
      stoopWorldClimate({
        biome: { displayName: 'Creek', feel: 'damp stones' },
      }),
    ).toBe('Creek — damp stones');
    expect(stoopWorldTraits({ place_traits: { quiet: true } })).toEqual(['quiet: true']);
  });

  it('labels group turn order', () => {
    expect(stoopGroupTurnLabel({ turn_order: 'random' }, 2)).toBe('Random · 2 characters');
  });

  it('upgrades a SOLO label when the blob is a world or group', () => {
    expect(stoopCardKind('SOLO', { biome: { displayName: 'Creek' } })).toBe('WORLD');
    expect(stoopCardKind('SOLO', { members: [{ name: 'A' }] })).toBe('GROUP');
    expect(stoopCardKind('SOLO', { first_mes: 'hi', personality: 'kind' })).toBe('SOLO');
  });
});
