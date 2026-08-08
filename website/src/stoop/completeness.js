/* The Stoop hub — card completeness gate + the 18+ intimate-preferences rule.
   Mirrors TWO server rules so the website and the API agree about a card:
     - backporch-server/src/lib/card-completeness.ts — reject the same
       incomplete shells (empty first_mes / persona / scenario, empty world
       lore, thin group casts);
     - backporch-server/src/lib/card-nsfw.ts — a card carrying intimate
       preferences is 18+ regardless of everything else on it.
   The server is the authority in both cases; this copy exists so the submit
   form can say so before you hit send. Keep them in sync when rules change. */
(function () {
  'use strict';
  window.Stoop = window.Stoop || {};

  function asObj(v) {
    return v && typeof v === 'object' && !Array.isArray(v) ? v : null;
  }
  function str(v) {
    return typeof v === 'string' ? v : '';
  }
  function present(v) {
    if (typeof v === 'string') return v.trim().length > 0;
    if (Array.isArray(v)) {
      return v.some(function (item) {
        return typeof item === 'string' ? item.trim().length > 0 : item != null;
      });
    }
    return false;
  }
  function chars(v) {
    return str(v).trim().length;
  }

  /** V2 may nest under data; Stoop stores the unwrapped node. */
  function unwrapCard(cardJson) {
    var root = asObj(cardJson) || {};
    var data = asObj(root.data);
    if (data && (present(data.first_mes) || present(data.description) || present(data.personality) || present(data.system_prompt))) {
      var out = {};
      Object.keys(root).forEach(function (k) { out[k] = root[k]; });
      Object.keys(data).forEach(function (k) { out[k] = data[k]; });
      out.extensions = data.extensions != null ? data.extensions : root.extensions;
      return out;
    }
    return root;
  }

  /** An intimate-preference list counts only when it holds a real phrase.
      Deliberately stricter than present(): a bare string, a number, or an
      object in there is malformed input, not an authored preference. */
  function prefListFilled(v) {
    return Array.isArray(v) && v.some(function (item) {
      return typeof item === 'string' && item.trim().length > 0;
    });
  }

  /** True when THIS one node — never its members — carries a filled intimate
      preference list. Type-check every hop rather than cast: a hostile upload's
      wrong-typed field must cost that one field, never throw and take the page
      down with it. */
  function carriesIntimate(node) {
    var n = asObj(node);
    var ext = n && asObj(n.extensions);
    var fp = ext && asObj(ext.front_porch);
    var re = fp && asObj(fp.realism_engine);
    var prefs = re && asObj(re.intimate_preferences);
    if (!prefs) return false;
    return prefListFilled(prefs.into) || prefListFilled(prefs.not_into);
  }

  /** One cast list, scanned. Each member is a full character card with its own
      extensions, and a member may itself be V2-nested — so the member and its
      `data` sibling are both checked, exactly as the server does.
      No array, no members: a wrong-typed field is simply nothing here. */
  function scanCast(list) {
    if (!Array.isArray(list)) return false;
    for (var i = 0; i < list.length; i++) {
      var m = asObj(list[i]);
      if (!m) continue;
      if (carriesIntimate(m) || carriesIntimate(m.data)) return true;
    }
    return false;
  }

  /** A card carrying ANY intimate preference is 18+, no exception.
      Testing for the KEY would be wrong and expensive: every Front Porch export
      writes `intimate_preferences` whether or not the author filled it in, so a
      key-existence check would drag the entire catalogue over the 18+ line. Only
      a non-blank phrase in `into` / `not_into` counts.

      TWO SCOPES, not one. `unwrapCard` only prefers the nested `data` object
      when that object also carries persona fields, so a card that keeps its
      persona at the ROOT and hides `extensions` under `data` comes back
      unwrapped and a root-only chain misses the preferences. Checking the raw
      `data` sibling too is two extra property reads and closes that hole — and
      it is what the server already does (card-nsfw.ts), so this makes the two
      EQUAL rather than making the form stricter than the API.

      BOTH CAST LISTS, not one. A group card carries its members under
      `members` AND `raw_member_data` — GroupCard.toJson writes both — while
      every consumer (GroupCard.fromJson, the importer, the desktop Stoop panel,
      this hub's card page) prefers `raw_member_data`. Picking one list means
      picking the one nobody reads: strip the extensions out of `members[]`,
      leave them in `raw_member_data[]`, and the card would publish as SFW while
      every downloader installs a character with intimate preferences. Both are
      scanned; a duplicate scan is free, a missed member is not.

      Group casts keep their preferences PER MEMBER — never at the root — so
      without the member walk anyone could dodge the tag by shipping a character
      inside a two-member group. */
  function hasIntimatePreferences(cardJson) {
    try {
      var root = asObj(cardJson);
      if (!root) return false;
      // The RAW ROOT IS A SCOPE OF ITS OWN, and it has to be. unwrapCard MERGES
      // (`{...root, ...data}`), so any key `data` also carries replaces the
      // root's copy — append `"data": {"first_mes":"…","members":[],
      // "raw_member_data":[]}` to an honest export and the unwrapped scope's
      // cast lists are the empty decoys while the real cast sits at the root,
      // which is exactly where GroupCard.fromJson reads it. Scanning the root
      // first, before anything can shadow it, is what closes that. Keep this in
      // step with card-nsfw.ts on the server — the two are meant to agree.
      var scopes = [root, unwrapCard(root), asObj(root.data)];
      for (var s = 0; s < scopes.length; s++) {
        var scope = scopes[s];
        if (!scope) continue;
        if (carriesIntimate(scope)) return true;
        if (scanCast(scope.members)) return true;
        if (scanCast(scope.raw_member_data)) return true;
      }
      return false;
    } catch (e) {
      // A stranger's upload is allowed to be any shape at all; a weird one must
      // never take the submit form down with it.
      return false;
    }
  }

  function field(key, label, value, critical) {
    var c = Array.isArray(value)
      ? value.reduce(function (n, item) {
          return n + (typeof item === 'string' ? item.trim().length : 0);
        }, 0)
      : chars(value);
    return { key: key, label: label, present: present(value), chars: c, critical: !!critical };
  }

  function lorebookStats(book) {
    var b = asObj(book);
    var entries = b && Array.isArray(b.entries) ? b.entries : [];
    var filled = 0;
    var placeholder = 0;
    var totalChars = 0;
    entries.forEach(function (e) {
      var m = asObj(e);
      var content = str(m && m.content).trim();
      totalChars += content.length;
      if (!content) {
        placeholder += 1;
        return;
      }
      if (/\[Insert\b/i.test(content)) placeholder += 1;
      else filled += 1;
    });
    return { entries: entries.length, filled: filled, placeholder: placeholder, totalChars: totalChars };
  }

  function soloCompleteness(card) {
    var fields = [
      field('first_mes', 'First message', card.first_mes || card.first_message, true),
      field('description', 'Description', card.description, true),
      field('personality', 'Personality', card.personality, true),
      field('scenario', 'Scenario', card.scenario, true),
      field('mes_example', 'Example messages', card.mes_example, false),
      field('system_prompt', 'System prompt', card.system_prompt, false),
      field('post_history_instructions', 'Post-history instructions', card.post_history_instructions, false),
      field('creator_notes', 'Creator notes', card.creator_notes, false),
      field('alternate_greetings', 'Alternate greetings', card.alternate_greetings, false),
    ];
    var hasIdentity = present(card.description) || present(card.personality);
    var hasFirst = present(card.first_mes || card.first_message);
    var hasScenario = present(card.scenario);
    var missingCritical = [];
    if (!hasFirst) missingCritical.push('First message');
    if (!hasIdentity) missingCritical.push('Description or personality');
    if (!hasScenario) missingCritical.push('Scenario');
    var missingOptional = fields.filter(function (f) { return !f.critical && !f.present; }).map(function (f) { return f.label; });
    var notes = [];
    var book = lorebookStats(card.character_book || card.lorebook);
    if (book.entries > 0) {
      notes.push(
        'Lorebook: ' + book.filled + '/' + book.entries + ' filled' +
        (book.placeholder ? ' · ' + book.placeholder + ' empty/placeholder' : '')
      );
    }
    var name = str(card.name).trim() || null;
    if (!hasFirst && !hasIdentity && present(card.system_prompt) && chars(card.system_prompt) > 500) {
      notes.push('Looks like a template/shell: system prompt present, character fields empty');
    }
    return {
      incomplete: missingCritical.length > 0,
      missingCritical: missingCritical,
      missingOptional: missingOptional,
      fields: fields,
      cardName: name,
      notes: notes,
    };
  }

  function groupCompleteness(card) {
    // Deliberately ONE list, unlike hasIntimatePreferences above. This gate
    // decides whether Submit is allowed, and it has to agree with the server's
    // groupCompleteness (card-completeness.ts), which picks the same single
    // list. Unioning here would block uploads the API would have accepted —
    // a false wall in front of the author. The 18+ predicate unions because
    // over-tagging costs nothing and under-tagging is an evasion.
    var members =
      (Array.isArray(card.members) && card.members) ||
      (Array.isArray(card.raw_member_data) && card.raw_member_data) ||
      [];
    var fields = [
      field('first_mes', 'Group first message', card.first_mes || card.first_message, true),
      field('scenario', 'Group scenario', card.scenario, true),
      field('system_prompt', 'System prompt', card.system_prompt, false),
    ];
    var missingCritical = [];
    if (!present(card.first_mes || card.first_message)) missingCritical.push('Group first message');
    if (!present(card.scenario)) missingCritical.push('Group scenario');
    if (!members.length) missingCritical.push('Members');
    members.forEach(function (raw, i) {
      var m = asObj(raw) || {};
      var label = str(m.name).trim() || ('Member ' + (i + 1));
      var idOk = present(m.description) || present(m.personality);
      fields.push(field('member_' + i + '_name', label + ' · name', m.name, true));
      fields.push(field('member_' + i + '_identity', label + ' · description/personality', idOk ? 'ok' : '', true));
      if (!str(m.name).trim()) missingCritical.push(label + ': name');
      if (!idOk) missingCritical.push(label + ': description or personality');
    });
    // de-dupe
    var seen = {};
    missingCritical = missingCritical.filter(function (x) {
      if (seen[x]) return false;
      seen[x] = true;
      return true;
    });
    return {
      incomplete: missingCritical.length > 0,
      missingCritical: missingCritical,
      missingOptional: fields.filter(function (f) { return !f.critical && !f.present; }).map(function (f) { return f.label; }),
      fields: fields,
      cardName: str(card.name).trim() || null,
      notes: [members.length + ' member(s)'],
    };
  }

  function worldCompleteness(card) {
    var biome = asObj(card.biome) || {};
    var book = lorebookStats(card.lorebook);
    var climatePresent = present(biome.displayName) || present(biome.description) || present(biome.feel);
    var fields = [
      field('biome', 'Biome / climate', climatePresent ? 'ok' : '', true),
      // Lore is useful but optional — worlds can ship climate first.
      field('lorebook', 'Lorebook content', book.totalChars > 0 ? 'ok' : '', false),
    ];
    var missingCritical = [];
    if (!climatePresent) missingCritical.push('Biome / climate');
    return {
      incomplete: missingCritical.length > 0,
      missingCritical: missingCritical,
      missingOptional: fields.filter(function (f) { return !f.critical && !f.present; }).map(function (f) { return f.label; }),
      fields: fields,
      cardName: str(card.name).trim() || null,
      notes: [
        'Lorebook: ' + book.filled + '/' + book.entries + ' filled' +
        (book.placeholder ? ' · ' + book.placeholder + ' empty/placeholder' : '') +
        (book.entries === 0 ? ' (optional)' : ''),
      ],
    };
  }

  function assess(cardJson, type) {
    var card = unwrapCard(cardJson);
    if (type === 'GROUP') return groupCompleteness(card);
    if (type === 'WORLD') return worldCompleteness(card);
    return soloCompleteness(card);
  }

  /** Short human sentence for toasts / form errors. */
  function message(comp) {
    if (!comp || !comp.incomplete) return '';
    var miss = (comp.missingCritical || []).join(', ');
    return 'This card is incomplete for Front Porch / The Stoop. Missing: ' + miss +
      '. Fill those fields in your app, re-export, and try again.';
  }

  window.Stoop.completeness = {
    assess: assess,
    unwrapCard: unwrapCard,
    hasIntimatePreferences: hasIntimatePreferences,
    message: message,
  };
})();
