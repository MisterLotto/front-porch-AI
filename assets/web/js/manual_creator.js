// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Manual Character Creator — 6-step Wizard (WebUI)
// Full parity with desktop Flutter create_character_page.dart
//
// Step 0: Identity (name, tags)
// Step 1: Personality (description, personality, scenario, system prompt)
// Step 2: Dialogue (first message, alt greetings, example dialogue)
// Step 3: Lorebook (CRUD)
// Step 4: Realism Engine
// Step 5: Review & Save

(function() {
  'use strict';

  // ── Helpers (shared patterns from chargen.js) ──
  function $(sel, parent) { return (parent || document).querySelector(sel); }
  function el(tag, attrs, ...children) {
    const e = document.createElement(tag);
    if (attrs) Object.entries(attrs).forEach(([k,v]) => {
      if (k === 'className') e.className = v;
      else if (k.startsWith('on')) e.addEventListener(k.slice(2).toLowerCase(), v);
      else if (k === 'innerHTML') e.innerHTML = v;
      else e.setAttribute(k, v);
    });
    children.forEach(c => { if (typeof c === 'string') e.appendChild(document.createTextNode(c)); else if (c) e.appendChild(c); });
    return e;
  }
  function esc(s) { const d=document.createElement('div'); d.textContent=s; return d.innerHTML; }

  async function apiJson(url, opts) {
    const token = sessionStorage.getItem('fp_token') || '';
    const headers = { 'Authorization': 'Bearer ' + token, ...(opts?.headers || {}) };
    try {
      const r = await fetch(url, { ...opts, headers });
      if (!r.ok) { const e = await r.json().catch(()=>({})); throw new Error(e.error || r.statusText); }
      return await r.json();
    } catch(e) { console.error('[mc]', url, e); return null; }
  }

  // ── Form State ──
  let mc = {
    step: 0,
    // Identity
    name: '', tags: [],
    // Personality
    description: '', personality: '', scenario: '', systemPrompt: '', postHistory: '',
    // Dialogue
    firstMessage: '', mesExample: '', altGreetings: [],
    // Lorebook
    lorebook: [],
    // Realism
    realismEnabled: false, realismTimeOfDay: 'morning', realismDayCount: 1,
    realismShortTermBond: 0, realismLongTermBond: 0, realismTrustLevel: 0,
    realismEmotion: '', realismEmotionIntensity: 'mild',
    realismNsfwCooldown: false, realismChaosMode: false,
  };

  function saveMcState() {
    try { sessionStorage.setItem('mc_state', JSON.stringify(mc)); } catch(_){}
  }
  function loadMcState() {
    try { const s = sessionStorage.getItem('mc_state'); if (s) Object.assign(mc, JSON.parse(s)); } catch(_){}
  }

  function updateStepIndicators() {
    const steps = document.querySelectorAll('#mc-steps .cw-step');
    steps.forEach(s => {
      const idx = parseInt(s.dataset.step);
      s.classList.toggle('active', idx === mc.step);
      s.classList.toggle('completed', idx < mc.step);
    });
  }

  // ── Field Builders ──
  function buildField(label, type, key, placeholder, opts={}) {
    const wrap = el('div', {style: opts.style || 'margin-bottom:16px'});
    wrap.appendChild(el('label', {style:'display:block;color:rgba(255,255,255,0.5);font-size:12px;font-weight:500;margin-bottom:6px'}, label));
    if (type === 'textarea') {
      const ta = el('textarea', {
        rows: String(opts.rows || 4),
        placeholder: placeholder || '',
        style:'width:100%;padding:10px 14px;background:#1e293b;border:1px solid rgba(255,255,255,0.08);border-radius:10px;color:#fff;font-size:14px;font-family:inherit;resize:vertical',
      });
      ta.value = mc[key] || '';
      ta.addEventListener('input', () => { mc[key] = ta.value; saveMcState(); });
      wrap.appendChild(ta);
    } else {
      const inp = el('input', {
        type: type, placeholder: placeholder || '',
        style:'width:100%;padding:10px 14px;background:#1e293b;border:1px solid rgba(255,255,255,0.08);border-radius:10px;color:#fff;font-size:14px',
      });
      inp.value = mc[key] || '';
      inp.addEventListener('input', () => { mc[key] = inp.value; saveMcState(); });
      wrap.appendChild(inp);
    }
    return wrap;
  }

  function buildNavBtns(onBack, onNext, nextLabel) {
    const nav = el('div', {style:'display:flex;justify-content:center;gap:16px;margin-top:24px;padding-bottom:16px'});
    if (onBack) {
      const b = el('button', {className:'cw-btn cw-btn-secondary', style:'height:48px;padding:0 24px'}, '← Back');
      b.addEventListener('click', onBack);
      nav.appendChild(b);
    }
    if (onNext) {
      const n = el('button', {className:'cw-btn cw-btn-primary', style:'height:48px;min-width:200px'}, nextLabel || 'Next →');
      n.addEventListener('click', onNext);
      nav.appendChild(n);
    }
    return nav;
  }

  function buildToggleRow(label, value, onChange, desc) {
    const row = el('div', {style:'display:flex;align-items:center;justify-content:space-between;padding:8px 0'});
    const left = el('div');
    left.appendChild(el('span', {style:'color:#fff;font-size:14px'}, label));
    if (desc) left.appendChild(el('div', {style:'color:rgba(255,255,255,0.3);font-size:11px;margin-top:2px'}, desc));
    row.appendChild(left);
    const toggle = el('label', {className:'toggle-switch'});
    const input = el('input', {type:'checkbox'});
    input.checked = value;
    input.addEventListener('change', () => onChange(input.checked));
    toggle.appendChild(input);
    toggle.appendChild(el('span', {className:'toggle-slider'}));
    row.appendChild(toggle);
    return row;
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 0: Identity
  // ═══════════════════════════════════════════════════════════
  function renderStep0() {
    const c = $('#mc-content'); c.innerHTML = '';
    const wrap = el('div', {style:'max-width:600px;margin:0 auto'});
    wrap.appendChild(el('div', {style:'font-size:22px;font-weight:700;color:#fff;margin-bottom:16px'}, '👤 Identity'));
    wrap.appendChild(buildField('Character Name *', 'text', 'name', 'e.g. Aria Blackthorn'));

    // Tags
    const tagSec = el('div', {style:'margin-bottom:16px'});
    tagSec.appendChild(el('label', {style:'display:block;color:rgba(255,255,255,0.5);font-size:12px;font-weight:500;margin-bottom:6px'}, 'Tags'));
    const tagRow = el('div', {style:'display:flex;gap:8px;margin-bottom:8px'});
    const tagInp = el('input', {type:'text', placeholder:'Add a tag...', style:'flex:1;padding:8px 12px;background:#1e293b;border:1px solid rgba(255,255,255,0.08);border-radius:8px;color:#fff;font-size:13px'});
    const addBtn = el('button', {style:'padding:8px 16px;background:#3b82f6;border:none;border-radius:8px;color:#fff;font-size:13px;cursor:pointer;font-weight:600'}, '+');
    addBtn.addEventListener('click', () => {
      const v = tagInp.value.trim();
      if (v && !mc.tags.includes(v)) { mc.tags.push(v); saveMcState(); renderStep0(); }
    });
    tagInp.addEventListener('keydown', e => { if (e.key === 'Enter') { e.preventDefault(); addBtn.click(); } });
    tagRow.appendChild(tagInp);
    tagRow.appendChild(addBtn);
    tagSec.appendChild(tagRow);
    if (mc.tags.length) {
      const pills = el('div', {style:'display:flex;flex-wrap:wrap;gap:6px'});
      mc.tags.forEach((t, i) => {
        const pill = el('span', {style:'display:inline-flex;align-items:center;gap:4px;padding:4px 10px;background:rgba(59,130,246,0.15);border:1px solid rgba(59,130,246,0.3);border-radius:12px;color:#60a5fa;font-size:12px'});
        pill.textContent = t;
        const x = el('span', {style:'cursor:pointer;opacity:0.6;font-size:14px'}, '×');
        x.addEventListener('click', () => { mc.tags.splice(i, 1); saveMcState(); renderStep0(); });
        pill.appendChild(x);
        pills.appendChild(pill);
      });
      tagSec.appendChild(pills);
    }
    wrap.appendChild(tagSec);

    wrap.appendChild(buildNavBtns(null, () => { if (!mc.name.trim()) { alert('Character name is required.'); return; } mc.step = 1; saveMcState(); render(); }, 'Next: Personality →'));
    c.appendChild(wrap);
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 1: Personality
  // ═══════════════════════════════════════════════════════════
  function renderStep1() {
    const c = $('#mc-content'); c.innerHTML = '';
    const wrap = el('div', {style:'max-width:600px;margin:0 auto'});
    wrap.appendChild(el('div', {style:'font-size:22px;font-weight:700;color:#fff;margin-bottom:16px'}, '🧠 Personality'));
    wrap.appendChild(buildField('Description', 'textarea', 'description', 'Physical appearance, background, personality overview...', {rows:5}));
    wrap.appendChild(buildField('Personality', 'textarea', 'personality', 'Core personality traits, behaviors, and quirks...', {rows:4}));
    wrap.appendChild(buildField('Scenario', 'textarea', 'scenario', 'The setting and context of the conversation...', {rows:3}));
    wrap.appendChild(buildField('System Prompt', 'textarea', 'systemPrompt', '(Optional) Custom system prompt for this character...', {rows:3}));
    wrap.appendChild(buildField('Post-History Instructions', 'textarea', 'postHistory', '(Optional) Instructions placed after chat history...', {rows:2}));

    wrap.appendChild(buildNavBtns(
      () => { mc.step = 0; saveMcState(); render(); },
      () => { mc.step = 2; saveMcState(); render(); },
      'Next: Dialogue →'
    ));
    c.appendChild(wrap);
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 2: Dialogue
  // ═══════════════════════════════════════════════════════════
  function renderStep2() {
    const c = $('#mc-content'); c.innerHTML = '';
    const wrap = el('div', {style:'max-width:600px;margin:0 auto'});
    wrap.appendChild(el('div', {style:'font-size:22px;font-weight:700;color:#fff;margin-bottom:16px'}, '💬 Dialogue'));
    wrap.appendChild(buildField('First Message *', 'textarea', 'firstMessage', "The character's opening message when a new chat starts...", {rows:5}));
    wrap.appendChild(buildField('Example Dialogue', 'textarea', 'mesExample', '<START>\n{{user}}: Hi!\n{{char}}: Hello there!', {rows:4}));

    // Alt Greetings
    const altSec = el('div', {style:'margin-bottom:16px'});
    const altHeader = el('div', {style:'display:flex;align-items:center;justify-content:space-between;margin-bottom:8px'});
    altHeader.appendChild(el('span', {style:'color:rgba(255,255,255,0.5);font-size:12px;font-weight:500'}, `Alternate Greetings (${mc.altGreetings.length})`));
    const addAltBtn = el('button', {style:'padding:4px 12px;background:rgba(59,130,246,0.15);border:1px solid rgba(59,130,246,0.3);border-radius:8px;color:#60a5fa;font-size:12px;cursor:pointer'}, '+ Add');
    addAltBtn.addEventListener('click', () => { mc.altGreetings.push(''); saveMcState(); renderStep2(); });
    altHeader.appendChild(addAltBtn);
    altSec.appendChild(altHeader);
    mc.altGreetings.forEach((g, i) => {
      const row = el('div', {style:'position:relative;margin-bottom:8px'});
      const ta = el('textarea', {rows:'3', placeholder:`Alt greeting ${i+1}...`, style:'width:100%;padding:10px 14px;padding-right:36px;background:#1e293b;border:1px solid rgba(255,255,255,0.08);border-radius:10px;color:#fff;font-size:13px;font-family:inherit;resize:vertical'});
      ta.value = g;
      ta.addEventListener('input', () => { mc.altGreetings[i] = ta.value; saveMcState(); });
      row.appendChild(ta);
      const del = el('button', {style:'position:absolute;top:6px;right:6px;background:rgba(239,68,68,0.15);border:none;border-radius:6px;color:#f87171;cursor:pointer;width:24px;height:24px;font-size:14px;display:flex;align-items:center;justify-content:center'}, '×');
      del.addEventListener('click', () => { mc.altGreetings.splice(i, 1); saveMcState(); renderStep2(); });
      row.appendChild(del);
      altSec.appendChild(row);
    });
    wrap.appendChild(altSec);

    wrap.appendChild(buildNavBtns(
      () => { mc.step = 1; saveMcState(); render(); },
      () => { mc.step = 3; saveMcState(); render(); },
      'Next: Lorebook →'
    ));
    c.appendChild(wrap);
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 3: Lorebook
  // ═══════════════════════════════════════════════════════════
  function renderStep3() {
    const c = $('#mc-content'); c.innerHTML = '';
    const wrap = el('div', {style:'max-width:600px;margin:0 auto'});
    const header = el('div', {style:'display:flex;align-items:center;justify-content:space-between;margin-bottom:16px'});
    header.appendChild(el('div', {style:'font-size:22px;font-weight:700;color:#fff'}, '📖 Lorebook'));
    const addBtn = el('button', {style:'padding:6px 16px;background:rgba(59,130,246,0.15);border:1px solid rgba(59,130,246,0.3);border-radius:8px;color:#60a5fa;font-size:13px;cursor:pointer;font-weight:600'}, '+ Add Entry');
    addBtn.addEventListener('click', () => { mc.lorebook.push({name:'', key:'', content:'', enabled:true}); saveMcState(); renderStep3(); });
    header.appendChild(addBtn);
    wrap.appendChild(header);

    if (!mc.lorebook.length) {
      wrap.appendChild(el('div', {style:'text-align:center;padding:32px;color:rgba(255,255,255,0.3);font-size:14px'}, 'No lorebook entries yet. Add one to include world-building context.'));
    }

    mc.lorebook.forEach((entry, i) => {
      const card = el('div', {style:'padding:14px;background:#1e293b;border:1px solid rgba(255,255,255,0.08);border-radius:12px;margin-bottom:12px'});
      const topRow = el('div', {style:'display:flex;align-items:center;justify-content:space-between;margin-bottom:10px'});
      topRow.appendChild(el('span', {style:'color:#60a5fa;font-size:13px;font-weight:600'}, `Entry ${i+1}`));
      const delBtn = el('button', {style:'background:rgba(239,68,68,0.1);border:1px solid rgba(239,68,68,0.3);border-radius:6px;color:#f87171;font-size:11px;padding:3px 10px;cursor:pointer'}, 'Delete');
      delBtn.addEventListener('click', () => { mc.lorebook.splice(i, 1); saveMcState(); renderStep3(); });
      topRow.appendChild(delBtn);
      card.appendChild(topRow);

      const nameInp = el('input', {type:'text', placeholder:'Entry name', style:'width:100%;padding:8px 12px;background:#0f172a;border:1px solid rgba(255,255,255,0.08);border-radius:8px;color:#fff;font-size:13px;margin-bottom:8px'});
      nameInp.value = entry.name;
      nameInp.addEventListener('input', () => { mc.lorebook[i].name = nameInp.value; saveMcState(); });
      card.appendChild(nameInp);

      const keyInp = el('input', {type:'text', placeholder:'Trigger keys (comma-separated)', style:'width:100%;padding:8px 12px;background:#0f172a;border:1px solid rgba(255,255,255,0.08);border-radius:8px;color:#fff;font-size:13px;margin-bottom:8px'});
      keyInp.value = entry.key;
      keyInp.addEventListener('input', () => { mc.lorebook[i].key = keyInp.value; saveMcState(); });
      card.appendChild(keyInp);

      const contentTa = el('textarea', {rows:'3', placeholder:'Lorebook content...', style:'width:100%;padding:8px 12px;background:#0f172a;border:1px solid rgba(255,255,255,0.08);border-radius:8px;color:#fff;font-size:13px;font-family:inherit;resize:vertical'});
      contentTa.value = entry.content;
      contentTa.addEventListener('input', () => { mc.lorebook[i].content = contentTa.value; saveMcState(); });
      card.appendChild(contentTa);

      wrap.appendChild(card);
    });

    wrap.appendChild(buildNavBtns(
      () => { mc.step = 2; saveMcState(); render(); },
      () => { mc.step = 4; saveMcState(); render(); },
      'Next: Realism →'
    ));
    c.appendChild(wrap);
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 4: Realism Engine (reuses patterns from chargen.js)
  // ═══════════════════════════════════════════════════════════
  const REALISM_TIME_OPTIONS = ['dawn','morning','late_morning','afternoon','evening','night'];
  const REALISM_INTENSITY_OPTIONS = ['mild','moderate','strong'];
  function _fmt(v) { return v.split('_').map(w=>w[0].toUpperCase()+w.slice(1)).join(' '); }
  function _stTier(s) { if(s>=80) return 'Devoted'; if(s>=50) return 'Affectionate'; if(s>=20) return 'Warm'; if(s>=5) return 'Friendly'; if(s>=-4) return 'Neutral'; if(s>=-19) return 'Cool'; if(s>=-49) return 'Distant'; if(s>=-79) return 'Hostile'; return 'Despised'; }
  function _ltTier(s) { if(s>=80) return 'Soulbound'; if(s>=50) return 'Deep Bond'; if(s>=20) return 'Close'; if(s>=5) return 'Familiar'; if(s>=-4) return 'Acquaintance'; if(s>=-19) return 'Uneasy'; if(s>=-49) return 'Estranged'; if(s>=-79) return 'Broken'; return 'Nemesis'; }
  function _trustName(l) { if(l>=80) return 'Absolute Trust'; if(l>=50) return 'Deep Trust'; if(l>=20) return 'Trusting'; if(l>=5) return 'Cautious Trust'; if(l>=-4) return 'Neutral'; if(l>=-19) return 'Wary'; if(l>=-49) return 'Suspicious'; if(l>=-79) return 'Paranoid'; return 'Absolute Distrust'; }
  function _bondCol(s) { if(s>=20) return '#4ade80'; if(s>=0) return '#60a5fa'; if(s>=-19) return '#fb923c'; return '#f87171'; }
  function _trustCol(l) { if(l>=20) return '#2dd4bf'; if(l>=0) return '#60a5fa'; if(l>=-19) return '#fb923c'; return '#f87171'; }

  function _slider(label, value, min, max, tierName, color, onChange) {
    const wrap = el('div', {style:'margin-bottom:16px'});
    const row = el('div', {style:'display:flex;align-items:center;justify-content:space-between;margin-bottom:4px'});
    row.appendChild(el('span', {style:'color:rgba(255,255,255,0.7);font-size:12px;font-weight:500'}, label));
    row.appendChild(el('span', {style:`padding:2px 8px;border-radius:6px;font-size:11px;font-weight:600;background:${color}26;color:${color}`}, `${tierName} (${value})`));
    wrap.appendChild(row);
    const s = el('input', {type:'range', min:String(min), max:String(max), step:'1', style:`width:100%;accent-color:${color}`});
    s.value = value;
    s.addEventListener('input', () => onChange(parseInt(s.value)));
    wrap.appendChild(s);
    return wrap;
  }

  function renderStep4() {
    const c = $('#mc-content'); c.innerHTML = '';
    const wrap = el('div', {style:'max-width:600px;margin:0 auto'});
    wrap.appendChild(el('div', {style:'font-size:22px;font-weight:700;color:#fff;margin-bottom:8px'}, '🧠 Realism Engine'));
    wrap.appendChild(el('div', {style:'font-size:13px;color:rgba(255,255,255,0.4);margin-bottom:24px'}, 'Set the initial realism state for new conversations with this character.'));

    // Master Toggle
    const toggleCard = el('div', {style:`padding:14px;border-radius:14px;background:#1e293b;border:1px solid ${mc.realismEnabled ? 'rgba(59,130,246,0.4)' : 'rgba(255,255,255,0.08)'};margin-bottom:20px`});
    toggleCard.appendChild(buildToggleRow('Enable Realism Engine', mc.realismEnabled, v => { mc.realismEnabled = v; saveMcState(); renderStep4(); }, mc.realismEnabled ? 'Character will start with pre-configured state' : 'Realism Engine will use defaults'));
    wrap.appendChild(toggleCard);

    if (mc.realismEnabled) {
      // Time & Day
      const timeCard = el('div', {style:'padding:14px;background:#1e293b;border-radius:14px;border:1px solid rgba(255,255,255,0.08);margin-bottom:16px'});
      timeCard.appendChild(el('div', {style:'color:#fbbf24;font-size:14px;font-weight:600;margin-bottom:12px'}, '⏰ Time & Day'));
      const timeRow = el('div', {style:'display:flex;gap:16px'});
      const timeCol = el('div', {style:'flex:2'});
      timeCol.appendChild(el('div', {style:'color:rgba(255,255,255,0.5);font-size:11px;margin-bottom:4px'}, 'Time of Day'));
      const timeSel = el('select', {style:'width:100%;padding:8px;background:#0f172a;border:1px solid rgba(255,255,255,0.08);border-radius:8px;color:#fff;font-size:13px'});
      REALISM_TIME_OPTIONS.forEach(t => { const o = el('option',{value:t},_fmt(t)); if(t===mc.realismTimeOfDay) o.selected=true; timeSel.appendChild(o); });
      timeSel.addEventListener('change', () => { mc.realismTimeOfDay = timeSel.value; saveMcState(); });
      timeCol.appendChild(timeSel);
      timeRow.appendChild(timeCol);
      const dayCol = el('div', {style:'flex:1'});
      dayCol.appendChild(el('div', {style:'color:rgba(255,255,255,0.5);font-size:11px;margin-bottom:4px'}, 'Day #'));
      const dayInp = el('input', {type:'number', min:'1', style:'width:100%;padding:8px;background:#0f172a;border:1px solid rgba(255,255,255,0.08);border-radius:8px;color:#fff;font-size:13px'});
      dayInp.value = mc.realismDayCount;
      dayInp.addEventListener('input', () => { const n=parseInt(dayInp.value); if(n>=1){mc.realismDayCount=n; saveMcState();} });
      dayCol.appendChild(dayInp);
      timeRow.appendChild(dayCol);
      timeCard.appendChild(timeRow);
      wrap.appendChild(timeCard);

      // Relationship
      const relCard = el('div', {style:'padding:14px;background:#1e293b;border-radius:14px;border:1px solid rgba(255,255,255,0.08);margin-bottom:16px'});
      relCard.appendChild(el('div', {style:'color:#ec4899;font-size:14px;font-weight:600;margin-bottom:12px'}, '❤️ Relationship'));
      relCard.appendChild(_slider('Short-Term Bond', mc.realismShortTermBond, -150, 150, _stTier(mc.realismShortTermBond), _bondCol(mc.realismShortTermBond), v => { mc.realismShortTermBond=v; saveMcState(); renderStep4(); }));
      relCard.appendChild(_slider('Long-Term Bond', mc.realismLongTermBond, -150, 150, _ltTier(mc.realismLongTermBond), _bondCol(mc.realismLongTermBond), v => { mc.realismLongTermBond=v; saveMcState(); renderStep4(); }));
      relCard.appendChild(_slider('Trust Level', mc.realismTrustLevel, -100, 100, _trustName(mc.realismTrustLevel), _trustCol(mc.realismTrustLevel), v => { mc.realismTrustLevel=v; saveMcState(); renderStep4(); }));
      wrap.appendChild(relCard);

      // Emotion
      const emoCard = el('div', {style:'padding:14px;background:#1e293b;border-radius:14px;border:1px solid rgba(255,255,255,0.08);margin-bottom:16px'});
      emoCard.appendChild(el('div', {style:'color:#a855f7;font-size:14px;font-weight:600;margin-bottom:12px'}, '😊 Starting Emotion'));
      const emoRow = el('div', {style:'display:flex;gap:16px'});
      const emoCol = el('div', {style:'flex:2'});
      const emoInp = el('input', {type:'text', placeholder:'e.g. curious, guarded', style:'width:100%;padding:8px;background:#0f172a;border:1px solid rgba(255,255,255,0.08);border-radius:8px;color:#fff;font-size:13px'});
      emoInp.value = mc.realismEmotion;
      emoInp.addEventListener('input', () => { mc.realismEmotion = emoInp.value; saveMcState(); });
      emoCol.appendChild(emoInp);
      emoRow.appendChild(emoCol);
      const intCol = el('div', {style:'flex:1'});
      const intSel = el('select', {style:'width:100%;padding:8px;background:#0f172a;border:1px solid rgba(255,255,255,0.08);border-radius:8px;color:#fff;font-size:13px'});
      REALISM_INTENSITY_OPTIONS.forEach(i => { const o = el('option',{value:i},i[0].toUpperCase()+i.slice(1)); if(i===mc.realismEmotionIntensity) o.selected=true; intSel.appendChild(o); });
      intSel.addEventListener('change', () => { mc.realismEmotionIntensity = intSel.value; saveMcState(); });
      intCol.appendChild(intSel);
      emoRow.appendChild(intCol);
      emoCard.appendChild(emoRow);
      wrap.appendChild(emoCard);

      // Optional toggles
      const optCard = el('div', {style:'padding:14px;background:#1e293b;border-radius:14px;border:1px solid rgba(255,255,255,0.08);margin-bottom:16px'});
      optCard.appendChild(el('div', {style:'color:#2dd4bf;font-size:14px;font-weight:600;margin-bottom:12px'}, '🎛️ Optional Features'));
      optCard.appendChild(buildToggleRow('🌡️ NSFW Cooldown', mc.realismNsfwCooldown, v => { mc.realismNsfwCooldown = v; saveMcState(); }, 'Realistic arousal/refractory mechanics'));
      optCard.appendChild(el('hr', {style:'border-color:rgba(255,255,255,0.06);margin:8px 0'}));
      optCard.appendChild(buildToggleRow('🎲 Chaos Mode', mc.realismChaosMode, v => { mc.realismChaosMode = v; saveMcState(); }, 'Random narrative events'));
      wrap.appendChild(optCard);
    }

    wrap.appendChild(buildNavBtns(
      () => { mc.step = 3; saveMcState(); render(); },
      () => { mc.step = 5; saveMcState(); render(); },
      'Next: Review →'
    ));
    c.appendChild(wrap);
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 5: Review & Save
  // ═══════════════════════════════════════════════════════════
  function renderStep5() {
    const c = $('#mc-content'); c.innerHTML = '';
    const wrap = el('div', {style:'max-width:600px;margin:0 auto'});
    wrap.appendChild(el('div', {style:'font-size:22px;font-weight:700;color:#fff;margin-bottom:16px'}, '✅ Review & Save'));

    function reviewSection(icon, title, items) {
      const sec = el('div', {style:'padding:14px;background:#1e293b;border-radius:14px;border:1px solid rgba(255,255,255,0.08);margin-bottom:12px'});
      sec.appendChild(el('div', {style:'color:#fff;font-size:14px;font-weight:600;margin-bottom:8px'}, `${icon} ${title}`));
      items.forEach(([label, value]) => {
        if (!value) return;
        const row = el('div', {style:'margin-bottom:6px'});
        row.appendChild(el('span', {style:'color:rgba(255,255,255,0.4);font-size:11px;display:block'}, label));
        const preview = String(value).length > 120 ? String(value).substring(0, 120) + '...' : String(value);
        row.appendChild(el('span', {style:'color:rgba(255,255,255,0.8);font-size:13px'}, preview));
        sec.appendChild(row);
      });
      return sec;
    }

    wrap.appendChild(reviewSection('👤', 'Identity', [
      ['Name', mc.name],
      ['Tags', mc.tags.join(', ')],
    ]));

    wrap.appendChild(reviewSection('🧠', 'Personality', [
      ['Description', mc.description],
      ['Personality', mc.personality],
      ['Scenario', mc.scenario],
      ['System Prompt', mc.systemPrompt],
    ]));

    wrap.appendChild(reviewSection('💬', 'Dialogue', [
      ['First Message', mc.firstMessage],
      ['Example Dialogue', mc.mesExample],
      ['Alt Greetings', mc.altGreetings.length ? `${mc.altGreetings.length} alternate greeting(s)` : ''],
    ]));

    if (mc.lorebook.length) {
      wrap.appendChild(reviewSection('📖', 'Lorebook', [
        ['Entries', `${mc.lorebook.length} lorebook entry(ies)`],
      ]));
    }

    if (mc.realismEnabled) {
      wrap.appendChild(reviewSection('🧠', 'Realism Engine', [
        ['Time of Day', _fmt(mc.realismTimeOfDay)],
        ['Day', String(mc.realismDayCount)],
        ['Short-Term Bond', `${mc.realismShortTermBond} (${_stTier(mc.realismShortTermBond)})`],
        ['Long-Term Bond', `${mc.realismLongTermBond} (${_ltTier(mc.realismLongTermBond)})`],
        ['Trust', `${mc.realismTrustLevel} (${_trustName(mc.realismTrustLevel)})`],
        ['Emotion', mc.realismEmotion || '(default)'],
        ['NSFW Cooldown', mc.realismNsfwCooldown ? 'Enabled' : 'Disabled'],
        ['Chaos Mode', mc.realismChaosMode ? 'Enabled' : 'Disabled'],
      ]));
    }

    // Save button
    const saveBtn = el('button', {style:'width:100%;padding:14px;background:linear-gradient(135deg,#3b82f6,#8b5cf6);border:none;border-radius:12px;color:#fff;font-size:16px;font-weight:700;cursor:pointer;margin-top:16px;transition:opacity 0.2s'}, '💾 Create Character');
    saveBtn.addEventListener('click', () => saveCharacter(saveBtn));
    wrap.appendChild(saveBtn);

    wrap.appendChild(buildNavBtns(
      () => { mc.step = 4; saveMcState(); render(); },
      null
    ));
    c.appendChild(wrap);
  }

  async function saveCharacter(btn) {
    btn.textContent = '⏳ Saving...';
    btn.disabled = true;

    const payload = {
      name: mc.name,
      description: mc.description,
      personality: mc.personality,
      scenario: mc.scenario,
      firstMessage: mc.firstMessage,
      mesExample: mc.mesExample || '',
      systemPrompt: mc.systemPrompt || '',
      postHistory: mc.postHistory || '',
      alternateGreetings: mc.altGreetings.filter(g => g.trim()),
      tags: mc.tags,
      lorebook: mc.lorebook.filter(e => e.name || e.content),
    };

    if (mc.realismEnabled) {
      payload.extensions = {
        front_porch: {
          realism_enabled: mc.realismEnabled,
          short_term_bond: mc.realismShortTermBond,
          long_term_bond: mc.realismLongTermBond,
          trust_level: mc.realismTrustLevel,
          day_count: mc.realismDayCount,
          time_of_day: mc.realismTimeOfDay,
          character_emotion: mc.realismEmotion,
          emotion_intensity: mc.realismEmotionIntensity,
          nsfw_cooldown_enabled: mc.realismNsfwCooldown,
          chaos_mode_enabled: mc.realismChaosMode,
        },
      };
    }

    const res = await apiJson('/api/characters/create', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify(payload),
    });

    if (res && (res.ok || res.id)) {
      alert(`Character "${mc.name}" created successfully!`);
      resetState();
      render();
      // Refresh home page
      if (window._fpSwitchPage) window._fpSwitchPage('home');
    } else {
      alert('Save failed: ' + (res?.error || 'Unknown error'));
      btn.textContent = '💾 Create Character';
      btn.disabled = false;
    }
  }

  function resetState() {
    mc = {
      step: 0, name: '', tags: [],
      description: '', personality: '', scenario: '', systemPrompt: '', postHistory: '',
      firstMessage: '', mesExample: '', altGreetings: [],
      lorebook: [],
      realismEnabled: false, realismTimeOfDay: 'morning', realismDayCount: 1,
      realismShortTermBond: 0, realismLongTermBond: 0, realismTrustLevel: 0,
      realismEmotion: '', realismEmotionIntensity: 'mild',
      realismNsfwCooldown: false, realismChaosMode: false,
    };
    saveMcState();
  }

  // ── Main ──
  function render() {
    updateStepIndicators();
    switch(mc.step) {
      case 0: renderStep0(); break;
      case 1: renderStep1(); break;
      case 2: renderStep2(); break;
      case 3: renderStep3(); break;
      case 4: renderStep4(); break;
      case 5: renderStep5(); break;
    }
  }

  function init() { loadMcState(); render(); }

  window.ManualCreatorModule = { init, resetState };
})();
