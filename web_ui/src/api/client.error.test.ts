import { describe, expect, it } from 'vitest';
import { parseApiErrorBody } from './client';

describe('parseApiErrorBody', () => {
  it('prefers the JSON error field over the raw body', () => {
    const e = parseApiErrorBody('{"error":"No chat to export"}', 404);
    expect(e.message).toBe('No chat to export');
    expect(e.status).toBe(404);
  });

  it('falls back to the raw text when the body is not JSON', () => {
    const e = parseApiErrorBody('not json', 500);
    expect(e.message).toBe('not json');
  });

  it('does not surface raw JSON when error is missing', () => {
    const e = parseApiErrorBody('{"ok":false}', 500);
    expect(e.message).toBe('Request failed (500)');
    expect(e.payload).toEqual({ ok: false });
  });

  it('treats a JSON null body as an empty payload', () => {
    const e = parseApiErrorBody('null', 500);
    expect(e.message).toBe('Request failed (500)');
    expect(e.payload).toEqual({});
  });
});
