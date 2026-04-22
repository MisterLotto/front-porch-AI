// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

// ═══════════════════════════════════════════════════════════
// AI Character Creator — WebUI Module
// Full parity with desktop Flutter character_creator_page.dart
// ═══════════════════════════════════════════════════════════

(function() {
  'use strict';

  // ── Preset Constants (exact match from Flutter source) ──

  const ARCHETYPES = {
    'Tsundere':     { concept: "A sharp-tongued person who hides their caring nature behind a cold exterior, denying their feelings while secretly looking out for {{user}}", keywords: "tsundere, sharp-tongued, secretly caring, stubborn, easily flustered" },
    'Yandere':      { concept: "An obsessively devoted person whose love borders on dangerous possessiveness, willing to do anything to keep {{user}} close", keywords: "yandere, obsessive, possessive, devoted, unstable, sweet on the surface" },
    'Kuudere':      { concept: "A stoic and emotionally reserved individual who rarely shows feelings, but whose rare moments of warmth are deeply meaningful", keywords: "kuudere, stoic, calm, reserved, analytical, quietly caring" },
    'Femme Fatale':  { concept: "A dangerously alluring and manipulative figure who uses charm and wit as weapons, always three steps ahead", keywords: "seductive, cunning, confident, dangerous, mysterious, manipulative" },
    'Dark Lord':    { concept: "A powerful and charismatic ruler of dark forces, whose iron will conceals a complex past and a surprising code of honor", keywords: "commanding, ruthless, charismatic, intelligent, dark humor, powerful" },
    'Mentor':       { concept: "A wise and experienced guide who mentors {{user}} through challenges, offering cryptic advice and hard-earned wisdom", keywords: "wise, patient, cryptic, experienced, protective, tough love" },
    'Rival':        { concept: "A fiercely competitive adversary who pushes {{user}} to their limits, respecting strength while refusing to lose", keywords: "competitive, proud, skilled, determined, begrudging respect, ambitious" },
    'Best Friend':  { concept: "A loyal and easygoing companion who always has {{user}}'s back, bringing laughter and genuine support to every situation", keywords: "loyal, funny, supportive, easygoing, ride-or-die, honest" },
    'The Healer':   { concept: "A gentle and empathetic soul with healing abilities who tends to everyone's wounds but their own, carrying quiet burdens", keywords: "gentle, empathetic, selfless, nurturing, quietly strong, burdened" },
    'Rogue':        { concept: "A charming and morally grey trickster who lives by their own rules, stealing hearts as easily as coin purses", keywords: "charming, witty, roguish, morally grey, quick on their feet, flirtatious" },
    'Chosen One':   { concept: "A reluctant hero burdened by an ancient prophecy, thrust into a destiny they never asked for while just wanting a normal life", keywords: "reluctant, burdened, humble, determined, conflicted, growing into power" },
    'The Ex':       { concept: "A former flame who reappears unexpectedly in {{user}}'s life, carrying unresolved tension, lingering feelings, and unanswered questions", keywords: "complicated, nostalgic, guarded, magnetic, unresolved, bittersweet" },
    'Dandere':      { concept: "A painfully shy and quiet soul who struggles to express themselves, but reveals incredible sweetness and depth once they feel safe enough to open up", keywords: "dandere, shy, quiet, gentle, sweet, anxious, secretly passionate" },
    'Genki':        { concept: "An unstoppable ball of infectious energy and optimism who drags everyone into adventures, refuses to let anyone be sad, and lights up every room", keywords: "genki, energetic, optimistic, loud, cheerful, stubborn positivity, adventurous" },
    'Ojou-sama':    { concept: "A sheltered noble or wealthy heir with an imperious demeanor and signature \"ohoho\" laugh, who secretly yearns for normal friendships and real connections", keywords: "ojou-sama, elegant, prideful, sheltered, secretly lonely, dramatic, refined" },
  };

  const ART_STYLES = ['Anime', 'Realistic', 'Painterly', 'Pixel Art', 'Comic Book', 'Watercolor', 'Fantasy Illustration'];
  const GREETING_LENGTHS = ['Short (1-2 paragraphs)', 'Medium (2-4 paragraphs)', 'Long (4-6 paragraphs)'];
  const GREETING_TONES = ['Neutral','Romantic','Spicy/NSFW','Flirty/Playful','Wholesome','Slice of Life','Story/Narrative','Adventure','Combat/Action','Comedy/Humor','Suspense/Thriller','Dark/Mystery','Melancholy'];
  const LORE_CATEGORIES = ['Locations','NPCs/Allies','Factions/Organizations','Culture/Customs','Abilities/Magic','Flora/Fauna','Items/Equipment','History/Events','Secrets/Hidden Lore'];
  const LORE_DEPTHS = ['Light', 'Standard', 'Deep'];
  const RELATIONSHIPS = ['Stranger','Childhood Friend','Rival','Best Friend','Mentor','Student','Roommate','Co-worker','Sparring Partner','Sibling','Love Interest','Secret Admirer','Forbidden Romance','FWB','Ex-lover','Arranged Marriage','Fake Dating','Bodyguard'];
  const NSFW_RELATIONSHIPS = new Set(['Love Interest','Secret Admirer','Forbidden Romance','FWB','Ex-lover','Arranged Marriage','Fake Dating','Bodyguard']);
  const BODY_TYPES = ['Petite','Slim','Athletic','Average','Curvy','Muscular','Plus-size','Tall & Lanky'];
  const RACE_OPTIONS = ['Human','Elven','Dark Elf','Beastkin','Demon','Angel','Vampire','Lycan','Dragon-blood','Fae','Merfolk','Spirit','Undead','Elemental','Android','Alien','Monster'];
  const HAIR_LENGTHS = ['Bald/Shaved','Pixie/Short','Medium','Long','Very Long'];
  const HAIR_STYLES = ['Straight','Wavy','Curly','Braided','Ponytail','Messy/Wild','Twin Tails'];
  const SKIN_TONES = ['Pale','Fair','Olive','Tan','Brown','Dark','Fantasy'];
  const NOTABLE_FEATURES = ['Glasses','Freckles','Scars','Tattoos','Piercings','Heterochromia','Fangs','Horns','Wings','Tail','Elf Ears','Cat Ears'];
  const ABS_CORE = ['Soft','Toned','Defined','Ripped'];
  const THIGHS = ['Slim','Average','Thick','Thunder'];
  const HIPS = ['Narrow','Average','Wide','Extra Wide'];
  const SHOULDERS = ['Narrow','Average','Broad','V-Shape'];
  const WAIST = ['Thick','Average','Narrow','Wasp'];
  const CHEST_SIZES = ['Flat','Small','Medium','Large','Huge'];
  const BUTT_SIZES = ['Flat','Small','Medium','Large','Huge'];
  const EXPERIENCE_OPTS = ['Innocent','Virgin','Curious','Experienced','Insatiable'];
  const DOMINANCE_OPTS = ['Submissive','Switch','Dominant'];
  const KINK_OPTS = ['Praise','Degradation','Biting/Marking','Bondage','Exhibitionism','Voyeurism','Facesitting','Smothering','Breath Play','Breeding','Jealousy/Possession'];
  const OUTFIT_VIBES = ['Revealing','Lingerie','Uniform','Leather','Barely There'];
  const BACKSTORY_ORIGINS = ['Orphan','Noble Birth','Self-Made','Exile/Outcast','Military/Warrior','Scholar/Academic','Criminal Past','Mysterious/Unknown','Supernatural Origin','Common Folk'];
  const BACKSTORY_TONES = ['Tragic','Heroic','Comedic','Dark/Gritty','Wholesome','Mysterious','Redemptive'];
  const BACKSTORY_ERAS = ['Ancient','Medieval','Victorian','Modern','Futuristic','Timeless/Fantasy'];
  const GEN_DETAIL_OPTS = ['Brief','Standard','Detailed','Comprehensive'];

  // ── Form State ──
  let state = {
    step: 0,
    // Step 0 (Setup)
    modelId: '',
    modelsLoaded: false, availableModels: [],
    // Step 1 (Mode Selection)
    creatorMode: 'automated', // 'automated', 'guided', or 'quick'
    // Step 2 (Configure — Automated) — order matches Flutter exactly
    nsfwEnabled: false,
    selectedArchetype: '',
    name: '', age: '', sex: '',
    race: '', customRace: '', bodyType: '', hairLength: '', hairStyle: '', skinTone: '',
    notableFeatures: [], absCore: '', thighs: '', hips: '', shoulders: '', waist: '',
    chestSize: '', buttSize: '',
    relationship: '', customRelationship: '',
    experience: '', dominance: '', kinks: [], customKinks: '', outfitVibe: '',
    keywords: '',
    backstoryOrigin: '', backstoryTone: '', backstoryEra: '', backstoryNotes: '',
    generationDetail: 'Standard',
    concept: '', conceptGenerated: false, isDescribing: false,
    isRandomizingName: false,
    generateLorebook: true, loreCategories: [], loreDepth: 'Standard',
    personaId: '',
    greetingTones: ['Neutral'],
    greetingLength: 'Medium (2-4 paragraphs)', altGreetingCount: 2,
    artStyle: 'Anime',
    // Step 2 (Configure — Guided)
    guidedVision: '', guidedAppearance: '', guidedHair: '', guidedFeatures: '', guidedRace: '',
    guidedPersonality: '', guidedSpeech: '', guidedSecret: '',
    guidedOrigin: '', guidedSetting: '', guidedTone: '',
    guidedRelDynamic: '', guidedRelScenario: '',
    guidedNsfwBody: '', guidedNsfwExp: '', guidedNsfwDom: '',
    guidedNsfwKinks: '', guidedNsfwClothing: '', guidedNsfwPersonality: '',
    isExpandingNarrative: false,
    // Step 2 (Configure — Quick)
    quickNsfwEnabled: false, quickSelectedTones: ['Neutral'], quickGreetingCount: 2,
    quickConcept: '', quickScenario: '', quickLoreUrls: '', quickLoreFiles: [],
    // Step 3 (Generating)
    isGenerating: false, genStatus: '', genPreview: '',
    // Step 4 (Realism Engine)
    realismEnabled: false, realismTimeOfDay: 'morning', realismDayCount: 1,
    realismShortTermBond: 0, realismLongTermBond: 0, realismTrustLevel: 0,
    realismEmotion: '', realismEmotionIntensity: 'mild',
    realismNsfwCooldown: false, realismChaosMode: false,
    // Step 5 (Review)
    generatedCard: null, avatarBase64: '', imagePrompt: '', lorebookEnabled: {},
    // UI state
    _open: {},
  };

  let sseSource = null;

  // ── Helpers ──
  function $(sel, parent) { return (parent || document).querySelector(sel); }
  function $$(sel, parent) { return (parent || document).querySelectorAll(sel); }
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

  function saveState() {
    try {
      const s = {...state};
      delete s.availableModels; delete s.modelsLoaded;
      sessionStorage.setItem('cw_state', JSON.stringify(s));
    } catch(_){}
  }
  function loadState() {
    try {
      const s = sessionStorage.getItem('cw_state');
      if (s) Object.assign(state, JSON.parse(s));
    } catch(_){}
  }

  async function apiJson(url, opts) {
    const token = sessionStorage.getItem('fp_token') || '';
    const headers = { 'Authorization': 'Bearer ' + token, ...(opts?.headers || {}) };
    try {
      const r = await fetch(url, { ...opts, headers });
      if (!r.ok) { const e = await r.json().catch(()=>({})); throw new Error(e.error || r.statusText); }
      return await r.json();
    } catch(e) { console.error('[chargen]', url, e); return null; }
  }

  function updateStepIndicators() {
    $$('#cw-steps .cw-step').forEach(stepEl => {
      const stepIdx = parseInt(stepEl.dataset.step);
      stepEl.classList.toggle('active', stepIdx === state.step);
      stepEl.classList.toggle('completed', stepIdx < state.step);
    });
  }

  // ── Chip Builder (in-place update) ──
  function buildChips(containerId, options, selected, onToggle, opts={}) {
    const wrap = el('div', {className:'cw-chips', id: containerId});
    _renderChipsInto(wrap, options, selected, onToggle, opts);
    return wrap;
  }
  function _renderChipsInto(wrap, options, selected, onToggle, opts) {
    wrap.innerHTML = '';
    options.forEach(opt => {
      const isNsfw = opts.nsfwSet ? opts.nsfwSet.has(opt) : false;
      if (isNsfw && !state.nsfwEnabled) return;
      // Filter Spicy/NSFW tone when NSFW is off
      if (opts.nsfwFilter && opt === 'Spicy/NSFW' && !state.nsfwEnabled) return;
      const isSel = opts.multi ? selected.includes(opt) : selected === opt;
      const chip = el('div', {
        className: `${opts.archetype ? 'cw-archetype-chip' : 'cw-chip'}${isSel ? ' selected' : ''}${isNsfw ? ' nsfw' : ''}`,
      }, opt);
      chip.addEventListener('click', () => onToggle(opt, wrap, options, opts));
      wrap.appendChild(chip);
    });
  }

  function makeSimpleToggle(key) {
    return (opt, wrap, options, opts) => {
      state[key] = state[key] === opt ? '' : opt;
      saveState();
      _renderChipsInto(wrap, options, state[key], makeSimpleToggle(key), opts);
    };
  }
  function makeMultiToggle(key) {
    return (opt, wrap, options, opts) => {
      const arr = state[key];
      const idx = arr.indexOf(opt);
      if (idx >= 0) arr.splice(idx, 1); else arr.push(opt);
      saveState();
      _renderChipsInto(wrap, options, state[key], makeMultiToggle(key), {...opts, multi:true});
    };
  }

  // ── Collapsible Section (tracks open state) ──
  function buildCollapsible(sectionId, title, contentFn) {
    const isOpen = state._open[sectionId] || false;
    const section = el('div', {className: 'cw-section'});
    const header = el('div', {className: 'cw-collapsible-header'});
    header.appendChild(el('div', {className:'cw-section-title', innerHTML: title}));
    const arrow = el('span', {className: 'cw-collapsible-arrow' + (isOpen?' open':'')}, '▼');
    header.appendChild(arrow);
    section.appendChild(header);
    const body = el('div', {className: 'cw-collapsible-body' + (isOpen?' open':'')});
    contentFn(body);
    section.appendChild(body);
    header.addEventListener('click', () => {
      const nowOpen = body.classList.toggle('open');
      arrow.classList.toggle('open');
      state._open[sectionId] = nowOpen;
    });
    return section;
  }

  function buildToggleRow(label, value, onChange, desc) {
    const row = el('div', {className:'cw-toggle-row'});
    const left = el('div');
    left.appendChild(el('span', {}, label));
    if (desc) left.appendChild(el('div', {className:'cw-toggle-description'}, desc));
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

  function buildSearchableModelSelect(label, key, placeholder) {
    const wrap = el('div', {className:'cw-field', style:'position:relative'});
    wrap.appendChild(el('label', {className:'cw-label'}, label));
    const currentModel = state.availableModels.find(m => m.id === state[key]);
    const input = el('input', {
      className:'cw-input',
      type:'text',
      placeholder: placeholder,
      style:'width:100%',
    });
    input.value = currentModel ? (currentModel.name + (currentModel.pricing ? ' (' + currentModel.pricing + ')' : '')) : '';
    const dropdown = el('div', {className:'cw-model-dropdown', style:'display:none;position:absolute;left:0;right:0;top:100%;z-index:100;max-height:300px;overflow-y:auto;background:#1e293b;border:1px solid rgba(255,255,255,0.15);border-radius:8px;margin-top:2px;box-shadow:0 8px 32px rgba(0,0,0,0.5)'});
    function renderOptions(filter) {
      dropdown.innerHTML = '';
      const q = (filter || '').toLowerCase();
      // Add "Use current model" option
      const defItem = el('div', {
        className: 'cw-model-option' + (!state[key] ? ' selected' : ''),
        style:'padding:8px 12px;cursor:pointer;font-size:13px;color:rgba(255,255,255,0.7);border-bottom:1px solid rgba(255,255,255,0.05)',
      }, '— ' + placeholder + ' —');
      defItem.addEventListener('click', () => { state[key] = ''; input.value = ''; dropdown.style.display = 'none'; saveState(); });
      defItem.addEventListener('mouseenter', () => defItem.style.background = 'rgba(255,255,255,0.08)');
      defItem.addEventListener('mouseleave', () => defItem.style.background = '');
      if (!q || placeholder.toLowerCase().includes(q)) dropdown.appendChild(defItem);
      state.availableModels.forEach(m => {
        const display = m.name + (m.pricing ? ' (' + m.pricing + ')' : '');
        if (q && !display.toLowerCase().includes(q) && !m.id.toLowerCase().includes(q)) return;
        const item = el('div', {
          className: 'cw-model-option' + (state[key] === m.id ? ' selected' : ''),
          style:'padding:8px 12px;cursor:pointer;font-size:13px;color:#e2e8f0',
        }, display);
        item.addEventListener('click', () => { state[key] = m.id; input.value = display; dropdown.style.display = 'none'; saveState(); });
        item.addEventListener('mouseenter', () => item.style.background = 'rgba(255,255,255,0.08)');
        item.addEventListener('mouseleave', () => item.style.background = '');
        dropdown.appendChild(item);
      });
      if (dropdown.children.length === 0) {
        dropdown.appendChild(el('div', {style:'padding:12px;color:rgba(255,255,255,0.4);font-size:13px'}, 'No models match your search'));
      }
    }
    input.addEventListener('focus', () => { renderOptions(input.value); dropdown.style.display = 'block'; });
    input.addEventListener('input', () => { renderOptions(input.value); dropdown.style.display = 'block'; });
    document.addEventListener('click', (e) => { if (!wrap.contains(e.target)) dropdown.style.display = 'none'; });
    wrap.appendChild(input);
    wrap.appendChild(dropdown);
    return wrap;
  }

  async function loadModels() {
    // Always fetch fresh — don't cache empty results
    try {
      console.log('[chargen] Fetching models from /api/models/list...');
      const data = await apiJson('/api/models/list');
      console.log('[chargen] Models response:', data);
      if (data && Array.isArray(data) && data.length > 0) {
        state.availableModels = data;
        state.modelsLoaded = true;
        console.log('[chargen] Loaded', data.length, 'models');
      } else {
        state.availableModels = [];
        state.modelsLoaded = true;
        console.warn('[chargen] No models returned from API');
      }
    } catch (e) {
      console.error('[chargen] Failed to load models:', e);
      state.availableModels = [];
      state.modelsLoaded = false; // Allow retry on failure
    }
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 0: Setup (Backend & Model Selection) — matches Flutter
  // ═══════════════════════════════════════════════════════════

  let _koboldStatus = '';
  let _isStartingKobold = false;
  let _backendType = 'openRouter'; // 'kobold' or 'openRouter'
  let _contextSize = 8192;
  let _koboldRunning = false;
  let _isIntelMac = false;

  async function fetchBackendState() {
    const data = await apiJson('/api/settings');
    if (data) {
      _backendType = data.activeBackend === 'kobold' ? 'kobold' : 'openRouter';
      _contextSize = data.contextSize || 8192;
      _koboldRunning = data.koboldRunning === true;
      _isIntelMac = data.isIntelMac === true;
      // Force API mode on Intel Macs
      if (_isIntelMac && _backendType === 'kobold') {
        _backendType = 'openRouter';
      }
    }
  }

  const CONTEXT_STEPS = [2048, 4096, 8192, 16384, 32768, 65536, 131072];
  function closestContextIdx(val) {
    let best = 0;
    for (let i = 0; i < CONTEXT_STEPS.length; i++) {
      if (Math.abs(CONTEXT_STEPS[i] - val) < Math.abs(CONTEXT_STEPS[best] - val)) best = i;
    }
    return best;
  }
  function contextLabel(val) {
    return val >= 1024 ? (val % 1024 === 0 ? (val/1024) + 'K' : (val/1024).toFixed(1) + 'K') : String(val);
  }

  async function renderStep0() {
    const c = $('#cw-content');
    c.innerHTML = '';
    c.appendChild(el('div', {className:'cw-page-header'}, 'Backend & Model Setup'));
    c.appendChild(el('div', {className:'cw-hint', style:'margin-bottom:24px'}, 'Choose your AI backend and model before configuring your character.'));

    // Fetch current backend state (non-blocking)
    try { await fetchBackendState(); } catch(_){}

    // ── Backend Toggle ──
    const backendSec = el('div', {className:'cw-section'});
    backendSec.appendChild(el('label', {className:'cw-label'}, 'Backend'));
    const backendRow = el('div', {style:'display:flex;gap:12px;margin-bottom:16px'});

    const koboldChip = el('div', {
      className: 'cw-backend-chip' + (_backendType === 'kobold' && !_isIntelMac ? ' selected' : ''),
      style: 'flex:1;padding:14px 16px;border-radius:10px;text-align:center;' + (_isIntelMac ? 'opacity:0.4;cursor:not-allowed;' : 'cursor:pointer;') + 'border:' + (_backendType === 'kobold' && !_isIntelMac ? '2px solid #3b82f6' : '1px solid rgba(255,255,255,0.12)') + ';background:' + (_backendType === 'kobold' && !_isIntelMac ? 'rgba(59,130,246,0.15)' : '#1e293b') + ';color:' + (_backendType === 'kobold' && !_isIntelMac ? '#3b82f6' : 'rgba(255,255,255,0.5)') + ';font-size:13px;font-weight:' + (_backendType === 'kobold' && !_isIntelMac ? '700' : '400'),
    }, '🖥️ KoboldCpp (Local)');
    if (!_isIntelMac) {
      koboldChip.addEventListener('click', async () => {
        if (_backendType !== 'kobold') {
          _backendType = 'kobold';
          await apiJson('/api/settings', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({activeBackend:'kobold'}) });
          renderStep0();
        }
      });
    }

    const apiChip = el('div', {
      className: 'cw-backend-chip' + (_backendType !== 'kobold' ? ' selected' : ''),
      style: 'flex:1;padding:14px 16px;border-radius:10px;text-align:center;cursor:pointer;border:' + (_backendType !== 'kobold' ? '2px solid #3b82f6' : '1px solid rgba(255,255,255,0.12)') + ';background:' + (_backendType !== 'kobold' ? 'rgba(59,130,246,0.15)' : '#1e293b') + ';color:' + (_backendType !== 'kobold' ? '#3b82f6' : 'rgba(255,255,255,0.5)') + ';font-size:13px;font-weight:' + (_backendType !== 'kobold' ? '700' : '400'),
    }, '☁️ API (Remote)');
    apiChip.addEventListener('click', async () => {
      if (_backendType !== 'openRouter') {
        _backendType = 'openRouter';
        await apiJson('/api/settings', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({activeBackend:'openRouter'}) });
        renderStep0();
      }
    });

    backendRow.appendChild(koboldChip);
    backendRow.appendChild(apiChip);
    backendSec.appendChild(backendRow);

    // Intel Mac warning
    if (_isIntelMac) {
      const warn = el('div', {style:'background:rgba(255,152,0,0.1);border:1px solid rgba(255,152,0,0.4);border-radius:8px;padding:10px 12px;margin-bottom:12px;display:flex;align-items:center;gap:8px'});
      warn.innerHTML = '<span style="font-size:16px">⚠️</span><span style="font-size:12px;color:#ffb74d">Local inference is not supported on Intel Macs. Only Remote API mode is available.</span>';
      backendSec.appendChild(warn);
    }

    c.appendChild(backendSec);

    if (_backendType === 'kobold') {
      // ── KoboldCpp Section ──
      const koboldSec = el('div', {className:'cw-section'});
      koboldSec.appendChild(el('div', {className:'cw-section-title'}, '🖥️ Local Model (.gguf)'));

      // Status indicator
      const statusRow = el('div', {style:'display:flex;align-items:center;gap:8px;margin-bottom:12px'});
      const dot = el('div', {style:'width:8px;height:8px;border-radius:50%;background:' + (_koboldRunning ? '#22c55e' : '#ef4444')});
      statusRow.appendChild(dot);
      statusRow.appendChild(el('span', {style:'font-size:12px;color:' + (_koboldRunning ? '#86efac' : '#ef4444')},
        _koboldRunning ? 'KoboldCpp is running' : 'KoboldCpp is not running'));
      koboldSec.appendChild(statusRow);

      // Model list container
      const modelList = el('div', {id:'cw-local-models', style:'max-height:250px;overflow-y:auto;background:#1e293b;border-radius:10px;border:1px solid rgba(255,255,255,0.12);margin-bottom:12px'});
      modelList.innerHTML = '<div style="padding:16px;text-align:center;color:rgba(255,255,255,0.3);font-size:13px">Loading local models...</div>';
      koboldSec.appendChild(modelList);

      // Load models async
      (async () => {
        const data = await apiJson('/api/backend/local-models');
        modelList.innerHTML = '';
        if (!data || !data.models || data.models.length === 0) {
          const empty = el('div', {style:'padding:24px;text-align:center'});
          empty.appendChild(el('div', {style:'color:rgba(255,255,255,0.15);font-size:28px;margin-bottom:8px'}, '📂'));
          empty.appendChild(el('div', {style:'color:rgba(255,255,255,0.3);font-size:13px'}, 'No .gguf models found'));
          if (data?.modelsDir) {
            empty.appendChild(el('div', {style:'color:rgba(255,255,255,0.15);font-size:11px;margin-top:4px'}, 'Place models in: ' + data.modelsDir));
          }
          modelList.appendChild(empty);
        } else {
          // Auto-select last used model
          if (!state._selectedLocalModel && data.lastUsedPath) {
            state._selectedLocalModel = data.lastUsedPath;
          }
          data.models.forEach(m => {
            const isSel = state._selectedLocalModel === m.path;
            const row = el('div', {
              style: 'display:flex;align-items:center;padding:10px 14px;cursor:pointer;border-bottom:1px solid rgba(255,255,255,0.04);' +
                (isSel ? 'background:rgba(59,130,246,0.15);' : '') +
                'transition:background 0.15s',
            });
            row.appendChild(el('span', {style:'margin-right:10px;font-size:14px;color:' + (isSel ? '#3b82f6' : 'rgba(255,255,255,0.15)')}, isSel ? '✅' : '📄'));
            const info = el('div', {style:'flex:1;min-width:0'});
            info.appendChild(el('div', {style:'font-size:13px;color:' + (isSel ? '#3b82f6' : '#e2e8f0') + ';overflow:hidden;text-overflow:ellipsis;white-space:nowrap'}, m.name));
            row.appendChild(info);
            row.appendChild(el('span', {style:'font-size:11px;color:rgba(255,255,255,0.3);margin-left:8px;flex-shrink:0'}, m.sizeGB + 'GB'));
            row.addEventListener('click', () => { state._selectedLocalModel = m.path; saveState(); renderStep0(); });
            row.addEventListener('mouseenter', () => { if (!isSel) row.style.background = 'rgba(255,255,255,0.04)'; });
            row.addEventListener('mouseleave', () => { if (!isSel) row.style.background = ''; });
            modelList.appendChild(row);
          });
        }
      })();

      // ── Context Size Slider ──
      const ctxWrap = el('div', {style:'margin-bottom:16px'});
      const ctxHeader = el('div', {style:'display:flex;align-items:center;justify-content:space-between;margin-bottom:4px'});
      ctxHeader.appendChild(el('span', {style:'color:rgba(255,255,255,0.5);font-size:12px;font-weight:500'}, '🧠 Context Size: ' + contextLabel(_contextSize) + ' tokens'));
      ctxHeader.appendChild(el('span', {style:'color:#3b82f6;font-size:12px;font-weight:700'}, String(_contextSize)));
      ctxWrap.appendChild(ctxHeader);

      const slider = el('input', {type:'range', min:'0', max:String(CONTEXT_STEPS.length-1), step:'1',
        style:'width:100%;accent-color:#3b82f6'});
      slider.value = closestContextIdx(_contextSize);
      slider.addEventListener('input', async () => {
        _contextSize = CONTEXT_STEPS[parseInt(slider.value)];
        ctxHeader.innerHTML = '';
        ctxHeader.appendChild(el('span', {style:'color:rgba(255,255,255,0.5);font-size:12px;font-weight:500'}, '🧠 Context Size: ' + contextLabel(_contextSize) + ' tokens'));
        ctxHeader.appendChild(el('span', {style:'color:#3b82f6;font-size:12px;font-weight:700'}, String(_contextSize)));
        await apiJson('/api/settings', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({contextSize:_contextSize}) });
      });
      ctxWrap.appendChild(slider);

      const ctxLabels = el('div', {style:'display:flex;justify-content:space-between'});
      ctxLabels.appendChild(el('span', {style:'color:rgba(255,255,255,0.15);font-size:10px'}, '2K'));
      ctxLabels.appendChild(el('span', {style:'color:rgba(255,255,255,0.15);font-size:10px'}, '128K'));
      ctxWrap.appendChild(ctxLabels);
      ctxWrap.appendChild(el('div', {style:'color:rgba(255,255,255,0.15);font-size:10px;margin-top:2px'}, 'Larger context uses more VRAM. Match your KoboldCpp --contextsize setting.'));
      koboldSec.appendChild(ctxWrap);

      // ── Start / Stop / Rescan buttons ──
      const btnRow = el('div', {style:'display:flex;align-items:center;gap:8px;flex-wrap:wrap'});

      if (_koboldRunning) {
        const stopBtn = el('button', {
          className: 'cw-btn',
          style: 'background:#ef4444;color:#fff;border:none;padding:8px 16px;border-radius:8px;cursor:pointer;font-size:13px;font-weight:600;display:flex;align-items:center;gap:6px',
        });
        stopBtn.innerHTML = '⏹ Stop KoboldCpp';
        stopBtn.addEventListener('click', async () => {
          stopBtn.disabled = true;
          stopBtn.innerHTML = '⏳ Stopping...';
          await apiJson('/api/backend/stop', { method:'POST', headers:{'Content-Type':'application/json'}, body: '{}' });
          _koboldRunning = false;
          renderStep0();
        });
        btnRow.appendChild(stopBtn);
      } else {
        const startBtn = el('button', {
          className: 'cw-btn',
          style: 'background:#16a34a;color:#fff;border:none;padding:8px 16px;border-radius:8px;cursor:pointer;font-size:13px;font-weight:600;display:flex;align-items:center;gap:6px' +
            (!state._selectedLocalModel ? ';opacity:0.4;cursor:not-allowed' : ''),
        });
        startBtn.innerHTML = '▶ Start KoboldCpp';
        if (!state._selectedLocalModel) {
          startBtn.disabled = true;
        }
        startBtn.addEventListener('click', async () => {
          if (!state._selectedLocalModel || _isStartingKobold) return;
          _isStartingKobold = true;
          startBtn.disabled = true;
          startBtn.innerHTML = '<span style="display:inline-block;width:14px;height:14px;border:2px solid rgba(255,255,255,0.3);border-top-color:#fff;border-radius:50%;animation:cw-spin 0.6s linear infinite"></span> Starting...';
          _koboldStatus = 'Starting KoboldCpp...';

          // Send non-blocking start request
          const startResult = await apiJson('/api/backend/start', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({ modelPath: state._selectedLocalModel }),
          });

          if (startResult?.error) {
            _isStartingKobold = false;
            _koboldStatus = 'Error: ' + startResult.error;
            renderStep0();
            return;
          }

          // Poll for readiness
          let elapsed = 0;
          const pollInterval = setInterval(async () => {
            elapsed += 2;
            try {
              const status = await apiJson('/api/backend/status');
              // modelReady is the real signal — running just means process started
              if (status?.modelReady) {
                clearInterval(pollInterval);
                _isStartingKobold = false;
                _koboldRunning = true;
                _koboldStatus = 'Model loaded successfully!';
                renderStep0();
                return;
              }
              // Show loading progress from backend
              if (status?.loadingStatus && startBtn && document.contains(startBtn)) {
                startBtn.innerHTML = '<span style="display:inline-block;width:14px;height:14px;border:2px solid rgba(255,255,255,0.3);border-top-color:#fff;border-radius:50%;animation:cw-spin 0.6s linear infinite"></span> ' + status.loadingStatus;
                return;
              }
            } catch(_) {}

            // Update button text with elapsed time
            if (startBtn && document.contains(startBtn)) {
              startBtn.innerHTML = '<span style="display:inline-block;width:14px;height:14px;border:2px solid rgba(255,255,255,0.3);border-top-color:#fff;border-radius:50%;animation:cw-spin 0.6s linear infinite"></span> Loading... ' + elapsed + 's';
            }

            // Timeout after 120s
            if (elapsed >= 120) {
              clearInterval(pollInterval);
              _isStartingKobold = false;
              _koboldStatus = 'Timeout — model may still be loading. Check desktop app.';
              renderStep0();
            }
          }, 2000);
        });
        btnRow.appendChild(startBtn);
      }

      const rescanBtn = el('button', {
        className: 'cw-btn',
        style: 'background:transparent;border:1px solid rgba(255,255,255,0.15);color:rgba(255,255,255,0.4);padding:8px 12px;border-radius:8px;cursor:pointer;font-size:12px;display:flex;align-items:center;gap:4px',
      });
      rescanBtn.innerHTML = '📂 Rescan';
      rescanBtn.addEventListener('click', () => renderStep0());
      btnRow.appendChild(rescanBtn);

      // Status text
      if (_koboldStatus) {
        const statusText = el('span', {style:'font-size:12px;color:' + (_koboldStatus.includes('Error') ? '#ef4444' : 'rgba(255,255,255,0.5)') + ';flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap'}, _koboldStatus);
        btnRow.appendChild(statusText);
      }

      koboldSec.appendChild(btnRow);
      c.appendChild(koboldSec);
    } else {
      // ── API Model Selector ──
      const modelSec = el('div', {className:'cw-section'});
      modelSec.appendChild(el('div', {className:'cw-section-title'}, '🤖 Model Selection'));
      if (!state.modelsLoaded) {
        modelSec.appendChild(el('div', {className:'cw-hint'}, 'Loading models...'));
        loadModels().then(() => renderStep0());
      } else {
        modelSec.appendChild(buildSearchableModelSelect('Generation Model', 'modelId', 'Use current model'));
        modelSec.appendChild(el('div', {className:'cw-hint', style:'margin-top:4px'}, 'Tip: Use a non-thinking model (GPT-4o, Claude, Gemini) for best results.'));
      }
      c.appendChild(modelSec);
    }

    c.appendChild(buildNavBtns(null, () => { state.step = 1; saveState(); render(); }));
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 1: Mode Selection
  // ═══════════════════════════════════════════════════════════
  function renderStep1_ModeSelect() {
    const c = $('#cw-content');
    c.innerHTML = '';
    const wrap = el('div', {style:'max-width:700px;margin:0 auto'});
    wrap.appendChild(el('div', {className:'cw-section-title', style:'font-size:24px;font-weight:700;margin-bottom:6px'}, 'How do you want to create?'));
    wrap.appendChild(el('div', {style:'color:rgba(255,255,255,0.5);font-size:14px;margin-bottom:28px'}, 'Choose the creation mode that fits your workflow.'));

    function modeCard(mode, icon, iconColor, title, subtitle, desc, features) {
      const sel = state.creatorMode === mode;
      let borderColor, bgColor;
      if (sel) {
        if (mode === 'guided') { borderColor = '#5eead4'; bgColor = 'rgba(94,234,212,0.06)'; }
        else if (mode === 'quick') { borderColor = '#4ade80'; bgColor = 'rgba(74,222,128,0.06)'; }
        else { borderColor = '#fbbf24'; bgColor = 'rgba(251,191,36,0.06)'; }
      } else {
        borderColor = 'rgba(255,255,255,0.08)';
        bgColor = '#1e293b';
      }
      const card = el('div', {
        className: 'cw-mode-card' + (sel ? ' selected' : ''),
        style: `display:flex;gap:16px;padding:20px;border-radius:16px;border:${sel?2:1}px solid ${borderColor};background:${bgColor};cursor:pointer;margin-bottom:16px;transition:all 0.2s`,
      });
      card.addEventListener('click', () => { state.creatorMode = mode; saveState(); renderStep1_ModeSelect(); });
      // Icon box
      const iconBox = el('div', {style:`width:56px;height:56px;border-radius:14px;background:${iconColor}22;display:flex;align-items:center;justify-content:center;flex-shrink:0;font-size:28px`});
      iconBox.textContent = icon;
      card.appendChild(iconBox);
      // Info
      const info = el('div', {style:'flex:1;min-width:0'});
      const titleRow = el('div', {style:'display:flex;justify-content:space-between;align-items:center'});
      titleRow.appendChild(el('div', {style:`font-size:18px;font-weight:700;color:${sel?'#fff':'rgba(255,255,255,0.7)'}`}, title));
      if (sel) {
        const badge = el('span', {style:`padding:4px 10px;border-radius:12px;background:${borderColor}4d;color:${borderColor};font-size:11px;font-weight:600`}, 'Selected');
        titleRow.appendChild(badge);
      }
      info.appendChild(titleRow);
      info.appendChild(el('div', {style:`color:${sel?iconColor:'rgba(255,255,255,0.3)'};font-size:13px;margin-top:2px`}, subtitle));
      info.appendChild(el('div', {style:'color:rgba(255,255,255,0.3);font-size:12px;line-height:1.4;margin-top:8px'}, desc));
      const featsWrap = el('div', {style:'display:flex;flex-wrap:wrap;gap:8px;margin-top:8px'});
      features.forEach(f => {
        const feat = el('div', {style:`display:flex;align-items:center;gap:4px;font-size:11px;color:${sel?'rgba(255,255,255,0.5)':'rgba(255,255,255,0.2)'}`});
        feat.textContent = '✓ ' + f;
        featsWrap.appendChild(feat);
      });
      info.appendChild(featsWrap);
      card.appendChild(info);
      return card;
    }

    wrap.appendChild(modeCard('automated', '✨', '#fbbf24', 'Automated Creator',
      'Pick traits from bubbles, let AI fill the gaps',
      'Best when you want to explore and discover. Select from archetypes, appearance options, backstory presets, and personality keywords. The AI handles the rest.',
      ['Archetype presets', 'Bubble selectors for every trait', 'AI generates description from selections']
    ));
    wrap.appendChild(modeCard('guided', '📝', '#5eead4', 'Guided Creator',
      'Write your vision, AI helps you flesh it out',
      'Best when you already have a character in mind but need help getting it on paper. Describe your idea in your own words — guided prompts and suggestions help you express your vision.',
      ['Free-form text with guided prompts', 'Suggestion chips for inspiration', '"Help me expand this" AI assist']
    ));
    wrap.appendChild(modeCard('quick', '⚡', '#4ade80', 'Quick Create',
      'Name it, describe it, done — AI does the rest',
      'Fastest path to a finished character. Just give a name and a one-liner. The full AI pipeline (interview, lorebook, greetings) runs automatically.',
      ['Name + concept only', 'NSFW toggle', 'Full pipeline in ~2 min']
    ));

    // Navigation
    const nav = el('div', {style:'display:flex;justify-content:center;gap:16px;margin-top:32px'});
    const backBtn = el('button', {className:'cw-btn cw-btn-secondary', style:'height:52px;padding:0 24px'}, '← Back');
    backBtn.addEventListener('click', () => { state.step = 0; saveState(); render(); });
    nav.appendChild(backBtn);
    let nextLabel, nextBg;
    if (state.creatorMode === 'guided') { nextLabel = 'Next: Guided Setup →'; nextBg = '#0d7377'; }
    else if (state.creatorMode === 'quick') { nextLabel = 'Next: Quick Setup →'; nextBg = '#16a34a'; }
    else { nextLabel = 'Next: Automated Setup →'; nextBg = '#3b82f6'; }
    const nextBtn = el('button', {className:'cw-btn cw-btn-primary', style:`height:52px;min-width:280px;background:${nextBg}`});
    nextBtn.textContent = nextLabel;
    nextBtn.addEventListener('click', () => { state.step = 2; saveState(); render(); });
    nav.appendChild(nextBtn);
    wrap.appendChild(nav);
    c.appendChild(wrap);
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 2 (Quick): Quick Character Configuration
  // ═══════════════════════════════════════════════════════════

  function renderStep2_Quick() {
    const c = $('#cw-content');
    c.innerHTML = '';
    const wrap = el('div', {style:'max-width:600px;margin:0 auto'});

    // Header
    const header = el('div', {style:'display:flex;align-items:center;gap:14px;margin-bottom:8px'});
    header.appendChild(el('div', {style:'width:42px;height:42px;border-radius:12px;background:rgba(74,222,128,0.12);display:flex;align-items:center;justify-content:center;font-size:22px'}, '⚡'));
    const headerInfo = el('div');
    headerInfo.appendChild(el('div', {style:'font-size:24px;font-weight:700;color:#fff'}, 'Quick Create'));
    headerInfo.appendChild(el('div', {style:'font-size:13px;color:rgba(255,255,255,0.5)'}, 'Name it, describe it, generate.'));
    header.appendChild(headerInfo);
    wrap.appendChild(header);
    wrap.appendChild(el('div', {style:'font-size:13px;color:rgba(255,255,255,0.5);margin-bottom:24px'}, 'Fastest path to a finished character.'));

    // Name field
    const nameSec = el('div', {style:'margin-bottom:24px'});
    nameSec.appendChild(el('div', {style:'color:rgba(255,255,255,0.5);font-size:12px;font-weight:500;margin-bottom:8px'}, 'Character Name'));
    const nameInp = el('input', {className:'cw-quick-input', type:'text', placeholder:'e.g. Morgana, Kaito, Vex...'});
    nameInp.value = state.name || '';
    nameInp.addEventListener('input', () => { state.name = nameInp.value; saveState(); });
    nameInp.addEventListener('focus', () => { nameInp.style.borderColor = '#4ade80'; });
    nameInp.addEventListener('blur', () => { nameInp.style.borderColor = 'rgba(255,255,255,0.12)'; });
    nameSec.appendChild(nameInp);
    wrap.appendChild(nameSec);

    // Concept field
    const conceptSec = el('div', {style:'margin-bottom:24px'});
    conceptSec.appendChild(el('div', {style:'color:rgba(255,255,255,0.5);font-size:12px;font-weight:500;margin-bottom:4px'}, 'Describe them (optional)'));
    conceptSec.appendChild(el('div', {style:'color:rgba(255,255,255,0.24);font-size:11px;margin-bottom:8px'}, 'A sentence or two is plenty. Leave it blank and the AI will invent someone.'));
    const conceptTa = el('textarea', {className:'cw-quick-textarea', rows:'4', placeholder:'A gruff dwarven blacksmith who secretly writes poetry...'});
    conceptTa.value = state.quickConcept || '';
    conceptTa.addEventListener('input', () => { state.quickConcept = conceptTa.value; saveState(); });
    conceptTa.addEventListener('focus', () => { conceptTa.style.borderColor = '#4ade80'; });
    conceptTa.addEventListener('blur', () => { conceptTa.style.borderColor = 'rgba(255,255,255,0.12)'; });
    conceptSec.appendChild(conceptTa);
    wrap.appendChild(conceptSec);

    // Scenario field
    const scenarioSec = el('div', {style:'margin-bottom:24px'});
    scenarioSec.appendChild(el('div', {style:'color:rgba(255,255,255,0.5);font-size:12px;font-weight:500;margin-bottom:4px'}, 'Scenario / Setting (optional)'));
    scenarioSec.appendChild(el('div', {style:'color:rgba(255,255,255,0.24);font-size:11px;margin-bottom:8px'}, 'Where does the story take place? What\'s the situation? The AI will build on this.'));
    const scenarioTa = el('textarea', {className:'cw-quick-textarea', rows:'3', placeholder:'A modern coffee shop where they work as a barista, a fantasy guild hall, a space station...'});
    scenarioTa.value = state.quickScenario || '';
    scenarioTa.addEventListener('input', () => { state.quickScenario = scenarioTa.value; saveState(); });
    scenarioTa.addEventListener('focus', () => { scenarioTa.style.borderColor = '#4ade80'; });
    scenarioTa.addEventListener('blur', () => { scenarioTa.style.borderColor = 'rgba(255,255,255,0.12)'; });
    scenarioSec.appendChild(scenarioTa);
    wrap.appendChild(scenarioSec);

    // Art style
    const artSec = el('div', {style:'margin-bottom:24px'});
    artSec.appendChild(el('div', {style:'color:rgba(255,255,255,0.5);font-size:12px;font-weight:500;margin-bottom:8px'}, 'Avatar Art Style'));
    artSec.appendChild(buildChips('chips-quick-art', ART_STYLES, state.artStyle, makeSimpleToggle('artStyle')));
    wrap.appendChild(artSec);

    // Greeting tones
    const toneSec = el('div', {style:'margin-bottom:24px'});
    const maxTones = state.quickGreetingCount + 1;
    toneSec.appendChild(el('div', {style:'color:rgba(255,255,255,0.5);font-size:12px;font-weight:500;margin-bottom:4px'}, 'Greeting Tone'));
    toneSec.appendChild(el('div', {style:'color:rgba(255,255,255,0.24);font-size:11px;margin-bottom:8px'},
      state.quickGreetingCount === 0 ? 'Tone for the first message.' : 'Select up to ' + maxTones + ' — one per greeting.'));
    const toneToggle = (opt, wrapEl, options, opts) => {
      const arr = state.quickSelectedTones;
      const idx = arr.indexOf(opt);
      if (idx >= 0) {
        if (arr.length > 1) arr.splice(idx, 1);
      } else {
        if (arr.length >= maxTones) arr.splice(arr.length - 1, 1);
        arr.push(opt);
      }
      saveState();
      _renderChipsInto(wrapEl, options, arr, toneToggle, opts);
    };
    toneSec.appendChild(buildChips('chips-quick-tones', GREETING_TONES, state.quickSelectedTones, toneToggle, {multi:true, nsfwFilter:true}));
    wrap.appendChild(toneSec);

    // Number of greetings
    const greetSec = el('div', {style:'margin-bottom:24px'});
    greetSec.appendChild(el('div', {style:'color:rgba(255,255,255,0.5);font-size:12px;font-weight:500;margin-bottom:4px'}, 'Number of Greetings'));
    greetSec.appendChild(el('div', {style:'color:rgba(255,255,255,0.24);font-size:11px;margin-bottom:8px'}, 'How many first messages to generate (1 main + alternates).'));
    const greetRow = el('div', {style:'display:flex;align-items:center;gap:12px'});
    const greetSlider = el('input', {type:'range', min:'0', max:'5', step:'1', style:'flex:1;accent-color:#4ade80'});
    greetSlider.value = state.quickGreetingCount;
    const greetVal = el('span', {style:'color:rgba(255,255,255,0.7);font-size:13px;min-width:80px;text-align:right'});
    function updateGreetLabel() {
      const count = parseInt(greetSlider.value);
      state.quickGreetingCount = count;
      const limit = count + 1;
      while (state.quickSelectedTones.length > limit) state.quickSelectedTones.pop();
      greetVal.textContent = count === 0 ? '1 greeting' : '1 + ' + count;
      saveState();
      _renderChipsInto(document.getElementById('chips-quick-tones'), GREETING_TONES, state.quickSelectedTones, toneToggle, {multi:true, nsfwFilter:true});
    }
    greetSlider.addEventListener('input', updateGreetLabel);
    greetRow.appendChild(greetSlider);
    greetRow.appendChild(greetVal);
    greetSec.appendChild(greetRow);
    wrap.appendChild(greetSec);

    // Lore input
    const loreSec = el('div', {style:'margin-bottom:24px'});
    loreSec.appendChild(el('div', {style:'color:rgba(255,255,255,0.5);font-size:12px;font-weight:500;margin-bottom:8px'}, 'World Lore / Wiki URLs (optional)'));
    const loreTa = el('textarea', {className:'cw-quick-textarea', rows:'3', placeholder:'https://wiki.example.com/character, https://lore.example.com/world...'});
    loreTa.value = state.quickLoreUrls || '';
    loreTa.addEventListener('input', () => { state.quickLoreUrls = loreTa.value; saveState(); });
    loreSec.appendChild(loreTa);
    loreSec.appendChild(el('div', {style:'color:rgba(255,255,255,0.24);font-size:11px;margin-top:4px'}, 'Comma-separated URLs or paste lore text directly.'));
    wrap.appendChild(loreSec);

    // NSFW toggle
    const nsfwSec = el('div', {className:'cw-quick-nsfw' + (state.quickNsfwEnabled ? ' active' : '')});
    nsfwSec.appendChild(el('span', {style:`font-size:20px;color:${state.quickNsfwEnabled?'#f472b6':'rgba(255,255,255,0.24)'}`}));
    const nsfwInfo = el('div', {style:'flex:1'});
    nsfwInfo.appendChild(el('div', {style:`color:${state.quickNsfwEnabled?'#f9a8d4':'rgba(255,255,255,0.7)'};font-size:14px;font-weight:600`}, 'NSFW Content'));
    nsfwInfo.appendChild(el('div', {style:`color:${state.quickNsfwEnabled?'rgba(244,114,182,0.6)':'rgba(255,255,255,0.24)'};font-size:11px`}, 'Enables adult themes in personality, lorebook, and greetings'));
    nsfwSec.appendChild(nsfwInfo);
    const nsfwToggle = el('label', {className:'toggle-switch', style:'margin:0'});
    const nsfwCb = el('input', {type:'checkbox'});
    nsfwCb.checked = state.quickNsfwEnabled;
    nsfwCb.addEventListener('change', () => {
      state.quickNsfwEnabled = nsfwCb.checked;
      saveState();
      renderStep2_Quick();
    });
    nsfwToggle.appendChild(nsfwCb);
    nsfwToggle.appendChild(el('span', {className:'toggle-slider'}));
    nsfwSec.appendChild(nsfwToggle);
    nsfwSec.addEventListener('click', (e) => {
      if (e.target === nsfwSec || e.target === nsfwInfo || e.target.tagName === 'SPAN' && e.target.parentElement === nsfwInfo) {
        state.quickNsfwEnabled = !state.quickNsfwEnabled;
        saveState();
        renderStep2_Quick();
      }
    });
    wrap.appendChild(nsfwSec);

    // Navigation
    const nav = el('div', {style:'display:flex;justify-content:space-between;align-items:center;margin-top:32px'});
    const backBtn = el('button', {className:'cw-btn cw-btn-secondary', style:'height:52px;padding:0 24px'});
    backBtn.textContent = '← Back';
    backBtn.addEventListener('click', () => { state.step = 1; saveState(); render(); });
    nav.appendChild(backBtn);
    const createBtn = el('button', {className:'cw-btn cw-btn-primary', style:'height:52px;flex:1;max-width:300px;margin-left:16px;background:#16a34a'});
    const nameEmpty = !state.name.trim();
    createBtn.textContent = nameEmpty ? 'Enter a name to continue' : 'Create Character ⚡';
    if (!nameEmpty) {
      createBtn.addEventListener('click', startQuickGeneration);
    } else {
      createBtn.style.opacity = '0.4';
      createBtn.style.cursor = 'not-allowed';
    }
    nav.appendChild(createBtn);
    wrap.appendChild(nav);
    c.appendChild(wrap);
  }

  async function startQuickGeneration() {
    if (!state.name.trim()) return;
    const concept = (state.quickConcept || '').trim() || 'Create an interesting, unique character for roleplay.';
    const scenario = (state.quickScenario || '').trim();

    state.isGenerating = true;
    state.genStatus = 'Starting Quick Create...';
    state.genPreview = '';
    state.step = 3;
    saveState();
    connectChargenSSE();
    startGenStatusPoller();

    const body = {
      name: state.name.trim(),
      concept: concept,
      scenario: scenario,
      artStyle: state.artStyle,
      greetingTones: state.quickSelectedTones,
      altGreetingCount: state.quickGreetingCount,
      greetingLength: 'Medium (2-4 paragraphs)',
      generateLorebook: true,
      loreCategories: [],
      loreDepth: 'Standard',
      nsfwEnabled: state.quickNsfwEnabled,
      generationDetail: 'Standard',
      personaId: state.personaId,
      modelId: state.modelId,
    };

    const res = await apiJson('/api/chargen/generate', {
      method: 'POST',
      headers: {'Content-Type':'application/json'},
      body: JSON.stringify(body),
    });

    if (!res || res.error) {
      state.genStatus = 'Error: ' + (res?.error || 'Failed to start generation');
      state.isGenerating = false;
      saveState();
      updateGenUI();
      stopGenStatusPoller();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 2 (Guided): Guided Character Configuration
  // ═══════════════════════════════════════════════════════════

  const GUIDED_VISION_PLACEHOLDERS = [
    'A tall, slender woman with flowing black hair was dancing in a nightclub when she locked eyes with {{user}}...',
    'A grizzled old blacksmith with one arm, haunted by the war, but still cracks jokes while forging weapons...',
    'Shy bookworm, always has cat hair on her sweater, secretly powerful mage, terrible at eye contact...',
    'Cocky bounty hunter with cybernetic eyes and a debt to the wrong people. Flirts with everyone...',
    'Ancient dragon disguised as a librarian, hoards rare first editions instead of gold...',
  ];
  const SCENARIO_SEEDS = [
    'Met at a café', 'Childhood friends', 'Mysterious stranger', 'Coworkers',
    'Online match', 'Rescued by them', 'Woke up next to them', 'Battle partners',
    'Neighbors', 'Classmates', 'Summoned them',
  ];

  function buildGuidedField(label, stateKey, hint, suggestions, opts) {
    opts = opts || {};
    const isNsfw = opts.nsfw || false;
    const accent = isNsfw ? '#f472b6' : '#5eead4';
    const wrap = el('div', {className:'cw-guided-field', style:'margin-bottom:16px'});
    // Label row
    const labelRow = el('div', {style:'display:flex;align-items:center;gap:4px;margin-bottom:6px'});
    if (isNsfw) labelRow.appendChild(el('span', {style:'font-size:12px'}, '🔥'));
    labelRow.appendChild(el('span', {style:`color:${isNsfw?'#f9a8d4':'rgba(255,255,255,0.5)'};font-size:12px;font-weight:500;flex:1`}, label));
    if (opts.trailing) labelRow.appendChild(opts.trailing);
    wrap.appendChild(labelRow);
    // Input
    const isMultiline = (opts.maxLines || 2) > 1;
    const inp = isMultiline
      ? el('textarea', {className:'cw-textarea', rows: String(opts.maxLines || 2), placeholder: hint || '', style:`border-color:transparent;background:#1e293b`})
      : el('input', {className:'cw-input', type:'text', placeholder: hint || '', style:`border-color:transparent;background:#1e293b`});
    inp.value = state[stateKey] || '';
    inp.addEventListener('input', () => { state[stateKey] = inp.value; saveState(); });
    inp.addEventListener('focus', () => { inp.style.borderColor = accent; });
    inp.addEventListener('blur', () => { inp.style.borderColor = 'transparent'; });
    wrap.appendChild(inp);
    // Suggestion chips
    if (suggestions && suggestions.length) {
      const chipsWrap = el('div', {style:'display:flex;flex-wrap:wrap;gap:6px;margin-top:6px'});
      suggestions.forEach(sug => {
        const isIn = (state[stateKey] || '').toLowerCase().includes(sug.toLowerCase());
        const chip = el('span', {
          style: `padding:4px 10px;border-radius:16px;font-size:11px;cursor:pointer;border:1px solid ${isIn ? accent+'80' : 'rgba(255,255,255,0.07)'};background:${isIn ? accent+'33' : '#1e293b'};color:${isIn ? accent : 'rgba(255,255,255,0.3)'};transition:all 0.15s`,
        }, sug);
        chip.addEventListener('click', () => {
          if (!isIn) {
            const cur = (state[stateKey] || '').trim();
            state[stateKey] = cur ? cur + ', ' + sug : sug;
            saveState();
            renderStep2_Guided();
          }
        });
        chipsWrap.appendChild(chip);
      });
      wrap.appendChild(chipsWrap);
    }
    return wrap;
  }

  function buildGuidedSection(title, subtitle, icon, children, opts) {
    opts = opts || {};
    const accent = opts.accent || '#5eead4';
    const sectionKey = 'guided_' + title.replace(/\s/g,'_');
    const isOpen = state._open[sectionKey] !== undefined ? state._open[sectionKey] : (opts.defaultOpen || false);
    const sec = el('div', {style:`margin-bottom:16px;border-radius:12px;border:1px solid ${accent}26;background:#162032`});
    // Header
    const header = el('div', {
      style: 'display:flex;align-items:center;gap:10px;padding:14px 16px;cursor:pointer;user-select:none',
    });
    header.appendChild(el('span', {style:`font-size:18px`}, icon));
    const titleCol = el('div', {style:'flex:1'});
    titleCol.appendChild(el('div', {style:'color:#fff;font-size:14px;font-weight:600'}, title));
    titleCol.appendChild(el('div', {style:'color:rgba(255,255,255,0.2);font-size:11px'}, subtitle));
    header.appendChild(titleCol);
    header.appendChild(el('span', {style:`color:${accent};font-size:14px;transition:transform 0.2s`}, isOpen ? '▼' : '▶'));
    header.addEventListener('click', () => {
      state._open[sectionKey] = !isOpen;
      saveState();
      renderStep2_Guided();
    });
    sec.appendChild(header);
    // Content
    if (isOpen) {
      const body = el('div', {style:'padding:0 16px 16px'});
      children.forEach(ch => body.appendChild(ch));
      sec.appendChild(body);
    }
    return sec;
  }

  function renderStep2_Guided() {
    const c = $('#cw-content');
    c.innerHTML = '';
    const wrap = el('div', {style:'max-width:700px;margin:0 auto'});
    wrap.appendChild(el('div', {className:'cw-section-title', style:'font-size:24px;font-weight:700;margin-bottom:6px;color:#5eead4'}, '📝 Guided Character Creator'));
    wrap.appendChild(el('div', {style:'color:rgba(255,255,255,0.5);font-size:13px;margin-bottom:24px'}, "Describe your character — we'll help you flesh them out."));

    // ── "What's your character like?" header ──
    wrap.appendChild(el('div', {style:'font-size:18px;font-weight:600;color:#fff;margin-bottom:4px'}, "What's your character like?"));
    wrap.appendChild(el('div', {style:'color:rgba(255,255,255,0.38);font-size:12px;line-height:1.4;margin-bottom:16px'}, "Don't worry about perfect writing — a few sentences, a scene, bullet points, whatever comes naturally."));

    // ── Name / Age / Sex ──
    const nameSection = el('div', {className:'cw-section', style:'margin-bottom:20px'});
    const nameRow = el('div', {style:'display:flex;gap:12px;flex-wrap:wrap;align-items:flex-end'});
    const nameField = buildField('Character Name *', 'text', 'name', 'e.g. Aria Blackthorn', {style:'flex:2;min-width:200px'});
    nameRow.appendChild(nameField);
    const diceBtn = el('button', {className:'cw-btn cw-btn-secondary cw-btn-sm', style:'height:38px;margin-bottom:0;white-space:nowrap'});
    diceBtn.textContent = state.isRandomizingName ? '⏳ ...' : '🎲 Random';
    diceBtn.disabled = state.isRandomizingName;
    diceBtn.addEventListener('click', randomizeName);
    nameRow.appendChild(diceBtn);
    nameSection.appendChild(nameRow);
    const ageSexRow = el('div', {style:'display:flex;gap:12px;flex-wrap:wrap;margin-top:12px'});
    ageSexRow.appendChild(buildField('Age', 'text', 'age', 'e.g. 24, Ancient, Timeless', {style:'flex:1;min-width:120px'}));
    ageSexRow.appendChild(buildField('Sex', 'text', 'sex', 'e.g. Female, Male, Non-binary', {style:'flex:1;min-width:120px'}));
    nameSection.appendChild(ageSexRow);
    wrap.appendChild(nameSection);

    // ── Collapsible Sections (matching Flutter order) ──
    // 1. Appearance
    wrap.appendChild(buildGuidedSection('Appearance', 'Already described their look above? Skip this.', '👤', [
      buildGuidedField('Build / Body Type', 'guidedAppearance', "Or describe: 'tall and lanky with long legs'", ['Petite', 'Slim', 'Athletic', 'Curvy', 'Muscular', 'Plus-size', 'Tall & Lanky']),
      buildGuidedField('Hair', 'guidedHair', "e.g. 'waist-length silver hair, usually messy'", ['Short', 'Long', 'Flowing', 'Braided', 'Wild', 'Shaved', 'Pixie']),
      buildGuidedField('Distinguishing Features', 'guidedFeatures', "e.g. 'a jagged scar across her left eye, pointed elf ears'", ['Glasses', 'Scars', 'Tattoos', 'Horns', 'Wings', 'Fangs', 'Cat Ears', 'Freckles']),
      buildGuidedField('Race / Species', 'guidedRace', "e.g. 'half-dragon shapeshifter'", ['Human', 'Elf', 'Demon', 'Vampire', 'Beastkin', 'Android', 'Angel', 'Fae']),
    ]));

    // 2. Personality & Vibe
    wrap.appendChild(buildGuidedSection('Personality & Vibe', "What's it like to spend time with them?", '🎭', [
      buildGuidedField('Personality', 'guidedPersonality', "What are they like? e.g. 'Sharp wit, never shows vulnerability, but secretly writes poetry'", ['Sarcastic', 'Gentle', 'Intense', 'Playful', 'Cold', 'Chaotic', 'Nurturing', 'Mysterious']),
      buildGuidedField('How They Talk', 'guidedSpeech', "e.g. 'Formal and old-fashioned' or 'Lots of slang, drops F-bombs'", ['Formal', 'Casual', 'Poetic', 'Blunt', 'Soft-spoken', 'Loud', 'Sarcastic', 'Flirty']),
      buildGuidedField('Secret / Hidden Depth', 'guidedSecret', "What's beneath the surface? e.g. 'Seems cold but is terrified of being alone'", ['Dark past', 'Hidden power', 'Secret identity', 'Tragic loss', 'Forbidden love', 'Dual personality']),
    ]));

    // 3. Backstory
    wrap.appendChild(buildGuidedSection('Backstory', 'Even a sentence helps the AI build a richer history.', '📖', [
      buildGuidedField('Origin / Background', 'guidedOrigin', "e.g. 'Grew up on the streets after her parents disappeared'", ['Orphan', 'Nobility', 'Self-made', 'Military', 'Criminal past', 'Mysterious origins', 'Small-town', 'Royalty']),
      buildGuidedField('Setting / Era', 'guidedSetting', "When and where? e.g. 'Cyberpunk megacity' or 'Medieval fantasy kingdom'", ['Modern', 'Medieval', 'Futuristic', 'Victorian', 'Ancient', 'Post-apocalyptic', 'Urban fantasy']),
      buildGuidedField('Tone', 'guidedTone', "Overall feel? e.g. 'Dark and gritty but with moments of warmth'", ['Dark', 'Wholesome', 'Tragic', 'Comedic', 'Mysterious', 'Heroic', 'Bittersweet']),
    ]));

    // 4. Relationship to {{user}}
    wrap.appendChild(buildGuidedSection('Relationship to {{user}}', 'How do they know {{user}}?', '💫', [
      buildGuidedField('Dynamic', 'guidedRelDynamic', "e.g. 'Coworkers who secretly like each other' or 'She's my bodyguard'", ['Strangers', 'Childhood friends', 'Rivals', 'Roommates', 'Love interest', 'Mentor/Student', 'Exes', 'Online friends']),
      buildGuidedField('Opening Scenario', 'guidedRelScenario', "Where does the story start? e.g. 'First day at a new school'", ['First meeting', 'Reunion', 'Rescue', 'Confrontation', 'Date', 'Mission briefing', 'Accident', 'Summoning', 'Dream']),
    ]));

    // ── NSFW Toggle (after Relationship, matching Flutter) ──
    const nsfwRow = el('div', {style:`display:flex;align-items:center;justify-content:space-between;padding:12px 16px;background:${state.nsfwEnabled?'rgba(244,114,182,0.08)':'#1e293b'};border-radius:12px;border:1px solid ${state.nsfwEnabled?'rgba(244,114,182,0.4)':'rgba(255,255,255,0.12)'};margin-bottom:16px`});
    const nsfwLeft = el('div', {style:'display:flex;align-items:center;gap:8px;flex:1'});
    nsfwLeft.appendChild(el('span', {style:`font-size:16px;color:${state.nsfwEnabled?'#f472b6':'rgba(255,255,255,0.24)'}`}, '🔥'));
    const nsfwInfo = el('div');
    nsfwInfo.appendChild(el('div', {style:`color:${state.nsfwEnabled?'#f9a8d4':'rgba(255,255,255,0.54)'};font-size:13px;font-weight:600`}, 'Enable NSFW Options'));
    nsfwInfo.appendChild(el('div', {style:`color:${state.nsfwEnabled?'rgba(244,114,182,0.5)':'rgba(255,255,255,0.24)'};font-size:10px`}, 'Unlock intimate character details'));
    nsfwLeft.appendChild(nsfwInfo);
    nsfwRow.appendChild(nsfwLeft);
    const toggle = el('label', {className:'toggle-switch', style:'margin:0'});
    const cb = el('input', {type:'checkbox'}); cb.checked = state.nsfwEnabled;
    cb.addEventListener('change', () => { state.nsfwEnabled = cb.checked; saveState(); renderStep2_Guided(); });
    toggle.appendChild(cb); toggle.appendChild(el('span', {className:'toggle-slider'}));
    nsfwRow.appendChild(toggle);
    wrap.appendChild(nsfwRow);

    // 5. NSFW Details (gated)
    if (state.nsfwEnabled) {
      wrap.appendChild(buildGuidedSection('Intimate Details', 'Guided prompts for romantic and sexual traits.', '🔥', [
        buildGuidedField('Body (intimate details)', 'guidedNsfwBody', "Describe specifics if you want: 'modest chest, wide hips, thick thighs'", ['Flat', 'Small', 'Medium', 'Large', 'Huge'], {nsfw: true}),
        buildGuidedField('Experience Level', 'guidedNsfwExp', "How experienced are they? e.g. 'First time, nervous but eager'", ['Innocent', 'Virgin', 'Curious', 'Experienced', 'Insatiable'], {nsfw: true}),
        buildGuidedField('Dominance', 'guidedNsfwDom', "Who takes the lead? e.g. 'Dominant in public, submissive behind closed doors'", ['Submissive', 'Switch', 'Dominant'], {nsfw: true}),
        buildGuidedField('Turn-ons & Kinks', 'guidedNsfwKinks', "What are they into? e.g. 'Loves being praised, goes weak when you grab her hair'", ['Praise', 'Teasing', 'Biting', 'Bondage', 'Exhibitionism', 'Jealousy', 'Breeding'], {nsfw: true}),
        buildGuidedField('Clothing / Aesthetic', 'guidedNsfwClothing', "What do they wear? e.g. 'Always wears thigh-highs and an oversized shirt at home'", ['Revealing', 'Lingerie', 'Uniform', 'Leather', 'Elegant', 'Barely There'], {nsfw: true}),
        buildGuidedField('Sexual Personality', 'guidedNsfwPersonality', "How do they act during intimacy? e.g. 'Giggly and playful, hides her face when embarrassed'", ['Teasing', 'Passionate', 'Tender', 'Aggressive', 'Shy', 'Seductive', 'Playful', 'Romantic'], {nsfw: true}),
      ], {accent: '#f472b6'}));
    }

    // ── Character Vision (after NSFW, matching Flutter) ──
    const visionSec = el('div', {style:'padding:16px;background:rgba(94,234,212,0.04);border-radius:12px;border:1px solid rgba(94,234,212,0.2);margin-bottom:16px'});
    const visionHeader = el('div', {style:'display:flex;align-items:center;gap:8px;margin-bottom:12px'});
    visionHeader.appendChild(el('span', {style:'font-size:18px;color:#5eead4'}, '📝'));
    const visionTitleCol = el('div');
    visionTitleCol.appendChild(el('div', {style:'font-size:16px;font-weight:600;color:#fff'}, 'Your Character Vision'));
    visionTitleCol.appendChild(el('div', {style:'font-size:11px;color:rgba(255,255,255,0.38);margin-top:2px'}, 'Write your idea, or let AI generate a description from the details above.'));
    visionHeader.appendChild(visionTitleCol);
    visionSec.appendChild(visionHeader);
    const phIdx = Math.abs(hashCode(state.name || 'x')) % GUIDED_VISION_PLACEHOLDERS.length;
    const visionTa = el('textarea', {className:'cw-textarea', rows:'6', placeholder: GUIDED_VISION_PLACEHOLDERS[phIdx], style:'border:1px solid rgba(255,255,255,0.12);background:#1e293b'});
    visionTa.value = state.guidedVision || '';
    visionTa.addEventListener('input', () => { state.guidedVision = visionTa.value; saveState(); });
    visionSec.appendChild(visionTa);
    // Scenario seed chips
    const seedWrap = el('div', {style:'display:flex;flex-wrap:wrap;gap:6px;margin-top:8px'});
    SCENARIO_SEEDS.forEach(seed => {
      const isIn = (state.guidedVision || '').toLowerCase().includes(seed.toLowerCase());
      const chip = el('span', {
        style: `padding:4px 10px;border-radius:16px;font-size:11px;cursor:pointer;border:1px solid ${isIn?'rgba(94,234,212,0.5)':'rgba(255,255,255,0.1)'};background:${isIn?'rgba(94,234,212,0.2)':'#1e293b'};color:${isIn?'#5eead4':'rgba(255,255,255,0.38)'}`,
      }, seed);
      chip.addEventListener('click', () => {
        if (!isIn) { const cur = (state.guidedVision||'').trim(); state.guidedVision = cur ? cur + '. ' + seed : seed; saveState(); renderStep2_Guided(); }
      });
      seedWrap.appendChild(chip);
    });
    visionSec.appendChild(seedWrap);
    // Generate Character Description button (right-aligned like Flutter)
    const expandRow = el('div', {style:'display:flex;justify-content:flex-end;margin-top:12px'});
    const expandBtn = el('button', {className:'cw-btn', style:'background:#0d7377;color:#fff;border:none;padding:10px 16px;border-radius:10px;font-size:13px;cursor:pointer'});
    expandBtn.textContent = state.isExpandingNarrative ? '⏳ Generating description...' : '✨ Generate Character Description';
    expandBtn.disabled = state.isExpandingNarrative || !state.name.trim();
    expandBtn.addEventListener('click', expandNarrative);
    expandRow.appendChild(expandBtn);
    visionSec.appendChild(expandRow);
    wrap.appendChild(visionSec);

    // ── Output Settings ──
    wrap.appendChild(buildGuidedSection('Output Settings', 'Greeting style, art style, lorebook, and detail level.', '⚙️', [
      buildSelectField('Generation Detail', ['Brief', 'Standard', 'Detailed', 'Comprehensive'], 'generationDetail'),
      buildSelectField('Art Style', ART_STYLES, 'artStyle'),
      buildSelectField('First Message Length', GREETING_LENGTHS, 'greetingLength'),
      buildSliderField('Alternate Greetings', 0, 5, state.altGreetingCount, v => {
        state.altGreetingCount = v;
        const newMax = v + 1;
        while (state.greetingTones.length > newMax) state.greetingTones.pop();
        saveState();
        renderStep2_Guided();
      }),
      (() => {
        const toneSec = el('div', {style:'margin-top:12px'});
        toneSec.appendChild(el('div', {style:'color:rgba(255,255,255,0.5);font-size:12px;font-weight:500;margin-bottom:4px'}, 'Greeting Tones'));
        const maxTones = state.altGreetingCount + 1;
        toneSec.appendChild(el('div', {style:'color:rgba(255,255,255,0.25);font-size:11px;margin-bottom:8px'},
          state.altGreetingCount === 0
            ? 'Tone for the first message.'
            : `Select up to ${maxTones} — one per greeting.`
        ));
        const toneToggle = (opt, wrap, options, opts) => {
          const arr = state.greetingTones;
          const idx = arr.indexOf(opt);
          if (idx >= 0) {
            if (arr.length > 1) arr.splice(idx, 1);
          } else {
            if (arr.length >= maxTones) arr.splice(arr.length - 1, 1);
            arr.push(opt);
          }
          saveState();
          _renderChipsInto(wrap, options, arr, toneToggle, opts);
        };
        toneSec.appendChild(buildChips('chips-guided-tones', GREETING_TONES, state.greetingTones, toneToggle, {multi:true, nsfwFilter:true}));
        return toneSec;
      })(),
      (() => {
        const loreRow = el('div', {style:'margin-top:8px'});
        const loreToggle = el('div', {style:'display:flex;align-items:center;justify-content:space-between;margin-bottom:8px'});
        loreToggle.appendChild(el('span', {style:'color:rgba(255,255,255,0.5);font-size:12px'}, 'Generate Lorebook'));
        const lt = el('label', {className:'toggle-switch', style:'margin:0'});
        const lcb = el('input', {type:'checkbox'}); lcb.checked = state.generateLorebook;
        lcb.addEventListener('change', () => { state.generateLorebook = lcb.checked; saveState(); });
        lt.appendChild(lcb); lt.appendChild(el('span', {className:'toggle-slider'}));
        loreToggle.appendChild(lt);
        loreRow.appendChild(loreToggle);
        return loreRow;
      })(),
    ], {defaultOpen: false}));

    // ── Navigation ──
    wrap.appendChild(buildNavBtns(
      () => { state.step = 1; saveState(); render(); },
      () => {
        if (!state.name.trim()) { alert('Please enter a character name.'); return; }
        if ((state.guidedVision||'').trim().length < 10) { alert('Please write at least a short character vision (10+ characters).'); return; }
        state.step = 3; saveState(); render(); startGuidedGeneration();
      },
      'Generate Character'
    ));
    c.appendChild(wrap);
  }

  function hashCode(s) { let h = 0; for (let i = 0; i < s.length; i++) { h = ((h << 5) - h) + s.charCodeAt(i); h |= 0; } return h; }

  async function expandNarrative() {
    if (state.isExpandingNarrative) return;
    state.isExpandingNarrative = true; saveState(); renderStep2_Guided();
    try {
      const body = {
        modelId: state.modelId, name: state.name, age: state.age, sex: state.sex,
        guidedVision: state.guidedVision, guidedAppearance: state.guidedAppearance,
        guidedHair: state.guidedHair, guidedFeatures: state.guidedFeatures, guidedRace: state.guidedRace,
        guidedPersonality: state.guidedPersonality, guidedSpeech: state.guidedSpeech, guidedSecret: state.guidedSecret,
        guidedOrigin: state.guidedOrigin, guidedSetting: state.guidedSetting, guidedTone: state.guidedTone,
        guidedRelDynamic: state.guidedRelDynamic, guidedRelScenario: state.guidedRelScenario,
        nsfwEnabled: state.nsfwEnabled,
        guidedNsfwBody: state.guidedNsfwBody, guidedNsfwExp: state.guidedNsfwExp,
        guidedNsfwDom: state.guidedNsfwDom, guidedNsfwKinks: state.guidedNsfwKinks,
        guidedNsfwClothing: state.guidedNsfwClothing, guidedNsfwPersonality: state.guidedNsfwPersonality,
      };
      let rawTokens = '';
      const result = await streamLlmSSE('/api/chargen/expand', body, (token) => { rawTokens += token; });
      if (result && result.expanded) {
        // Show accept/discard modal
        showExpandModal(result.expanded);
      } else {
        alert('Description generation failed: ' + (result?.error || 'No response'));
      }
    } catch(e) {
      alert('Description generation failed: ' + e.message);
    }
    state.isExpandingNarrative = false; saveState(); renderStep2_Guided();
  }

  function showExpandModal(expandedText) {
    // Remove any existing modal
    const existing = document.querySelector('.cw-modal-overlay');
    if (existing) existing.remove();
    const overlay = el('div', {className:'cw-modal-overlay', style:'position:fixed;inset:0;background:rgba(0,0,0,0.7);z-index:9999;display:flex;align-items:center;justify-content:center;padding:20px'});
    const modal = el('div', {style:'background:#1e293b;border-radius:16px;max-width:550px;width:100%;padding:24px;border:1px solid rgba(94,234,212,0.3)'});
    // Title
    const titleRow = el('div', {style:'display:flex;align-items:center;gap:8px;margin-bottom:16px'});
    titleRow.appendChild(el('span', {style:'font-size:20px'}, '✨'));
    titleRow.appendChild(el('span', {style:'color:#fff;font-size:18px;font-weight:600'}, 'Generated Description'));
    modal.appendChild(titleRow);
    modal.appendChild(el('div', {style:'color:rgba(255,255,255,0.3);font-size:12px;margin-bottom:12px'}, 'AI generated this description from your details:'));
    const preview = el('div', {style:'background:#0f172a;padding:14px;border-radius:10px;border:1px solid rgba(94,234,212,0.3);color:rgba(255,255,255,0.7);font-size:13px;line-height:1.5;max-height:300px;overflow-y:auto;user-select:text'});
    preview.textContent = expandedText;
    modal.appendChild(preview);
    modal.appendChild(el('div', {style:'color:rgba(255,255,255,0.15);font-size:11px;margin-top:8px'}, 'This will replace the current vision text. You can edit it after.'));
    // Buttons
    const btnRow = el('div', {style:'display:flex;justify-content:flex-end;gap:12px;margin-top:16px'});
    const discardBtn = el('button', {className:'cw-btn cw-btn-secondary'}, 'Discard');
    discardBtn.addEventListener('click', () => overlay.remove());
    btnRow.appendChild(discardBtn);
    const useBtn = el('button', {className:'cw-btn cw-btn-primary', style:'background:#0d7377'}, 'Use This');
    useBtn.addEventListener('click', () => {
      state.guidedVision = expandedText;
      saveState();
      overlay.remove();
      renderStep2_Guided();
    });
    btnRow.appendChild(useBtn);
    modal.appendChild(btnRow);
    overlay.appendChild(modal);
    overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });
    document.body.appendChild(overlay);
  }

  async function startGuidedGeneration() {
    // Assemble guided fields into enriched concept (mirrors Flutter _startGuidedGeneration)
    const vision = (state.guidedVision || '').trim();
    const conceptParts = [vision];
    const addPart = (key, label) => { const v = (state[key]||'').trim(); if (v) conceptParts.push(label + ': ' + v); };
    addPart('guidedAppearance', 'Physical build');
    addPart('guidedHair', 'Hair');
    addPart('guidedFeatures', 'Distinguishing features');
    addPart('guidedRace', 'Race/Species');
    addPart('guidedPersonality', 'Personality');
    addPart('guidedSpeech', 'Speech style');
    addPart('guidedSecret', 'Hidden depth');
    addPart('guidedOrigin', 'Background');
    addPart('guidedSetting', 'Setting');
    addPart('guidedTone', 'Tone');
    addPart('guidedRelDynamic', 'Relationship to {{user}}');
    addPart('guidedRelScenario', 'Opening scenario');
    if (state.nsfwEnabled) {
      addPart('guidedNsfwBody', 'Intimate body details');
      addPart('guidedNsfwExp', 'Sexual experience');
      addPart('guidedNsfwDom', 'Dominance');
      addPart('guidedNsfwKinks', 'Turn-ons/kinks');
      addPart('guidedNsfwClothing', 'Clothing aesthetic');
      addPart('guidedNsfwPersonality', 'Sexual personality');
    }
    const enrichedConcept = conceptParts.join('. ');

    // Use the existing generation flow with the assembled concept
    state.isGenerating = true; state.genStatus = 'Starting generation...'; state.genPreview = ''; saveState();
    connectChargenSSE();
    startGenStatusPoller();
    const body = {
      name: state.name, concept: enrichedConcept, keywords: (state.guidedPersonality||'').trim(),
      age: state.age, sex: state.sex,
      relationship: (state.guidedRelDynamic||'').trim(),
      greetingLength: state.greetingLength, altGreetingCount: state.altGreetingCount,
      greetingTones: state.greetingTones,
      generateLorebook: state.generateLorebook, loreCategories: state.loreCategories, loreDepth: state.loreDepth,
      nsfwEnabled: state.nsfwEnabled, generationDetail: state.generationDetail,
      backstoryNotes: (state.guidedOrigin||'').trim(), artStyle: state.artStyle, personaId: state.personaId,
      modelId: state.modelId,
      backstoryOrigin: (state.guidedOrigin||'').trim(),
      backstoryTone: (state.guidedTone||'').trim(),
      backstoryEra: (state.guidedSetting||'').trim(),
    };
    const res = await apiJson('/api/chargen/generate', {
      method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(body),
    });
    if (!res || res.error) {
      state.genStatus = 'Error: ' + (res?.error || 'Failed to start generation');
      state.isGenerating = false; saveState(); updateGenUI();
      stopGenStatusPoller();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 2 (Automated): Configure — EXACT Flutter layout order
  // 1. NSFW toggle  2. Archetypes  3. Name  4. Age/Sex
  // 5. Appearance (race,body,hair,skin,features,measurements,NSFW chest/butt)
  // 6. Relationship  7. NSFW Sexual Traits  8. Personality Keywords
  // 9. Backstory  10. Description Detail  11. Description
  // 12. Lorebook  13. Persona  14. Greeting Tones
  // 15. Message Length / Alt Greetings  16. Art Style
  // ═══════════════════════════════════════════════════════════
  function renderStep2_Automated() {
    const c = $('#cw-content');
    c.innerHTML = '';

    c.appendChild(el('div', {className:'cw-page-header'}, 'Bring Your Character to Life'));
    c.appendChild(el('div', {className:'cw-hint', style:'margin-bottom:20px'}, 'Give us a name and a concept — the AI will do the rest. It will generate a complete character card with personality, backstory, dialogue examples, and a custom avatar.'));

    // ── 1. NSFW Toggle ──
    const nsfwSec = el('div', {className:'cw-section cw-nsfw-toggle-section'});
    nsfwSec.appendChild(buildToggleRow('🔞 Enable NSFW Options', state.nsfwEnabled, v => {
      state.nsfwEnabled = v; saveState(); renderStep2_Automated();
    }, 'Unlock spicy appearance & relationship options'));
    c.appendChild(nsfwSec);

    // ── 2. Archetype Quick Start ──
    const archSec = el('div', {className:'cw-section'});
    archSec.appendChild(el('div', {className:'cw-section-title', style:'color:#ffd700'}, '⚡ Quick Start — Archetype Presets'));
    archSec.appendChild(el('div', {className:'cw-hint', style:'margin-bottom:8px'}, 'Tap to auto-fill concept & personality'));
    archSec.appendChild(buildChips('chips-arch', Object.keys(ARCHETYPES), state.selectedArchetype, (opt) => {
      if (state.selectedArchetype === opt) { state.selectedArchetype = ''; }
      else {
        state.selectedArchetype = opt;
        state.concept = ARCHETYPES[opt].concept;
        state.keywords = ARCHETYPES[opt].keywords;
        if (!state.name) state.name = opt;
      }
      saveState(); renderStep2_Automated();
    }, {archetype:true}));
    c.appendChild(archSec);

    // ── 3. Character Name (with randomize button) ──
    const nameSec = el('div', {className:'cw-section'});
    const nameHeader = el('div', {style:'display:flex;align-items:center;gap:8px;margin-bottom:4px'});
    nameHeader.appendChild(el('label', {className:'cw-label', style:'margin:0'}, 'Character Name *'));
    if (state.isRandomizingName) {
      nameHeader.appendChild(el('span', {className:'cw-hint', style:'color:#ffd700'}, '🎲 Generating...'));
    } else {
      const diceBtn = el('button', {className:'cw-btn cw-btn-sm', style:'background:transparent;border:1px solid rgba(255,215,0,0.3);color:#ffd700;padding:2px 8px;border-radius:8px;cursor:pointer;font-size:14px', title:'Generate a random character name'}, '🎲');
      diceBtn.addEventListener('click', randomizeName);
      nameHeader.appendChild(diceBtn);
    }
    nameSec.appendChild(nameHeader);
    const nameInp = el('input', {className:'cw-input', type:'text', placeholder:'e.g. Aria Blackwood, Captain Zara, Luna...'});
    nameInp.value = state.name || '';
    nameInp.addEventListener('input', () => { state.name = nameInp.value; saveState(); });
    nameSec.appendChild(nameInp);
    c.appendChild(nameSec);

    // ── 4. Age / Sex (side by side) ──
    const ageSec = el('div', {className:'cw-section'});
    const ageRow = el('div', {style:'display:flex;gap:12px'});
    ageRow.appendChild(buildField('Age', 'text', 'age', 'e.g. 25, Ancient...', {style:'flex:1'}));
    ageRow.appendChild(buildField('Sex', 'text', 'sex', 'e.g. Female, Male...', {style:'flex:1'}));
    ageSec.appendChild(ageRow);
    c.appendChild(ageSec);

    // ── 5. Character Appearance (boxed section) ──
    c.appendChild(buildCollapsible('sec-appearance', '👁️ Character Appearance <span style="color:rgba(255,255,255,0.2);font-size:10px;margin-left:auto">All optional</span>', body => {
      body.appendChild(el('label', {className:'cw-label'}, 'Race / Species'));
      body.appendChild(buildChips('chips-race', RACE_OPTIONS, state.race, makeSimpleToggle('race')));
      body.appendChild(buildField('Custom', 'text', 'customRace', 'e.g. Kitsune, Arachnid, Void-born...'));
      body.appendChild(el('label', {className:'cw-label'}, 'Body Type'));
      body.appendChild(buildChips('chips-body', BODY_TYPES, state.bodyType, makeSimpleToggle('bodyType')));
      body.appendChild(el('label', {className:'cw-label'}, 'Hair Length'));
      body.appendChild(buildChips('chips-hairlen', HAIR_LENGTHS, state.hairLength, makeSimpleToggle('hairLength')));
      body.appendChild(el('label', {className:'cw-label'}, 'Hair Style'));
      body.appendChild(buildChips('chips-hairstyle', HAIR_STYLES, state.hairStyle, makeSimpleToggle('hairStyle')));
      body.appendChild(el('label', {className:'cw-label'}, 'Skin Tone'));
      body.appendChild(buildChips('chips-skin', SKIN_TONES, state.skinTone, makeSimpleToggle('skinTone')));
      body.appendChild(el('label', {className:'cw-label'}, 'Notable Features'));
      body.appendChild(buildChips('chips-features', NOTABLE_FEATURES, state.notableFeatures, makeMultiToggle('notableFeatures'), {multi:true}));
      body.appendChild(el('hr', {style:'border-color:rgba(255,255,255,0.06);margin:12px 0'}));
      body.appendChild(el('label', {className:'cw-label'}, 'Abs / Core'));
      body.appendChild(buildChips('chips-abs', ABS_CORE, state.absCore, makeSimpleToggle('absCore')));
      body.appendChild(el('label', {className:'cw-label'}, 'Thighs'));
      body.appendChild(buildChips('chips-thighs', THIGHS, state.thighs, makeSimpleToggle('thighs')));
      body.appendChild(el('label', {className:'cw-label'}, 'Hips'));
      body.appendChild(buildChips('chips-hips', HIPS, state.hips, makeSimpleToggle('hips')));
      body.appendChild(el('label', {className:'cw-label'}, 'Shoulders'));
      body.appendChild(buildChips('chips-shoulders', SHOULDERS, state.shoulders, makeSimpleToggle('shoulders')));
      body.appendChild(el('label', {className:'cw-label'}, 'Waist'));
      body.appendChild(buildChips('chips-waist', WAIST, state.waist, makeSimpleToggle('waist')));
      // NSFW body (chest/butt only — inside appearance like Flutter)
      if (state.nsfwEnabled) {
        body.appendChild(el('hr', {style:'border-color:rgba(255,105,180,0.3);margin:12px 0'}));
        body.appendChild(el('label', {className:'cw-label nsfw'}, '🔥 Chest Size'));
        body.appendChild(buildChips('chips-chest', CHEST_SIZES, state.chestSize, makeSimpleToggle('chestSize')));
        body.appendChild(el('label', {className:'cw-label nsfw'}, '🔥 Butt Size'));
        body.appendChild(buildChips('chips-butt', BUTT_SIZES, state.buttSize, makeSimpleToggle('buttSize')));
      }
    }));

    // ── 6. Relationship to {{user}} (multi-select) ──
    const relSec = el('div', {className:'cw-section'});
    relSec.appendChild(el('div', {className:'cw-section-title'}, '💕 Relationship to {{user}}'));
    relSec.appendChild(el('div', {className:'cw-hint', style:'margin-bottom:8px'}, 'Select one or more dynamics'));
    relSec.appendChild(buildChips('chips-rel', RELATIONSHIPS, state.relationship, makeSimpleToggle('relationship'), {nsfwSet: NSFW_RELATIONSHIPS}));
    relSec.appendChild(buildField('Custom Relationship', 'text', 'customRelationship', 'Or type a custom relationship...'));
    c.appendChild(relSec);

    // ── 7. NSFW Sexual Traits (separate boxed section, only when NSFW on) ──
    if (state.nsfwEnabled) {
      c.appendChild(buildCollapsible('sec-nsfw-traits', '🔥 Sexual Traits <span style="color:rgba(255,255,255,0.2);font-size:10px;margin-left:auto">All optional</span>', body => {
        body.appendChild(el('label', {className:'cw-label nsfw'}, 'Experience'));
        body.appendChild(buildChips('chips-exp', EXPERIENCE_OPTS, state.experience, makeSimpleToggle('experience')));
        body.appendChild(el('label', {className:'cw-label nsfw'}, 'Dominance'));
        body.appendChild(buildChips('chips-dom', DOMINANCE_OPTS, state.dominance, makeSimpleToggle('dominance')));
        body.appendChild(el('label', {className:'cw-label nsfw'}, 'Kinks'));
        body.appendChild(buildChips('chips-kinks', KINK_OPTS, state.kinks, makeMultiToggle('kinks'), {multi:true}));
        body.appendChild(buildField('Custom Kinks', 'text', 'customKinks', 'e.g. foot worship, roleplay, praise kink...'));
        body.appendChild(el('label', {className:'cw-label nsfw'}, 'Outfit Vibe'));
        body.appendChild(buildChips('chips-outfit', OUTFIT_VIBES, state.outfitVibe, makeSimpleToggle('outfitVibe')));
      }));
    }

    // ── 8. Personality Keywords ──
    const kwSec = el('div', {className:'cw-section'});
    kwSec.appendChild(buildField('Personality Keywords', 'text', 'keywords', 'e.g. witty, secretive, bookish, brave, loyal...'));
    c.appendChild(kwSec);

    // ── 9. Backstory (boxed) ──
    c.appendChild(buildCollapsible('sec-backstory', '📜 Backstory <span style="color:rgba(255,255,255,0.2);font-size:10px;margin-left:auto">All optional</span>', body => {
      body.appendChild(el('label', {className:'cw-label'}, 'Origin'));
      body.appendChild(buildChips('chips-bsorigin', BACKSTORY_ORIGINS, state.backstoryOrigin, makeSimpleToggle('backstoryOrigin')));
      body.appendChild(el('label', {className:'cw-label'}, 'Tone'));
      body.appendChild(buildChips('chips-bstone', BACKSTORY_TONES, state.backstoryTone, makeSimpleToggle('backstoryTone')));
      body.appendChild(el('label', {className:'cw-label'}, 'Era'));
      body.appendChild(buildChips('chips-bsera', BACKSTORY_ERAS, state.backstoryEra, makeSimpleToggle('backstoryEra')));
      body.appendChild(buildTextareaField('Custom Backstory Notes', 'backstoryNotes', 'e.g. Was betrayed by their order, seeks revenge...'));
    }));

    // ── 10. Description Detail ──
    const detailSec = el('div', {className:'cw-section'});
    detailSec.appendChild(el('div', {className:'cw-section-title'}, '📏 Description Detail'));
    detailSec.appendChild(el('div', {className:'cw-hint', style:'margin-bottom:8px'}, 'Controls how detailed the character description will be'));
    detailSec.appendChild(buildChips('chips-detail', GEN_DETAIL_OPTS, state.generationDetail, makeSimpleToggle('generationDetail')));
    c.appendChild(detailSec);

    // ── 11. Description (locked until AI generates it, like Flutter magic wand) ──
    const descSec = el('div', {className:'cw-section'});
    const descHeader = el('div', {style:'display:flex;align-items:center;gap:8px;margin-bottom:8px'});
    descHeader.appendChild(el('label', {className:'cw-label', style:'margin:0'}, 'Description *'));
    if (state.isDescribing) {
      descHeader.appendChild(el('span', {className:'cw-hint', style:'color:#ffd700'}, '⏳ Generating...'));
    } else {
      const genBtn = el('button', {className:'cw-btn cw-btn-sm', style:'background:linear-gradient(135deg,#ffd700,#ff8c00);color:#000;font-weight:600;border:none;padding:4px 12px;border-radius:8px;cursor:pointer;font-size:12px'}, '✨ Generate Description');
      genBtn.addEventListener('click', generateDescription);
      descHeader.appendChild(genBtn);
    }
    descSec.appendChild(descHeader);
    const descTa = el('textarea', {
      className:'cw-textarea',
      id:'cw-describe-textarea',
      rows:'5',
      placeholder: state.conceptGenerated ? 'Edit the generated description...' : 'Click ✨ Generate Description to create a description from your selections above',
    });
    descTa.value = state.concept || '';
    if (!state.conceptGenerated) {
      descTa.readOnly = true;
      descTa.style.opacity = '0.5';
      descTa.style.cursor = 'not-allowed';
    } else {
      descTa.addEventListener('input', () => { state.concept = descTa.value; saveState(); });
    }
    descSec.appendChild(descTa);
    c.appendChild(descSec);

    // ── 12. Lorebook (boxed, with toggle) ──
    const loreSec = el('div', {className:'cw-section cw-lore-section'});
    loreSec.appendChild(el('div', {className:'cw-section-title'}, '📖 Auto-generate World Lore'));
    loreSec.appendChild(buildToggleRow('Generate Lorebook', state.generateLorebook, v => {
      state.generateLorebook = v; saveState();
      const details = document.getElementById('lore-details');
      if (details) details.style.display = v ? 'block' : 'none';
    }));
    const loreDetails = el('div', {id:'lore-details', style: state.generateLorebook ? 'display:block' : 'display:none'});
    loreDetails.appendChild(el('label', {className:'cw-label', style:'margin-top:8px'}, 'Depth'));
    const LORE_DEPTH_DISPLAY = ['Light (3-4)', 'Standard (5-8)', 'Deep (10-15)'];
    const LORE_DEPTH_MAP = {'Light (3-4)': 'Light', 'Standard (5-8)': 'Standard', 'Deep (10-15)': 'Deep'};
    const currentDepthDisplay = Object.entries(LORE_DEPTH_MAP).find(([k,v]) => v === state.loreDepth)?.[0] || 'Standard (5-8)';
    loreDetails.appendChild(buildChips('chips-loredepth', LORE_DEPTH_DISPLAY, currentDepthDisplay, (opt, wrap, options, opts) => {
      state.loreDepth = LORE_DEPTH_MAP[opt] || 'Standard';
      saveState();
      const newDisplay = opt;
      _renderChipsInto(wrap, options, newDisplay, arguments.callee, opts);
    }));
    loreDetails.appendChild(el('label', {className:'cw-label', style:'margin-top:8px'}, 'Focus areas (optional)'));
    loreDetails.appendChild(buildChips('chips-lorecat', LORE_CATEGORIES, state.loreCategories, makeMultiToggle('loreCategories'), {multi:true}));
    loreSec.appendChild(loreDetails);
    c.appendChild(loreSec);

    // ── 13. User Persona ──
    const persaSec = el('div', {className:'cw-section'});
    persaSec.appendChild(el('div', {className:'cw-section-title'}, '🧑 {{user}} Persona for Greetings'));
    persaSec.appendChild(el('div', {className:'cw-hint', style:'margin-bottom:8px'}, 'Select a persona to tailor greetings, or "None" for public cards.'));
    const personaSel = el('select', {className:'cw-select', style:'width:100%'});
    personaSel.appendChild(el('option', {value:''}, '— None (Blank Slate) —'));
    loadPersonasForSelect(personaSel);
    personaSel.addEventListener('change', () => { state.personaId = personaSel.value; saveState(); });
    persaSec.appendChild(personaSel);
    c.appendChild(persaSec);

    // ── 14. Greeting Tones (with max limit = altGreetingCount + 1) ──
    const toneSec = el('div', {className:'cw-section'});
    toneSec.appendChild(el('div', {className:'cw-section-title'}, '💬 Greeting Tones'));
    const maxTones = state.altGreetingCount + 1;
    toneSec.appendChild(el('div', {className:'cw-hint', style:'margin-bottom:8px'},
      state.altGreetingCount === 0
        ? 'Tone for the first message.'
        : `Select up to ${maxTones} — one per greeting (first message + ${state.altGreetingCount} alternate${state.altGreetingCount === 1 ? '' : 's'}).`
    ));
    // Custom toggle that enforces max limit with swap (matches Flutter)
    const toneToggle = (opt, wrap, options, opts) => {
      const arr = state.greetingTones;
      const idx = arr.indexOf(opt);
      if (idx >= 0) {
        // Deselect — but keep at least 1
        if (arr.length > 1) arr.splice(idx, 1);
      } else {
        // Select — swap if at limit
        if (arr.length >= maxTones) arr.splice(arr.length - 1, 1);
        arr.push(opt);
      }
      saveState();
      _renderChipsInto(wrap, options, arr, toneToggle, opts);
    };
    toneSec.appendChild(buildChips('chips-tones', GREETING_TONES, state.greetingTones, toneToggle, {multi:true, nsfwFilter:true}));
    c.appendChild(toneSec);

    // ── 15. Message Length + Alt Greetings (side by side) ──
    const greetSec = el('div', {className:'cw-section'});
    const greetRow = el('div', {style:'display:flex;gap:16px;flex-wrap:wrap'});
    greetRow.appendChild(buildSelectField('First Message Length', GREETING_LENGTHS, 'greetingLength', {style:'flex:1;min-width:200px'}));
    greetRow.appendChild(buildSliderField('Alternate Greetings', 0, 5, state.altGreetingCount, v => {
      state.altGreetingCount = v;
      // Trim excess tones to new max (like Flutter)
      const newMax = v + 1;
      while (state.greetingTones.length > newMax) state.greetingTones.pop();
      saveState();
      renderStep2_Automated(); // Re-render to update hint text and chips
    }));
    greetSec.appendChild(greetRow);
    c.appendChild(greetSec);

    // ── 16. Avatar Art Style (last, like Flutter) ──
    const artSec = el('div', {className:'cw-section'});
    artSec.appendChild(el('div', {className:'cw-section-title'}, '🎨 Avatar Art Style'));
    artSec.appendChild(buildChips('chips-artstyle', ART_STYLES, state.artStyle, makeSimpleToggle('artStyle')));
    c.appendChild(artSec);

    // Navigation
    c.appendChild(buildNavBtns(
      () => { state.step = 1; saveState(); render(); },
      () => {
        if (!state.name.trim()) { alert('Please enter a character name.'); return; }
        state.step = 3; saveState(); render(); startGeneration();
      },
      'Generate ✨'
    ));
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 2: Generating
  // ═══════════════════════════════════════════════════════════
  function renderStep3() {
    const c = $('#cw-content');
    c.innerHTML = '';
    const wrap = el('div', {className:'cw-gen-wrap'});
    wrap.appendChild(el('div', {className:'cw-gen-status', id:'cw-gen-status'}, state.genStatus || 'Starting generation...'));
    const progressBar = el('div', {className:'cw-gen-progress'});
    progressBar.appendChild(el('div', {className:'cw-gen-progress-fill', id:'cw-gen-progress-fill'}));
    wrap.appendChild(progressBar);
    wrap.appendChild(el('div', {className:'cw-gen-preview', id:'cw-gen-preview'}, state.genPreview || 'Waiting for AI response...'));
    const cancelBtn = el('button', {className:'cw-btn cw-btn-danger', style:'margin-top:20px'}, 'Cancel');
    cancelBtn.addEventListener('click', () => { disconnectChargenSSE(); stopGenStatusPoller(); state.step = 2; state.isGenerating = false; saveState(); render(); });
    wrap.appendChild(cancelBtn);
    c.appendChild(wrap);
  }

  async function startGeneration() {
    state.isGenerating = true; state.genStatus = 'Starting generation...'; state.genPreview = ''; saveState();
    connectChargenSSE();
    startGenStatusPoller(); // Polling fallback in case SSE drops
    const body = {
      name: state.name, concept: state.concept, keywords: state.keywords,
      age: state.age, sex: state.sex,
      relationship: state.customRelationship || state.relationship,
      greetingLength: state.greetingLength, altGreetingCount: state.altGreetingCount,
      greetingTones: state.greetingTones,
      generateLorebook: state.generateLorebook, loreCategories: state.loreCategories, loreDepth: state.loreDepth,
      nsfwEnabled: state.nsfwEnabled, generationDetail: state.generationDetail,
      backstoryNotes: state.backstoryNotes, artStyle: state.artStyle, personaId: state.personaId,
      modelId: state.modelId,
      race: state.race, customRace: state.customRace, bodyType: state.bodyType,
      hairLength: state.hairLength, hairStyle: state.hairStyle, skinTone: state.skinTone,
      notableFeatures: state.notableFeatures, absCore: state.absCore,
      thighs: state.thighs, hips: state.hips, shoulders: state.shoulders, waist: state.waist,
      chestSize: state.chestSize, buttSize: state.buttSize, experience: state.experience,
      dominance: state.dominance, kinks: state.kinks, customKinks: state.customKinks, outfitVibe: state.outfitVibe,
      backstoryOrigin: state.backstoryOrigin, backstoryTone: state.backstoryTone, backstoryEra: state.backstoryEra,
    };
    const res = await apiJson('/api/chargen/generate', {
      method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(body),
    });
    if (!res || res.error) {
      state.genStatus = 'Error: ' + (res?.error || 'Failed to start generation');
      state.isGenerating = false; saveState(); updateGenUI();
      stopGenStatusPoller();
    }
  }

  let _genPollTimer = null;
  function startGenStatusPoller() {
    stopGenStatusPoller();
    _genPollTimer = setInterval(async () => {
      if (!state.isGenerating) { stopGenStatusPoller(); return; }
      try {
        const data = await apiJson('/api/chargen/status');
        if (!data) return;

        // Update status and preview
        if (data.status && data.status !== state.genStatus) {
          state.genStatus = data.status; saveState(); updateGenUI();
        }
        if (data.preview && data.preview !== state.genPreview) {
          state.genPreview = data.preview; saveState(); updateGenUI();
        }

        // Handle completion
        if (data.complete && data.card) {
          console.log('[chargen] Poll detected completion!');
          state.generatedCard = data.card;
          state.imagePrompt = data.card.imagePrompt || '';
          state.avatarBase64 = '';
          state.lorebookEnabled = {};
          if (data.card.lorebook) data.card.lorebook.forEach((e,i) => { state.lorebookEnabled[i] = e.enabled !== false; });
          state.isGenerating = false; state.step = 4;
          saveState(); disconnectChargenSSE(); stopGenStatusPoller(); render();
          // Auto-start avatar generation
          setTimeout(() => tryAutoAvatar(), 500);
          return;
        }

        // Handle error
        if (data.error && !data.isGenerating) {
          state.genStatus = '❌ ' + data.error;
          state.isGenerating = false; saveState(); updateGenUI();
          stopGenStatusPoller();
          return;
        }
      } catch(e) {
        console.warn('[chargen] Poll error:', e);
      }
    }, 2000);
  }
  function stopGenStatusPoller() {
    if (_genPollTimer) { clearInterval(_genPollTimer); _genPollTimer = null; }
  }

  function connectChargenSSE() {
    disconnectChargenSSE();
    const token = sessionStorage.getItem('fp_token') || '';
    sseSource = new EventSource('/api/chargen/stream?token=' + encodeURIComponent(token));
    sseSource.onopen = () => { console.log('[chargen] SSE connected, readyState:', sseSource.readyState); };
    sseSource.onmessage = (evt) => {
      console.log('[chargen] SSE event received:', evt.data.substring(0, 120));
      try {
        const data = JSON.parse(evt.data);
        switch (data.event) {
          case 'status': state.genStatus = data.text; saveState(); updateGenUI(); break;
          case 'preview': state.genPreview = data.text; saveState(); updateGenUI(); break;
          case 'complete':
            state.generatedCard = data.card;
            state.imagePrompt = data.card.imagePrompt || '';
            state.avatarBase64 = '';
            state.lorebookEnabled = {};
            if (data.card.lorebook) data.card.lorebook.forEach((e,i) => { state.lorebookEnabled[i] = e.enabled !== false; });
            state.isGenerating = false; state.step = 4;
            saveState(); disconnectChargenSSE(); render();
            // Auto-start avatar generation
            setTimeout(() => tryAutoAvatar(), 500);
            break;
          case 'error':
            state.genStatus = '❌ ' + data.text;
            state.isGenerating = false; saveState(); updateGenUI();
            break;
          default:
            console.log('[chargen] SSE unknown event type:', data.event);
        }
      } catch(e) { console.error('[chargen] SSE parse error', e, 'raw:', evt.data); }
    };
    sseSource.onerror = (e) => { console.warn('[chargen] SSE error, readyState:', sseSource?.readyState, e); };
  }
  function disconnectChargenSSE() { if (sseSource) { sseSource.close(); sseSource = null; } }
  function updateGenUI() {
    const statusEl = document.getElementById('cw-gen-status');
    const previewEl = document.getElementById('cw-gen-preview');
    if (statusEl) statusEl.textContent = state.genStatus;
    if (previewEl) previewEl.textContent = state.genPreview || 'Waiting for AI response...';
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 4: Realism Engine
  // ═══════════════════════════════════════════════════════════

  const REALISM_TIME_OPTIONS = ['dawn','morning','late_morning','afternoon','evening','night'];
  const REALISM_INTENSITY_OPTIONS = ['mild','moderate','strong'];

  function _formatTimeLabel(v) { return v.split('_').map(w => w[0].toUpperCase() + w.slice(1)).join(' '); }
  function _shortTermTierName(s) { if(s>=80) return 'Devoted'; if(s>=50) return 'Affectionate'; if(s>=20) return 'Warm'; if(s>=5) return 'Friendly'; if(s>=-4) return 'Neutral'; if(s>=-19) return 'Cool'; if(s>=-49) return 'Distant'; if(s>=-79) return 'Hostile'; return 'Despised'; }
  function _longTermTierName(s) { if(s>=80) return 'Soulbound'; if(s>=50) return 'Deep Bond'; if(s>=20) return 'Close'; if(s>=5) return 'Familiar'; if(s>=-4) return 'Acquaintance'; if(s>=-19) return 'Uneasy'; if(s>=-49) return 'Estranged'; if(s>=-79) return 'Broken'; return 'Nemesis'; }
  function _trustLevelName(l) { if(l>=80) return 'Absolute Trust'; if(l>=50) return 'Deep Trust'; if(l>=20) return 'Trusting'; if(l>=5) return 'Cautious Trust'; if(l>=-4) return 'Neutral'; if(l>=-19) return 'Wary'; if(l>=-49) return 'Suspicious'; if(l>=-79) return 'Paranoid'; return 'Absolute Distrust'; }
  function _bondColor(s) { if(s>=20) return '#4ade80'; if(s>=0) return '#60a5fa'; if(s>=-19) return '#fb923c'; return '#f87171'; }
  function _trustColor(l) { if(l>=20) return '#2dd4bf'; if(l>=0) return '#60a5fa'; if(l>=-19) return '#fb923c'; return '#f87171'; }

  function _buildRealismSlider(label, value, min, max, tierName, color, onChange) {
    const wrap = el('div', {style:'margin-bottom:16px'});
    const row = el('div', {style:'display:flex;align-items:center;justify-content:space-between;margin-bottom:4px'});
    row.appendChild(el('span', {style:'color:rgba(255,255,255,0.7);font-size:12px;font-weight:500'}, label));
    const badge = el('span', {style:`padding:2px 8px;border-radius:6px;font-size:11px;font-weight:600;background:${color}26;color:${color}`}, `${tierName} (${value})`);
    row.appendChild(badge);
    wrap.appendChild(row);
    const slider = el('input', {type:'range', min:String(min), max:String(max), step:'1', style:`width:100%;accent-color:${color}`});
    slider.value = value;
    slider.addEventListener('input', () => onChange(parseInt(slider.value)));
    wrap.appendChild(slider);
    return wrap;
  }

  function renderStep4_Realism() {
    const c = $('#cw-content');
    c.innerHTML = '';

    if (!state.generatedCard) {
      // Error state
      const errWrap = el('div', {style:'text-align:center;padding:64px 24px'});
      errWrap.appendChild(el('div', {style:'font-size:64px;margin-bottom:16px'}, '❌'));
      errWrap.appendChild(el('div', {style:'color:rgba(255,255,255,0.7);font-size:16px;margin-bottom:24px'}, 'Generation failed. The LLM did not produce valid output.'));
      const retryBtn = el('button', {className:'cw-btn cw-btn-primary'}, '← Try Again');
      retryBtn.addEventListener('click', () => { state.step = 2; state.genPreview = ''; saveState(); render(); });
      errWrap.appendChild(retryBtn);
      c.appendChild(errWrap);
      return;
    }

    const wrap = el('div', {style:'max-width:700px;margin:0 auto;padding:0 16px'});
    wrap.appendChild(el('div', {style:'font-size:28px;font-weight:700;color:#fff;margin-bottom:8px'}, 'Realism Engine'));
    wrap.appendChild(el('div', {style:'font-size:14px;color:rgba(255,255,255,0.5);line-height:1.5;margin-bottom:32px'}, 'Set the initial state for the Realism Engine when a new conversation starts. These values will seed the relationship, emotion, and time-of-day systems.'));

    // ── Master Toggle ──
    const toggleCard = el('div', {style:`padding:16px;border-radius:16px;background:#1e293b;border:1px solid ${state.realismEnabled ? 'rgba(59,130,246,0.4)' : 'rgba(255,255,255,0.08)'};margin-bottom:20px`});
    const toggleRow = el('div', {style:'display:flex;align-items:center;gap:12px'});
    const iconBox = el('div', {style:`width:44px;height:44px;border-radius:12px;background:${state.realismEnabled ? 'rgba(59,130,246,0.2)' : 'rgba(255,255,255,0.05)'};display:flex;align-items:center;justify-content:center;font-size:24px`}, '🧠');
    toggleRow.appendChild(iconBox);
    const toggleInfo = el('div', {style:'flex:1'});
    toggleInfo.appendChild(el('div', {style:'color:#fff;font-size:16px;font-weight:600'}, 'Enable Realism Engine'));
    toggleInfo.appendChild(el('div', {style:`color:${state.realismEnabled ? '#60a5fa' : 'rgba(255,255,255,0.38)'};font-size:12px`}, state.realismEnabled ? 'Character will start with pre-configured state' : 'Realism Engine will use default values'));
    toggleRow.appendChild(toggleInfo);
    const toggle = el('label', {className:'toggle-switch'});
    const toggleInput = el('input', {type:'checkbox'});
    toggleInput.checked = state.realismEnabled;
    toggleInput.addEventListener('change', () => { state.realismEnabled = toggleInput.checked; saveState(); renderStep4_Realism(); });
    toggle.appendChild(toggleInput);
    toggle.appendChild(el('span', {className:'toggle-slider'}));
    toggleRow.appendChild(toggle);
    toggleCard.appendChild(toggleRow);
    wrap.appendChild(toggleCard);

    if (state.realismEnabled) {
      // ── Time & Day ──
      const timeSec = el('div', {style:'margin-bottom:20px'});
      const timeHeader = el('div', {style:'display:flex;align-items:center;gap:8px;margin-bottom:12px'});
      timeHeader.appendChild(el('span', {style:'color:#fbbf24;font-size:18px'}, '⏰'));
      timeHeader.appendChild(el('span', {style:'color:#fbbf24;font-size:15px;font-weight:600'}, 'Time & Day'));
      timeSec.appendChild(timeHeader);
      const timeCard = el('div', {style:'padding:16px;background:#1e293b;border-radius:14px;border:1px solid rgba(255,255,255,0.08)'});
      const timeRow = el('div', {style:'display:flex;gap:16px'});
      // Time dropdown
      const timeCol = el('div', {style:'flex:2'});
      timeCol.appendChild(el('div', {style:'color:rgba(255,255,255,0.7);font-size:12px;font-weight:500;margin-bottom:8px'}, 'Time of Day'));
      const timeSel = el('select', {style:'width:100%;padding:8px 12px;background:#0f172a;border:1px solid rgba(255,255,255,0.08);border-radius:10px;color:#fff;font-size:14px'});
      REALISM_TIME_OPTIONS.forEach(t => {
        const opt = el('option', {value:t}, _formatTimeLabel(t));
        if (t === state.realismTimeOfDay) opt.selected = true;
        timeSel.appendChild(opt);
      });
      timeSel.addEventListener('change', () => { state.realismTimeOfDay = timeSel.value; saveState(); });
      timeCol.appendChild(timeSel);
      timeRow.appendChild(timeCol);
      // Day number
      const dayCol = el('div', {style:'flex:1'});
      dayCol.appendChild(el('div', {style:'color:rgba(255,255,255,0.7);font-size:12px;font-weight:500;margin-bottom:8px'}, 'Day Number'));
      const dayInp = el('input', {type:'number', min:'1', style:'width:100%;padding:8px 12px;background:#0f172a;border:1px solid rgba(255,255,255,0.08);border-radius:10px;color:#fff;font-size:14px'});
      dayInp.value = state.realismDayCount;
      dayInp.addEventListener('input', () => { const n = parseInt(dayInp.value); if (n >= 1) { state.realismDayCount = n; saveState(); } });
      dayCol.appendChild(dayInp);
      timeRow.appendChild(dayCol);
      timeCard.appendChild(timeRow);
      timeSec.appendChild(timeCard);
      wrap.appendChild(timeSec);

      // ── Relationship ──
      const relSec = el('div', {style:'margin-bottom:20px'});
      const relHeader = el('div', {style:'display:flex;align-items:center;gap:8px;margin-bottom:12px'});
      relHeader.appendChild(el('span', {style:'color:#ec4899;font-size:18px'}, '❤️'));
      relHeader.appendChild(el('span', {style:'color:#ec4899;font-size:15px;font-weight:600'}, 'Relationship'));
      relSec.appendChild(relHeader);
      const relCard = el('div', {style:'padding:16px;background:#1e293b;border-radius:14px;border:1px solid rgba(255,255,255,0.08)'});
      relCard.appendChild(_buildRealismSlider('Short-Term Bond', state.realismShortTermBond, -150, 150, _shortTermTierName(state.realismShortTermBond), _bondColor(state.realismShortTermBond), v => { state.realismShortTermBond = v; saveState(); renderStep4_Realism(); }));
      relCard.appendChild(_buildRealismSlider('Long-Term Bond', state.realismLongTermBond, -150, 150, _longTermTierName(state.realismLongTermBond), _bondColor(state.realismLongTermBond), v => { state.realismLongTermBond = v; saveState(); renderStep4_Realism(); }));
      relCard.appendChild(_buildRealismSlider('Trust Level', state.realismTrustLevel, -100, 100, _trustLevelName(state.realismTrustLevel), _trustColor(state.realismTrustLevel), v => { state.realismTrustLevel = v; saveState(); renderStep4_Realism(); }));
      relSec.appendChild(relCard);
      wrap.appendChild(relSec);

      // ── Emotion ──
      const emoSec = el('div', {style:'margin-bottom:20px'});
      const emoHeader = el('div', {style:'display:flex;align-items:center;gap:8px;margin-bottom:12px'});
      emoHeader.appendChild(el('span', {style:'color:#a855f7;font-size:18px'}, '😊'));
      emoHeader.appendChild(el('span', {style:'color:#a855f7;font-size:15px;font-weight:600'}, 'Starting Emotion'));
      emoSec.appendChild(emoHeader);
      const emoCard = el('div', {style:'padding:16px;background:#1e293b;border-radius:14px;border:1px solid rgba(255,255,255,0.08)'});
      const emoRow = el('div', {style:'display:flex;gap:16px'});
      const emoCol = el('div', {style:'flex:2'});
      emoCol.appendChild(el('div', {style:'color:rgba(255,255,255,0.7);font-size:12px;font-weight:500;margin-bottom:8px'}, 'Emotion'));
      const emoInp = el('input', {type:'text', placeholder:'e.g. curious, guarded, amused', style:'width:100%;padding:8px 12px;background:#0f172a;border:1px solid rgba(255,255,255,0.08);border-radius:10px;color:#fff;font-size:14px'});
      emoInp.value = state.realismEmotion;
      emoInp.addEventListener('input', () => { state.realismEmotion = emoInp.value; saveState(); });
      emoCol.appendChild(emoInp);
      emoRow.appendChild(emoCol);
      const intCol = el('div', {style:'flex:1'});
      intCol.appendChild(el('div', {style:'color:rgba(255,255,255,0.7);font-size:12px;font-weight:500;margin-bottom:8px'}, 'Intensity'));
      const intSel = el('select', {style:'width:100%;padding:8px 12px;background:#0f172a;border:1px solid rgba(255,255,255,0.08);border-radius:10px;color:#fff;font-size:14px'});
      REALISM_INTENSITY_OPTIONS.forEach(i => {
        const opt = el('option', {value:i}, i[0].toUpperCase() + i.slice(1));
        if (i === state.realismEmotionIntensity) opt.selected = true;
        intSel.appendChild(opt);
      });
      intSel.addEventListener('change', () => { state.realismEmotionIntensity = intSel.value; saveState(); });
      intCol.appendChild(intSel);
      emoRow.appendChild(intCol);
      emoCard.appendChild(emoRow);
      emoSec.appendChild(emoCard);
      wrap.appendChild(emoSec);

      // ── Optional Toggles ──
      const optSec = el('div', {style:'margin-bottom:20px'});
      const optHeader = el('div', {style:'display:flex;align-items:center;gap:8px;margin-bottom:12px'});
      optHeader.appendChild(el('span', {style:'color:#2dd4bf;font-size:18px'}, '🎛️'));
      optHeader.appendChild(el('span', {style:'color:#2dd4bf;font-size:15px;font-weight:600'}, 'Optional Features'));
      optSec.appendChild(optHeader);
      const optCard = el('div', {style:'padding:16px;background:#1e293b;border-radius:14px;border:1px solid rgba(255,255,255,0.08)'});
      optCard.appendChild(buildToggleRow('🌡️ NSFW Cooldown System', state.realismNsfwCooldown, v => { state.realismNsfwCooldown = v; saveState(); }, 'Realistic arousal/refractory mechanics'));
      optCard.appendChild(el('hr', {style:'border-color:rgba(255,255,255,0.06);margin:12px 0'}));
      optCard.appendChild(buildToggleRow('🎲 Chaos Mode (Chance Time)', state.realismChaosMode, v => { state.realismChaosMode = v; saveState(); }, 'Random narrative events during roleplay'));
      optSec.appendChild(optCard);
      wrap.appendChild(optSec);
    }

    // Navigation
    const nav = el('div', {style:'display:flex;justify-content:center;gap:16px;margin-top:32px;padding-bottom:32px'});
    const backBtn = el('button', {className:'cw-btn cw-btn-secondary', style:'height:52px;padding:0 24px'}, '← Back');
    backBtn.addEventListener('click', () => { state.step = 3; saveState(); render(); });
    nav.appendChild(backBtn);
    const nextBtn = el('button', {className:'cw-btn cw-btn-primary', style:'height:52px;min-width:280px'}, 'Next: Review & Save →');
    nextBtn.addEventListener('click', () => { state.step = 5; saveState(); render(); });
    nav.appendChild(nextBtn);
    wrap.appendChild(nav);
    c.appendChild(wrap);
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 5: Review
  // ═══════════════════════════════════════════════════════════
  function renderStep5() {
    const c = $('#cw-content');
    c.innerHTML = '';
    const card = state.generatedCard;
    if (!card) { c.textContent = 'No generated card found.'; return; }
    const review = el('div', {className:'cw-review'});

    // Left column
    const left = el('div', {className:'cw-review-left'});
    const avatarBox = el('div', {className:'cw-avatar-box', id:'cw-avatar-box'});
    if (state.avatarBase64) {
      avatarBox.appendChild(el('img', {src:'data:image/png;base64,' + state.avatarBase64}));
    } else {
      const ph = el('div', {className:'cw-avatar-placeholder'});
      ph.innerHTML = '<svg viewBox="0 0 24 24" width="48" height="48" fill="currentColor"><path d="M21 19V5c0-1.1-.9-2-2-2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2zM8.5 13.5l2.5 3.01L14.5 12l4.5 6H5l3.5-4.5z"/></svg><br>No avatar generated';
      avatarBox.appendChild(ph);
    }
    left.appendChild(avatarBox);
    const avatarBtn = el('button', {className:'cw-btn cw-btn-secondary cw-btn-sm', style:'width:100%;margin-bottom:8px'}, state.avatarBase64 ? '🔄 Regenerate Avatar' : '🎨 Generate Avatar');
    avatarBtn.addEventListener('click', generateAvatar);
    left.appendChild(avatarBtn);
    left.appendChild(el('label', {className:'cw-label'}, 'Image Prompt'));
    const imgTa = el('textarea', {className:'cw-textarea', rows:'3', style:'font-size:11px'});
    imgTa.value = state.imagePrompt;
    imgTa.addEventListener('input', () => { state.imagePrompt = imgTa.value; saveState(); });
    left.appendChild(imgTa);
    left.appendChild(el('div', {className:'cw-review-name'}, card.name));
    if (card.tags && card.tags.length) {
      const tagsWrap = el('div', {className:'cw-review-tags'});
      card.tags.forEach(t => tagsWrap.appendChild(el('span', {className:'tag-pill'}, t)));
      left.appendChild(tagsWrap);
    }
    const saveBtn = el('button', {className:'cw-btn cw-btn-success', style:'width:100%;margin-top:12px'}, '💾 Save Character');
    saveBtn.addEventListener('click', saveCharacter);
    left.appendChild(saveBtn);
    const exportBtn = el('button', {className:'cw-btn cw-btn-secondary', style:'width:100%;margin-top:8px'}, '📥 Export PNG');
    exportBtn.addEventListener('click', exportCharacterPng);
    left.appendChild(exportBtn);
    const restartBtn = el('button', {className:'cw-btn cw-btn-danger', style:'width:100%;margin-top:8px'}, '🔄 Start Over');
    restartBtn.addEventListener('click', () => { resetState(); render(); });
    left.appendChild(restartBtn);
    review.appendChild(left);

    // Right column
    const right = el('div', {className:'cw-review-right'});
    right.appendChild(buildEditField('Description', 'description', card.description));
    right.appendChild(buildEditField('Personality', 'personality', card.personality));
    right.appendChild(buildEditField('Scenario', 'scenario', card.scenario));
    right.appendChild(buildEditField('First Message', 'firstMessage', card.firstMessage, 6));
    right.appendChild(buildEditField('Example Dialogue', 'mesExample', card.mesExample || '', 3));
    // System Prompt is intentionally omitted — left blank for characters generated
    // by the AI pipeline (matches Flutter app behavior since v0.9.5+).
    if (card.alternateGreetings && card.alternateGreetings.length) {
      const altSec = el('div', {className:'cw-section', style:'margin-top:16px'});
      altSec.appendChild(el('div', {className:'cw-section-title'}, `Alternate Greetings (${card.alternateGreetings.length})`));
      card.alternateGreetings.forEach((g, i) => {
        altSec.appendChild(buildEditField(`Alt Greeting ${i+1}`, `altGreeting_${i}`, g, 4, (v) => {
          state.generatedCard.alternateGreetings[i] = v; saveState();
        }));
      });
      right.appendChild(altSec);
    }
    if (card.lorebook && card.lorebook.length) {
      const loreSec = el('div', {className:'cw-section', style:'margin-top:16px'});
      loreSec.appendChild(el('div', {className:'cw-section-title'}, `📖 Lorebook Entries (${card.lorebook.length})`));
      card.lorebook.forEach((entry, i) => {
        const enabled = state.lorebookEnabled[i] !== false;
        const card2 = el('div', {className:'cw-lore-entry' + (enabled?'':' disabled')});
        const cb = el('input', {type:'checkbox'});
        cb.checked = enabled;
        cb.addEventListener('change', () => { state.lorebookEnabled[i] = cb.checked; saveState(); renderStep5(); });
        card2.appendChild(cb);
        const info = el('div', {style:'flex:1;min-width:0'});
        info.appendChild(el('div', {className:'cw-lore-name'}, entry.name || 'Untitled'));
        info.appendChild(el('div', {className:'cw-lore-keys'}, '🔑 ' + (entry.key || '')));
        info.appendChild(el('div', {className:'cw-lore-content'}, entry.content || ''));
        card2.appendChild(info);
        loreSec.appendChild(card2);
      });
      right.appendChild(loreSec);
    }
    review.appendChild(right);
    c.appendChild(review);
  }

  async function generateAvatar() {
    if (!state.imagePrompt) { alert('Please enter an image prompt first.'); return; }
    const btn = document.querySelector('#cw-content .cw-review-left .cw-btn-secondary');
    if (btn) { btn.textContent = '⏳ Generating...'; btn.disabled = true; }
    const res = await apiJson('/api/chargen/avatar', {
      method: 'POST', headers: {'Content-Type':'application/json'},
      body: JSON.stringify({ prompt: state.imagePrompt }),
    });
    if (res && res.image) { state.avatarBase64 = res.image; saveState(); renderStep5(); }
    else {
      // Show friendly inline message instead of ugly alert
      const avatarBox = document.querySelector('#cw-avatar-box');
      if (avatarBox) {
        avatarBox.innerHTML = `<div style="padding:16px;text-align:center;color:var(--text-muted);font-size:12px">
          <p style="margin:0 0 8px">⚠️ Image generation not available</p>
          <p style="margin:0 0 12px;font-size:11px;opacity:0.7">Copy the prompt below and use your preferred image generator</p>
          <button class="cw-btn cw-btn-secondary cw-btn-sm" onclick="navigator.clipboard.writeText(document.querySelector('#cw-content textarea').value);this.textContent='✅ Copied!'">📋 Copy Prompt</button>
        </div>`;
      }
      if (btn) { btn.textContent = '🎨 Generate Avatar'; btn.disabled = false; }
    }
  }

  /** Auto-avatar wrapper: silently skips if image gen isn't configured (KoboldCpp / no API key). */
  async function tryAutoAvatar() {
    // Quick probe: try generating. If 503, just skip silently — the prompt is visible for manual use.
    if (!state.imagePrompt) return;
    const res = await apiJson('/api/chargen/avatar', {
      method: 'POST', headers: {'Content-Type':'application/json'},
      body: JSON.stringify({ prompt: state.imagePrompt }),
    });
    if (res && res.image) { state.avatarBase64 = res.image; saveState(); renderStep5(); }
    // On failure: silently do nothing — user can see the prompt and generate manually
  }

  /** Export the current character card as a PNG with embedded V2 character data.
   *  Uses the standard SillyTavern-compatible format: tEXt chunk with keyword 'chara'. */
  async function exportCharacterPng() {
    const card = state.generatedCard;
    if (!card) { alert('No character to export.'); return; }

    // Build V2 character card JSON (SillyTavern compatible)
    const v2Card = {
      spec: 'chara_card_v2',
      spec_version: '2.0',
      data: {
        name: card.name || '',
        description: card.description || '',
        personality: card.personality || '',
        scenario: card.scenario || '',
        first_mes: card.firstMessage || '',
        mes_example: card.mesExample || '',
        system_prompt: card.systemPrompt || '',
        post_history_instructions: '',
        alternate_greetings: card.alternateGreetings || [],
        tags: card.tags || [],
        creator: 'Front Porch AI',
        creator_notes: '',
        character_version: '1.0',
        extensions: {},
      },
    };
    // Add V2.5 Front Porch extensions
    if (state.realismEnabled) {
      v2Card.data.extensions.front_porch = {
        realism_enabled: state.realismEnabled,
        short_term_bond: state.realismShortTermBond,
        long_term_bond: state.realismLongTermBond,
        trust_level: state.realismTrustLevel,
        day_count: state.realismDayCount,
        time_of_day: state.realismTimeOfDay,
        character_emotion: state.realismEmotion,
        emotion_intensity: state.realismEmotionIntensity,
        nsfw_cooldown_enabled: state.realismNsfwCooldown,
        chaos_mode_enabled: state.realismChaosMode,
      };
    }
    // Add lorebook if present
    if (card.lorebook && card.lorebook.length) {
      v2Card.data.character_book = {
        entries: card.lorebook.map((e, i) => ({
          keys: (e.key || '').split(',').map(k => k.trim()),
          content: e.content || '',
          extensions: {},
          enabled: e.enabled !== false,
          insertion_order: i,
          name: e.name || '',
          priority: 10,
          id: i,
          comment: '',
          selective: false,
          secondary_keys: [],
          constant: false,
          position: 'before_char',
        })),
      };
    }

    const charaJson = JSON.stringify(v2Card);
    const charaB64 = btoa(unescape(encodeURIComponent(charaJson)));

    // Get the avatar PNG bytes, or create a placeholder
    let pngBytes;
    if (state.avatarBase64) {
      // Decode existing avatar base64 to bytes
      const raw = atob(state.avatarBase64);
      pngBytes = new Uint8Array(raw.length);
      for (let i = 0; i < raw.length; i++) pngBytes[i] = raw.charCodeAt(i);
    } else {
      // Create a 256x256 placeholder PNG via canvas
      const canvas = document.createElement('canvas');
      canvas.width = 256; canvas.height = 256;
      const ctx = canvas.getContext('2d');
      ctx.fillStyle = '#2a2a3a';
      ctx.fillRect(0, 0, 256, 256);
      ctx.fillStyle = '#ffffff';
      ctx.font = 'bold 20px sans-serif';
      ctx.textAlign = 'center';
      ctx.fillText(card.name || 'Character', 128, 128);
      const dataUrl = canvas.toDataURL('image/png');
      const raw = atob(dataUrl.split(',')[1]);
      pngBytes = new Uint8Array(raw.length);
      for (let i = 0; i < raw.length; i++) pngBytes[i] = raw.charCodeAt(i);
    }

    // Embed character data as a tEXt chunk before IEND
    const resultPng = embedPngTextChunk(pngBytes, 'chara', charaB64);

    // Trigger download
    const blob = new Blob([resultPng], {type: 'image/png'});
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = (card.name || 'character').replace(/[^a-zA-Z0-9_-]/g, '_') + '.png';
    a.click();
    URL.revokeObjectURL(url);
  }

  /** Embed a tEXt chunk into a PNG file before the IEND chunk. */
  function embedPngTextChunk(pngBytes, keyword, text) {
    // Find IEND chunk (last 12 bytes: length(4) + 'IEND'(4) + CRC(4))
    let iendPos = -1;
    for (let i = pngBytes.length - 12; i >= 8; i--) {
      if (pngBytes[i+4] === 0x49 && pngBytes[i+5] === 0x45 &&
          pngBytes[i+6] === 0x4E && pngBytes[i+7] === 0x44) {
        iendPos = i;
        break;
      }
    }
    if (iendPos < 0) return pngBytes; // Can't find IEND, return as-is

    // Build tEXt chunk: keyword + null + text
    const keyBytes = new TextEncoder().encode(keyword);
    const textBytes = new TextEncoder().encode(text);
    const chunkData = new Uint8Array(keyBytes.length + 1 + textBytes.length);
    chunkData.set(keyBytes, 0);
    chunkData[keyBytes.length] = 0; // null separator
    chunkData.set(textBytes, keyBytes.length + 1);

    // Chunk: length(4) + type('tEXt', 4) + data + CRC(4)
    const chunkType = new Uint8Array([0x74, 0x45, 0x58, 0x74]); // 'tEXt'
    const chunkLen = chunkData.length;

    // Calculate CRC32 over type + data
    const crcInput = new Uint8Array(4 + chunkData.length);
    crcInput.set(chunkType, 0);
    crcInput.set(chunkData, 4);
    const crc = crc32(crcInput);

    // Build the full chunk (length + type + data + crc)
    const chunk = new Uint8Array(4 + 4 + chunkData.length + 4);
    chunk[0] = (chunkLen >> 24) & 0xFF;
    chunk[1] = (chunkLen >> 16) & 0xFF;
    chunk[2] = (chunkLen >> 8) & 0xFF;
    chunk[3] = chunkLen & 0xFF;
    chunk.set(chunkType, 4);
    chunk.set(chunkData, 8);
    chunk[chunk.length - 4] = (crc >> 24) & 0xFF;
    chunk[chunk.length - 3] = (crc >> 16) & 0xFF;
    chunk[chunk.length - 2] = (crc >> 8) & 0xFF;
    chunk[chunk.length - 1] = crc & 0xFF;

    // Insert chunk before IEND
    const result = new Uint8Array(pngBytes.length + chunk.length);
    result.set(pngBytes.subarray(0, iendPos), 0);
    result.set(chunk, iendPos);
    result.set(pngBytes.subarray(iendPos), iendPos + chunk.length);
    return result;
  }

  /** CRC32 for PNG chunks. */
  function crc32(bytes) {
    let crc = 0xFFFFFFFF;
    for (let i = 0; i < bytes.length; i++) {
      crc ^= bytes[i];
      for (let j = 0; j < 8; j++) {
        crc = (crc >>> 1) ^ (crc & 1 ? 0xEDB88320 : 0);
      }
    }
    return (crc ^ 0xFFFFFFFF) >>> 0;
  }

  async function saveCharacter() {
    const card = state.generatedCard;
    if (!card) return;
    const body = {
      name: card.name, description: card.description, personality: card.personality,
      scenario: card.scenario, firstMessage: card.firstMessage,
      mesExample: card.mesExample || '', systemPrompt: card.systemPrompt || '',
      alternateGreetings: card.alternateGreetings || [], tags: card.tags || [],
      avatar: state.avatarBase64 || '',
      lorebook: card.lorebook ? card.lorebook.map((e,i) => ({...e, enabled: state.lorebookEnabled[i] !== false})) : [],
    };
    // Add V2.5 Front Porch extensions if realism is configured
    if (state.realismEnabled) {
      body.extensions = {
        front_porch: {
          realism_enabled: state.realismEnabled,
          short_term_bond: state.realismShortTermBond,
          long_term_bond: state.realismLongTermBond,
          trust_level: state.realismTrustLevel,
          day_count: state.realismDayCount,
          time_of_day: state.realismTimeOfDay,
          character_emotion: state.realismEmotion,
          emotion_intensity: state.realismEmotionIntensity,
          nsfw_cooldown_enabled: state.realismNsfwCooldown,
          chaos_mode_enabled: state.realismChaosMode,
        },
      };
    }
    const btn = document.querySelector('#cw-content .cw-btn-success');
    if (btn) { btn.textContent = '⏳ Saving...'; btn.disabled = true; }
    const res = await apiJson('/api/chargen/save', {
      method: 'POST', headers: {'Content-Type':'application/json'}, body: JSON.stringify(body),
    });
    if (res && res.status === 'ok') {
      alert('Character saved! ID: ' + res.id);
      resetState();
      const switchPage = window._fpSwitchPage;
      if (switchPage) switchPage('home');
    } else {
      alert('Save failed: ' + (res?.error || 'Unknown error'));
      if (btn) { btn.textContent = '💾 Save Character'; btn.disabled = false; }
    }
  }

  function resetState() {
    const fresh = {
      step:0, modelId:'', modelsLoaded:false, availableModels:[],
      creatorMode:'automated',
      nsfwEnabled:false, selectedArchetype:'',
      name:'', age:'', sex:'',
      race:'', customRace:'', bodyType:'', hairLength:'', hairStyle:'', skinTone:'',
      notableFeatures:[], absCore:'', thighs:'', hips:'', shoulders:'', waist:'',
      chestSize:'', buttSize:'',
      relationship:'', customRelationship:'',
      experience:'', dominance:'', kinks:[], customKinks:'', outfitVibe:'',
      keywords:'',
      backstoryOrigin:'', backstoryTone:'', backstoryEra:'', backstoryNotes:'',
      generationDetail:'Standard', concept:'', conceptGenerated:false, isDescribing:false,
      isRandomizingName:false,
      generateLorebook:true, loreCategories:[], loreDepth:'Standard',
      personaId:'', greetingTones:['Neutral'],
      greetingLength:'Medium (2-4 paragraphs)', altGreetingCount:2, artStyle:'Anime',
      guidedVision:'', guidedAppearance:'', guidedHair:'', guidedFeatures:'', guidedRace:'',
      guidedPersonality:'', guidedSpeech:'', guidedSecret:'',
      guidedOrigin:'', guidedSetting:'', guidedTone:'',
      guidedRelDynamic:'', guidedRelScenario:'',
      guidedNsfwBody:'', guidedNsfwExp:'', guidedNsfwDom:'',
      guidedNsfwKinks:'', guidedNsfwClothing:'', guidedNsfwPersonality:'',
      isExpandingNarrative:false,
      quickNsfwEnabled:false, quickSelectedTones:['Neutral'], quickGreetingCount:2,
      quickConcept:'', quickScenario:'', quickLoreUrls:'', quickLoreFiles:[],
      isGenerating:false, genStatus:'', genPreview:'',
      realismEnabled:false, realismTimeOfDay:'morning', realismDayCount:1,
      realismShortTermBond:0, realismLongTermBond:0, realismTrustLevel:0,
      realismEmotion:'', realismEmotionIntensity:'mild',
      realismNsfwCooldown:false, realismChaosMode:false,
      generatedCard:null, avatarBase64:'', imagePrompt:'', lorebookEnabled:{},
      _open:{},
    };
    Object.assign(state, fresh); saveState();
  }

  async function generateDescription() {
    if (state.isDescribing) return;
    state.isDescribing = true; saveState(); renderStep2_Automated();
    try {
      const body = {
        selectedArchetype: state.selectedArchetype, name: state.name, keywords: state.keywords,
        age: state.age, sex: state.sex, race: state.race, customRace: state.customRace,
        bodyType: state.bodyType, hairLength: state.hairLength, hairStyle: state.hairStyle,
        skinTone: state.skinTone, notableFeatures: state.notableFeatures,
        relationship: state.customRelationship || state.relationship,
        backstoryOrigin: state.backstoryOrigin, backstoryTone: state.backstoryTone,
        backstoryEra: state.backstoryEra, backstoryNotes: state.backstoryNotes,
        nsfwEnabled: state.nsfwEnabled, experience: state.experience,
        dominance: state.dominance, kinks: state.kinks, outfitVibe: state.outfitVibe,
        generationDetail: state.generationDetail, modelId: state.modelId,
      };
      let rawTokens = '';
      const result = await streamLlmSSE('/api/chargen/describe', body, (token) => {
        rawTokens += token;
        // Live-update the textarea
        const ta = document.querySelector('#cw-describe-textarea');
        if (ta) { ta.value = rawTokens; ta.style.opacity = '0.7'; }
      });
      if (result && result.concept) {
        state.concept = result.concept;
        state.conceptGenerated = true;
      } else {
        alert('Description generation failed: ' + (result?.error || 'No response'));
      }
    } catch(e) {
      alert('Description generation failed: ' + e.message);
    }
    state.isDescribing = false; saveState(); renderStep2_Automated();
  }

  /** Re-render the current config step (works for automated, guided, and quick modes). */
  function rerenderConfigStep() {
    if (state.creatorMode === 'guided') renderStep2_Guided();
    else if (state.creatorMode === 'quick') renderStep2_Quick();
    else renderStep2_Automated();
  }

  async function randomizeName() {
    if (state.isRandomizingName) return;
    state.isRandomizingName = true; saveState(); rerenderConfigStep();
    try {
      let rawTokens = '';
      const result = await streamLlmSSE('/api/chargen/randomname', {
        selectedArchetype: state.selectedArchetype, modelId: state.modelId,
      }, (token) => {
        rawTokens += token;
        // Live-update the name input
        const inp = document.querySelector('.cw-section input[type="text"]');
        if (inp) inp.value = rawTokens;
      });
      if (result && result.name) {
        state.name = result.name;
      }
    } catch(e) {
      console.error('[chargen] randomize name failed', e);
    }
    state.isRandomizingName = false; saveState(); rerenderConfigStep();
  }

  /** Read an SSE stream from a POST endpoint. Calls onToken for each token event.
   *  Returns the parsed JSON from the 'done' event, or throws on error. */
  async function streamLlmSSE(url, body, onToken) {
    const token = sessionStorage.getItem('fp_token') || '';
    const resp = await fetch(url, {
      method: 'POST',
      headers: { 'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    });
    if (!resp.ok) {
      const err = await resp.json().catch(() => ({}));
      throw new Error(err.error || resp.statusText);
    }
    const reader = resp.body.getReader();
    const decoder = new TextDecoder();
    let buffer = '';
    let result = null;

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });

      // Parse SSE events from buffer
      while (buffer.includes('\n\n')) {
        const idx = buffer.indexOf('\n\n');
        const block = buffer.substring(0, idx);
        buffer = buffer.substring(idx + 2);

        let eventType = 'message';
        let eventData = '';
        for (const line of block.split('\n')) {
          if (line.startsWith('event: ')) eventType = line.substring(7).trim();
          else if (line.startsWith('data: ')) eventData = line.substring(6);
        }

        if (eventType === 'token' && onToken) {
          onToken(eventData);
        } else if (eventType === 'done') {
          try { result = JSON.parse(eventData); } catch(_) {}
        } else if (eventType === 'error') {
          try { result = JSON.parse(eventData); } catch(_) { result = {error: eventData}; }
        }
      }
    }
    return result;
  }

  // ── UI Builders ──
  function buildField(label, type, key, placeholder, opts) {
    const wrap = el('div', {className:'cw-field'});
    if (opts?.style) wrap.setAttribute('style', opts.style);
    wrap.appendChild(el('label', {className:'cw-label'}, label));
    const inp = el('input', {className:'cw-input', type, placeholder: placeholder||''});
    inp.value = state[key] || '';
    inp.addEventListener('input', () => { state[key] = inp.value; saveState(); });
    wrap.appendChild(inp);
    return wrap;
  }
  function buildTextareaField(label, key, placeholder) {
    const wrap = el('div', {className:'cw-field'});
    wrap.appendChild(el('label', {className:'cw-label'}, label));
    const ta = el('textarea', {className:'cw-textarea', rows:'3', placeholder: placeholder||''});
    ta.value = state[key] || '';
    ta.addEventListener('input', () => { state[key] = ta.value; saveState(); });
    wrap.appendChild(ta);
    return wrap;
  }
  function buildSelectField(label, options, key, opts) {
    const wrap = el('div', {className:'cw-field'});
    if (opts?.style) wrap.setAttribute('style', opts.style);
    wrap.appendChild(el('label', {className:'cw-label'}, label));
    const sel = el('select', {className:'cw-select', style:'width:100%'});
    options.forEach(opt => {
      const o = el('option', {value: opt}, opt);
      if (state[key] === opt) o.selected = true;
      sel.appendChild(o);
    });
    sel.addEventListener('change', () => { state[key] = sel.value; saveState(); });
    wrap.appendChild(sel);
    return wrap;
  }
  function buildSliderField(label, min, max, value, onChange) {
    const wrap = el('div', {className:'cw-slider-row'});
    wrap.appendChild(el('label', {className:'cw-label', style:'margin:0;flex-shrink:0'}, label));
    const slider = el('input', {type:'range', min:String(min), max:String(max), step:'1'});
    slider.value = value;
    const valSpan = el('span', {className:'cw-slider-value'}, String(value));
    slider.addEventListener('input', () => { valSpan.textContent = slider.value; onChange(parseInt(slider.value)); });
    wrap.appendChild(slider);
    wrap.appendChild(valSpan);
    return wrap;
  }
  function buildEditField(label, key, value, rows, customSetter) {
    const wrap = el('div', {className:'cw-edit-field'});
    wrap.appendChild(el('label', {}, label));
    const ta = el('textarea', {className:'cw-textarea', rows: String(rows || 4)});
    ta.value = value || '';
    ta.addEventListener('input', () => {
      if (customSetter) customSetter(ta.value);
      else { state.generatedCard[key] = ta.value; saveState(); }
    });
    wrap.appendChild(ta);
    return wrap;
  }
  function buildNavBtns(onBack, onNext, nextLabel) {
    const nav = el('div', {className:'cw-nav-btns'});
    if (onBack) { const b = el('button', {className:'cw-btn cw-btn-secondary'}, '← Back'); b.addEventListener('click', onBack); nav.appendChild(b); }
    else nav.appendChild(el('div'));
    if (onNext) { const n = el('button', {className:'cw-btn cw-btn-primary'}, nextLabel || 'Next →'); n.addEventListener('click', onNext); nav.appendChild(n); }
    return nav;
  }
  async function loadPersonasForSelect(select) {
    const data = await apiJson('/api/personas');
    if (data && Array.isArray(data)) {
      data.forEach(p => {
        const displayName = p.title || p.name || 'Untitled';
        const opt = el('option', {value: p.id || p.name}, displayName);
        if (state.personaId === String(p.id || p.name)) opt.selected = true;
        select.appendChild(opt);
      });
    }
  }

  // ── Main ──
  function render() {
    updateStepIndicators();
    switch(state.step) {
      case 0: renderStep0(); break;
      case 1: renderStep1_ModeSelect(); break;
      case 2:
        if (state.creatorMode === 'guided') renderStep2_Guided();
        else if (state.creatorMode === 'quick') renderStep2_Quick();
        else renderStep2_Automated();
        break;
      case 3: renderStep3(); break;
      case 4: renderStep4_Realism(); break;
      case 5: renderStep5(); break;
    }
  }
  function init() { loadState(); render(); }
  window.ChargenModule = { init, resetState };
})();
