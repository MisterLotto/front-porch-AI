import { describe, expect, it } from 'vitest';
import {
  chatExportFilename,
  chatExportStem,
  importResultMessage,
} from './chatPackage';

describe('chatExportStem', () => {
  it('keeps a simple name', () => {
    expect(chatExportStem('Alice')).toBe('Alice');
  });

  it('replaces spaces and punctuation', () => {
    expect(chatExportStem('Malumbra the Oblivian')).toBe('Malumbra_the_Oblivian');
  });

  it('falls back when the title is empty', () => {
    expect(chatExportStem('')).toBe('chat');
    expect(chatExportStem('@@@')).toBe('chat');
  });
});

describe('chatExportFilename', () => {
  it('ends with the requested extension', () => {
    expect(chatExportFilename('Alice', 'jsonl')).toMatch(/\.jsonl$/);
    expect(chatExportFilename('Alice', 'fpchat')).toMatch(/\.fpchat$/);
  });
});

describe('importResultMessage', () => {
  it('names a full restore', () => {
    expect(importResultMessage({ fullRestore: true })).toBe(
      'Chat imported with full Front Porch state',
    );
  });

  it('names dialogue-only', () => {
    expect(importResultMessage({ fullRestore: false })).toBe(
      'Chat imported (dialogue only)',
    );
  });
});
