// ════════════════════════════════════════════════════════════════════════════
// stories.js — Porch Stories Web UI
// ════════════════════════════════════════════════════════════════════════════
(function () {
  'use strict';

  // ── Helpers ────────────────────────────────────────────────────────────────
  const $ = (sel, ctx = document) => ctx.querySelector(sel);
  const $$ = (sel, ctx = document) => [...ctx.querySelectorAll(sel)];
  const esc = s => String(s ?? '').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');

  function getToken() {
    return sessionStorage.getItem('fp_token') || localStorage.getItem('fp_token') || '';
  }

  async function api(path, opts = {}) {
    const tok = getToken();
    const headers = { ...(opts.headers || {}) };
    if (tok) headers['Authorization'] = `Bearer ${tok}`;
    if (opts.body && !headers['Content-Type']) headers['Content-Type'] = 'application/json';
    try {
      const res = await fetch(path, { ...opts, headers });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res;
    } catch (e) {
      console.error('[Stories]', path, e);
      return null;
    }
  }

  async function apiJson(path, opts = {}) {
    const res = await api(path, opts);
    if (!res) return null;
    try { return await res.json(); } catch { return null; }
  }

  // ── State ──────────────────────────────────────────────────────────────────
  let _projects = [];
  let _currentProject = null;
  let _currentView = 'dashboard'; // 'dashboard' | 'detail' | 'reader'
  let _sseSource = null;
  let _pipelineRunning = false;

  // ── Entry Point ────────────────────────────────────────────────────────────
  async function init() {
    const container = document.getElementById('stories-container');
    if (!container) return;
    await loadDashboard();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DASHBOARD
  // ════════════════════════════════════════════════════════════════════════════

  async function loadDashboard() {
    _currentView = 'dashboard';
    _currentProject = null;
    disconnectSSE();

    const container = document.getElementById('stories-container');
    container.innerHTML = '<p style="text-align:center;color:var(--text-muted);padding:40px">Loading stories…</p>';

    const list = await apiJson('/api/stories');
    _projects = Array.isArray(list) ? list : [];
    renderDashboard();
  }

  function renderDashboard() {
    const container = document.getElementById('stories-container');
    if (!container) return;

    const cards = _projects.length === 0
      ? '<p style="text-align:center;color:var(--text-muted);padding:40px 0">No stories yet. Start your first one!</p>'
      : _projects.map(p => `
        <div class="story-card" data-id="${esc(p.id)}" style="
          background:var(--bg-card);border:1px solid var(--border);border-radius:12px;
          padding:20px;cursor:pointer;transition:border-color .2s,box-shadow .2s;
          display:flex;flex-direction:column;gap:8px;
        ">
          <div style="display:flex;justify-content:space-between;align-items:flex-start;gap:12px">
            <div style="font-size:17px;font-weight:700;color:var(--text-primary);line-height:1.3">${esc(p.title)}</div>
            <button class="btn-icon story-delete-btn" data-id="${esc(p.id)}" title="Delete story"
              style="flex-shrink:0;opacity:.5;font-size:16px;line-height:1;padding:4px">🗑️</button>
          </div>
          <div style="color:var(--text-secondary);font-size:13px;line-height:1.5">${esc(p.concept)}</div>
          <div style="display:flex;gap:16px;margin-top:4px;font-size:12px;color:var(--text-muted)">
            <span>📚 ${p.actCount} acts</span>
            <span>✍️ ${(p.wordCount||0).toLocaleString()} words</span>
            <span>🕐 ${new Date(p.updatedAt).toLocaleDateString()}</span>
          </div>
        </div>
      `).join('');

    container.innerHTML = `
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:20px">
        <h2 style="margin:0;color:var(--text-primary);font-size:20px">Your Stories</h2>
        <button class="btn btn-primary" id="btn-new-story">+ New Story</button>
      </div>
      <div style="display:flex;flex-direction:column;gap:14px" id="story-card-list">
        ${cards}
      </div>
    `;

    // New story
    $('#btn-new-story', container)?.addEventListener('click', () => showNewStoryWizard());

    // Open story
    $$('.story-card', container).forEach(card => {
      card.addEventListener('click', e => {
        if (e.target.closest('.story-delete-btn')) return;
        openStory(card.dataset.id);
      });
    });

    // Delete
    $$('.story-delete-btn', container).forEach(btn => {
      btn.addEventListener('click', async e => {
        e.stopPropagation();
        if (!confirm('Delete this story? This cannot be undone.')) return;
        const res = await api('/api/stories/delete', {
          method: 'POST',
          body: JSON.stringify({ id: btn.dataset.id }),
        });
        if (res?.ok) await loadDashboard();
      });
    });
  }

  // ════════════════════════════════════════════════════════════════════════════
  // NEW STORY WIZARD
  // ════════════════════════════════════════════════════════════════════════════

  function showNewStoryWizard() {
    let overlayEl = document.getElementById('story-wizard-overlay');
    if (!overlayEl) {
      overlayEl = document.createElement('div');
      overlayEl.id = 'story-wizard-overlay';
      overlayEl.className = 'modal-overlay';
      document.body.appendChild(overlayEl);
    }

    const genres = ['Fantasy','Sci-Fi','Romance','Mystery','Thriller','Horror','Adventure','Historical','Comedy','Drama','Literary'];
    const moods  = ['Dark','Humorous','Hopeful','Melancholic','Tense','Romantic','Mysterious','Epic','Cozy','Bittersweet'];
    const wizard = {
      title: '', concept: '', actCount: 3, pov: 'Third Person Limited',
      maturityRating: 'teen', proseLength: 'standard', narrativePace: 'moderate',
      dialogueDensity: 'balanced', writingStyle: '',
      selectedGenres: [], selectedMoods: [],
      characterCardSnapshots: [],
    };

    function render() {
      overlayEl.innerHTML = `
        <div class="modal" style="min-width:min(600px,95vw);max-height:88vh;display:flex;flex-direction:column;overflow:hidden">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:20px">
            <h2 style="margin:0;font-size:20px;color:var(--text-primary)">📖 New Story</h2>
            <button id="wizard-close" class="btn btn-outlined" style="padding:4px 10px;font-size:14px">✕</button>
          </div>
          <div style="overflow-y:auto;flex:1;display:flex;flex-direction:column;gap:18px">

            <div>
              <label class="field-label">Story Title *</label>
              <input type="text" id="wiz-title" class="settings-input" value="${esc(wizard.title)}" placeholder="Give your story a working title…">
            </div>

            <div>
              <label class="field-label">Core Concept *</label>
              <textarea id="wiz-concept" class="settings-textarea" rows="4"
                placeholder="Describe the premise of your story in a few sentences. The more detail you give, the better…"
              >${esc(wizard.concept)}</textarea>
            </div>

            <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
              <div>
                <label class="field-label">Acts</label>
                <select id="wiz-acts" class="settings-select">
                  ${[1,2,3,4,5].map(n=>`<option value="${n}" ${wizard.actCount==n?'selected':''}>${n}-Act Structure</option>`).join('')}
                </select>
              </div>
              <div>
                <label class="field-label">Point of View</label>
                <select id="wiz-pov" class="settings-select">
                  ${['First Person','Third Person Limited','Third Person Omniscient','Second Person']
                    .map(p=>`<option value="${p}" ${wizard.pov===p?'selected':''}>${p}</option>`).join('')}
                </select>
              </div>
            </div>

            <div style="display:grid;grid-template-columns:1fr 1fr;gap:12px">
              <div>
                <label class="field-label">Maturity Rating</label>
                <select id="wiz-maturity" class="settings-select">
                  ${[['everyone','Everyone'],['teen','Teen'],['mature','Mature (17+)'],['adult','Adult (18+)']]
                    .map(([v,l])=>`<option value="${v}" ${wizard.maturityRating===v?'selected':''}>${l}</option>`).join('')}
                </select>
              </div>
              <div>
                <label class="field-label">Prose Length</label>
                <select id="wiz-prose-length" class="settings-select">
                  ${[['brief','Brief'],['standard','Standard'],['detailed','Detailed'],['epic','Epic']]
                    .map(([v,l])=>`<option value="${v}" ${wizard.proseLength===v?'selected':''}>${l}</option>`).join('')}
                </select>
              </div>
            </div>

            <div>
              <label class="field-label">Genres</label>
              <div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:4px">
                ${genres.map(g=>`
                  <label style="display:flex;align-items:center;gap:4px;font-size:13px;cursor:pointer">
                    <input type="checkbox" class="wiz-genre" value="${g}" ${wizard.selectedGenres.includes(g)?'checked':''}> ${g}
                  </label>`).join('')}
              </div>
            </div>

            <div>
              <label class="field-label">Mood &amp; Tone</label>
              <div style="display:flex;flex-wrap:wrap;gap:8px;margin-top:4px">
                ${moods.map(m=>`
                  <label style="display:flex;align-items:center;gap:4px;font-size:13px;cursor:pointer">
                    <input type="checkbox" class="wiz-mood" value="${m}" ${wizard.selectedMoods.includes(m)?'checked':''}> ${m}
                  </label>`).join('')}
              </div>
            </div>

            <div>
              <label class="field-label">Writing Style / Author Voice (optional)</label>
              <input type="text" id="wiz-style" class="settings-input" value="${esc(wizard.writingStyle)}"
                placeholder="e.g. Tolkien-esque, terse thriller prose, lyrical literary fiction…">
            </div>

          </div>
          <div style="display:flex;justify-content:flex-end;gap:10px;margin-top:16px;padding-top:12px;border-top:1px solid var(--border)">
            <button class="btn btn-outlined" id="wiz-cancel">Cancel</button>
            <button class="btn btn-primary" id="wiz-create">Create Story &amp; Start Pipeline</button>
          </div>
        </div>
      `;

      overlayEl.classList.add('active');
      overlayEl.querySelector('#wizard-close').onclick = () => overlayEl.classList.remove('active');
      overlayEl.querySelector('#wiz-cancel').onclick   = () => overlayEl.classList.remove('active');
      overlayEl.addEventListener('click', e => { if (e.target === overlayEl) overlayEl.classList.remove('active'); });

      overlayEl.querySelector('#wiz-create').onclick = async () => {
        wizard.title          = overlayEl.querySelector('#wiz-title').value.trim();
        wizard.concept        = overlayEl.querySelector('#wiz-concept').value.trim();
        wizard.actCount       = parseInt(overlayEl.querySelector('#wiz-acts').value) || 3;
        wizard.pov            = overlayEl.querySelector('#wiz-pov').value;
        wizard.maturityRating = overlayEl.querySelector('#wiz-maturity').value;
        wizard.proseLength    = overlayEl.querySelector('#wiz-prose-length').value;
        wizard.writingStyle   = overlayEl.querySelector('#wiz-style').value.trim();
        wizard.selectedGenres = [...overlayEl.querySelectorAll('.wiz-genre:checked')].map(c=>c.value);
        wizard.selectedMoods  = [...overlayEl.querySelectorAll('.wiz-mood:checked')].map(c=>c.value);

        if (!wizard.title)   { alert('Please enter a title.'); return; }
        if (!wizard.concept) { alert('Please describe the story concept.'); return; }

        const btn = overlayEl.querySelector('#wiz-create');
        btn.disabled = true;
        btn.textContent = 'Creating…';

        const payload = Object.assign({}, wizard);
        const result = await apiJson('/api/stories/create', {
          method: 'POST',
          body: JSON.stringify(payload),
        });

        if (!result?.id) {
          btn.disabled = false;
          btn.textContent = 'Create Story & Start Pipeline';
          alert('Failed to create story. Check the server logs.');
          return;
        }

        overlayEl.classList.remove('active');
        await openStory(result.id);
      };
    }

    render();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STORY DETAIL VIEW
  // ════════════════════════════════════════════════════════════════════════════

  async function openStory(id) {
    const container = document.getElementById('stories-container');
    container.innerHTML = '<p style="text-align:center;color:var(--text-muted);padding:40px">Loading…</p>';

    const data = await apiJson(`/api/stories/${id}`);
    if (!data) {
      container.innerHTML = '<p style="color:red;text-align:center;padding:40px">Failed to load story.</p>';
      return;
    }
    _currentProject = data;
    _currentView = 'detail';
    renderDetail();
  }

  function renderDetail() {
    const container = document.getElementById('stories-container');
    if (!container || !_currentProject) return;

    const p = _currentProject;
    const acts = p.acts || [];
    const hasBible = !!(p.statusQuo || p.themes);
    const hasActs  = acts.length > 0;

    // Build acts accordion
    const actsHtml = hasActs ? acts.map((act, ai) => {
      const scenes = p.scenes?.[ai] || [];
      const scenesHtml = scenes.map((scene, si) => {
        const beats = scene.beats || [];
        const beatsHtml = beats.map((beat, bi) => {
          const key = `${ai}-${si}-${bi}`;
          const prose = p.prose?.[key];
          const hasProse = !!(prose?.final_ || prose?.draft);
          return `
            <div style="padding:6px 10px;border-radius:6px;background:${hasProse?'rgba(34,197,94,.08)':'rgba(255,255,255,.03)'};
              border:1px solid ${hasProse?'rgba(34,197,94,.25)':'rgba(255,255,255,.08)'};margin-bottom:4px">
              <div style="display:flex;justify-content:space-between;align-items:center">
                <span style="font-size:12px;color:var(--text-secondary)">Beat ${bi+1}: ${esc(beat.summary||beat.description||'')}</span>
                <div style="display:flex;gap:6px">
                  ${hasProse
                    ? `<button class="btn btn-sm story-read-beat" data-ai="${ai}" data-si="${si}" data-bi="${bi}" style="font-size:11px;padding:2px 8px;color:#22c55e;border-color:#22c55e">📖 Read</button>`
                    : `<button class="btn btn-sm story-run-prose" data-ai="${ai}" data-si="${si}" data-bi="${bi}" data-id="${esc(p.id)}" style="font-size:11px;padding:2px 8px">✨ Write</button>`
                  }
                </div>
              </div>
            </div>`;
        }).join('');

        return `
          <div style="margin:6px 0 6px 12px;border-left:2px solid rgba(255,255,255,.1);padding-left:10px">
            <div style="font-size:13px;font-weight:600;color:var(--text-primary);margin-bottom:6px">
              Scene ${si+1}: ${esc(scene.title||scene.description||'')}
            </div>
            ${beats.length > 0 ? beatsHtml : `
              <button class="btn btn-sm story-run-stage" data-stage="beats" data-ai="${ai}" data-si="${si}" data-id="${esc(p.id)}" style="font-size:11px;padding:3px 10px">
                ✨ Generate Beats
              </button>`}
            ${beats.length > 0 ? `
              <button class="btn btn-sm story-run-stage" data-stage="archivist" data-ai="${ai}" data-si="${si}" data-id="${esc(p.id)}" style="font-size:11px;padding:3px 10px;margin-top:6px;color:#a78bfa;border-color:#a78bfa">
                📝 Archivist
              </button>` : ''}
          </div>`;
      }).join('');

      return `
        <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:16px;margin-bottom:12px">
          <div style="font-size:15px;font-weight:700;color:var(--text-primary);margin-bottom:4px">
            Act ${ai+1}: ${esc(act.title||'')}
          </div>
          <div style="font-size:12px;color:var(--text-muted);margin-bottom:10px">${esc(act.description||'')}</div>

          ${scenes.length > 0 ? scenesHtml : `
            <button class="btn btn-sm story-run-stage" data-stage="scenes" data-ai="${ai}" data-id="${esc(p.id)}" style="font-size:12px;padding:4px 12px">
              ✨ Generate Scenes (Act ${ai+1})
            </button>`}

          ${scenes.length > 0 && scenes.some(s => !(s.beats?.length)) ? `
            <button class="btn btn-sm story-run-stage" data-stage="scenes" data-ai="${ai}" data-id="${esc(p.id)}" style="font-size:12px;padding:4px 12px;margin-top:6px;opacity:.7">
              🔄 Regenerate Scenes
            </button>` : ''}
        </div>`;
    }).join('') : '';

    container.innerHTML = `
      <!-- Back button -->
      <div style="display:flex;align-items:center;gap:10px;margin-bottom:20px">
        <button class="btn btn-outlined" id="btn-back-to-dashboard" style="padding:6px 14px;font-size:13px">← All Stories</button>
        <div style="flex:1;position:relative" id="story-title-wrap">
          <h2 id="story-title-display"
            style="margin:0;font-size:20px;color:var(--text-primary);cursor:text;
                   border-bottom:1px dashed rgba(255,255,255,0.2);display:inline-block;
                   padding-bottom:2px;transition:border-color 0.2s"
            title="Click to edit story title"
          >${esc(p.title||'Untitled Story')}</h2>
        </div>
        <button class="btn btn-outlined" id="btn-read-story" style="font-size:13px;padding:6px 16px;color:#f59e0b;border-color:#f59e0b">📖 Reader View</button>
      </div>

      <!-- Concept -->
      <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:16px;margin-bottom:16px">
        <div style="font-size:13px;font-weight:600;color:var(--text-muted);margin-bottom:6px">CONCEPT</div>
        <div style="color:var(--text-secondary);font-size:14px;line-height:1.6">${esc(p.concept||'')}</div>
      </div>

      <!-- Pipeline progress -->
      <div id="story-pipeline-panel" style="display:none;background:rgba(59,130,246,.08);border:1px solid rgba(59,130,246,.3);border-radius:10px;padding:16px;margin-bottom:16px">
        <div style="display:flex;align-items:center;gap:10px;margin-bottom:8px">
          <span id="story-spinner" style="display:inline-block;animation:spin 1s linear infinite;font-size:18px">⚙️</span>
          <span id="story-pipeline-status" style="font-size:13px;color:#93c5fd;font-weight:600">Running pipeline…</span>
        </div>
        <div id="story-pipeline-log"
          style="background:rgba(0,0,0,.3);border-radius:6px;padding:10px;font-size:11px;font-family:monospace;color:rgba(255,255,255,.6);max-height:120px;overflow-y:auto;white-space:pre-wrap;word-break:break-word">
        </div>
      </div>

      <!-- Pipeline stages -->
      <div style="background:var(--bg-card);border:1px solid var(--border);border-radius:10px;padding:16px;margin-bottom:16px">
        <div style="font-size:13px;font-weight:700;color:var(--text-primary);margin-bottom:12px">🛠 Pipeline Stages</div>
        <div style="display:flex;flex-wrap:wrap;gap:8px">
          <button class="btn btn-sm story-run-stage" data-stage="architect" data-id="${esc(p.id)}"
            style="background:${hasBible?'rgba(34,197,94,.15)':'rgba(59,130,246,.15)'};border-color:${hasBible?'#22c55e':'#3b82f6'}">
            ${hasBible ? '✅' : '1️⃣'} Story Architect
          </button>
          <button class="btn btn-sm story-run-stage" data-stage="structure" data-id="${esc(p.id)}"
            ${!hasBible?'disabled':''} style="background:${hasActs?'rgba(34,197,94,.15)':'rgba(59,130,246,.15)'};border-color:${hasActs?'#22c55e':'#3b82f6'}">
            ${hasActs ? '✅' : '2️⃣'} Act Structurer
          </button>
          <button class="btn btn-sm story-run-stage" data-stage="distill" data-id="${esc(p.id)}"
            style="background:rgba(139,92,246,.15);border-color:#8b5cf6;color:#c4b5fd">
            💬 Distil Chats
          </button>
        </div>
      </div>

      <!-- Acts/Scenes/Beats -->
      ${hasActs ? `
        <div style="font-size:14px;font-weight:700;color:var(--text-primary);margin-bottom:10px">📋 Story Structure</div>
        ${actsHtml}
      ` : ''}
    `;

    // Back
    document.getElementById('btn-back-to-dashboard')?.addEventListener('click', loadDashboard);

    // Inline title edit
    document.getElementById('story-title-display')?.addEventListener('click', () => {
      const display = document.getElementById('story-title-display');
      const wrap = document.getElementById('story-title-wrap');
      if (!display || !wrap) return;
      const currentTitle = _currentProject.title || '';
      const input = document.createElement('input');
      input.type = 'text';
      input.value = currentTitle;
      input.className = 'settings-input';
      input.style.cssText = 'font-size:18px;font-weight:700;width:100%;max-width:400px';
      wrap.replaceChild(input, display);
      input.focus();
      input.select();

      async function commitTitleEdit() {
        const newTitle = input.value.trim() || currentTitle;
        // Restore display
        display.textContent = newTitle;
        wrap.replaceChild(display, input);
        if (newTitle === currentTitle) return;
        _currentProject.title = newTitle;
        // Also update dashboard cache
        const proj = _projects.find(p2 => p2.id === _currentProject.id);
        if (proj) proj.title = newTitle;
        // Persist
        try {
          await api(`/api/stories/${_currentProject.id}/update`, {
            method: 'POST',
            body: JSON.stringify({ title: newTitle }),
          });
        } catch(e) { console.error('Title update failed:', e); }
      }

      input.addEventListener('keydown', e => {
        if (e.key === 'Enter') { e.preventDefault(); commitTitleEdit(); }
        if (e.key === 'Escape') { wrap.replaceChild(display, input); }
      });
      input.addEventListener('blur', commitTitleEdit);
    });

    // Reader
    document.getElementById('btn-read-story')?.addEventListener('click', () => showReaderView(_currentProject));


    // Pipeline stage buttons
    $$('.story-run-stage', container).forEach(btn => {
      btn.addEventListener('click', () => {
        if (_pipelineRunning) { alert('Pipeline is already running.'); return; }
        runPipelineStage(btn.dataset.id, btn.dataset.stage, {
          actIdx:   parseInt(btn.dataset.ai  || 0),
          sceneIdx: parseInt(btn.dataset.si  || 0),
        });
      });
    });

    // Beat prose write
    $$('.story-run-prose', container).forEach(btn => {
      btn.addEventListener('click', () => {
        if (_pipelineRunning) { alert('Pipeline is already running.'); return; }
        runPipelineStage(btn.dataset.id, 'prose', {
          actIdx:   parseInt(btn.dataset.ai),
          sceneIdx: parseInt(btn.dataset.si),
          beatIdx:  parseInt(btn.dataset.bi),
        });
      });
    });

    // Beat read
    $$('.story-read-beat', container).forEach(btn => {
      btn.addEventListener('click', () => {
        const ai = parseInt(btn.dataset.ai);
        const si = parseInt(btn.dataset.si);
        const bi = parseInt(btn.dataset.bi);
        showProseEditor(_currentProject, ai, si, bi);
      });
    });
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PIPELINE RUNNER
  // ════════════════════════════════════════════════════════════════════════════

  async function runPipelineStage(storyId, stage, params = {}) {
    if (_pipelineRunning) return;
    _pipelineRunning = true;

    const panel    = document.getElementById('story-pipeline-panel');
    const statusEl = document.getElementById('story-pipeline-status');
    const logEl    = document.getElementById('story-pipeline-log');

    if (panel)    panel.style.display = '';
    if (statusEl) statusEl.textContent = `Starting: ${stage}…`;
    if (logEl)    logEl.textContent = '';

    // Connect SSE first
    disconnectSSE();
    const tok = getToken();
    const sseUrl = `/api/stories/${storyId}/pipeline/stream` + (tok ? `?token=${encodeURIComponent(tok)}` : '');
    _sseSource = new EventSource(sseUrl);

    _sseSource.addEventListener('message', e => {
      try {
        const ev = JSON.parse(e.data);
        if (ev.event === 'status' && statusEl) {
          statusEl.textContent = ev.text || '';
        }
        if (ev.event === 'token' && logEl) {
          logEl.textContent += ev.text || '';
          logEl.scrollTop = logEl.scrollHeight;
        }
        if (ev.event === 'complete') {
          _pipelineRunning = false;
          if (statusEl) statusEl.textContent = '✅ Complete!';
          if (ev.project) {
            _currentProject = ev.project;
            setTimeout(() => {
              if (panel) panel.style.display = 'none';
              renderDetail();
            }, 1500);
          }
          disconnectSSE();
        }
        if (ev.event === 'error') {
          _pipelineRunning = false;
          if (statusEl) statusEl.textContent = '❌ ' + (ev.text || 'Error');
          disconnectSSE();
        }
      } catch {}
    });

    _sseSource.onerror = () => {
      // SSE will retry; only mark failed after timeout
    };

    // Now kick off the pipeline
    const endpoint = stage === 'distill'
      ? `/api/stories/${storyId}/distill`
      : `/api/stories/${storyId}/pipeline/run`;

    const body = stage === 'distill'
      ? {}
      : { stage, ...params };

    const res = await api(endpoint, {
      method: 'POST',
      body: JSON.stringify(body),
    });

    if (!res?.ok) {
      _pipelineRunning = false;
      if (statusEl) statusEl.textContent = '❌ Failed to start pipeline.';
      disconnectSSE();
    }
  }

  function disconnectSSE() {
    if (_sseSource) {
      _sseSource.close();
      _sseSource = null;
    }
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PROSE EDITOR MODAL
  // ════════════════════════════════════════════════════════════════════════════

  function showProseEditor(project, ai, si, bi) {
    const key   = `${ai}-${si}-${bi}`;
    const prose = project.prose?.[key];
    const text  = prose?.final_ || prose?.draft || '';

    const act   = project.acts?.[ai];
    const scene = project.scenes?.[ai]?.[si];
    const beat  = scene?.beats?.[bi];

    let overlay = document.createElement('div');
    overlay.className = 'modal-overlay active';
    overlay.innerHTML = `
      <div class="modal" style="min-width:min(700px,95vw);max-height:85vh;display:flex;flex-direction:column">
        <div class="modal-title" style="font-size:16px">
          ✍️ Beat ${bi+1} — ${esc(beat?.summary || beat?.description || '')}
          <div style="font-size:12px;color:var(--text-muted);font-weight:400;margin-top:2px">
            Act ${ai+1}: ${esc(act?.title||'')} › Scene ${si+1}: ${esc(scene?.title||'')}
          </div>
        </div>
        <textarea id="prose-edit-ta" class="settings-textarea" rows="18"
          style="flex:1;font-size:14px;line-height:1.7;font-family:Georgia,serif;resize:vertical"
        >${esc(text)}</textarea>
        <div class="modal-actions" style="gap:8px">
          <span id="prose-edit-status" style="flex:1;font-size:12px;color:var(--text-muted)"></span>
          <button class="btn btn-outlined" id="btn-prose-close">Close</button>
          <button class="btn btn-primary" id="btn-prose-save">💾 Save</button>
        </div>
      </div>
    `;
    document.body.appendChild(overlay);
    overlay.addEventListener('click', e => { if (e.target === overlay) overlay.remove(); });
    overlay.querySelector('#btn-prose-close').onclick = () => overlay.remove();

    overlay.querySelector('#btn-prose-save').onclick = async () => {
      const ta  = overlay.querySelector('#prose-edit-ta');
      const sts = overlay.querySelector('#prose-edit-status');
      sts.textContent = 'Saving…';
      const res = await api(`/api/stories/${project.id}/prose/edit`, {
        method: 'POST',
        body: JSON.stringify({ actIdx: ai, sceneIdx: si, beatIdx: bi, prose: ta.value }),
      });
      if (res?.ok) {
        sts.textContent = '✅ Saved';
        // Update local state
        if (!_currentProject.prose) _currentProject.prose = {};
        _currentProject.prose[key] = { draft: text, final_: ta.value };
      } else {
        sts.textContent = '❌ Save failed';
      }
    };
  }

  // ════════════════════════════════════════════════════════════════════════════
  // READER VIEW
  // ════════════════════════════════════════════════════════════════════════════

  function showReaderView(project) {
    let overlay = document.getElementById('story-reader-overlay');
    if (!overlay) {
      overlay = document.createElement('div');
      overlay.id = 'story-reader-overlay';
      overlay.style.cssText = `
        position:fixed;inset:0;z-index:9000;
        background:var(--bg-primary, #0f172a);
        overflow-y:auto;display:flex;flex-direction:column;
      `;
      document.body.appendChild(overlay);
    }

    // Gather all prose in order
    const acts = project.acts || [];
    let fullText = `<h1 style="text-align:center;margin:40px 0 8px;color:var(--text-primary)">${esc(project.title)}</h1>`;
    if (project.concept) {
      fullText += `<p style="text-align:center;color:var(--text-muted);font-style:italic;margin-bottom:40px;max-width:600px;margin-left:auto;margin-right:auto">${esc(project.concept)}</p>`;
    }

    let hasAnyProse = false;
    acts.forEach((act, ai) => {
      const scenes = project.scenes?.[ai] || [];
      fullText += `<h2 style="margin:48px 0 16px;color:var(--text-primary);border-bottom:1px solid var(--border);padding-bottom:8px">Act ${ai+1}: ${esc(act.title||'')}</h2>`;
      scenes.forEach((scene, si) => {
        fullText += `<h3 style="margin:32px 0 12px;color:var(--text-secondary)">Scene ${si+1}: ${esc(scene.title||'')}</h3>`;
        const beats = scene.beats || [];
        beats.forEach((beat, bi) => {
          const key   = `${ai}-${si}-${bi}`;
          const prose = project.prose?.[key];
          const text  = prose?.final_ || prose?.draft || '';
          if (text) {
            hasAnyProse = true;
            const paragraphs = text.split(/\n\n+/).map(p => `<p style="margin:0 0 1.2em">${esc(p.trim()).replace(/\n/g,'<br>')}</p>`).join('');
            fullText += `<div class="story-beat-block">${paragraphs}</div>`;
          }
        });
      });
    });

    if (!hasAnyProse) {
      fullText += '<p style="text-align:center;color:var(--text-muted);margin-top:60px">No prose generated yet. Use the pipeline to write scenes.</p>';
    }

    overlay.innerHTML = `
      <div style="max-width:720px;margin:0 auto;padding:40px 24px 80px;width:100%">
        <div style="display:flex;justify-content:flex-end;margin-bottom:16px">
          <button id="btn-close-reader" class="btn btn-outlined" style="font-size:13px">✕ Close Reader</button>
        </div>
        <div style="font-size:16px;line-height:1.9;color:var(--text-primary);font-family:Georgia,'Times New Roman',serif">
          ${fullText}
        </div>
      </div>
    `;

    overlay.querySelector('#btn-close-reader').addEventListener('click', () => {
      overlay.remove();
    });
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ════════════════════════════════════════════════════════════════════════════

  window.StoriesModule = { init };

  // Add spin animation if not already injected
  if (!document.getElementById('story-spin-style')) {
    const style = document.createElement('style');
    style.id = 'story-spin-style';
    style.textContent = `
      @keyframes spin { to { transform: rotate(360deg); } }
      .story-beat-block + .story-beat-block { margin-top: 2em; }
    `;
    document.head.appendChild(style);
  }

})();
