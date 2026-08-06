/* The Stoop hub — card completeness gate.
   Mirrors backporch-server/src/lib/card-completeness.ts so the website and
   API reject the same incomplete shells (empty first_mes / persona / scenario,
   empty world lore, thin group casts). Keep the two in sync when rules change. */
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
      field('lorebook', 'Lorebook content', book.totalChars > 0 ? 'ok' : '', true),
    ];
    var missingCritical = [];
    if (!climatePresent) missingCritical.push('Biome / climate');
    if (book.entries === 0 || book.filled === 0) missingCritical.push('Lorebook entries with content');
    return {
      incomplete: missingCritical.length > 0,
      missingCritical: missingCritical,
      missingOptional: [],
      fields: fields,
      cardName: str(card.name).trim() || null,
      notes: [
        'Lorebook: ' + book.filled + '/' + book.entries + ' filled' +
        (book.placeholder ? ' · ' + book.placeholder + ' empty/placeholder' : ''),
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
    message: message,
  };
})();
