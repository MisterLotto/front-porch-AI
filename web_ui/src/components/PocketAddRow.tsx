// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Hand-add row for Pockets & Wardrobe (desktop dialog parity).
// "Give" hands the item over in-scene — it lands in their hands and they know
// it came from you. "Add" is the quiet drop (the Easter egg): it lands in
// the chosen section and their next reply is surprised to find it.
// When Wearing is selected, "Put on" is the record correction: they are
// wearing it as fact, no surprise, no gift. Item text follows the same
// "name (state)" convention as everywhere else.

import { useState } from 'react';

export type PocketAddFn = (
  section: string,
  name: string,
  gift: boolean,
  correction?: boolean,
) => void;

export function PocketAddRow({ onAdd }: { onAdd: PocketAddFn }) {
  const [name, setName] = useState('');
  const [section, setSection] = useState('carrying');
  const wearing = section === 'worn';
  const submit = (opts: { gift?: boolean; correction?: boolean }) => {
    const n = name.trim();
    if (!n) return;
    if (opts.correction) {
      // Record fix: honour the selected section (dress UI sends worn). Gift
      // is ignored — you don't hand someone a coat onto their body.
      onAdd(section, n, false, true);
    } else if (opts.gift) {
      // A gift lands in their hands regardless of the selected section —
      // you hand someone a sweater, you don't dress them in it (desktop rule).
      onAdd('carrying', n, true, false);
    } else {
      onAdd(section, n, false, false);
    }
    setName('');
  };
  return (
    <div className="pocket-add">
      <input
        value={name}
        placeholder={wearing ? 'red sundress' : 'brass key (scuffed)'}
        onChange={(e) => setName(e.target.value)}
        onKeyDown={(e) =>
          e.key === 'Enter' && submit(wearing ? { correction: true } : { gift: false })
        }
      />
      <select value={section} onChange={(e) => setSection(e.target.value)}>
        <option value="worn">Wearing</option>
        <option value="carrying">Carrying</option>
        <option value="set_aside">Set aside</option>
      </select>
      {!wearing && (
        <button
          title="Slip it in quietly — they'll be surprised to find it"
          onClick={() => submit({ gift: false })}
        >
          Add
        </button>
      )}
      {wearing ? (
        <button
          className="put-on"
          title="Record that they're wearing this — next reply they're just dressed"
          onClick={() => submit({ correction: true })}
        >
          Put on
        </button>
      ) : (
        <button
          title="Hand it over in-scene — they'll know it came from you"
          onClick={() => submit({ gift: true })}
        >
          Give
        </button>
      )}
    </div>
  );
}
