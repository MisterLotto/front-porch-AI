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
  const LORE_CATEGORIES = ['Locations','NPCs/Allies','Items/Equipment','History/Lore','Factions/Organizations','Abilities/Magic','Culture/Customs','Secrets/Hidden Lore'];
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
    // Step 1 (Configure) — order matches Flutter exactly
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
    // Step 2 (Generating)
    isGenerating: false, genStatus: '', genPreview: '',
    // Step 3 (Review)
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

  async function fetchBackendState() {
    const data = await apiJson('/api/settings');
    if (data) {
      _backendType = data.activeBackend === 'kobold' ? 'kobold' : 'openRouter';
      _contextSize = data.contextSize || 8192;
      _koboldRunning = data.koboldRunning === true;
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
    // Fetch current backend state first
    await fetchBackendState();

    const c = $('#cw-content');
    c.innerHTML = '';
    c.appendChild(el('div', {className:'cw-page-header'}, 'Backend & Model Setup'));
    c.appendChild(el('div', {className:'cw-hint', style:'margin-bottom:24px'}, 'Choose your AI backend and model before configuring your character.'));

    // ── Backend Toggle ──
    const backendSec = el('div', {className:'cw-section'});
    backendSec.appendChild(el('label', {className:'cw-label'}, 'Backend'));
    const backendRow = el('div', {style:'display:flex;gap:12px;margin-bottom:16px'});

    const koboldChip = el('div', {
      className: 'cw-backend-chip' + (_backendType === 'kobold' ? ' selected' : ''),
      style: 'flex:1;padding:14px 16px;border-radius:10px;text-align:center;cursor:pointer;border:' + (_backendType === 'kobold' ? '2px solid #3b82f6' : '1px solid rgba(255,255,255,0.12)') + ';background:' + (_backendType === 'kobold' ? 'rgba(59,130,246,0.15)' : '#1e293b') + ';color:' + (_backendType === 'kobold' ? '#3b82f6' : 'rgba(255,255,255,0.5)') + ';font-size:13px;font-weight:' + (_backendType === 'kobold' ? '700' : '400'),
    }, '🖥️ KoboldCpp (Local)');
    koboldChip.addEventListener('click', async () => {
      if (_backendType !== 'kobold') {
        _backendType = 'kobold';
        await apiJson('/api/settings', { method:'POST', headers:{'Content-Type':'application/json'}, body: JSON.stringify({activeBackend:'kobold'}) });
        renderStep0();
      }
    });

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
  // STEP 1: Configure — EXACT Flutter layout order
  // 1. NSFW toggle  2. Archetypes  3. Name  4. Age/Sex
  // 5. Appearance (race,body,hair,skin,features,measurements,NSFW chest/butt)
  // 6. Relationship  7. NSFW Sexual Traits  8. Personality Keywords
  // 9. Backstory  10. Description Detail  11. Description
  // 12. Lorebook  13. Persona  14. Greeting Tones
  // 15. Message Length / Alt Greetings  16. Art Style
  // ═══════════════════════════════════════════════════════════
  function renderStep1() {
    const c = $('#cw-content');
    c.innerHTML = '';

    c.appendChild(el('div', {className:'cw-page-header'}, 'Bring Your Character to Life'));
    c.appendChild(el('div', {className:'cw-hint', style:'margin-bottom:20px'}, 'Give us a name and a concept — the AI will do the rest. It will generate a complete character card with personality, backstory, dialogue examples, and a custom avatar.'));

    // ── 1. NSFW Toggle ──
    const nsfwSec = el('div', {className:'cw-section cw-nsfw-toggle-section'});
    nsfwSec.appendChild(buildToggleRow('🔞 Enable NSFW Options', state.nsfwEnabled, v => {
      state.nsfwEnabled = v; saveState(); renderStep1();
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
      saveState(); renderStep1();
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
      renderStep1(); // Re-render to update hint text and chips
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
      () => { state.step = 0; saveState(); render(); },
      () => {
        if (!state.name.trim()) { alert('Please enter a character name.'); return; }
        state.step = 2; saveState(); render(); startGeneration();
      },
      'Generate ✨'
    ));
  }

  // ═══════════════════════════════════════════════════════════
  // STEP 2: Generating
  // ═══════════════════════════════════════════════════════════
  function renderStep2() {
    const c = $('#cw-content');
    c.innerHTML = '';
    const wrap = el('div', {className:'cw-gen-wrap'});
    wrap.appendChild(el('div', {className:'cw-gen-status', id:'cw-gen-status'}, state.genStatus || 'Starting generation...'));
    const progressBar = el('div', {className:'cw-gen-progress'});
    progressBar.appendChild(el('div', {className:'cw-gen-progress-fill', id:'cw-gen-progress-fill'}));
    wrap.appendChild(progressBar);
    wrap.appendChild(el('div', {className:'cw-gen-preview', id:'cw-gen-preview'}, state.genPreview || 'Waiting for AI response...'));
    const cancelBtn = el('button', {className:'cw-btn cw-btn-danger', style:'margin-top:20px'}, 'Cancel');
    cancelBtn.addEventListener('click', () => { disconnectChargenSSE(); stopGenStatusPoller(); state.step = 1; state.isGenerating = false; saveState(); render(); });
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
          state.isGenerating = false; state.step = 3;
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
            state.isGenerating = false; state.step = 3;
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
  // STEP 3: Review
  // ═══════════════════════════════════════════════════════════
  function renderStep3() {
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
    right.appendChild(buildEditField('System Prompt', 'systemPrompt', card.systemPrompt || '', 3));
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
        cb.addEventListener('change', () => { state.lorebookEnabled[i] = cb.checked; saveState(); renderStep3(); });
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
    if (res && res.image) { state.avatarBase64 = res.image; saveState(); renderStep3(); }
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
    if (res && res.image) { state.avatarBase64 = res.image; saveState(); renderStep3(); }
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
      isGenerating:false, genStatus:'', genPreview:'',
      generatedCard:null, avatarBase64:'', imagePrompt:'', lorebookEnabled:{},
      _open:{},
    };
    Object.assign(state, fresh); saveState();
  }

  async function generateDescription() {
    if (state.isDescribing) return;
    state.isDescribing = true; saveState(); renderStep1();
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
    state.isDescribing = false; saveState(); renderStep1();
  }

  async function randomizeName() {
    if (state.isRandomizingName) return;
    state.isRandomizingName = true; saveState(); renderStep1();
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
    state.isRandomizingName = false; saveState(); renderStep1();
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
  function render() { updateStepIndicators(); switch(state.step) { case 0: renderStep0(); break; case 1: renderStep1(); break; case 2: renderStep2(); break; case 3: renderStep3(); break; } }
  function init() { loadState(); render(); }
  window.ChargenModule = { init, resetState };
})();
