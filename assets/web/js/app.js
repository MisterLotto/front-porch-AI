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

/* ═══════════════════════════════════════════════════════════
   Front Porch AI — Web UI Application
   Mirrors the desktop Flutter app in function and appearance.
   ═══════════════════════════════════════════════════════════ */

(function () {
    'use strict';

    // ── State ──
    let token = sessionStorage.getItem('fp_token') || null;
    let currentCharacterId = null;
    let currentCharacterName = null;
    let currentCharacterDesc = null;
    let currentCharacterHasAvatar = false;
    let pollTimer = null;
    let lastMessageCount = 0;
    let sseSource = null;
    let streamingText = '';
    let isStreaming = false;
    let gridScale = 260;
    let searchQuery = '';
    let sortMode = 'name';
    let activeFolderId = null;
    let folderStack = [];
    let isSelectingForGroup = false;
    let selectedForGroup = new Set(); // Set of charId strings
    let allCharactersCache = [];      // cached character list for group modal

    // ── DOM refs ──
    const $ = (sel) => document.querySelector(sel);
    const $$ = (sel) => document.querySelectorAll(sel);

    // ── Helpers ──
    function esc(s) { const d = document.createElement('div'); d.textContent = s; return d.innerHTML; }

    function isNearBottom(el) { return el.scrollHeight - el.scrollTop - el.clientHeight < 100; }

    async function updateModelLabel() {
        const label = $('#chat-model-label');
        if (!label) return;
        try {
            const data = await apiJson('/api/settings');
            if (data && data.apiModel) {
                // Show just the model basename (e.g. "claude-3.5-sonnet" from "anthropic/claude-3.5-sonnet")
                const name = data.apiModel.includes('/') ? data.apiModel.split('/').pop() : data.apiModel;
                label.textContent = name;
                label.style.display = '';
            } else {
                label.style.display = 'none';
            }
        } catch { label.style.display = 'none'; }
    }

    async function api(path, opts = {}) {
        const headers = { ...opts.headers };
        if (token) headers['Authorization'] = `Bearer ${token}`;
        if (opts.body && typeof opts.body === 'string') headers['Content-Type'] = 'application/json';
        try {
            const res = await fetch(path, { ...opts, headers });
            if (res.status === 401) { logout(); return null; }
            return res;
        } catch (e) { return null; }
    }

    async function apiJson(path, opts = {}) {
        const res = await api(path, opts);
        if (!res || !res.ok) return null;
        try { return await res.json(); } catch { return null; }
    }

    // ═══════════════════════════════════════════════════════════
    // TEXT FORMATTING — matches _StyledTextController
    // ═══════════════════════════════════════════════════════════

    // ── Image consent tracking ──
    // Stores character IDs that have been consented for external images.
    // Persists in localStorage so consent survives page reloads.
    const IMAGE_CONSENT_KEY = 'image_consent_chars';
    function getImageConsent() {
        try { return JSON.parse(localStorage.getItem(IMAGE_CONSENT_KEY) || '[]'); } catch { return []; }
    }
    function setImageConsent(charId) {
        const list = getImageConsent();
        if (!list.includes(charId)) { list.push(charId); localStorage.setItem(IMAGE_CONSENT_KEY, JSON.stringify(list)); }
    }
    function hasImageConsent(charId) { return getImageConsent().includes(charId); }

    // Pending image loads — URLs that have been checked as cached and can load without consent
    const _cachedImageUrls = new Set();

    function formatText(text) {
        if (!text) return '';
        // Extract ![alt](url) image markdown BEFORE escaping, replace with placeholders
        const imagePlaceholders = [];
        let processed = text.replace(/!\[([^\]]*)\]\(([^)]+)\)/g, (match, alt, url) => {
            const idx = imagePlaceholders.length;
            const charId = currentCharacterId || '';
            const consented = hasImageConsent(charId);
            const cached = _cachedImageUrls.has(url);
            let imgHtml;
            if (consented || cached) {
                if (!consented && cached) setImageConsent(charId);
                const proxyUrl = `/api/image-cache/serve?url=${encodeURIComponent(url)}&token=${encodeURIComponent(token || '')}`;
                imgHtml = `<div class="chat-inline-img-wrap"><img class="chat-inline-img" src="${proxyUrl}" alt="${esc(alt)}" loading="lazy"></div>`;
            } else {
                imgHtml = `<div class="chat-img-consent"><div class="img-consent-icon">\u{1F5BC}\u{FE0F}</div><div class="img-consent-text">External image detected</div><button class="btn btn-sm img-consent-btn" onclick="window._showImageConsentDialog('${url.replace(/'/g, "\\'")}')">View Image</button></div>`;
            }
            imagePlaceholders.push(imgHtml);
            return `%%IMG_${idx}%%`;
        });
        // Now escape and format text
        let html = esc(processed);
        // Quotes: "text" → amber
        html = html.replace(/&quot;([^&]*?)&quot;/g, '<span class="quote">"$1"</span>');
        html = html.replace(/"([^"]*?)"/g, '<span class="quote">"$1"</span>');
        // Actions: *text* → blue italic
        html = html.replace(/\*([^*]+?)\*/g, '<span class="action">*$1*</span>');
        // Restore image placeholders
        for (let i = 0; i < imagePlaceholders.length; i++) {
            html = html.replace(`%%IMG_${i}%%`, imagePlaceholders[i]);
        }
        return html;
    }

    // Show the consent dialog for external images
    window._showImageConsentDialog = function(url) {
        const charId = currentCharacterId || '';

        // First check if already cached on server — skip consent if so
        apiJson(`/api/image-cache/check?url=${encodeURIComponent(url)}`).then(data => {
            if (data && data.cached) {
                _cachedImageUrls.add(url);
                setImageConsent(charId);
                pollChatState(); // Re-render to show the image
                return;
            }
            // Not cached — show warning dialog
            _showImageWarningModal(charId, url);
        }).catch(() => {
            _showImageWarningModal(charId, url);
        });
    };

    function _showImageWarningModal(charId, url) {
        let overlay = $('#image-consent-modal');
        if (!overlay) {
            overlay = document.createElement('div');
            overlay.id = 'image-consent-modal';
            overlay.className = 'modal-overlay';
            document.body.appendChild(overlay);
        }
        overlay.innerHTML = `<div class="modal" style="max-width:440px">
            <div class="modal-title">⚠️ External Image</div>
            <div style="font-size:13px;color:var(--text-secondary);line-height:1.6;margin-bottom:16px">
                <p style="margin:0 0 8px">This message contains an image from an <strong>unverified external source</strong>.</p>
                <p style="margin:0 0 8px"><strong>Security risks:</strong></p>
                <ul style="margin:0 0 8px;padding-left:20px">
                    <li>Your IP address will be exposed to the image host</li>
                    <li>PNG files can potentially contain malicious payloads</li>
                    <li>The host may track when and how often images are viewed</li>
                </ul>
                <p style="margin:0;color:var(--text-muted);font-size:11px">Images are proxied through the server and cached locally. This consent applies to all images for this character.</p>
            </div>
            <div class="modal-actions">
                <button class="btn btn-outlined" id="img-consent-cancel">Block</button>
                <button class="btn btn-primary" id="img-consent-allow">Allow Images</button>
            </div>
        </div>`;
        overlay.classList.add('active');
        overlay.querySelector('#img-consent-cancel').addEventListener('click', () => overlay.classList.remove('active'));
        overlay.querySelector('#img-consent-allow').addEventListener('click', () => {
            setImageConsent(charId);
            overlay.classList.remove('active');
            pollChatState(); // Re-render messages with images loaded
        });
    }

    // ═══════════════════════════════════════════════════════════
    // LOGIN
    // ═══════════════════════════════════════════════════════════

    const loginScreen = $('#login-screen');
    const appShell = $('#app-shell');
    let pinValue = '';
    const PIN_LEN = 6;

    function buildPinPad() {
        const dots = $('#pin-dots');
        dots.innerHTML = '';
        for (let i = 0; i < PIN_LEN; i++) {
            const d = document.createElement('div');
            d.className = 'pin-dot' + (i < pinValue.length ? ' filled' : '');
            dots.appendChild(d);
        }

        const grid = $('#pin-grid');
        if (grid.children.length > 0) return;
        for (let i = 1; i <= 9; i++) addPinBtn(grid, String(i));
        addPinBtn(grid, '⌫', 'backspace');
        addPinBtn(grid, '0');
        addPinBtn(grid, '✓', 'submit');
    }

    function addPinBtn(grid, label, type) {
        const btn = document.createElement('button');
        btn.className = 'pin-btn' + (type === 'submit' ? ' submit' : '');
        btn.textContent = label;
        btn.addEventListener('click', () => {
            if (type === 'backspace') {
                pinValue = pinValue.slice(0, -1);
            } else if (type === 'submit') {
                attemptLogin();
                return;
            } else if (pinValue.length < PIN_LEN) {
                pinValue += label;
            }
            updatePinDots();
            if (pinValue.length === PIN_LEN) attemptLogin();
        });
        grid.appendChild(btn);
    }

    function updatePinDots() {
        const dots = $$('.pin-dot');
        dots.forEach((d, i) => d.classList.toggle('filled', i < pinValue.length));
    }

    async function attemptLogin() {
        const res = await fetch('/api/auth/login', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ pin: pinValue }),
        });
        if (res.ok) {
            const data = await res.json();
            token = data.token;
            sessionStorage.setItem('fp_token', token);
            $('#login-error').textContent = '';
            showApp();
        } else {
            $('#login-error').textContent = 'Invalid PIN';
            pinValue = '';
            updatePinDots();
        }
    }

    // ═══════════════════════════════════════════════════════════
    // APP SHELL
    // ═══════════════════════════════════════════════════════════

    function showApp() {
        loginScreen.classList.add('hidden');
        appShell.classList.add('active');
        loadCharacters();
    }

    function showLogin() {
        loginScreen.classList.remove('hidden');
        appShell.classList.remove('active');
        pinValue = '';
        buildPinPad();
    }

    async function logout() {
        await api('/api/auth/logout', { method: 'POST' });
        token = null;
        sessionStorage.removeItem('fp_token');
        stopPolling();
        disconnectSSE();
        currentCharacterId = null;
        showLogin();
    }

    // ═══════════════════════════════════════════════════════════
    // SIDEBAR NAVIGATION
    // ═══════════════════════════════════════════════════════════

    function initSidebar() {
        $$('.nav-item[data-page]').forEach(item => {
            item.addEventListener('click', (e) => {
                e.preventDefault();
                const page = item.dataset.page;
                switchPage(page);
            });
        });

        // Mobile menu
        $('#mobile-menu-btn')?.addEventListener('click', () => {
            $('#sidebar').classList.toggle('open');
            $('#sidebar-backdrop').classList.toggle('active');
        });

        $('#sidebar-backdrop')?.addEventListener('click', () => {
            $('#sidebar').classList.remove('open');
            $('#sidebar-backdrop').classList.remove('active');
        });
    }

    function switchPage(pageName) {
        // Update nav items
        $$('.nav-item').forEach(n => n.classList.remove('active'));
        const navItem = $(`.nav-item[data-page="${pageName}"]`);
        if (navItem) navItem.classList.add('active');

        // Show page
        $$('.page').forEach(p => p.classList.remove('active'));
        const page = $(`#page-${pageName}`);
        if (page) page.classList.add('active');

        // Hide right panel unless chat
        if (pageName !== 'chat') {
            $('#right-panel').classList.remove('active');
        }

        // Close mobile sidebar
        $('#sidebar').classList.remove('open');
        $('#sidebar-backdrop').classList.remove('active');

        // If leaving chat, clean up
        if (pageName !== 'chat') {
            stopPolling();
            disconnectSSE();
        }

        // Load page-specific data
        if (pageName === 'home') loadCharacters();
        if (pageName === 'settings' || pageName === 'models') loadSettings();
        if (pageName === 'persona') loadPersonas();
        if (pageName === 'worlds') loadWorlds();
        if (pageName === 'sync') loadSyncStatus();
        if (pageName === 'creator' && window.ChargenModule) window.ChargenModule.init();
    }

    // Expose switchPage for external modules (chargen save redirect)
    window._fpSwitchPage = switchPage;

    // Mobile back buttons on sidebar pages
    document.addEventListener('click', (e) => {
        const btn = e.target.closest('.mobile-back-btn');
        if (btn) switchPage(btn.dataset.back || 'home');
    });

    // ═══════════════════════════════════════════════════════════
    // CHARACTER GRID (HOME PAGE)
    // ═══════════════════════════════════════════════════════════

    async function loadCharacters() {
        let url = '/api/characters';
        const params = [];
        if (searchQuery) params.push(`search=${encodeURIComponent(searchQuery)}`);
        if (sortMode) params.push(`sort=${sortMode}`);
        if (activeFolderId) params.push(`folder=${encodeURIComponent(activeFolderId)}`);
        if (params.length) url += '?' + params.join('&');

        const data = await apiJson(url);
        if (!data) return;

        // Fetch folders (unless searching — search bypasses folder hierarchy)
        let folders = [];
        if (!searchQuery) {
            const allFolders = await apiJson('/api/folders') || [];
            // Show folders whose parentId matches activeFolderId (null/empty = top level)
            folders = allFolders.filter(f => {
                const parent = f.parentId || '';
                const active = activeFolderId || '';
                return parent === active;
            });
            folders.sort((a, b) => (a.name || '').localeCompare(b.name || ''));
        }

        allCharactersCache = data.characters || data;
        renderCharacterGrid(allCharactersCache, folders);
    }

    function renderCharacterGrid(characters, folders = []) {
        const grid = $('#char-grid');
        grid.innerHTML = '';
        grid.style.setProperty('--grid-card-size', gridScale + 'px');

        // "Back" card when inside a folder
        if (activeFolderId) {
            const back = document.createElement('div');
            back.className = 'char-card folder-card';
            back.innerHTML = `
                <div class="char-card-img-wrap">
                    <div class="char-card-placeholder" style="font-size:28px">↩</div>
                </div>
                <div class="char-card-info">
                    <div class="char-card-name">← Back</div>
                </div>
            `;
            back.addEventListener('click', () => {
                const prev = folderStack.pop();
                activeFolderId = prev || null;
                loadCharacters();
            });
            grid.appendChild(back);
        }

        // Render folder cards
        folders.forEach(f => {
            const card = document.createElement('div');
            card.className = 'char-card folder-card';
            const count = f.characterCount || 0;
            card.innerHTML = `
                <div class="char-card-img-wrap">
                    <div class="char-card-placeholder" style="font-size:28px">📁</div>
                    <button class="char-card-delete" title="Delete folder">🗑️</button>
                </div>
                <div class="char-card-info">
                    <div class="char-card-name">${esc(f.name)}</div>
                    <div style="font-size:11px;color:var(--text-muted)">${count} character${count === 1 ? '' : 's'}</div>
                </div>
            `;
            // Delete folder
            card.querySelector('.char-card-delete').addEventListener('click', async (e) => {
                e.stopPropagation();
                if (!confirm(`Delete folder "${f.name}"? Characters inside will be unfoldered.`)) return;
                const res = await api('/api/folders/delete', {
                    method: 'POST',
                    body: JSON.stringify({ id: f.id }),
                });
                if (res && res.ok) loadCharacters();
            });
            // Right-click to rename
            card.addEventListener('contextmenu', async (e) => {
                e.preventDefault();
                const newName = prompt('Rename folder:', f.name);
                if (!newName || !newName.trim() || newName.trim() === f.name) return;
                const res = await api('/api/folders/rename', {
                    method: 'POST',
                    body: JSON.stringify({ id: f.id, name: newName.trim() }),
                });
                if (res && res.ok) loadCharacters();
            });
            card.addEventListener('click', () => {
                if (activeFolderId) folderStack.push(activeFolderId);
                activeFolderId = f.id;
                loadCharacters();
            });
            grid.appendChild(card);
        });

        // Render group cards (only at top level, not searching, not selecting)
        if (!activeFolderId && !searchQuery && !isSelectingForGroup) {
            apiJson('/api/groups').then(groups => {
                if (!groups || !Array.isArray(groups) || groups.length === 0) return;
                const firstCharCard = grid.querySelector('.char-card:not(.folder-card):not(.group-card)');
                groups.forEach(g => {
                    const gcard = document.createElement('div');
                    gcard.className = 'char-card group-card';
                    const memberNames = (g.character_ids || []).slice(0, 3).map(cid => {
                        const c = allCharactersCache.find(ch => ch.charId === cid);
                        return c ? c.name : cid;
                    });
                    const moreCount = (g.character_ids || []).length - 3;
                    const nameList = memberNames.join(', ') + (moreCount > 0 ? ` +${moreCount}` : '');
                    gcard.innerHTML = `
                        <div class="char-card-img-wrap">
                            <div class="char-card-placeholder" style="font-size:24px">👥</div>
                            <button class="char-card-delete" title="Delete group">🗑️</button>
                        </div>
                        <div class="char-card-info">
                            <div class="char-card-name">${esc(g.name)}</div>
                            <div style="font-size:11px;color:var(--text-muted)">${nameList}</div>
                            ${g.director_mode ? '<div style="font-size:10px;color:#FBBF24">🎬 Director</div>' : ''}
                        </div>
                    `;
                    gcard.querySelector('.char-card-delete').addEventListener('click', async (e) => {
                        e.stopPropagation();
                        if (!confirm(`Delete group "${g.name}"? Characters will NOT be deleted.`)) return;
                        const res = await api('/api/groups/delete', {
                            method: 'POST', body: JSON.stringify({ id: g.id }),
                        });
                        if (res && res.ok) loadCharacters();
                    });
                    gcard.addEventListener('click', async () => {
                        const res = await apiJson('/api/groups/select', {
                            method: 'POST', body: JSON.stringify({ id: g.id }),
                        });
                        if (res) {
                            currentCharacterId = g.id;
                            currentCharacterName = g.name;
                            currentCharacterDesc = '';
                            currentCharacterHasAvatar = false;
                            showChatView(g.name, '', false);
                        }
                    });
                    if (firstCharCard) grid.insertBefore(gcard, firstCharCard);
                    else grid.appendChild(gcard);
                });
            });
        }

        // Render character cards
        if (!characters || characters.length === 0) {
            if (folders.length === 0 && !activeFolderId) {
                grid.innerHTML = `<div style="grid-column:1/-1;text-align:center;color:rgba(255,255,255,0.38);padding:60px 0;">
                    ${searchQuery ? `No characters match "${esc(searchQuery)}"` : 'No characters found'}
                </div>`;
            }
            return;
        }

        characters.forEach(char => {
            const card = document.createElement('div');
            card.className = 'char-card' + (isSelectingForGroup && selectedForGroup.has(char.charId) ? ' group-selected' : '');
            card.dataset.id = char.id;

            const avatarUrl = char.hasAvatar
                ? `/api/characters/${char.id}/avatar?token=${encodeURIComponent(token)}`
                : '';

            const tagsHtml = (char.tags || []).slice(0, 3).map(t =>
                `<span class="tag-pill">${esc(t)}</span>`
            ).join('');

            const checkboxHtml = isSelectingForGroup
                ? `<div class="group-select-check">${selectedForGroup.has(char.charId) ? '☑' : '☐'}</div>`
                : '';

            card.innerHTML = `
                <div class="char-card-img-wrap">
                    ${char.hasAvatar
                    ? `<img class="char-card-img" src="${avatarUrl}" alt="${esc(char.name)}" loading="lazy">`
                    : `<div class="char-card-placeholder">${esc(char.name.charAt(0).toUpperCase())}</div>`
                }
                    ${checkboxHtml}
                    ${!isSelectingForGroup ? '<button class="char-card-export" title="Export PNG" style="position:absolute;top:4px;left:4px;background:rgba(0,0,0,0.6);border:none;border-radius:50%;width:28px;height:28px;cursor:pointer;font-size:14px;display:flex;align-items:center;justify-content:center;z-index:2">📥</button><button class="char-card-delete" title="Delete character">🗑️</button>' : ''}
                </div>
                <div class="char-card-info">
                    <div style="display:flex;align-items:center;gap:4px">
                        <div class="char-card-name" style="flex:1;min-width:0">${esc(char.name)}</div>
                        ${(char.messageCount || 0) > 0 ? `<span class="char-card-msg-count"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z"/></svg>${char.messageCount}</span>` : ''}
                    </div>
                    ${char.description ? `<div class="char-card-desc">${esc(char.description.replace(/\{\{char\}\}/gi, char.name).replace(/\{char\}/gi, char.name).replace(/<char>/gi, char.name))}</div>` : ''}
                    ${tagsHtml ? `<div class="char-card-tags">${tagsHtml}</div>` : ''}
                </div>
            `;

            if (isSelectingForGroup) {
                card.addEventListener('click', () => {
                    if (selectedForGroup.has(char.charId)) {
                        selectedForGroup.delete(char.charId);
                    } else {
                        selectedForGroup.add(char.charId);
                    }
                    // Update UI
                    const countEl = $('#group-select-count');
                    const createBtn = $('#btn-create-group');
                    if (countEl) countEl.textContent = selectedForGroup.size >= 2
                        ? `${selectedForGroup.size} characters selected`
                        : `Select ${2 - selectedForGroup.size} more`;
                    if (createBtn) createBtn.disabled = selectedForGroup.size < 2;
                    // Re-render
                    renderCharacterGrid(allCharactersCache, []);
                });
            } else {
                // Delete button
                card.querySelector('.char-card-delete').addEventListener('click', async (e) => {
                    e.stopPropagation();
                    if (!confirm(`Delete "${char.name}"? This cannot be undone.`)) return;
                    const res = await api(`/api/characters/${char.id}/delete`, { method: 'POST' });
                    if (res && res.ok) loadCharacters();
                });

                // Export PNG button
                card.querySelector('.char-card-export').addEventListener('click', (e) => {
                    e.stopPropagation();
                    const a = document.createElement('a');
                    a.href = `/api/characters/${char.id}/export.png?token=` + encodeURIComponent(sessionStorage.getItem('fp_token') || '');
                    a.download = (char.name || 'character').replace(/[^a-zA-Z0-9_-]/g, '_') + '.png';
                    a.click();
                });

                card.addEventListener('click', () => selectCharacter(char));
            }
            grid.appendChild(card);
        });
    }

    // ═══════════════════════════════════════════════════════════
    // GROUP CREATION MODAL
    // ═══════════════════════════════════════════════════════════

    const DEFAULT_GROUP_SYSTEM_PROMPT = 'You are roleplaying in a multi-character group conversation. CRITICAL RULES:\n1. You MUST only write dialogue and actions for the character whose turn it is (indicated after <START>). NEVER write dialogue, thoughts, or actions for other characters or {{user}}.\n2. Stay fully in character — use the speaking character\'s unique voice, mannerisms, personality, and speech patterns.\n3. Keep your response focused on ONE character\'s contribution. Do not narrate what other characters do or say.\n4. React naturally to what other characters and {{user}} have said. Reference their words, but do not put words in their mouths.\n5. Write in the style of collaborative roleplay: use *asterisks* for actions/narration and regular text for dialogue.\n6. Keep responses concise and punchy — leave room for the next character to respond.\n7. Never break character or reference the fact that you are an AI.';

    const OBSERVER_MODE_SYSTEM_PROMPT = 'You are roleplaying in a multi-character group conversation. The user is NOT a participant in this story — they are an invisible observer/director. CRITICAL RULES:\n1. You MUST only write dialogue and actions for the character whose turn it is. NEVER write for other characters.\n2. Characters should interact naturally WITH EACH OTHER — address other characters by name, respond to what they said, react to their actions. Build on the conversation organically.\n3. Stay fully in character — use the speaking character\'s unique voice and personality.\n4. If a [Director] note appears, follow its guidance to steer the scene (introduce new topics, create conflict, have a character enter/leave, etc.) but do NOT acknowledge the director directly.\n5. Write in collaborative roleplay style: *asterisks* for actions, regular text for dialogue.\n6. Keep responses concise — leave room for the next character to respond.\n7. Never break character or reference being an AI.\n8. Characters may naturally address each other, start side conversations, argue, agree, tell stories, ask questions, or react emotionally — make the conversation feel alive and dynamic.';

    function showGroupCreationModal() {
        const selectedChars = allCharactersCache.filter(c => selectedForGroup.has(c.charId));
        if (selectedChars.length < 2) return;

        const defaultName = selectedChars.map(c => c.name).join(' & ');

        // Build modal overlay
        const overlay = document.createElement('div');
        overlay.className = 'modal-overlay active';
        overlay.id = 'group-create-modal';

        overlay.innerHTML = `
        <div class="group-create-dialog">
            <h2 style="display:flex;align-items:center;gap:8px;margin:0 0 16px 0;color:#fff">
                <span style="font-size:20px">👥</span> Create Group Chat
            </h2>

            <div class="group-warn-banner">
                ⚠️ Pre-Alpha Feature — expect rough edges depending on model quality
            </div>

            <div class="group-chips" id="group-chips">
                ${selectedChars.map(c => `<span class="group-chip">${esc(c.name)}</span>`).join('')}
            </div>

            <label class="group-label">Group Name</label>
            <input type="text" id="group-name" class="group-input" value="${esc(defaultName)}" placeholder="Enter a group name...">

            <label class="group-label" style="margin-top:12px">Turn Order</label>
            <div class="group-toggle-row">
                <button class="group-toggle active" data-order="roundRobin">🔄 Round Robin</button>
                <button class="group-toggle" data-order="random">🎲 Random</button>
            </div>

            <div class="group-switch-row">
                <label class="group-switch-label">
                    <input type="checkbox" id="group-auto-advance">
                    <span>Auto-Advance</span>
                </label>
                <span class="group-hint">Characters respond automatically one-by-one</span>
            </div>

            <div class="group-switch-row" style="border-color:#FBBF24">
                <label class="group-switch-label">
                    <input type="checkbox" id="group-director-mode">
                    <span>🎬 Director Mode</span>
                </label>
                <span class="group-hint" style="color:#FBBF24">Characters chat autonomously — you direct the scene</span>
            </div>

            <div class="group-field-row">
                <label class="group-label">Scenario <span style="color:var(--text-muted)">(optional)</span></label>
                <button id="btn-gen-scenario" class="group-gen-btn">✨ Generate</button>
            </div>
            <textarea id="group-scenario" class="group-textarea" rows="2" placeholder="e.g. {{user}} and friends are at a rooftop bar..."></textarea>

            <div class="group-field-row">
                <label class="group-label">First Message <span style="color:var(--text-muted)">(optional)</span></label>
                <button id="btn-gen-first-msg" class="group-gen-btn">✨ Generate</button>
            </div>
            <textarea id="group-first-msg" class="group-textarea" rows="5" placeholder="Custom greeting or tap ✨ Generate"></textarea>

            <label class="group-label" style="margin-top:12px">System Prompt</label>
            <textarea id="group-system-prompt" class="group-textarea" rows="3">${esc(DEFAULT_GROUP_SYSTEM_PROMPT)}</textarea>

            <div class="group-actions">
                <button id="btn-group-cancel" class="btn btn-secondary">Cancel</button>
                <button id="btn-group-create-final" class="btn btn-primary" style="background:#8B5CF6">Create</button>
            </div>
        </div>
        `;

        document.body.appendChild(overlay);

        // State
        let turnOrder = 'roundRobin';
        let isGeneratingScenario = false;
        let isGeneratingFirstMsg = false;

        // Turn order toggles
        overlay.querySelectorAll('.group-toggle').forEach(btn => {
            btn.addEventListener('click', () => {
                overlay.querySelectorAll('.group-toggle').forEach(b => b.classList.remove('active'));
                btn.classList.add('active');
                turnOrder = btn.dataset.order;
            });
        });

        // Director mode auto-generates
        const directorCheck = overlay.querySelector('#group-director-mode');
        const autoAdvCheck = overlay.querySelector('#group-auto-advance');
        directorCheck.addEventListener('change', async () => {
            if (directorCheck.checked) {
                autoAdvCheck.checked = true;
                autoAdvCheck.disabled = true;
                overlay.querySelector('#group-system-prompt').value = OBSERVER_MODE_SYSTEM_PROMPT;
                // Auto-generate scenario then first message
                await generateScenario(true);
            } else {
                autoAdvCheck.disabled = false;
                overlay.querySelector('#group-system-prompt').value = DEFAULT_GROUP_SYSTEM_PROMPT;
            }
        });

        // Generate scenario
        async function generateScenario(chainFirstMsg = false) {
            if (isGeneratingScenario) return;
            isGeneratingScenario = true;
            const btn = overlay.querySelector('#btn-gen-scenario');
            btn.textContent = '⏳ Generating...';
            btn.disabled = true;

            const isDirector = directorCheck.checked;
            const charBriefs = selectedChars.map(c => {
                const trait = c.personality ? c.personality.split('.')[0]
                    : (c.description ? c.description.split('.')[0] : c.name);
                return `${c.name} (${trait})`;
            }).join(', ');

            const prompt = isDirector
                ? `[Output ONLY the scenario text. No planning, reasoning, or explanation. Do NOT use <think> tags.]\n\nWrite a brief scenario (1-2 sentences max) for a group roleplay with: ${charBriefs}.\nThis is a DIRECTOR MODE scenario — there is NO user/player present. The characters interact ONLY with each other.\nDescribe WHERE the characters are and WHAT is happening between them.\n\nSCENARIO: `
                : `[Output ONLY the scenario text. No planning, reasoning, or explanation. Do NOT use <think> tags.]\n\nWrite a brief scenario (1-2 sentences max) for a group roleplay with: ${charBriefs}.\nThe scenario should describe WHERE the characters are and WHAT is happening.\nUse {{user}} to refer to the player. Keep it concise.\n\nSCENARIO: `;

            try {
                const res = await apiJson('/api/generate', {
                    method: 'POST',
                    body: JSON.stringify({
                        prompt, maxLength: 500, temperature: 0.9,
                        stopSequences: ['\n\n', 'END', '---', '<think>'],
                    }),
                });
                if (res && res.text) {
                    let text = res.text
                        .replace(/<think>[\s\S]*?<\/think>/gi, '')
                        .replace(/<think>[\s\S]*$/gi, '')
                        .replace(/<\/think>/gi, '')
                        .replace(/^SCENARIO:\s*/i, '')
                        .replace(/"/g, '')
                        .trim();
                    if (text) overlay.querySelector('#group-scenario').value = text;
                }
            } catch (e) { console.error('Scenario gen failed:', e); }

            btn.textContent = '✨ Generate';
            btn.disabled = false;
            isGeneratingScenario = false;

            if (chainFirstMsg) await generateFirstMessage();
        }

        // Generate first message
        async function generateFirstMessage() {
            if (isGeneratingFirstMsg) return;
            isGeneratingFirstMsg = true;
            const btn = overlay.querySelector('#btn-gen-first-msg');
            btn.textContent = '⏳ Generating...';
            btn.disabled = true;

            const isDirector = directorCheck.checked;
            const charDescriptions = selectedChars.map(c => {
                const persona = c.personality || c.description;
                return `- ${c.name}: ${persona}`;
            }).join('\n');
            const scenarioCtx = overlay.querySelector('#group-scenario').value.trim();
            const scenarioLine = scenarioCtx ? `\nThe ${isDirector ? '' : 'group '}scenario is: ${scenarioCtx}` : '';

            const prompt = isDirector
                ? `[INSTRUCTIONS: Output ONLY the creative scene text. Do NOT plan, reason, analyze, or explain. Do NOT use <think> tags. Start writing IMMEDIATELY.]\n\nWrite a vivid, immersive opening scene (3-5 paragraphs) for a DIRECTOR MODE group roleplay featuring:\n${charDescriptions}\n${scenarioLine}\n\nCRITICAL: There is NO user/player present. Characters interact ONLY with each other.\nEach character MUST have at least 2 lines of dialogue.\nCharacters address and react to EACH OTHER.\nUse *asterisks* for actions.\nWhen done, write "END SCENE" on its own line.\n\nBEGIN SCENE:\n`
                : `[INSTRUCTIONS: Output ONLY the creative scene text. Do NOT plan, reason, analyze, or explain. Do NOT use <think> tags. Start writing the scene IMMEDIATELY.]\n\nWrite a vivid, immersive opening scene (4-6 paragraphs, at least 400 words) for a group roleplay featuring:\n${charDescriptions}\n${scenarioLine}\n\nCRITICAL REQUIREMENTS:\n- {{user}} is PRESENT in the scene. Characters notice, acknowledge, and speak TO {{user}}.\n- EACH character MUST have at least 2 lines of spoken dialogue using quotation marks.\n- Characters MUST interact with EACH OTHER.\n- Use *asterisks* for actions and descriptions.\n- Do NOT write any dialogue, thoughts, or actions for {{user}}.\n- End with a character directly addressing {{user}}.\n- When done, write "END SCENE" on its own line.\n\nBEGIN SCENE:\n`;

            try {
                const res = await apiJson('/api/generate', {
                    method: 'POST',
                    body: JSON.stringify({
                        prompt, maxLength: isDirector ? 2000 : 4000, temperature: 0.85,
                        stopSequences: ['END SCENE', '---', '[END]', '<think>'],
                    }),
                });
                if (res && res.text) {
                    let text = res.text
                        .replace(/<think>[\s\S]*?<\/think>/gi, '')
                        .replace(/<think>[\s\S]*$/gi, '')
                        .replace(/<\/think>/gi, '');
                    const marker = text.indexOf('BEGIN SCENE:');
                    if (marker >= 0) text = text.substring(marker + 'BEGIN SCENE:'.length);
                    text = text.split('\n').filter(line => {
                        const t = line.trimStart();
                        return !(t.startsWith('The user wants') || t.startsWith('I need to') ||
                            t.startsWith('I will') || t.startsWith('I should') ||
                            t.startsWith('Let me ') || t.startsWith("I'll ") ||
                            /^\d+\.\s+(Write|Use|Set|Make|Do|Keep|NOT|Create|End|Establish)/.test(t));
                    }).join('\n').trim();
                    if (text) overlay.querySelector('#group-first-msg').value = text;
                }
            } catch (e) { console.error('First message gen failed:', e); }

            btn.textContent = '✨ Generate';
            btn.disabled = false;
            isGeneratingFirstMsg = false;
        }

        overlay.querySelector('#btn-gen-scenario').addEventListener('click', () => generateScenario(false));
        overlay.querySelector('#btn-gen-first-msg').addEventListener('click', () => generateFirstMessage());

        // Cancel
        overlay.querySelector('#btn-group-cancel').addEventListener('click', () => overlay.remove());
        overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });

        // Create
        overlay.querySelector('#btn-group-create-final').addEventListener('click', async () => {
            const name = overlay.querySelector('#group-name').value.trim();
            if (!name) { alert('Group name is required'); return; }

            const body = {
                name,
                character_ids: [...selectedForGroup],
                turn_order: turnOrder,
                auto_advance: autoAdvCheck.checked,
                director_mode: directorCheck.checked,
                first_message: overlay.querySelector('#group-first-msg').value.trim(),
                scenario: overlay.querySelector('#group-scenario').value.trim(),
                system_prompt: overlay.querySelector('#group-system-prompt').value.trim(),
            };

            const res = await apiJson('/api/groups/create', {
                method: 'POST', body: JSON.stringify(body),
            });

            if (res && res.id) {
                overlay.remove();
                // Exit selection mode
                isSelectingForGroup = false;
                selectedForGroup.clear();
                $('#btn-select-group').style.outline = '';
                const bar = $('#group-select-bar');
                if (bar) bar.remove();
                loadCharacters();
            } else {
                alert('Failed to create group');
            }
        });
    }

    // ═══════════════════════════════════════════════════════════
    // CHARACTER SELECTION → CHAT
    // ═══════════════════════════════════════════════════════════

    async function selectCharacter(char) {
        // Server expects POST /api/chat/select with {characterId: id} in body
        const result = await apiJson('/api/chat/select', {
            method: 'POST',
            body: JSON.stringify({ characterId: char.id }),
        });
        if (!result) return;

        currentCharacterId = char.id;
        currentCharacterName = char.name;
        currentCharacterDesc = (char.description || '').replace(/\{\{char\}\}/gi, char.name).replace(/\{char\}/gi, char.name).replace(/<char>/gi, char.name);
        currentCharacterHasAvatar = char.hasAvatar;

        // Update chat appbar
        $('#chat-char-name').textContent = char.name;
        $('#chat-char-desc').textContent = currentCharacterDesc.length > 40
            ? currentCharacterDesc.substring(0, 40) + '...'
            : currentCharacterDesc;

        // Fetch and show current model name
        updateModelLabel();

        const avatarEl = $('#chat-avatar');
        if (char.hasAvatar) {
            avatarEl.src = `/api/characters/${char.id}/avatar?token=${encodeURIComponent(token)}`;
            avatarEl.style.display = '';
        } else {
            avatarEl.style.display = 'none';
        }

        // Update right panel
        const rpImg = $('#rp-char-img');
        if (char.hasAvatar) {
            rpImg.src = `/api/characters/${char.id}/avatar?token=${encodeURIComponent(token)}`;
            rpImg.style.display = '';
        } else {
            rpImg.style.display = 'none';
        }

        // Fill right panel text
        const replaceCharPlaceholders = (text) => (text || '').replace(/\{\{char\}\}/gi, char.name).replace(/\{char\}/gi, char.name).replace(/<char>/gi, char.name);
        $('#rp-scenario').textContent = replaceCharPlaceholders(char.scenario);
        $('#rp-description').textContent = replaceCharPlaceholders(char.description);

        // Author's note will be loaded from chat state once SSE connects

        // Switch to chat page and show right panel
        switchPage('chat');
        $('#right-panel').classList.add('active');

        // Clear old messages and connect
        $('#chat-messages').innerHTML = '';
        lastMessageCount = 0;
        window._lastMessages = null;

        connectSSE();
        startPolling();
    }

    // ═══════════════════════════════════════════════════════════
    // CHAT STATE POLLING (fallback — SSE handles real-time)
    // ═══════════════════════════════════════════════════════════

    function startPolling() {
        stopPolling();
        pollChatState();
        pollTimer = setInterval(pollChatState, 3000);
    }

    function stopPolling() {
        if (pollTimer) { clearInterval(pollTimer); pollTimer = null; }
    }

    async function pollChatState() {
        const data = await apiJson('/api/chat/state');
        if (!data) return;
        window._chatState = data;
        renderMessages(data.messages || [], data);
        updateGenerationUI(data);

        // Populate author's note (only on first load or if empty)
        const noteEl = $('#rp-author-note');
        if (noteEl && data.authorNote !== undefined && !noteEl._loaded) {
            noteEl.value = data.authorNote || '';
            noteEl._loaded = true;
        }
        const strengthEl = $('#rp-author-strength');
        if (strengthEl && data.authorNoteDepth !== undefined && !strengthEl._loaded) {
            strengthEl.value = data.authorNoteDepth || 4;
            strengthEl._loaded = true;
            try { updateStrengthLabel(strengthEl.value); } catch (_) { }
        }

        // Update summary panel
        const summarySection = $('#rp-summary-section');
        if (summarySection) {
            // Show the section if summary exists or is generating
            const hasSummary = data.summary || data.isSummaryGenerating;
            summarySection.style.display = hasSummary ? '' : 'none';

            const summaryEl = $('#rp-summary-text');
            if (summaryEl && data.summary !== undefined && !summaryEl._userEditing) {
                summaryEl.value = data.summary || '';
            }

            const spinner = $('#rp-summary-spinner');
            if (spinner) spinner.style.display = data.isSummaryGenerating ? '' : 'none';

            const pauseBtn = $('#btn-summary-pause');
            if (pauseBtn) {
                pauseBtn.textContent = data.summaryPaused ? '▶ Resume' : '⏸ Pause';
            }

            const statusEl = $('#rp-summary-status');
            if (statusEl && data.summaryLastIndex > 0) {
                statusEl.textContent = `Last updated at message #${data.summaryLastIndex}`;
            }
        }

        // Update lorebook triggers panel
        const loreEl = $('#rp-lorebook');
        if (loreEl && data.lorebook) {
            if (data.lorebook.length === 0) {
                loreEl.innerHTML = '<span style="color:rgba(255,255,255,0.3)">No lorebook entries.</span>';
            } else {
                loreEl.innerHTML = data.lorebook.map(e => {
                    let dotColor = '#EF4444'; // red = inactive
                    if (e.constant) dotColor = '#3B82F6'; // blue = always active
                    else if (e.isTriggered) dotColor = '#4ADE80'; // green = triggered
                    const textColor = (e.isTriggered || e.constant) ? 'rgba(255,255,255,0.9)' : 'rgba(255,255,255,0.5)';
                    const label = e.key && !e.constant ? e.name : (e.constant ? '⚡ Always Active' : e.name);
                    return `<div style="display:flex;align-items:center;gap:8px;padding:3px 0">
                        <span style="width:8px;height:8px;border-radius:50%;background:${dotColor};flex-shrink:0;display:inline-block"></span>
                        <span style="color:${textColor};font-size:12px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${esc(e.key || '')}">${esc(label)}</span>
                    </div>`;
                }).join('');
            }
        }
    }

    // ═══════════════════════════════════════════════════════════
    // SSE STREAMING
    // ═══════════════════════════════════════════════════════════

    function connectSSE() {
        disconnectSSE();
        if (!token) return;

        sseSource = new AbortController();

        fetch('/api/chat/stream', {
            headers: { 'Authorization': `Bearer ${token}` },
            signal: sseSource.signal,
        }).then(response => {
            console.log('[SSE] Stream response status:', response.status);
            if (!response.ok) {
                console.error('[SSE] Stream failed with status:', response.status);
                setTimeout(connectSSE, 3000);
                return;
            }
            const reader = response.body.getReader();
            const decoder = new TextDecoder();
            let buffer = '';

            function processStream() {
                reader.read().then(({ done, value }) => {
                    if (done) { console.log('[SSE] Stream ended'); setTimeout(connectSSE, 2000); return; }

                    buffer += decoder.decode(value, { stream: true });
                    const lines = buffer.split('\n\n');
                    buffer = lines.pop();

                    for (const line of lines) {
                        if (line.startsWith('data: ')) {
                            try {
                                const event = JSON.parse(line.substring(6));
                                console.log('[SSE] Event:', event.event, event.data ? event.data.substring(0, 20) : '');
                                handleSSEEvent(event);
                            } catch (e) { console.error('[SSE] Parse error:', e); }
                        }
                    }
                    processStream();
                }).catch(err => {
                    if (err.name !== 'AbortError') {
                        console.error('[SSE] Read error:', err);
                        setTimeout(connectSSE, 3000);
                    }
                });
            }

            processStream();
        }).catch(err => {
            if (err.name !== 'AbortError') {
                console.error('[SSE] Connection error:', err);
                setTimeout(connectSSE, 3000);
            }
        });
    }

    function disconnectSSE() {
        if (sseSource) { sseSource.abort(); sseSource = null; }
    }

    // ── Generation stats tracking ──
    let genStartTime = 0;
    let genTokenCount = 0;

    // ── Smooth display buffer ──
    // Incoming tokens are buffered and drained at a smooth rate
    let tokenBuffer = '';       // Characters waiting to be displayed
    let displayedText = '';     // What's currently shown on screen
    let fullReceivedText = '';  // All text received so far
    let drainTimer = null;
    const DRAIN_INTERVAL_MS = 16;  // ~60fps
    const CHARS_PER_FRAME = 3;     // Characters to show per frame (adjust for speed)

    function startDraining() {
        if (drainTimer) return;
        drainTimer = setInterval(() => {
            if (tokenBuffer.length === 0) return;

            // Calculate how many chars to drain based on buffered amount
            // If buffer is growing large, drain faster to keep up
            const charsThisFrame = tokenBuffer.length > 50
                ? Math.min(tokenBuffer.length, CHARS_PER_FRAME * 4)
                : CHARS_PER_FRAME;

            const chunk = tokenBuffer.substring(0, charsThisFrame);
            tokenBuffer = tokenBuffer.substring(charsThisFrame);
            displayedText += chunk;
            updateStreamingMessage(displayedText);
        }, DRAIN_INTERVAL_MS);
    }

    function stopDraining() {
        if (drainTimer) { clearInterval(drainTimer); drainTimer = null; }
    }

    function flushBuffer() {
        // Show all remaining text immediately
        if (tokenBuffer.length > 0) {
            displayedText += tokenBuffer;
            tokenBuffer = '';
            updateStreamingMessage(displayedText);
        }
        stopDraining();
    }

    function handleSSEEvent(event) {
        switch (event.event) {
            case 'connected':
                console.log('[SSE] Connected');
                break;

            case 'generating':
                isStreaming = true;
                streamingText = '';
                fullReceivedText = '';
                displayedText = '';
                tokenBuffer = '';
                genStartTime = performance.now();
                genTokenCount = 0;
                showGeneratingUI(true);
                startDraining();
                break;

            case 'token':
                if (!isStreaming) {
                    isStreaming = true;
                    streamingText = '';
                    fullReceivedText = '';
                    displayedText = '';
                    tokenBuffer = '';
                    genStartTime = performance.now();
                    genTokenCount = 0;
                    showGeneratingUI(true);
                    startDraining();
                }
                fullReceivedText += event.data;
                streamingText = fullReceivedText;
                tokenBuffer += event.data;
                genTokenCount++;
                updateGenStats();
                break;

            case 'done':
                isStreaming = false;
                flushBuffer();
                showGeneratingUI(false);
                pollChatState();
                break;

            case 'error':
                isStreaming = false;
                flushBuffer();
                showGeneratingUI(false);
                pollChatState();
                break;

            case 'chat_updated':
                pollChatState();
                break;

            case 'disconnected':
                disconnectSSE();
                break;
        }
    }

    function updateGenStats() {
        const elapsed = (performance.now() - genStartTime) / 1000; // seconds
        const tps = elapsed > 0 ? (genTokenCount / elapsed).toFixed(1) : '0.0';

        const tpsEl = $('#gen-tps');
        const tokensEl = $('#gen-tokens');

        if (tpsEl) tpsEl.textContent = `⚡ ${tps} T/s`;
        if (tokensEl) tokensEl.textContent = `${genTokenCount} tokens`;
    }

    function showGeneratingUI(show) {
        const genBar = $('#gen-bar');
        const sendBtn = $('#btn-send');
        const stopBtn = $('#btn-stop');

        if (show) {
            genBar.classList.add('active');
            sendBtn.classList.add('hidden');
            stopBtn.classList.remove('hidden');
        } else {
            genBar.classList.remove('active');
            sendBtn.classList.remove('hidden');
            stopBtn.classList.add('hidden');
            // Clear stats on done
            const tpsEl = $('#gen-tps');
            const tokensEl = $('#gen-tokens');
            if (tpsEl) tpsEl.textContent = '';
            if (tokensEl) tokensEl.textContent = '';
        }
    }

    function updateStreamingMessage(text) {
        const container = $('#chat-messages');
        let streamEl = container.querySelector('.message-streaming');

        if (!streamEl) {
            streamEl = document.createElement('div');
            streamEl.className = 'message message-ai message-streaming';
            streamEl.innerHTML = `
                <div class="message-sender">
                    <span class="message-sender-name">${esc(currentCharacterName || 'AI')}</span>
                </div>
                <div class="message-text"></div>
            `;
            container.appendChild(streamEl);
        }

        streamEl.querySelector('.message-text').innerHTML = formatText(text.trimStart());

        const wrap = $('#chat-messages-wrap');
        if (isNearBottom(wrap)) {
            requestAnimationFrame(() => { wrap.scrollTop = wrap.scrollHeight; });
        }
    }

    // ═══════════════════════════════════════════════════════════
    // MESSAGE RENDERING
    // ═══════════════════════════════════════════════════════════

    function updateGenerationUI(data) {
        if (data.isGenerating && !isStreaming) {
            showGeneratingUI(true);
        } else if (!data.isGenerating && !isStreaming) {
            showGeneratingUI(false);
        }
    }

    function renderMessages(messages, chatState) {
        const container = $('#chat-messages');
        const wrap = $('#chat-messages-wrap');
        const shouldScroll = isNearBottom(wrap);

        // Remove streaming element if generation done
        if (!isStreaming) {
            const streamEl = container.querySelector('.message-streaming');
            if (streamEl) streamEl.remove();
        }

        // Re-render if count changed
        if (messages.length !== lastMessageCount || needsRerender(messages)) {
            const streamEl = container.querySelector('.message-streaming');
            container.innerHTML = '';

            messages.forEach((msg, index) => {
                container.appendChild(createMessageElement(msg, index, messages.length, chatState || window._chatState || {}));
            });

            if (streamEl && isStreaming) container.appendChild(streamEl);

            lastMessageCount = messages.length;
            window._lastMessages = messages;
            window._lastChatState = chatState || window._chatState || {};

            if (shouldScroll) {
                requestAnimationFrame(() => { wrap.scrollTop = wrap.scrollHeight; });
            }
        }
    }

    function needsRerender(messages) {
        if (!window._lastMessages) return true;
        if (messages.length !== window._lastMessages.length) return true;
        // Check ALL messages for text or swipe changes
        for (let i = 0; i < messages.length; i++) {
            if (messages[i].text !== window._lastMessages[i].text) return true;
            if (messages[i].activeSwipeIndex !== window._lastMessages[i].activeSwipeIndex) return true;
        }
        // Check if greetingIndex changed
        const cs = window._chatState || {};
        const lastCs = window._lastChatState || {};
        if (cs.greetingIndex !== lastCs.greetingIndex) return true;
        return false;
    }

    function createMessageElement(msg, index, totalMessages, chatState) {
        const el = document.createElement('div');
        const isUser = msg.isUser;
        el.className = `message ${isUser ? 'message-user' : 'message-ai'}`;

        // Sender with name
        const personaName = chatState.userPersonaName || 'You';
        const senderName = msg.sender || (isUser ? personaName : currentCharacterName || 'AI');
        const charName = currentCharacterName || 'AI';
        // Replace {{user}}, {user}, <user> and {{char}}, {char}, {character}, <char> placeholders
        let displayText = (msg.text || '')
            .replace(/<think>[\s\S]*?<\/think>/gi, '')
            .replace(/<think>[\s\S]*$/gi, '')
            .replace(/<\/think>/gi, '')
            .replace(/\{\{user\}\}/gi, personaName)
            .replace(/\{user\}/gi, personaName)
            .replace(/<user>/gi, personaName)
            .replace(/\{\{char\}\}/gi, charName)
            .replace(/\{char\}/gi, charName)
            .replace(/\{character\}/gi, charName)
            .replace(/<char>/gi, charName)
            .trim();
        const isLastAiMsg = !isUser && index === totalMessages - 1 && !chatState.isGenerating;

        // Message actions (hover) — edit, fork, delete
        const actionsHtml = `
            <div class="message-actions">
                <button class="msg-action-btn" title="Edit" data-action="edit" data-index="${index}">
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"/></svg>
                </button>
                <button class="msg-action-btn" title="Fork from here" data-action="fork" data-index="${index}">
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="M14 4l2.29 2.29-2.88 2.88 1.42 1.42 2.88-2.88L20 10V4h-6zM10 4H4v6l2.29-2.29 4.71 4.7V20h2v-8.41l-5.29-5.3L10 4z"/></svg>
                </button>
                <button class="msg-action-btn" title="Delete" data-action="delete" data-index="${index}">
                    <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="M6 19c0 1.1.9 2 2 2h8c1.1 0 2-.9 2-2V7H6v12zM19 4h-3.5l-1-1h-5l-1 1H5v2h14V4z"/></svg>
                </button>
            </div>
        `;

        // Thinking display (collapsible)
        let thinkingHtml = '';
        if (!isUser && msg.hasThinking && msg.thinkingContent) {
            const durationText = msg.thinkingDurationMs > 0
                ? `Thought for ${(msg.thinkingDurationMs / 1000).toFixed(1)}s`
                : 'Thinking...';
            thinkingHtml = `
                <div class="thinking-chip" onclick="this.classList.toggle('expanded')">
                    <span class="thinking-toggle">▶</span>
                    <span class="thinking-label">💡 ${esc(durationText)}</span>
                </div>
                <div class="thinking-content">${esc(msg.thinkingContent)}</div>
            `;
        }

        // Swipe controls for messages with multiple swipes
        const swipeCount = msg.swipeCount || 1;
        const swipeIndex = (msg.swipeIndex || 0) + 1;
        const swipeHtml = !isUser && swipeCount > 1 ? `
            <div class="swipe-controls">
                <button class="swipe-btn" data-swipe="prev" data-index="${index}" ${swipeIndex <= 1 ? 'disabled' : ''}>◀</button>
                <span class="swipe-counter">${swipeIndex}/${swipeCount}</span>
                <button class="swipe-btn" data-swipe="next" data-index="${index}" ${swipeIndex >= swipeCount ? 'disabled' : ''}>▶</button>
            </div>
        ` : '';

        // Alt greeting controls on first AI message
        let greetingHtml = '';
        if (index === 0 && !isUser && chatState.totalGreetings > 1) {
            const gi = (chatState.greetingIndex || 0) + 1;
            const gt = chatState.totalGreetings;
            greetingHtml = `
                <div class="greeting-controls">
                    <button class="swipe-btn" data-greeting="-1">◀</button>
                    <span class="swipe-counter" style="color:var(--accent-orange)">${gi}/${gt}</span>
                    <button class="swipe-btn" data-greeting="1">▶</button>
                </div>
            `;
        }

        // Regen + Continue buttons on last AI message
        let actionBarHtml = '';
        if (isLastAiMsg) {
            actionBarHtml = `
                <div class="msg-action-bar">
                    <button class="msg-inline-btn" data-action="regenerate" title="Regenerate">
                        <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M17.65 6.35C16.2 4.9 14.21 4 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08c-.82 2.33-3.04 4-5.65 4-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z"/></svg>
                        <span>Regen</span>
                    </button>
                    <button class="msg-inline-btn" data-action="continue" title="Continue generation">
                        <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor"><path d="M20 12l-1.41-1.41L13 16.17V4h-2v12.17l-5.58-5.59L4 12l8 8 8-8z"/></svg>
                        <span>Continue</span>
                    </button>
                </div>
            `;
        }

        // TTS button for AI messages
        const ttsBtn = !isUser && msg.sender !== 'System' ? `
            <button class="msg-tts-btn" data-action="tts" data-index="${index}" title="Speak message">
                <svg viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="M3 9v6h4l5 5V4L7 9H3zm13.5 3c0-1.77-1.02-3.29-2.5-4.03v8.05c1.48-.73 2.5-2.25 2.5-4.02zM14 3.23v2.06c2.89.86 5 3.54 5 6.71s-2.11 5.85-5 6.71v2.06c4.01-.91 7-4.49 7-8.77s-2.99-7.86-7-8.77z"/></svg>
            </button>
        ` : '';

        el.innerHTML = `
            ${actionsHtml}
            <div class="message-sender">
                <span class="message-sender-name">${esc(senderName)}</span>
                ${ttsBtn}
            </div>
            ${thinkingHtml}
            <div class="message-text">${formatText(displayText)}</div>
            ${greetingHtml}
            ${swipeHtml}
            ${actionBarHtml}
        `;

        return el;
    }

    // ═══════════════════════════════════════════════════════════
    // CHAT ACTIONS
    // ═══════════════════════════════════════════════════════════

    function sendMessage() {
        const input = $('#chat-input');
        const text = input.value.trim();
        if (!text) return;

        apiJson('/api/chat/send', {
            method: 'POST',
            body: JSON.stringify({ text: text }),
        });
        input.value = '';
        input.style.height = 'auto';
    }

    function stopGeneration() {
        api('/api/chat/stop', { method: 'POST' });
    }

    async function regenerate() {
        await api('/api/chat/regenerate', { method: 'POST' });
    }

    async function continueGeneration() {
        await api('/api/chat/continue', { method: 'POST' });
    }

    async function impersonateMe() {
        const input = $('#chat-input');
        const prefix = input ? input.value : '';
        const data = await apiJson('/api/chat/impersonate', {
            method: 'POST',
            body: JSON.stringify({ prefix }),
        });
        if (data && data.text && input) {
            input.value = data.text;
            input.style.height = 'auto';
            input.style.height = input.scrollHeight + 'px';
        }
    }

    async function cycleGreeting(direction) {
        await api('/api/chat/cycle-greeting', {
            method: 'POST',
            body: JSON.stringify({ direction }),
        });
        pollChatState();
    }

    async function forkFromMessage(index) {
        if (!confirm('Fork from this message? This creates a new session from this point.')) return;
        await api('/api/chat/fork', {
            method: 'POST',
            body: JSON.stringify({ index }),
        });
        pollChatState();
    }

    // TTS playback through the browser
    let _ttsAudio = null;
    let _ttsPlayingIndex = -1;

    async function playTtsForMessage(index, btn) {
        // If already playing this message, stop it
        if (_ttsAudio && _ttsPlayingIndex === index) {
            _ttsAudio.pause();
            _ttsAudio.src = '';
            _ttsAudio = null;
            _ttsPlayingIndex = -1;
            if (btn) btn.style.color = '';
            return;
        }

        // Stop any current playback
        if (_ttsAudio) {
            _ttsAudio.pause();
            _ttsAudio.src = '';
            _ttsAudio = null;
        }

        const messages = window._lastMessages;
        if (!messages || !messages[index]) return;

        const msg = messages[index];
        if (btn) {
            btn.style.color = 'var(--accent-orange, #f59e0b)';
            btn.title = 'Generating audio...';
        }

        try {
            const response = await fetch('/api/tts/speak', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    text: msg.text,
                    sender: msg.sender,
                }),
            });

            if (!response.ok) {
                const err = await response.json().catch(() => ({}));
                alert(err.error || 'TTS generation failed. Check TTS configuration in Settings.');
                if (btn) { btn.style.color = ''; btn.title = 'Speak message'; }
                return;
            }

            const blob = await response.blob();
            const url = URL.createObjectURL(blob);
            _ttsAudio = new Audio(url);
            _ttsPlayingIndex = index;

            if (btn) btn.title = 'Stop speaking';

            _ttsAudio.onended = () => {
                URL.revokeObjectURL(url);
                _ttsAudio = null;
                _ttsPlayingIndex = -1;
                if (btn) { btn.style.color = ''; btn.title = 'Speak message'; }
            };

            _ttsAudio.onerror = () => {
                URL.revokeObjectURL(url);
                _ttsAudio = null;
                _ttsPlayingIndex = -1;
                if (btn) { btn.style.color = ''; btn.title = 'Speak message'; }
            };

            await _ttsAudio.play();
        } catch (e) {
            console.error('TTS playback error:', e);
            if (btn) { btn.style.color = ''; btn.title = 'Speak message'; }
            _ttsAudio = null;
            _ttsPlayingIndex = -1;
        }
    }

    async function newChat() {
        await api('/api/chat/session', {
            method: 'POST',
            body: JSON.stringify({ action: 'new' }),
        });
        lastMessageCount = 0;
        window._lastMessages = null;
        $('#chat-messages').innerHTML = '';
        pollChatState();
    }

    async function deleteMessage(index) {
        if (!confirm('Delete this message? This cannot be undone.')) return;
        await api('/api/chat/delete', {
            method: 'POST',
            body: JSON.stringify({ index: index }),
        });
        lastMessageCount = 0;
        pollChatState();
    }

    async function editMessage(index) {
        const messages = window._lastMessages;
        if (!messages || !messages[index]) return;

        const originalText = messages[index].text;

        // Build edit modal
        const overlay = document.createElement('div');
        overlay.className = 'modal-overlay active';
        overlay.id = 'edit-msg-modal';
        overlay.innerHTML = `
        <div class="edit-msg-dialog">
            <h3 style="margin:0 0 12px 0;color:#fff;font-size:16px;display:flex;align-items:center;gap:8px">
                ✏️ Edit Message
            </h3>
            <textarea id="edit-msg-textarea" class="edit-msg-textarea">${esc(originalText)}</textarea>
            <div style="display:flex;justify-content:flex-end;gap:10px;margin-top:12px">
                <button id="edit-msg-cancel" class="btn btn-secondary" style="padding:8px 20px;border:none;border-radius:8px;background:var(--bg-input);color:var(--text-secondary);cursor:pointer;font-family:inherit;font-size:13px">Cancel</button>
                <button id="edit-msg-save" class="btn btn-primary" style="padding:8px 20px;border:none;border-radius:8px;background:#3B82F6;color:#fff;cursor:pointer;font-family:inherit;font-size:13px;font-weight:600">Save</button>
            </div>
        </div>
        `;

        document.body.appendChild(overlay);

        const textarea = overlay.querySelector('#edit-msg-textarea');
        textarea.focus();
        // Move cursor to end
        textarea.setSelectionRange(textarea.value.length, textarea.value.length);
        // Auto-resize
        textarea.style.height = Math.min(Math.max(120, textarea.scrollHeight), 400) + 'px';
        textarea.addEventListener('input', () => {
            textarea.style.height = 'auto';
            textarea.style.height = Math.min(Math.max(120, textarea.scrollHeight), 400) + 'px';
        });

        const close = () => overlay.remove();

        overlay.querySelector('#edit-msg-cancel').addEventListener('click', close);
        overlay.addEventListener('click', (e) => { if (e.target === overlay) close(); });
        overlay.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });

        overlay.querySelector('#edit-msg-save').addEventListener('click', async () => {
            const newText = textarea.value;
            if (newText === originalText) { close(); return; }
            close();
            await api('/api/chat/edit', {
                method: 'POST',
                body: JSON.stringify({ index: index, text: newText }),
            });
            pollChatState();
        });
    }

    async function swipeMessage(index, direction) {
        await api('/api/chat/swipe', {
            method: 'POST',
            body: JSON.stringify({ index: index, direction: direction }),
        });
        pollChatState();
    }

    // ═══════════════════════════════════════════════════════════
    // CHAT HISTORY
    // ═══════════════════════════════════════════════════════════

    async function showChatHistory() {
        if (!currentCharacterId) return;
        const data = await apiJson(`/api/characters/${currentCharacterId}/sessions`);
        if (!data) return;

        const list = $('#session-list');
        const sessions = Array.isArray(data) ? data : (data.sessions || []);

        if (!sessions.length) {
            list.innerHTML = '<p style="color:rgba(255,255,255,0.38);text-align:center;padding:40px 0;">No previous chats found.</p>';
        } else {
            list.innerHTML = sessions.map(s => `
                <div class="session-item" data-session-id="${s.id}">
                    <div style="flex:1;min-width:0">
                        <div class="session-preview">${esc(s.preview || s.name || 'Chat session')}</div>
                        <div class="session-date">${s.createdAt ? new Date(s.createdAt).toLocaleString() : ''}</div>
                    </div>
                    <button class="btn-icon btn-delete-session" data-session-id="${s.id}" title="Delete chat" style="color:#e74c3c;flex-shrink:0;font-size:16px;background:none;border:none;cursor:pointer;padding:4px 8px">🗑️</button>
                </div>
            `).join('');

            list.querySelectorAll('.session-item').forEach(item => {
                item.addEventListener('click', async (e) => {
                    if (e.target.closest('.btn-delete-session')) return;
                    await api('/api/chat/session', {
                        method: 'POST',
                        body: JSON.stringify({ sessionId: item.dataset.sessionId }),
                    });
                    $('#history-modal').classList.remove('active');
                    lastMessageCount = 0;
                    window._lastMessages = null;
                    pollChatState();
                });
            });

            list.querySelectorAll('.btn-delete-session').forEach(btn => {
                btn.addEventListener('click', async (e) => {
                    e.stopPropagation();
                    if (!confirm('Delete this chat? This cannot be undone.')) return;
                    const res = await api('/api/chat/session/delete', {
                        method: 'POST',
                        body: JSON.stringify({ sessionId: btn.dataset.sessionId }),
                    });
                    if (res && res.ok) {
                        lastMessageCount = 0;
                        window._lastMessages = null;
                        showChatHistory(); // refresh the list
                        pollChatState();
                    }
                });
            });
        }

        $('#history-modal').classList.add('active');
    }

    // ═══════════════════════════════════════════════════════════
    // EVENT LISTENERS
    // ═══════════════════════════════════════════════════════════

    function initEventListeners() {
        // Send message
        $('#btn-send').addEventListener('click', sendMessage);
        $('#btn-stop').addEventListener('click', stopGeneration);

        // Enter key to send
        $('#chat-input').addEventListener('keydown', (e) => {
            if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                sendMessage();
            }
        });

        // Auto-resize textarea
        $('#chat-input').addEventListener('input', function () {
            this.style.height = 'auto';
            this.style.height = Math.min(this.scrollHeight, 120) + 'px';
        });

        // Back to home
        $('#btn-back').addEventListener('click', () => {
            stopPolling();
            disconnectSSE();
            currentCharacterId = null;
            switchPage('home');
        });

        // Chat management menu
        $('#btn-chat-menu').addEventListener('click', showChatHistory);
        $('#btn-impersonate').addEventListener('click', impersonateMe);

        // New chat
        $('#btn-new-chat').addEventListener('click', () => {
            if (confirm('Start a new chat? This will clear the current conversation.')) {
                newChat();
                $('#history-modal').classList.remove('active');
            }
        });

        // Close history modal
        $('#btn-close-history').addEventListener('click', () => {
            $('#history-modal').classList.remove('active');
        });

        // Search
        $('#search-input').addEventListener('input', (e) => {
            searchQuery = e.target.value;
            loadCharacters();
        });

        // Sort
        $('#sort-dropdown').addEventListener('change', (e) => {
            sortMode = e.target.value;
            loadCharacters();
        });

        // Grid scale
        $('#grid-scale').addEventListener('input', (e) => {
            gridScale = parseInt(e.target.value);
            const grid = $('#char-grid');
            if (grid) grid.style.setProperty('--grid-card-size', gridScale + 'px');
        });

        // Message actions (delegated)
        $('#chat-messages').addEventListener('click', (e) => {
            const actionBtn = e.target.closest('[data-action]');
            if (actionBtn) {
                const action = actionBtn.dataset.action;
                const index = parseInt(actionBtn.dataset.index);
                if (action === 'edit') editMessage(index);
                if (action === 'delete') deleteMessage(index);
                if (action === 'fork') forkFromMessage(index);
                if (action === 'regenerate') regenerate();
                if (action === 'continue') continueGeneration();
                if (action === 'tts') {
                    const msgIndex = parseInt(actionBtn.dataset.index);
                    playTtsForMessage(msgIndex, actionBtn);
                }
                return;
            }

            const swipeBtn = e.target.closest('.swipe-btn[data-swipe]');
            if (swipeBtn) {
                const dir = swipeBtn.dataset.swipe;
                const index = parseInt(swipeBtn.dataset.index);
                swipeMessage(index, dir);
                return;
            }

            const greetBtn = e.target.closest('[data-greeting]');
            if (greetBtn) {
                const direction = parseInt(greetBtn.dataset.greeting);
                cycleGreeting(direction);
                return;
            }
        });

        // History modal backdrop close
        $('#history-modal').addEventListener('click', (e) => {
            if (e.target === $('#history-modal')) {
                $('#history-modal').classList.remove('active');
            }
        });

        // Organize (create folder) button
        $('#btn-organize')?.addEventListener('click', () => {
            const name = prompt('New folder name:');
            if (!name || !name.trim()) return;
            api('/api/folders/create', {
                method: 'POST',
                body: JSON.stringify({ name: name.trim(), parentId: activeFolderId || null }),
            }).then(res => {
                if (res && res.ok) loadCharacters();
                else alert('Failed to create folder');
            });
        });

        // Group chat button (toggle selection mode)
        $('#btn-select-group')?.addEventListener('click', () => {
            isSelectingForGroup = !isSelectingForGroup;
            selectedForGroup.clear();
            const btn = $('#btn-select-group');
            if (isSelectingForGroup) {
                btn.style.outline = '2px solid #8B5CF6';
                // Show floating bar
                let bar = $('#group-select-bar');
                if (!bar) {
                    bar = document.createElement('div');
                    bar.id = 'group-select-bar';
                    bar.className = 'group-select-bar';
                    bar.innerHTML = `
                        <span id="group-select-count">Select 2+ characters</span>
                        <button id="btn-create-group" class="btn btn-primary" disabled>Create Group</button>
                        <button id="btn-cancel-group" class="btn btn-secondary">Cancel</button>
                    `;
                    document.body.appendChild(bar);
                    $('#btn-create-group').addEventListener('click', () => {
                        if (selectedForGroup.size >= 2) showGroupCreationModal();
                    });
                    $('#btn-cancel-group').addEventListener('click', () => {
                        isSelectingForGroup = false;
                        selectedForGroup.clear();
                        btn.style.outline = '';
                        bar.remove();
                        loadCharacters();
                    });
                }
                bar.style.display = 'flex';
            } else {
                btn.style.outline = '';
                const bar = $('#group-select-bar');
                if (bar) bar.remove();
            }
            loadCharacters();
        });

        // Right panel buttons

        // Import character
        $('#btn-import-char')?.addEventListener('click', () => {
            $('#import-char-input').click();
        });
        $('#import-char-input')?.addEventListener('change', async (e) => {
            const files = e.target.files;
            if (!files || files.length === 0) return;

            for (const file of files) {
                try {
                    const base64 = await new Promise((resolve, reject) => {
                        const reader = new FileReader();
                        reader.onload = () => resolve(reader.result.split(',')[1]);
                        reader.onerror = reject;
                        reader.readAsDataURL(file);
                    });
                    const res = await api('/api/characters/import', {
                        method: 'POST',
                        body: JSON.stringify({ filename: file.name, data: base64 }),
                    });
                    if (res && res.ok) {
                        const result = await res.json();
                        console.log(`[Import] Imported: ${result.name}`);
                    } else {
                        alert(`Failed to import ${file.name}`);
                    }
                } catch (err) {
                    alert(`Error importing ${file.name}: ${err.message}`);
                }
            }
            e.target.value = '';
            loadCharacters();
        });

        $('#btn-edit-char').addEventListener('click', showEditCharacterModal);
        $('#btn-rp-chat').addEventListener('click', async () => {
            // Open sampler settings as modal overlay
            const data = await apiJson('/api/settings');
            if (!data) return;
            let overlay = $('#rp-chat-modal');
            if (!overlay) {
                overlay = document.createElement('div');
                overlay.id = 'rp-chat-modal';
                overlay.className = 'modal-overlay';
                document.body.appendChild(overlay);
            }
            const f2 = v => parseFloat(v).toFixed(2);
            overlay.innerHTML = `<div class="modal" style="min-width:min(500px,95vw);max-width:min(700px,95vw);max-height:85vh;display:flex;flex-direction:column;">
                <div class="modal-title">⚙ Chat / Sampler Settings</div>
                <div style="overflow-y:auto;flex:1;padding:12px 0;">
                    <div class="slider-row"><label class="slider-label">Temperature</label>
                        <input type="range" id="m-temperature" min="0" max="2" step="0.05" value="${data.temperature ?? 0.7}" class="settings-slider">
                        <span class="slider-value">${f2(data.temperature ?? 0.7)}</span></div>
                    <div class="slider-row"><label class="slider-label">Min P</label>
                        <input type="range" id="m-min-p" min="0" max="1" step="0.01" value="${data.minP ?? 0.1}" class="settings-slider">
                        <span class="slider-value">${f2(data.minP ?? 0.1)}</span></div>
                    <div class="slider-row"><label class="slider-label">Rep. Penalty</label>
                        <input type="range" id="m-rep-pen" min="1" max="3" step="0.05" value="${data.repetitionPenalty ?? 1.1}" class="settings-slider">
                        <span class="slider-value">${f2(data.repetitionPenalty ?? 1.1)}</span></div>
                    <div class="slider-row"><label class="slider-label">Rep Pen Tokens</label>
                        <input type="number" id="m-rep-pen-tokens" value="${data.repeatPenaltyTokens ?? 64}" min="0" max="512" class="settings-number"></div>
                    <div class="slider-row"><label class="slider-label">XTC Threshold</label>
                        <input type="range" id="m-xtc-threshold" min="0" max="0.5" step="0.01" value="${data.xtcThreshold ?? 0.1}" class="settings-slider">
                        <span class="slider-value">${f2(data.xtcThreshold ?? 0.1)}</span></div>
                    <div class="slider-row"><label class="slider-label">XTC Probability</label>
                        <input type="range" id="m-xtc-prob" min="0" max="1" step="0.05" value="${data.xtcProbability ?? 0.5}" class="settings-slider">
                        <span class="slider-value">${f2(data.xtcProbability ?? 0.5)}</span></div>
                    <div class="slider-row"><label class="slider-label">Max Output Tokens</label>
                        <input type="number" id="m-max-tokens" value="${data.maxTokens ?? 200}" min="16" max="2048" class="settings-number"></div>
                    <div class="slider-row"><label class="slider-label">Min Output Tokens</label>
                        <input type="number" id="m-min-tokens" value="${data.minTokens ?? 0}" min="0" max="512" class="settings-number"></div>
                    <div class="slider-row"><label class="slider-label">Context Size</label>
                        <input type="number" id="m-context-size" value="${data.contextSize ?? 8192}" min="4098" max="500000" class="settings-number"></div>
                    <div class="slider-row"><label class="slider-label">Dynamic Temp</label>
                        <label class="toggle-switch"><input type="checkbox" id="m-dyntemp" ${data.dynamicTempEnabled ? 'checked' : ''}><span class="toggle-slider"></span></label></div>
                    <div class="slider-row" id="m-dyntemp-row" style="${data.dynamicTempEnabled ? '' : 'display:none'}"><label class="slider-label">Dynatemp Range</label>
                        <input type="range" id="m-dyntemp-range" min="0" max="2" step="0.05" value="${data.dynamicTempRange ?? 0.7}" class="settings-slider">
                        <span class="slider-value">${f2(data.dynamicTempRange ?? 0.7)}</span></div>
                </div>
                <div class="modal-actions">
                    <button class="btn btn-outlined" id="m-chat-cancel">Cancel</button>
                    <button class="btn btn-primary" id="m-chat-save">Save</button>
                </div>
            </div>`;
            overlay.classList.add('active');
            overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.classList.remove('active'); });
            // Slider feedback
            overlay.querySelectorAll('.settings-slider').forEach(sl => {
                sl.addEventListener('input', () => {
                    const valSpan = sl.nextElementSibling;
                    if (valSpan) valSpan.textContent = f2(sl.value);
                });
            });
            overlay.querySelector('#m-dyntemp')?.addEventListener('change', (e) => {
                const row = overlay.querySelector('#m-dyntemp-row');
                if (row) row.style.display = e.target.checked ? 'flex' : 'none';
            });
            overlay.querySelector('#m-chat-cancel').addEventListener('click', () => overlay.classList.remove('active'));
            overlay.querySelector('#m-chat-save').addEventListener('click', async () => {
                const res = await api('/api/settings', {
                    method: 'POST',
                    body: JSON.stringify({
                        temperature: parseFloat(overlay.querySelector('#m-temperature').value),
                        minP: parseFloat(overlay.querySelector('#m-min-p').value),
                        repetitionPenalty: parseFloat(overlay.querySelector('#m-rep-pen').value),
                        repeatPenaltyTokens: parseInt(overlay.querySelector('#m-rep-pen-tokens').value),
                        xtcThreshold: parseFloat(overlay.querySelector('#m-xtc-threshold').value),
                        xtcProbability: parseFloat(overlay.querySelector('#m-xtc-prob').value),
                        maxTokens: parseInt(overlay.querySelector('#m-max-tokens').value),
                        minTokens: parseInt(overlay.querySelector('#m-min-tokens').value),
                        contextSize: parseInt(overlay.querySelector('#m-context-size').value),
                        dynamicTempEnabled: overlay.querySelector('#m-dyntemp').checked,
                        dynamicTempRange: parseFloat(overlay.querySelector('#m-dyntemp-range').value),
                    }),
                });
                if (res && res.ok) {
                    overlay.classList.remove('active');
                    loadSettings();
                }
            });
        });

        $('#btn-rp-model').addEventListener('click', async () => {
            // Open model/API settings as modal overlay
            const data = await apiJson('/api/settings');
            if (!data) return;
            let overlay = $('#rp-model-modal');
            if (!overlay) {
                overlay = document.createElement('div');
                overlay.id = 'rp-model-modal';
                overlay.className = 'modal-overlay';
                document.body.appendChild(overlay);
            }
            overlay.innerHTML = `<div class="modal" style="min-width:min(500px, 95vw);max-width:700px;max-height:85vh;display:flex;flex-direction:column;">
                <div class="modal-title">🧠 Model / API Config</div>
                <div style="overflow-y:auto;flex:1;padding:12px 0;">
                    <div class="radio-group" style="margin-bottom:12px">
                        <label class="radio-option"><input type="radio" name="m-backend" value="kobold" ${data.activeBackend === 'kobold' ? 'checked' : ''}><span>🖥️ Local</span></label>
                        <label class="radio-option"><input type="radio" name="m-backend" value="openRouter" ${data.activeBackend !== 'kobold' ? 'checked' : ''}><span>☁️ Remote API</span></label>
                    </div>
                    <div class="settings-field"><label class="field-label">API URL</label>
                        <input type="text" id="m-api-url" class="settings-input" value="${esc(data.apiUrl || '')}"></div>
                    <div class="settings-field"><label class="field-label">API Key</label>
                        <input type="password" id="m-api-key" class="settings-input" placeholder="${data.apiKeySet ? 'Key saved (' + data.apiKey + ')' : 'Enter API key...'}"></div>
                    <div class="settings-field"><label class="field-label">Model</label>
                        <button class="btn btn-sm" id="m-refresh-models" style="margin-bottom:6px">🔄 Refresh Models</button>
                        <input type="text" id="m-model-search" class="settings-input" placeholder="Search models..." style="margin-bottom:4px;display:none">
                        <select id="m-api-model" class="settings-select" style="min-height:36px">
                            <option value="${esc(data.apiModel || '')}" selected>${esc(data.apiModel || '-- Tap Refresh to load models --')}</option>
                        </select></div>
                    <div class="toggle-row" style="margin-top:8px"><span>🧠 Reasoning</span>
                        <label class="toggle-switch"><input type="checkbox" id="m-reasoning" ${data.reasoningEnabled ? 'checked' : ''}><span class="toggle-slider"></span></label></div>
                    <div class="settings-field" id="m-effort-row" style="${data.reasoningEnabled ? '' : 'display:none'}"><label class="field-label">Effort</label>
                        <select id="m-reasoning-effort" class="settings-select" style="width:150px">
                            <option value="low" ${data.reasoningEffort === 'low' ? 'selected' : ''}>Low</option>
                            <option value="medium" ${data.reasoningEffort === 'medium' ? 'selected' : ''}>Medium</option>
                            <option value="high" ${data.reasoningEffort === 'high' ? 'selected' : ''}>High</option>
                        </select></div>
                </div>
                <div class="modal-actions">
                    <button class="btn btn-outlined" id="m-model-cancel">Cancel</button>
                    <button class="btn btn-primary" id="m-model-save">Save</button>
                </div>
            </div>`;
            overlay.classList.add('active');
            overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.classList.remove('active'); });
            overlay.querySelector('#m-reasoning')?.addEventListener('change', (e) => {
                const row = overlay.querySelector('#m-effort-row');
                if (row) row.style.display = e.target.checked ? 'block' : 'none';
            });
            // Refresh Models
            overlay.querySelector('#m-refresh-models').addEventListener('click', async () => {
                const btn = overlay.querySelector('#m-refresh-models');
                btn.textContent = '⏳ Loading...';
                btn.disabled = true;
                try {
                    // Save key/url first if user entered new ones
                    const key = overlay.querySelector('#m-api-key').value;
                    const url = overlay.querySelector('#m-api-url').value;
                    if (key || url) {
                        await api('/api/settings', {
                            method: 'POST',
                            body: JSON.stringify({
                                ...(key ? { apiKey: key } : {}),
                                ...(url ? { apiUrl: url } : {}),
                            }),
                        });
                    }
                    const models = await apiJson('/api/models/list');
                    const sel = overlay.querySelector('#m-api-model');
                    const search = overlay.querySelector('#m-model-search');
                    if (sel && models && Array.isArray(models)) {
                        const currentVal = sel.value;
                        sel.innerHTML = '<option value="">-- Select a model --</option>';
                        for (const m of models) {
                            const opt = document.createElement('option');
                            opt.value = m.id;
                            opt.textContent = `${m.name}${m.isFree ? ' 🟢' : ''} ${m.pricing || ''}`;
                            if (m.id === currentVal) opt.selected = true;
                            sel.appendChild(opt);
                        }
                        if (search) {
                            search.style.display = models.length > 5 ? 'block' : 'none';
                            search.value = '';
                            search.oninput = () => {
                                const q = search.value.toLowerCase();
                                for (const opt of sel.options) {
                                    if (!opt.value) continue;
                                    opt.hidden = q && !opt.textContent.toLowerCase().includes(q);
                                }
                            };
                        }
                    }
                } catch (e) {
                    showInfoModal('Error', 'Failed to load models.');
                } finally {
                    btn.textContent = '🔄 Refresh Models';
                    btn.disabled = false;
                }
            });
            overlay.querySelector('#m-model-cancel').addEventListener('click', () => overlay.classList.remove('active'));
            overlay.querySelector('#m-model-save').addEventListener('click', async () => {
                const payload = {
                    activeBackend: overlay.querySelector('input[name="m-backend"]:checked')?.value || 'openRouter',
                    apiUrl: overlay.querySelector('#m-api-url').value,
                    apiModel: overlay.querySelector('#m-api-model').value,
                    reasoningEnabled: overlay.querySelector('#m-reasoning').checked,
                    reasoningEffort: overlay.querySelector('#m-reasoning-effort').value,
                };
                const key = overlay.querySelector('#m-api-key').value;
                if (key) payload.apiKey = key;
                const res = await api('/api/settings', {
                    method: 'POST',
                    body: JSON.stringify(payload),
                });
                if (res && res.ok) {
                    overlay.classList.remove('active');
                    loadSettings();
                    updateModelLabel();
                }
            });
        });

        // Appbar overflow menu — toggle & dispatch
        const overflowBtn = $('#btn-appbar-overflow');
        const overflowMenu = $('#appbar-overflow-menu');
        if (overflowBtn && overflowMenu) {
            overflowBtn.addEventListener('click', (e) => {
                e.stopPropagation();
                overflowMenu.classList.toggle('open');
            });
            // Close menu when clicking anywhere else
            document.addEventListener('click', () => overflowMenu.classList.remove('open'));
            overflowMenu.addEventListener('click', (e) => {
                const btn = e.target.closest('[data-action]');
                if (!btn) return;
                overflowMenu.classList.remove('open');
                const action = btn.dataset.action;
                if (action === 'model') $('#btn-rp-model').click();
                if (action === 'samplers') $('#btn-rp-chat').click();
                if (action === 'memory') $('#btn-rp-memory').click();
                if (action === 'tts') $('#btn-rp-tts').click();
                if (action === 'edit') $('#btn-edit-char').click();
            });
        }

        // ── Memory / RAG modal ──
        $('#btn-rp-memory').addEventListener('click', async () => {
            const data = await apiJson('/api/settings');
            if (!data) return;
            let overlay = $('#rp-memory-modal');
            if (!overlay) {
                overlay = document.createElement('div');
                overlay.id = 'rp-memory-modal';
                overlay.className = 'modal-overlay';
                document.body.appendChild(overlay);
            }
            const ragCount = data.ragRetrievalCount ?? 10;
            const ragWin = data.ragWindowSize ?? 5;
            const apInt = data.autoPersonaInterval ?? 5;

            overlay.innerHTML = `<div class="modal" style="min-width:min(500px,95vw);max-width:700px;max-height:85vh;display:flex;flex-direction:column;">
                <div class="modal-title">💾 Memory (RAG)</div>
                <div style="overflow-y:auto;flex:1;padding:12px 0;">
                    <div class="toggle-row"><span>Enable RAG Memory</span>
                        <label class="toggle-switch"><input type="checkbox" id="m-rag-enabled" ${data.ragEnabled ? 'checked' : ''}><span class="toggle-slider"></span></label></div>
                    <div id="m-rag-fields" style="${data.ragEnabled ? '' : 'display:none'};margin-top:8px">
                        <div class="slider-row"><label class="slider-label">Memories per turn</label>
                            <input type="range" id="m-rag-retrieval" min="0" max="50" step="1" value="${ragCount}" class="settings-slider">
                            <span class="slider-value" id="m-rag-retrieval-val">${ragCount === 0 ? 'All' : ragCount}</span></div>
                        <div class="slider-row"><label class="slider-label">Window size</label>
                            <input type="range" id="m-rag-window" min="3" max="10" step="1" value="${ragWin}" class="settings-slider">
                            <span class="slider-value" id="m-rag-window-val">${ragWin}</span></div>
                        <div class="settings-field" style="margin-top:8px"><label class="field-label">Embedding source</label>
                            <select id="m-rag-source" class="settings-select">
                                <option value="auto" ${data.ragEmbeddingSource === 'auto' ? 'selected' : ''}>Auto</option>
                                <option value="onnx" ${data.ragEmbeddingSource === 'onnx' ? 'selected' : ''}>ONNX Local</option>
                                <option value="kobold" ${data.ragEmbeddingSource === 'kobold' ? 'selected' : ''}>KoboldCpp</option>
                                <option value="api" ${data.ragEmbeddingSource === 'api' ? 'selected' : ''}>API</option>
                            </select></div>
                        <div class="settings-field" style="margin-top:8px"><label class="field-label">API model</label>
                            <input type="text" id="m-rag-model" class="settings-input" value="${esc(data.ragEmbeddingModel || '')}" placeholder="text-embedding-3-small"></div>
                        <div style="padding:8px;background:rgba(0,0,0,0.2);border-radius:6px;color:rgba(255,255,255,0.4);font-size:11px;margin-top:8px">
                            ℹ️ Embeds messages in the background. API embedding uses tokens.</div>
                        <div style="border-top:1px solid rgba(255,255,255,0.08);margin:12px 0"></div>
                        <div class="toggle-row"><span>✨ Auto-update persona</span>
                            <label class="toggle-switch"><input type="checkbox" id="m-auto-persona" ${data.autoPersonaEnabled ? 'checked' : ''}><span class="toggle-slider"></span></label></div>
                        <div id="m-persona-fields" style="${data.autoPersonaEnabled ? '' : 'display:none'};margin-top:4px">
                            <div class="slider-row"><label class="slider-label">Extract every</label>
                                <input type="range" id="m-persona-interval" min="5" max="50" step="5" value="${apInt}" class="settings-slider">
                                <span class="slider-value" id="m-persona-interval-val">${apInt} msgs</span></div>
                            <div style="font-size:11px;color:rgba(255,255,255,0.3)">
                                Extracts personal facts from your messages using the LLM.</div>
                        </div>
                    </div>
                </div>
                <div class="modal-actions">
                    <button class="btn btn-outlined" id="m-rag-cancel">Cancel</button>
                    <button class="btn btn-primary" id="m-rag-save">Save</button>
                </div>
            </div>`;
            overlay.classList.add('active');
            overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.classList.remove('active'); });

            // Toggle visibility
            overlay.querySelector('#m-rag-enabled')?.addEventListener('change', (e) => {
                const f = overlay.querySelector('#m-rag-fields');
                if (f) f.style.display = e.target.checked ? 'block' : 'none';
            });
            overlay.querySelector('#m-auto-persona')?.addEventListener('change', (e) => {
                const f = overlay.querySelector('#m-persona-fields');
                if (f) f.style.display = e.target.checked ? 'block' : 'none';
            });
            // Slider feedback
            overlay.querySelector('#m-rag-retrieval')?.addEventListener('input', (e) => {
                const v = parseInt(e.target.value);
                const s = overlay.querySelector('#m-rag-retrieval-val');
                if (s) s.textContent = v === 0 ? 'All' : v;
            });
            overlay.querySelector('#m-rag-window')?.addEventListener('input', (e) => {
                const s = overlay.querySelector('#m-rag-window-val');
                if (s) s.textContent = e.target.value;
            });
            overlay.querySelector('#m-persona-interval')?.addEventListener('input', (e) => {
                const s = overlay.querySelector('#m-persona-interval-val');
                if (s) s.textContent = e.target.value + ' msgs';
            });
            // Cancel
            overlay.querySelector('#m-rag-cancel').addEventListener('click', () => overlay.classList.remove('active'));
            // Save
            overlay.querySelector('#m-rag-save').addEventListener('click', async () => {
                const payload = {
                    ragEnabled: overlay.querySelector('#m-rag-enabled').checked,
                    ragRetrievalCount: parseInt(overlay.querySelector('#m-rag-retrieval').value),
                    ragWindowSize: parseInt(overlay.querySelector('#m-rag-window').value),
                    ragEmbeddingSource: overlay.querySelector('#m-rag-source').value,
                    ragEmbeddingModel: overlay.querySelector('#m-rag-model').value,
                    autoPersonaEnabled: overlay.querySelector('#m-auto-persona').checked,
                    autoPersonaInterval: parseInt(overlay.querySelector('#m-persona-interval').value),
                };
                const res = await api('/api/settings', {
                    method: 'POST',
                    body: JSON.stringify(payload),
                });
                if (res && res.ok) {
                    overlay.classList.remove('active');
                    loadSettings();
                }
            });
        });

        $('#btn-rp-tts').addEventListener('click', async () => {
            // Open TTS settings as modal overlay
            const data = await apiJson('/api/settings');
            if (!data) return;
            let overlay = $('#rp-tts-modal');
            if (!overlay) {
                overlay = document.createElement('div');
                overlay.id = 'rp-tts-modal';
                overlay.className = 'modal-overlay';
                document.body.appendChild(overlay);
            }
            const voices = data.ttsVoices || [];
            const voiceOpts = voices.map(v =>
                `<option value="${esc(v.id)}" ${v.id === data.ttsVoice ? 'selected' : ''}>${esc(v.name || v.id)}</option>`
            ).join('');

            overlay.innerHTML = `<div class="modal" style="min-width:min(500px,95vw);max-width:700px;max-height:85vh;display:flex;flex-direction:column;">
                <div class="modal-title">🔊 TTS Settings</div>
                <div style="overflow-y:auto;flex:1;padding:12px 0;">
                    <div class="toggle-row"><span>Enable TTS</span>
                        <label class="toggle-switch"><input type="checkbox" id="m-tts-enabled" ${data.ttsEnabled ? 'checked' : ''}><span class="toggle-slider"></span></label></div>
                    <div class="settings-field" style="margin-top:8px"><label class="field-label">Engine</label>
                        <select id="m-tts-engine" class="settings-select">
                            <option value="kokoro" ${data.ttsEngine === 'kokoro' ? 'selected' : ''}>Kokoro (Local)</option>
                            <option value="openai" ${data.ttsEngine === 'openai' ? 'selected' : ''}>OpenAI TTS (Cloud)</option>
                            <option value="elevenlabs" ${data.ttsEngine === 'elevenlabs' ? 'selected' : ''}>ElevenLabs (Premium)</option>
                            <option value="piper" ${data.ttsEngine === 'piper' ? 'selected' : ''}>Piper (Legacy)</option>
                        </select></div>
                    <div class="settings-field"><label class="field-label">Voice</label>
                        <select id="m-tts-voice" class="settings-select">
                            <option value="">-- Select voice --</option>
                            ${voiceOpts}
                        </select></div>
                    <div class="slider-row"><label class="slider-label">Speech Rate</label>
                        <input type="range" id="m-tts-rate" min="0.5" max="2.0" step="0.1" value="${data.ttsSpeechRate ?? 1.0}" class="settings-slider">
                        <span class="slider-value">${parseFloat(data.ttsSpeechRate ?? 1.0).toFixed(1)}×</span></div>
                    <div class="slider-row"><label class="slider-label">Concurrency</label>
                        <input type="number" id="m-tts-concurrency" value="${data.ttsConcurrency ?? 4}" min="1" max="16" class="settings-number" style="width:80px"></div>
                    <div class="toggle-row"><span>Auto-play on receive</span>
                        <label class="toggle-switch"><input type="checkbox" id="m-tts-autoplay" ${data.ttsAutoPlay ? 'checked' : ''}><span class="toggle-slider"></span></label></div>

                    <!-- OpenAI fields -->
                    <div id="m-openai-tts-fields" style="${data.ttsEngine === 'openai' ? '' : 'display:none'}">
                        <div class="settings-field"><label class="field-label">OpenAI TTS API Key</label>
                            <input type="password" id="m-openai-tts-key" class="settings-input" placeholder="${data.openaiTtsApiKeySet ? 'Key saved' : 'sk-...'}"></div>
                        <div class="settings-field"><label class="field-label">OpenAI TTS Model</label>
                            <select id="m-openai-tts-model" class="settings-select">
                                <option value="tts-1" ${data.openaiTtsModel === 'tts-1' ? 'selected' : ''}>tts-1</option>
                                <option value="tts-1-hd" ${data.openaiTtsModel === 'tts-1-hd' ? 'selected' : ''}>tts-1-hd</option>
                            </select></div>
                    </div>

                    <!-- ElevenLabs fields -->
                    <div id="m-elevenlabs-fields" style="${data.ttsEngine === 'elevenlabs' ? '' : 'display:none'}">
                        <div class="settings-field"><label class="field-label">ElevenLabs API Key</label>
                            <input type="password" id="m-elevenlabs-key" class="settings-input" placeholder="${data.elevenlabsApiKeySet ? 'Key saved' : 'Enter API key...'}"></div>
                        <div class="settings-field"><label class="field-label">ElevenLabs Model</label>
                            <select id="m-elevenlabs-model" class="settings-select">
                                <option value="eleven_flash_v2_5" ${data.elevenlabsModel === 'eleven_flash_v2_5' ? 'selected' : ''}>Flash v2.5 — fastest (~75ms)</option>
                                <option value="eleven_multilingual_v2" ${data.elevenlabsModel === 'eleven_multilingual_v2' ? 'selected' : ''}>Multilingual v2 — 29 languages</option>
                                <option value="eleven_v3" ${data.elevenlabsModel === 'eleven_v3' ? 'selected' : ''}>v3 — best quality</option>
                            </select></div>
                        <div class="slider-row"><label class="slider-label">Stability</label>
                            <input type="range" id="m-el-stability" min="0" max="1" step="0.05" value="${data.elevenlabsStability ?? 0.5}" class="settings-slider">
                            <span class="slider-value">${parseFloat(data.elevenlabsStability ?? 0.5).toFixed(2)}</span></div>
                        <div style="display:flex;justify-content:space-between;font-size:10px;color:#ffffff44;margin:-4px 0 4px"><span>Expressive</span><span>Consistent</span></div>
                        <div class="slider-row"><label class="slider-label">Similarity</label>
                            <input type="range" id="m-el-similarity" min="0" max="1" step="0.05" value="${data.elevenlabsSimilarity ?? 0.75}" class="settings-slider">
                            <span class="slider-value">${parseFloat(data.elevenlabsSimilarity ?? 0.75).toFixed(2)}</span></div>
                        <div style="display:flex;justify-content:space-between;font-size:10px;color:#ffffff44;margin:-4px 0 4px"><span>Creative</span><span>Faithful</span></div>
                        <div class="slider-row"><label class="slider-label">Style</label>
                            <input type="range" id="m-el-style" min="0" max="1" step="0.05" value="${data.elevenlabsStyle ?? 0.0}" class="settings-slider">
                            <span class="slider-value">${parseFloat(data.elevenlabsStyle ?? 0.0).toFixed(2)}</span></div>
                        <div style="display:flex;justify-content:space-between;font-size:10px;color:#ffffff44;margin:-4px 0 4px"><span>Subtle</span><span>Expressive</span></div>
                        <div style="padding:8px;background:rgba(0,0,0,0.2);border-radius:6px;color:#ffffff66;font-size:11px;margin-top:4px">☁️ Requires ElevenLabs API key. Free tier: ~10 min/month.</div>
                    </div>

                    <!-- Narration Filters -->
                    <div style="border-top:1px solid #ffffff1a;margin-top:12px;padding-top:12px">
                        <div style="color:#ffffff88;font-size:12px;font-weight:600;margin-bottom:8px">Narration Filters</div>
                        <div class="toggle-row"><span style="font-size:13px">Only narrate "quotes"</span>
                            <label class="toggle-switch"><input type="checkbox" id="m-tts-quotes-only" ${data.ttsNarrateQuotedOnly ? 'checked' : ''}><span class="toggle-slider"></span></label></div>
                        <div class="toggle-row"><span style="font-size:13px">Ignore *text inside asterisks*</span>
                            <label class="toggle-switch"><input type="checkbox" id="m-tts-ignore-asterisks" ${data.ttsIgnoreAsterisks ? 'checked' : ''}><span class="toggle-slider"></span></label></div>
                    </div>
                </div>
                <div class="modal-actions">
                    <button class="btn btn-outlined" id="m-tts-cancel">Cancel</button>
                    <button class="btn btn-primary" id="m-tts-save">Save</button>
                </div>
            </div>`;
            overlay.classList.add('active');
            overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.classList.remove('active'); });
            // Slider feedback
            overlay.querySelector('#m-tts-rate')?.addEventListener('input', (e) => {
                const valSpan = e.target.nextElementSibling;
                if (valSpan) valSpan.textContent = parseFloat(e.target.value).toFixed(1) + '×';
            });
            for (const sid of ['#m-el-stability', '#m-el-similarity', '#m-el-style']) {
                overlay.querySelector(sid)?.addEventListener('input', (e) => {
                    const valSpan = e.target.nextElementSibling;
                    if (valSpan) valSpan.textContent = parseFloat(e.target.value).toFixed(2);
                });
            }
            overlay.querySelector('#m-tts-engine')?.addEventListener('change', (e) => {
                const oai = overlay.querySelector('#m-openai-tts-fields');
                const el = overlay.querySelector('#m-elevenlabs-fields');
                if (oai) oai.style.display = e.target.value === 'openai' ? 'block' : 'none';
                if (el) el.style.display = e.target.value === 'elevenlabs' ? 'block' : 'none';
            });
            overlay.querySelector('#m-tts-cancel').addEventListener('click', () => overlay.classList.remove('active'));
            overlay.querySelector('#m-tts-save').addEventListener('click', async () => {
                const payload = {
                    ttsEnabled: overlay.querySelector('#m-tts-enabled').checked,
                    ttsEngine: overlay.querySelector('#m-tts-engine').value,
                    ttsVoice: overlay.querySelector('#m-tts-voice').value,
                    ttsSpeechRate: parseFloat(overlay.querySelector('#m-tts-rate').value),
                    ttsConcurrency: parseInt(overlay.querySelector('#m-tts-concurrency').value),
                    ttsAutoPlay: overlay.querySelector('#m-tts-autoplay').checked,
                    openaiTtsModel: overlay.querySelector('#m-openai-tts-model')?.value || 'tts-1',
                    elevenlabsModel: overlay.querySelector('#m-elevenlabs-model')?.value || 'eleven_flash_v2_5',
                    elevenlabsStability: parseFloat(overlay.querySelector('#m-el-stability')?.value || 0.5),
                    elevenlabsSimilarity: parseFloat(overlay.querySelector('#m-el-similarity')?.value || 0.75),
                    elevenlabsStyle: parseFloat(overlay.querySelector('#m-el-style')?.value || 0.0),
                    ttsNarrateQuotedOnly: overlay.querySelector('#m-tts-quotes-only')?.checked || false,
                    ttsIgnoreAsterisks: overlay.querySelector('#m-tts-ignore-asterisks')?.checked || false,
                };
                const oaiKey = overlay.querySelector('#m-openai-tts-key')?.value;
                if (oaiKey) payload.openaiTtsApiKey = oaiKey;
                const elKey = overlay.querySelector('#m-elevenlabs-key')?.value;
                if (elKey) payload.elevenlabsApiKey = elKey;
                const res = await api('/api/settings', {
                    method: 'POST',
                    body: JSON.stringify(payload),
                });
                if (res && res.ok) {
                    overlay.classList.remove('active');
                    loadSettings();
                }
            });
        });

        // Author's note strength slider label
        function updateStrengthLabel(val) {
            const label = $('#rp-author-strength-val');
            if (!label) return;
            const v = parseInt(val);
            if (v <= 3) { label.textContent = 'Gentle'; label.style.color = '#4CAF50'; }
            else if (v <= 7) { label.textContent = 'Normal'; label.style.color = 'var(--text-secondary)'; }
            else { label.textContent = 'Strong'; label.style.color = '#e74c3c'; }
        }
        $('#rp-author-strength')?.addEventListener('input', (e) => updateStrengthLabel(e.target.value));

        // Author's note save button
        $('#btn-save-author-note')?.addEventListener('click', async () => {
            const note = $('#rp-author-note')?.value || '';
            const strength = parseInt($('#rp-author-strength')?.value || '4');
            const res = await api('/api/chat/author-note', {
                method: 'POST',
                body: JSON.stringify({ authorNote: note, strength }),
            });
            if (res && res.ok) showInfoModal('Saved', 'Author\'s note saved.');
        });

        // Summary event handlers
        const summaryTextEl = $('#rp-summary-text');
        if (summaryTextEl) {
            summaryTextEl.addEventListener('focus', () => { summaryTextEl._userEditing = true; });
            summaryTextEl.addEventListener('blur', () => { summaryTextEl._userEditing = false; });
        }

        $('#btn-save-summary')?.addEventListener('click', async () => {
            const summary = $('#rp-summary-text')?.value || '';
            const res = await api('/api/chat/summary', {
                method: 'POST',
                body: JSON.stringify({ summary }),
            });
            if (res && res.ok) showInfoModal('Saved', 'Summary saved.');
        });

        $('#btn-summary-pause')?.addEventListener('click', async () => {
            const isPaused = $('#btn-summary-pause')?.textContent?.includes('Resume');
            await api('/api/chat/summary/pause', {
                method: 'POST',
                body: JSON.stringify({ paused: !isPaused }),
            });
            pollChatState();
        });

        $('#btn-summary-regen')?.addEventListener('click', async () => {
            const btn = $('#btn-summary-regen');
            if (btn) { btn.disabled = true; btn.textContent = '⏳ Generating...'; }
            await api('/api/chat/summary/regenerate', { method: 'POST' });
            if (btn) { btn.disabled = false; btn.textContent = '🔄 Regenerate'; }
            pollChatState();
        });
    }

    // ═══════════════════════════════════════════════════════════
    // MODALS
    // ═══════════════════════════════════════════════════════════

    function showInfoModal(title, message) {
        let overlay = $('#info-modal');
        if (!overlay) {
            overlay = document.createElement('div');
            overlay.id = 'info-modal';
            overlay.className = 'modal-overlay';
            document.body.appendChild(overlay);
        }
        overlay.innerHTML = `
            <div class="modal">
                <div class="modal-title">${esc(title)}</div>
                <p style="color:var(--text-secondary);line-height:1.6;font-size:14px;">${esc(message)}</p>
                <div class="modal-actions">
                    <button class="btn btn-outlined" id="btn-close-info">OK</button>
                </div>
            </div>
        `;
        overlay.classList.add('active');
        overlay.querySelector('#btn-close-info').addEventListener('click', () => overlay.classList.remove('active'));
        overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.classList.remove('active'); });
    }

    function showConfirmModal(title, message, onConfirm) {
        let overlay = document.createElement('div');
        overlay.className = 'modal-overlay active';
        overlay.innerHTML = `
            <div class="modal">
                <div class="modal-title">${esc(title)}</div>
                <p style="color:var(--text-secondary);line-height:1.6;font-size:14px;">${esc(message)}</p>
                <div class="modal-actions">
                    <button class="btn btn-outlined" id="btn-confirm-cancel">Cancel</button>
                    <button class="btn btn-primary" id="btn-confirm-ok" style="background:var(--accent-red,#e74c3c);border-color:var(--accent-red,#e74c3c)">Delete</button>
                </div>
            </div>
        `;
        document.body.appendChild(overlay);
        overlay.querySelector('#btn-confirm-cancel').addEventListener('click', () => overlay.remove());
        overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });
        overlay.querySelector('#btn-confirm-ok').addEventListener('click', async () => {
            overlay.remove();
            await onConfirm();
        });
    }

    function showEditCharacterModal() {
        if (!currentCharacterId) return;

        let overlay = $('#edit-char-modal');
        if (!overlay) {
            overlay = document.createElement('div');
            overlay.id = 'edit-char-modal';
            overlay.className = 'modal-overlay';
            document.body.appendChild(overlay);
        }

        overlay.innerHTML = `<div class="modal" style="min-width:min(700px,95vw);max-width:min(900px,95vw);max-height:85vh;display:flex;flex-direction:column;">
            <div class="modal-title">Edit Character</div>
            <p style="color:var(--text-muted);text-align:center;padding:24px">Loading character data...</p>
        </div>`;
        overlay.classList.add('active');
        overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.classList.remove('active'); });

        // Fetch full character data then render
        _loadEditCharacterData(overlay);
    }

    async function _loadEditCharacterData(overlay) {
        const data = await apiJson(`/api/characters/${currentCharacterId}/detail`);
        if (!data || !data.name) {
            overlay.querySelector('.modal').innerHTML = `
                <div class="modal-title">Error</div>
                <p style="color:var(--text-muted)">Failed to load character data.</p>
                <div class="modal-actions"><button class="btn btn-outlined" onclick="this.closest('.modal-overlay').classList.remove('active')">Close</button></div>`;
            return;
        }

        // Fetch worlds list for Worlds tab
        const worldsData = await apiJson('/api/worlds');
        const allWorlds = Array.isArray(worldsData) ? worldsData : [];

        let altGreetings = Array.isArray(data.alternateGreetings) ? [...data.alternateGreetings] : [];
        let tags = Array.isArray(data.tags) ? [...data.tags] : [];
        let lorebook = data.lorebook && data.lorebook.entries ? { entries: [...data.lorebook.entries] } : { entries: [] };
        let selectedWorlds = Array.isArray(data.worldNames) ? [...data.worldNames] : [];
        let activeTab = 'details';

        function render() {
            const modal = overlay.querySelector('.modal');
            modal.innerHTML = `
                <div class="modal-title" style="display:flex;justify-content:space-between;align-items:center">
                    <span>Edit — ${esc(data.name)}</span>
                    <div class="ec-tabs" style="display:flex;gap:4px">
                        <button class="ec-tab${activeTab === 'details' ? ' active' : ''}" data-tab="details">Details</button>
                        <button class="ec-tab${activeTab === 'lorebook' ? ' active' : ''}" data-tab="lorebook">Lorebook</button>
                        <button class="ec-tab${activeTab === 'worlds' ? ' active' : ''}" data-tab="worlds">Worlds</button>
                    </div>
                </div>
                <div class="ec-body" style="overflow-y:auto;flex:1;padding:4px 0;">
                    ${activeTab === 'details' ? renderDetailsTab() : activeTab === 'lorebook' ? renderLorebookTab() : renderWorldsTab()}
                </div>
                <div class="modal-actions">
                    <button class="btn btn-outlined" id="btn-ec-cancel">Cancel</button>
                    <button class="btn btn-primary" id="btn-ec-save">Save</button>
                </div>
            `;

            // Tab switching
            modal.querySelectorAll('.ec-tab').forEach(tab => {
                tab.addEventListener('click', () => { activeTab = tab.dataset.tab; render(); });
            });

            modal.querySelector('#btn-ec-cancel').addEventListener('click', () => overlay.classList.remove('active'));
            modal.querySelector('#btn-ec-save').addEventListener('click', saveCharacter);

            // Bind dynamic controls
            if (activeTab === 'details') bindDetailsTab(modal);
            if (activeTab === 'lorebook') bindLorebookTab(modal);
            if (activeTab === 'worlds') bindWorldsTab(modal);
        }

        function renderDetailsTab() {
            const field = (id, label, val, rows) => rows > 1
                ? `<div><label class="slider-label" style="display:block;margin-bottom:4px">${label}</label>
                    <textarea id="${id}" class="settings-textarea ec-autogrow" rows="${rows}" style="min-height:${rows * 22}px">${esc(val || '')}</textarea></div>`
                : `<div><label class="slider-label" style="display:block;margin-bottom:4px">${label}</label>
                    <input type="text" id="${id}" class="settings-text-input" value="${esc(val || '')}"></div>`;

            let altHtml = altGreetings.map((g, i) => `
                <div style="display:flex;gap:8px;align-items:start">
                    <textarea class="settings-textarea ec-alt-greeting ec-autogrow" rows="5" style="min-height:110px" data-idx="${i}">${esc(g)}</textarea>
                    <button class="btn-icon ec-remove-alt" data-idx="${i}" title="Remove">❌</button>
                </div>
            `).join('');

            let tagsHtml = tags.map((t, i) => `
                <span class="stop-seq-chip">${esc(t)} <button class="ec-remove-tag" data-idx="${i}" style="background:none;border:none;color:var(--text-muted);cursor:pointer;font-size:12px;padding:0 2px;">✕</button></span>
            `).join('');

            return `<div style="display:flex;flex-direction:column;gap:14px;padding:8px">
                ${field('ec-name', 'Name', data.name, 1)}
                ${field('ec-desc', 'Description', data.description, 6)}
                ${field('ec-personality', 'Personality', data.personality, 6)}
                ${field('ec-scenario', 'Scenario', data.scenario, 3)}
                ${field('ec-first-msg', 'First Message', data.firstMessage, 8)}
                <div>
                    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">
                        <label class="slider-label">Alternate Greetings</label>
                        <button class="btn btn-outlined" id="btn-ec-add-alt" style="font-size:12px;padding:4px 10px">+ Add</button>
                    </div>
                    <div style="display:flex;flex-direction:column;gap:8px">${altHtml}</div>
                </div>
                ${field('ec-mes-example', 'Example Dialogues', data.mesExample, 8)}
                ${field('ec-system-prompt', 'System Prompt', data.systemPrompt, 6)}
                ${field('ec-post-history', 'Post-History Instructions', data.postHistoryInstructions, 4)}
                <div>
                    <label class="slider-label" style="display:block;margin-bottom:4px">Tags</label>
                    <div style="display:flex;flex-wrap:wrap;gap:6px;margin-bottom:8px">${tagsHtml}</div>
                    <div style="display:flex;gap:8px">
                        <input type="text" id="ec-tag-input" class="settings-text-input" placeholder="Add a tag..." style="flex:1">
                        <button class="btn btn-outlined" id="btn-ec-add-tag" style="font-size:12px;padding:4px 10px">Add</button>
                    </div>
                </div>
            </div>`;
        }

        function renderLorebookTab() {
            if (!lorebook.entries.length) {
                return `<div style="padding:16px;text-align:center">
                    <p style="color:var(--text-muted)">No lorebook entries.</p>
                    <button class="btn btn-primary" id="btn-ec-add-lore" style="margin-top:12px">+ Add Entry</button>
                </div>`;
            }

            let html = `<div style="padding:8px"><button class="btn btn-primary" id="btn-ec-add-lore" style="margin-bottom:12px;font-size:13px;padding:6px 14px">+ Add Entry</button>`;
            lorebook.entries.forEach((entry, i) => {
                const isConst = entry.constant || false;
                const isEnabled = entry.enabled !== false;
                html += `<div class="lore-entry" style="background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius-sm);padding:12px;margin-bottom:8px;">
                    <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">
                        <strong style="color:var(--text-primary);font-size:13px">${esc(entry.key || '(no key)')}</strong>
                        <div style="display:flex;gap:8px;align-items:center">
                            <label style="display:flex;align-items:center;gap:4px;color:var(--text-secondary);font-size:12px">
                                <input type="checkbox" class="lore-enabled" data-idx="${i}" ${isEnabled ? 'checked' : ''}> On
                            </label>
                            <label style="display:flex;align-items:center;gap:4px;color:var(--text-secondary);font-size:12px">
                                <input type="checkbox" class="lore-constant" data-idx="${i}" ${isConst ? 'checked' : ''}> Always
                            </label>
                            <button class="btn-icon ec-edit-lore" data-idx="${i}" title="Edit">✏️</button>
                            <button class="btn-icon ec-delete-lore" data-idx="${i}" title="Delete">🗑️</button>
                        </div>
                    </div>
                    <div style="color:var(--text-secondary);font-size:12px;white-space:pre-wrap;max-height:60px;overflow:hidden">${esc(entry.content || '')}</div>
                </div>`;
            });
            html += '</div>';
            return html;
        }

        function renderWorldsTab() {
            if (!allWorlds.length) {
                return `<div style="padding:24px;text-align:center;color:var(--text-muted)">No worlds available. Create them on the Worlds page.</div>`;
            }
            let html = '<div style="padding:8px;display:flex;flex-direction:column;gap:8px">';
            allWorlds.forEach(w => {
                const checked = selectedWorlds.includes(w.name) ? 'checked' : '';
                html += `<label style="display:flex;align-items:start;gap:10px;padding:10px;background:var(--bg-card);border:1px solid var(--border);border-radius:var(--radius-sm);cursor:pointer">
                    <input type="checkbox" class="world-checkbox" data-name="${esc(w.name)}" ${checked} style="margin-top:2px">
                    <div>
                        <div style="color:var(--text-primary);font-size:13px;font-weight:600">${esc(w.name)}</div>
                        <div style="color:var(--text-secondary);font-size:12px">${esc(w.description || '')}</div>
                    </div>
                </label>`;
            });
            html += '</div>';
            return html;
        }

        function bindDetailsTab(modal) {
            // Add alt greeting
            modal.querySelector('#btn-ec-add-alt')?.addEventListener('click', () => {
                altGreetings.push('');
                render();
            });
            // Remove alt greeting
            modal.querySelectorAll('.ec-remove-alt').forEach(btn => {
                btn.addEventListener('click', () => { altGreetings.splice(parseInt(btn.dataset.idx), 1); render(); });
            });
            // Sync alt greeting text on blur
            modal.querySelectorAll('.ec-alt-greeting').forEach(ta => {
                ta.addEventListener('input', () => { altGreetings[parseInt(ta.dataset.idx)] = ta.value; });
            });
            // Add tag
            const addTag = () => {
                const input = modal.querySelector('#ec-tag-input');
                const val = input?.value.trim().toLowerCase();
                if (val && !tags.includes(val)) { tags.push(val); render(); }
            };
            modal.querySelector('#btn-ec-add-tag')?.addEventListener('click', addTag);
            modal.querySelector('#ec-tag-input')?.addEventListener('keydown', (e) => { if (e.key === 'Enter') { e.preventDefault(); addTag(); } });
            // Remove tag
            modal.querySelectorAll('.ec-remove-tag').forEach(btn => {
                btn.addEventListener('click', () => { tags.splice(parseInt(btn.dataset.idx), 1); render(); });
            });
            // Auto-grow textareas
            modal.querySelectorAll('.ec-autogrow').forEach(ta => {
                const autoGrow = () => {
                    ta.style.height = 'auto';
                    ta.style.height = Math.max(ta.scrollHeight, parseInt(ta.style.minHeight || 0)) + 'px';
                };
                ta.addEventListener('input', autoGrow);
                // Auto-size on initial render
                requestAnimationFrame(autoGrow);
            });
        }

        function bindLorebookTab(modal) {
            modal.querySelector('#btn-ec-add-lore')?.addEventListener('click', () => {
                lorebook.entries.push({ key: 'New Key', content: '', enabled: true, constant: false, stickyDepth: 4 });
                render();
            });
            modal.querySelectorAll('.ec-delete-lore').forEach(btn => {
                btn.addEventListener('click', () => { lorebook.entries.splice(parseInt(btn.dataset.idx), 1); render(); });
            });
            modal.querySelectorAll('.lore-enabled').forEach(cb => {
                cb.addEventListener('change', () => { lorebook.entries[parseInt(cb.dataset.idx)].enabled = cb.checked; });
            });
            modal.querySelectorAll('.lore-constant').forEach(cb => {
                cb.addEventListener('change', () => { lorebook.entries[parseInt(cb.dataset.idx)].constant = cb.checked; });
            });
            modal.querySelectorAll('.ec-edit-lore').forEach(btn => {
                btn.addEventListener('click', () => showEditLoreEntryModal(parseInt(btn.dataset.idx)));
            });
        }

        function bindWorldsTab(modal) {
            modal.querySelectorAll('.world-checkbox').forEach(cb => {
                cb.addEventListener('change', () => {
                    const name = cb.dataset.name;
                    if (cb.checked && !selectedWorlds.includes(name)) selectedWorlds.push(name);
                    if (!cb.checked) selectedWorlds = selectedWorlds.filter(n => n !== name);
                });
            });
        }

        function showEditLoreEntryModal(idx) {
            const entry = lorebook.entries[idx];
            let loreOverlay = document.createElement('div');
            loreOverlay.className = 'modal-overlay active';
            loreOverlay.style.zIndex = '1001';
            loreOverlay.innerHTML = `
                <div class="modal" style="min-width:min(450px,95vw);">
                    <div class="modal-title">Edit Lorebook Entry</div>
                    <div style="display:flex;flex-direction:column;gap:12px">
                        <div style="display:flex;align-items:center;gap:12px">
                            <label style="color:var(--text-secondary);font-size:13px;display:flex;align-items:center;gap:6px">
                                <input type="checkbox" id="le-constant" ${entry.constant ? 'checked' : ''}> Always Active
                            </label>
                            <div id="le-depth-row" style="display:${entry.constant ? 'none' : 'flex'};align-items:center;gap:8px">
                                <label class="slider-label" style="font-size:12px">Trigger Depth:</label>
                                <input type="number" id="le-depth" value="${entry.stickyDepth || 4}" min="1" max="100" class="settings-text-input" style="width:60px">
                            </div>
                        </div>
                        <div>
                            <label class="slider-label" style="display:block;margin-bottom:4px">Keywords (comma separated)</label>
                            <input type="text" id="le-key" class="settings-text-input" value="${esc(entry.key || '')}">
                        </div>
                        <div>
                            <label class="slider-label" style="display:block;margin-bottom:4px">Content</label>
                            <textarea id="le-content" class="settings-textarea" rows="6">${esc(entry.content || '')}</textarea>
                        </div>
                    </div>
                    <div class="modal-actions">
                        <button class="btn btn-outlined" id="btn-le-cancel">Cancel</button>
                        <button class="btn btn-primary" id="btn-le-save">Save</button>
                    </div>
                </div>`;
            document.body.appendChild(loreOverlay);

            loreOverlay.querySelector('#le-constant').addEventListener('change', (e) => {
                loreOverlay.querySelector('#le-depth-row').style.display = e.target.checked ? 'none' : 'flex';
            });
            loreOverlay.querySelector('#btn-le-cancel').addEventListener('click', () => loreOverlay.remove());
            loreOverlay.addEventListener('click', (e) => { if (e.target === loreOverlay) loreOverlay.remove(); });
            loreOverlay.querySelector('#btn-le-save').addEventListener('click', () => {
                entry.key = loreOverlay.querySelector('#le-key').value;
                entry.content = loreOverlay.querySelector('#le-content').value;
                entry.constant = loreOverlay.querySelector('#le-constant').checked;
                entry.stickyDepth = parseInt(loreOverlay.querySelector('#le-depth').value) || 4;
                loreOverlay.remove();
                render();
            });
        }

        async function saveCharacter() {
            const modal = overlay.querySelector('.modal');
            // Gather current field values (only if on details tab they exist)
            const getName = () => modal.querySelector('#ec-name')?.value.trim() || data.name;
            const getVal = (id) => modal.querySelector(id)?.value ?? '';

            // Read values from DOM if currently on details tab, otherwise use data/state
            const payload = {
                name: activeTab === 'details' ? getName() : data.name,
                description: activeTab === 'details' ? getVal('#ec-desc') : data.description,
                personality: activeTab === 'details' ? getVal('#ec-personality') : data.personality,
                scenario: activeTab === 'details' ? getVal('#ec-scenario') : data.scenario,
                firstMessage: activeTab === 'details' ? getVal('#ec-first-msg') : data.firstMessage,
                mesExample: activeTab === 'details' ? getVal('#ec-mes-example') : data.mesExample,
                systemPrompt: activeTab === 'details' ? getVal('#ec-system-prompt') : data.systemPrompt,
                postHistoryInstructions: activeTab === 'details' ? getVal('#ec-post-history') : data.postHistoryInstructions,
                alternateGreetings: altGreetings.filter(g => g.trim()),
                tags: tags,
                lorebook: lorebook,
                worldNames: selectedWorlds,
            };

            // Update data object so tab switching preserves edits
            if (activeTab === 'details') {
                data.name = payload.name;
                data.description = payload.description;
                data.personality = payload.personality;
                data.scenario = payload.scenario;
                data.firstMessage = payload.firstMessage;
                data.mesExample = payload.mesExample;
                data.systemPrompt = payload.systemPrompt;
                data.postHistoryInstructions = payload.postHistoryInstructions;
            }

            const res = await api('/api/characters/' + currentCharacterId + '/edit', {
                method: 'POST',
                body: JSON.stringify(payload),
            });

            if (res && res.ok) {
                currentCharacterName = payload.name;
                const nameEl = $('#chat-char-name');
                if (nameEl) nameEl.textContent = payload.name;
                const descEl = $('#rp-description');
                if (descEl) descEl.textContent = payload.description;
                const scnEl = $('#rp-scenario');
                if (scnEl) scnEl.textContent = payload.scenario;
                overlay.classList.remove('active');
                showInfoModal('Saved', 'Character updated successfully.');
            } else {
                showInfoModal('Error', 'Failed to save character.');
            }
        }

        render();
    }

    // ═══════════════════════════════════════════════════════════
    // SETTINGS & SIDEBAR PAGES
    // ═══════════════════════════════════════════════════════════

    async function loadSettings() {
        const data = await apiJson('/api/settings');
        if (!data) return;

        // Settings page — General tab
        const prompt = $('#setting-system-prompt');
        if (prompt) prompt.value = data.systemPrompt || '';

        // Backend mode
        const backendRadio = document.querySelector(`input[name="backendMode"][value="${data.activeBackend || 'openRouter'}"]`);
        if (backendRadio) backendRadio.checked = true;

        // API Config
        const apiUrl = $('#setting-api-url');
        if (apiUrl) apiUrl.value = data.apiUrl || '';
        const apiKey = $('#setting-api-key');
        if (apiKey && data.apiKeySet) apiKey.placeholder = `Key saved (${data.apiKey})`;
        const apiModelSel = $('#setting-api-model');
        if (apiModelSel && data.apiModel) {
            // Add a placeholder option with current model
            let found = false;
            for (let opt of apiModelSel.options) {
                if (opt.value === data.apiModel) { opt.selected = true; found = true; }
            }
            if (!found) {
                const opt = document.createElement('option');
                opt.value = data.apiModel;
                opt.textContent = data.apiModel;
                opt.selected = true;
                apiModelSel.appendChild(opt);
            }
        }

        // Reasoning
        const reasoningCb = $('#setting-reasoning-enabled');
        if (reasoningCb) {
            reasoningCb.checked = data.reasoningEnabled ?? false;
            const effortRow = $('#reasoning-effort-row');
            if (effortRow) effortRow.style.display = reasoningCb.checked ? 'block' : 'none';
        }
        const effortSel = $('#setting-reasoning-effort');
        if (effortSel) effortSel.value = data.reasoningEffort || 'medium';

        // TTS settings
        const ttsCb = $('#setting-tts-enabled');
        if (ttsCb) ttsCb.checked = data.ttsEnabled ?? false;
        const ttsEngine = $('#setting-tts-engine');
        if (ttsEngine) ttsEngine.value = data.ttsEngine || 'kokoro';
        // Show/hide OpenAI TTS fields
        const openaiFields = $('#openai-tts-fields');
        if (openaiFields) openaiFields.style.display = (data.ttsEngine === 'openai') ? 'block' : 'none';
        // Populate voice dropdown
        const voiceSel = $('#setting-tts-voice');
        if (voiceSel && data.ttsVoices) {
            voiceSel.innerHTML = '<option value="">-- Select voice --</option>';
            for (const v of data.ttsVoices) {
                const opt = document.createElement('option');
                opt.value = v.id;
                opt.textContent = v.name || v.id;
                if (v.id === data.ttsVoice) opt.selected = true;
                voiceSel.appendChild(opt);
            }
        }
        const ttsRate = $('#setting-tts-rate');
        if (ttsRate) {
            ttsRate.value = data.ttsSpeechRate ?? 1.0;
            const rv = $('#tts-rate-value');
            if (rv) rv.textContent = parseFloat(ttsRate.value).toFixed(1) + '×';
        }
        const ttsConcur = $('#setting-tts-concurrency');
        if (ttsConcur) ttsConcur.value = data.ttsConcurrency ?? 4;
        const ttsAuto = $('#setting-tts-autoplay');
        if (ttsAuto) ttsAuto.checked = data.ttsAutoPlay ?? false;
        const oaiKey = $('#setting-openai-tts-key');
        if (oaiKey && data.openaiTtsApiKeySet) oaiKey.placeholder = 'Key saved';
        const oaiModel = $('#setting-openai-tts-model');
        if (oaiModel) oaiModel.value = data.openaiTtsModel || 'tts-1';
        // Show/hide ElevenLabs TTS fields
        const elFields = $('#elevenlabs-tts-fields');
        if (elFields) elFields.style.display = (data.ttsEngine === 'elevenlabs') ? 'block' : 'none';
        const elKey = $('#setting-elevenlabs-key');
        if (elKey && data.elevenlabsApiKeySet) elKey.placeholder = 'Key saved';
        const elModel = $('#setting-elevenlabs-model');
        if (elModel) elModel.value = data.elevenlabsModel || 'eleven_flash_v2_5';
        const elStab = $('#setting-el-stability');
        if (elStab) { elStab.value = data.elevenlabsStability ?? 0.5; const v = $('#el-stability-value'); if (v) v.textContent = parseFloat(elStab.value).toFixed(2); }
        const elSim = $('#setting-el-similarity');
        if (elSim) { elSim.value = data.elevenlabsSimilarity ?? 0.75; const v = $('#el-similarity-value'); if (v) v.textContent = parseFloat(elSim.value).toFixed(2); }
        const elStyle = $('#setting-el-style');
        if (elStyle) { elStyle.value = data.elevenlabsStyle ?? 0.0; const v = $('#el-style-value'); if (v) v.textContent = parseFloat(elStyle.value).toFixed(2); }

        // Image Gen
        const igCb = $('#setting-imgen-enabled');
        if (igCb) igCb.checked = data.imageGenEnabled ?? false;
        const igModel = $('#setting-imgen-model');
        if (igModel) igModel.value = data.imageGenModel || '';

        // RAG / Memory
        const ragCb = $('#setting-rag-enabled');
        if (ragCb) ragCb.checked = data.ragEnabled ?? false;
        const ragFields = $('#rag-config-fields');
        if (ragFields) ragFields.style.display = (data.ragEnabled) ? 'block' : 'none';
        const ragRetrieval = $('#setting-rag-retrieval');
        if (ragRetrieval) {
            ragRetrieval.value = data.ragRetrievalCount ?? 10;
            const rv = $('#rag-retrieval-value');
            if (rv) rv.textContent = data.ragRetrievalCount == 0 ? 'All' : data.ragRetrievalCount;
        }
        const ragWindow = $('#setting-rag-window');
        if (ragWindow) {
            ragWindow.value = data.ragWindowSize ?? 5;
            const wv = $('#rag-window-value');
            if (wv) wv.textContent = data.ragWindowSize ?? 5;
        }
        const ragSource = $('#setting-rag-source');
        if (ragSource) ragSource.value = data.ragEmbeddingSource || 'auto';
        const ragModel = $('#setting-rag-model');
        if (ragModel) ragModel.value = data.ragEmbeddingModel || '';
        // Auto-persona
        const apCb = $('#setting-auto-persona');
        if (apCb) apCb.checked = data.autoPersonaEnabled ?? false;
        const apFields = $('#auto-persona-fields');
        if (apFields) apFields.style.display = (data.autoPersonaEnabled) ? 'block' : 'none';
        const apInterval = $('#setting-persona-interval');
        if (apInterval) {
            apInterval.value = data.autoPersonaInterval ?? 5;
            const iv = $('#persona-interval-value');
            if (iv) iv.textContent = (data.autoPersonaInterval ?? 5) + ' msgs';
        }

        // Font scale
        const scaleSlider = $('#setting-text-scale');
        if (scaleSlider) {
            scaleSlider.value = data.textScale || 1.0;
            const scaleVal = $('#text-scale-value');
            if (scaleVal) scaleVal.textContent = parseFloat(scaleSlider.value).toFixed(1) + '×';
        }

        // Advanced tab — sampler sliders
        const setSlider = (id, valId, value, fmt) => {
            const el = $(id);
            if (el) {
                el.value = value;
                const v = $(valId);
                if (v) v.textContent = fmt(value);
            }
        };
        const f2 = v => parseFloat(v).toFixed(2);

        setSlider('#setting-temperature', '#temperature-value', data.temperature ?? 0.7, f2);
        setSlider('#setting-min-p', '#min-p-value', data.minP ?? 0.1, f2);
        setSlider('#setting-rep-pen', '#rep-pen-value', data.repetitionPenalty ?? 1.1, f2);
        setSlider('#setting-xtc-threshold', '#xtc-threshold-value', data.xtcThreshold ?? 0.1, f2);
        setSlider('#setting-xtc-prob', '#xtc-prob-value', data.xtcProbability ?? 0.5, f2);

        const maxTok = $('#setting-max-tokens');
        if (maxTok) maxTok.value = data.maxTokens ?? 200;
        const minTok = $('#setting-min-tokens');
        if (minTok) minTok.value = data.minTokens ?? 0;
        const repPenTok = $('#setting-rep-pen-tokens');
        if (repPenTok) repPenTok.value = data.repeatPenaltyTokens ?? 64;
        const ctxSize = $('#setting-context-size');
        if (ctxSize) ctxSize.value = data.contextSize ?? 8192;

        // Dynamic temperature
        const dynCheck = $('#setting-dyntemp-enabled');
        if (dynCheck) {
            dynCheck.checked = data.dynamicTempEnabled ?? false;
            const row = $('#dyntemp-range-row');
            if (row) row.style.display = dynCheck.checked ? 'flex' : 'none';
        }
        setSlider('#setting-dyntemp-range', '#dyntemp-range-value', data.dynamicTempRange ?? 0.7, f2);

        // Stop sequences
        const stopList = $('#stop-sequences-list');
        if (stopList) {
            const seqs = data.stopSequences || [];
            if (seqs.length > 0) {
                stopList.innerHTML = seqs.map(s => `<span class="stop-seq-chip">${esc(s)}</span>`).join('');
            } else {
                stopList.innerHTML = '<span style="color:var(--text-muted);font-size:13px">None configured</span>';
            }
        }

        // Models page
        const backend = $('#model-backend');
        if (backend) backend.textContent = data.activeBackend || '—';
        const provider = $('#model-provider');
        if (provider) provider.textContent = data.activeBackend || '—';
        const modelName = $('#model-name');
        if (modelName) modelName.textContent = data.apiModel || '—';

        const apiModelInput = $('#api-model-input');
        if (apiModelInput) apiModelInput.value = data.apiModel || '';
        const apiUrlInput = $('#api-url-input');
        if (apiUrlInput) apiUrlInput.value = data.apiUrl || '';
    }

    async function loadPersonas() {
        const data = await apiJson('/api/personas');
        const list = $('#persona-list');
        if (!list) return;

        const personas = Array.isArray(data) ? data : [];

        if (!personas.length) {
            list.innerHTML = '<p style="text-align:center;color:var(--text-muted);padding:40px 0">No personas yet. Click "+ New Persona" to create one.</p>';
            return;
        }

        list.innerHTML = personas.map(p => `
            <div class="persona-card${p.isActive ? ' active' : ''}" data-persona-id="${p.id}">
                <div class="persona-card-header">
                    <div class="persona-card-name">${esc(p.name || p.title || 'Untitled')}</div>
                    <div style="display:flex;gap:8px;align-items:center">
                        ${p.isActive ? '<span class="persona-card-badge">Active</span>' : ''}
                        <button class="btn-icon btn-edit-persona" data-id="${p.id}" data-title="${esc(p.title || '')}" data-name="${esc(p.name || '')}" data-desc="${esc(p.description || '')}" title="Edit">✏️</button>
                        <button class="btn-icon btn-delete-persona" data-id="${p.id}" title="Delete">🗑️</button>
                    </div>
                </div>
                <div class="persona-card-desc">
                    ${esc(p.description || p.persona || 'No description')}
                </div>
            </div>
        `).join('');

        // Click card body to set active (not on icon buttons)
        list.querySelectorAll('.persona-card').forEach(card => {
            card.addEventListener('click', async (e) => {
                if (e.target.closest('.btn-icon')) return;
                const id = card.dataset.personaId;
                await api('/api/personas/active', {
                    method: 'POST',
                    body: JSON.stringify({ id }),
                });
                loadPersonas();
            });
        });

        // Delete buttons
        list.querySelectorAll('.btn-delete-persona').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                e.stopPropagation();
                e.preventDefault();
                const id = btn.dataset.id;
                showConfirmModal('Delete Persona', 'Are you sure you want to delete this persona?', async () => {
                    await api('/api/personas/delete', {
                        method: 'POST',
                        body: JSON.stringify({ id }),
                    });
                    loadPersonas();
                });
            });
        });

        // Edit buttons
        list.querySelectorAll('.btn-edit-persona').forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.stopPropagation();
                showEditPersonaModal(btn.dataset.id, btn.dataset.title, btn.dataset.name, btn.dataset.desc);
            });
        });
    }

    function showEditPersonaModal(id, title, name, desc) {
        let overlay = document.createElement('div');
        overlay.className = 'modal-overlay active';
        overlay.innerHTML = `
            <div class="modal" style="min-width:min(460px,95vw);">
                <div class="modal-title">Edit Persona</div>
                <div style="display:flex;flex-direction:column;gap:12px;">
                    <label style="color:var(--text-secondary);font-size:13px;">Title
                        <input id="ep-title" type="text" value="${esc(title)}"
                               style="width:100%;margin-top:4px;padding:8px 12px;background:var(--bg-input);border:1px solid var(--border);border-radius:var(--radius-sm);color:var(--text-primary);font-family:inherit;font-size:14px;outline:none;">
                    </label>
                    <label style="color:var(--text-secondary);font-size:13px;">Name
                        <input id="ep-name" type="text" value="${esc(name)}"
                               style="width:100%;margin-top:4px;padding:8px 12px;background:var(--bg-input);border:1px solid var(--border);border-radius:var(--radius-sm);color:var(--text-primary);font-family:inherit;font-size:14px;outline:none;">
                    </label>
                    <label style="color:var(--text-secondary);font-size:13px;">Description
                        <textarea id="ep-desc" rows="3"
                                  style="width:100%;margin-top:4px;padding:8px 12px;background:var(--bg-input);border:1px solid var(--border);border-radius:var(--radius-sm);color:var(--text-primary);font-family:inherit;font-size:14px;outline:none;resize:vertical;">${esc(desc)}</textarea>
                    </label>
                </div>
                <div class="modal-actions">
                    <button class="btn btn-outlined" id="btn-ep-cancel">Cancel</button>
                    <button class="btn btn-primary" id="btn-ep-save">Save</button>
                </div>
            </div>`;
        document.body.appendChild(overlay);

        overlay.querySelector('#btn-ep-cancel').addEventListener('click', () => overlay.remove());
        overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });
        overlay.querySelector('#btn-ep-save').addEventListener('click', async () => {
            const res = await api('/api/personas/update', {
                method: 'POST',
                body: JSON.stringify({
                    id,
                    title: overlay.querySelector('#ep-title').value.trim(),
                    name: overlay.querySelector('#ep-name').value.trim(),
                    description: overlay.querySelector('#ep-desc').value.trim(),
                }),
            });
            if (res && res.ok) { overlay.remove(); loadPersonas(); }
        });
    }

    function showCreatePersonaModal() {
        let overlay = $('#create-persona-modal');
        if (!overlay) {
            overlay = document.createElement('div');
            overlay.id = 'create-persona-modal';
            overlay.className = 'modal-overlay';
            document.body.appendChild(overlay);
        }

        overlay.innerHTML = `
            <div class="modal" style="min-width:min(460px,95vw);">
                <div class="modal-title">Create Persona</div>
                <div style="display:flex;flex-direction:column;gap:12px;">
                    <label style="color:var(--text-secondary);font-size:13px;">Title
                        <input id="cp-title" type="text" placeholder="e.g. Adventure Writer"
                               style="width:100%;margin-top:4px;padding:8px 12px;background:var(--bg-input);border:1px solid var(--border);border-radius:var(--radius-sm);color:var(--text-primary);font-family:inherit;font-size:14px;outline:none;">
                    </label>
                    <label style="color:var(--text-secondary);font-size:13px;">Display Name
                        <input id="cp-name" type="text" value="User" placeholder="Your name in chat"
                               style="width:100%;margin-top:4px;padding:8px 12px;background:var(--bg-input);border:1px solid var(--border);border-radius:var(--radius-sm);color:var(--text-primary);font-family:inherit;font-size:14px;outline:none;">
                    </label>
                    <label style="color:var(--text-secondary);font-size:13px;">Description
                        <textarea id="cp-desc" rows="2" placeholder="Short description..."
                                  style="width:100%;margin-top:4px;padding:8px 12px;background:var(--bg-input);border:1px solid var(--border);border-radius:var(--radius-sm);color:var(--text-primary);font-family:inherit;font-size:14px;outline:none;resize:vertical;"></textarea>
                    </label>
                    <label style="color:var(--text-secondary);font-size:13px;">Persona Text
                        <textarea id="cp-persona" rows="4" placeholder="Describe your persona in detail..."
                                  style="width:100%;margin-top:4px;padding:8px 12px;background:var(--bg-input);border:1px solid var(--border);border-radius:var(--radius-sm);color:var(--text-primary);font-family:inherit;font-size:14px;outline:none;resize:vertical;"></textarea>
                    </label>
                </div>
                <div class="modal-actions">
                    <button class="btn btn-outlined" id="btn-cp-cancel">Cancel</button>
                    <button class="btn btn-primary" id="btn-cp-save">Create</button>
                </div>
            </div>
        `;
        overlay.classList.add('active');

        overlay.querySelector('#btn-cp-cancel').addEventListener('click', () => overlay.classList.remove('active'));
        overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.classList.remove('active'); });

        overlay.querySelector('#btn-cp-save').addEventListener('click', async () => {
            const title = overlay.querySelector('#cp-title').value.trim();
            const name = overlay.querySelector('#cp-name').value.trim() || 'User';
            const desc = overlay.querySelector('#cp-desc').value.trim();
            const persona = overlay.querySelector('#cp-persona').value.trim();

            if (!title) { showInfoModal('Error', 'Title is required.'); return; }

            const res = await api('/api/personas', {
                method: 'POST',
                body: JSON.stringify({ title, name, description: desc, persona }),
            });
            if (res && res.ok) {
                overlay.classList.remove('active');
                loadPersonas();
            }
        });
    }

    // ═══════════════════════════════════════════════════════════
    // WORLD MANAGEMENT
    // ═══════════════════════════════════════════════════════════

    async function loadWorlds() {
        const data = await apiJson('/api/worlds');
        const list = document.querySelector('#world-list');
        if (!list) return;

        const worlds = Array.isArray(data) ? data : [];
        if (!worlds.length) {
            list.innerHTML = '<p style="text-align:center;color:var(--text-muted);padding:40px 0">No worlds yet. Click "+ New World" to create one.</p>';
            return;
        }

        list.innerHTML = worlds.map(w => {
            const entryCount = w.lorebook && w.lorebook.entries ? w.lorebook.entries.length : 0;
            return `<div class="persona-card" style="margin:0">
                <div class="persona-card-header">
                    <div class="persona-card-name">${esc(w.name)}</div>
                    <div style="display:flex;gap:8px;align-items:center">
                        <span style="color:var(--text-muted);font-size:12px">${entryCount} entries</span>
                        <button class="btn-icon btn-edit-world" data-id="${w.id}" data-name="${esc(w.name)}" data-desc="${esc(w.description || '')}" data-lore='${esc(JSON.stringify(w.lorebook || { entries: [] }))}' title="Edit">✏️</button>
                        <button class="btn-icon btn-delete-world" data-id="${w.id}" title="Delete">🗑️</button>
                    </div>
                </div>
                <div class="persona-card-desc">${esc(w.description || 'No description')}</div>
            </div>`;
        }).join('');

        list.querySelectorAll('.btn-edit-world').forEach(btn => {
            btn.addEventListener('click', () => {
                let lore;
                try { lore = JSON.parse(btn.dataset.lore); } catch (_) { lore = { entries: [] }; }
                showWorldModal(btn.dataset.id, btn.dataset.name, btn.dataset.desc, lore);
            });
        });

        list.querySelectorAll('.btn-delete-world').forEach(btn => {
            btn.addEventListener('click', async () => {
                if (!confirm('Delete this world?')) return;
                await api('/api/worlds/delete', { method: 'POST', body: JSON.stringify({ id: btn.dataset.id }) });
                loadWorlds();
            });
        });
    }

    function showWorldModal(editId, name, desc, lorebook) {
        const isEdit = !!editId;
        let lore = lorebook || { entries: [] };

        let overlay = document.createElement('div');
        overlay.className = 'modal-overlay active';

        function renderModal() {
            let entriesHtml = lore.entries.map((e, i) => `
                <div style="display:flex;gap:8px;align-items:center;padding:8px;background:var(--bg-input);border-radius:var(--radius-sm);">
                    <div style="flex:1">
                        <div style="color:var(--text-primary);font-size:13px;font-weight:600">${esc(e.key || '(no key)')}</div>
                        <div style="color:var(--text-secondary);font-size:11px;max-height:30px;overflow:hidden">${esc(e.content || '')}</div>
                    </div>
                    <button class="btn-icon wm-edit-entry" data-idx="${i}" title="Edit">✏️</button>
                    <button class="btn-icon wm-del-entry" data-idx="${i}" title="Delete">🗑️</button>
                </div>
            `).join('');

            overlay.innerHTML = `
                <div class="modal" style="min-width:min(520px,95vw);max-height:80vh;display:flex;flex-direction:column;">
                    <div class="modal-title">${isEdit ? 'Edit' : 'Create'} World</div>
                    <div style="overflow-y:auto;flex:1;display:flex;flex-direction:column;gap:12px;padding:4px">
                        <div><label class="slider-label" style="display:block;margin-bottom:4px">Name</label>
                            <input type="text" id="wm-name" class="settings-text-input" value="${esc(name || '')}"></div>
                        <div><label class="slider-label" style="display:block;margin-bottom:4px">Description</label>
                            <textarea id="wm-desc" class="settings-textarea" rows="2">${esc(desc || '')}</textarea></div>
                        <div>
                            <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">
                                <label class="slider-label">Lorebook Entries</label>
                                <button class="btn btn-outlined" id="btn-wm-add-entry" style="font-size:12px;padding:4px 10px">+ Add</button>
                            </div>
                            <div style="display:flex;flex-direction:column;gap:6px">${entriesHtml || '<p style="color:var(--text-muted);font-size:12px">No entries yet.</p>'}</div>
                        </div>
                    </div>
                    <div class="modal-actions">
                        <button class="btn btn-outlined" id="btn-wm-cancel">Cancel</button>
                        <button class="btn btn-primary" id="btn-wm-save">${isEdit ? 'Save' : 'Create'}</button>
                    </div>
                </div>`;

            overlay.querySelector('#btn-wm-cancel').addEventListener('click', () => overlay.remove());
            overlay.querySelector('#btn-wm-add-entry')?.addEventListener('click', () => {
                lore.entries.push({ key: 'New Key', content: '', enabled: true, constant: false, stickyDepth: 4 });
                renderModal();
            });
            overlay.querySelectorAll('.wm-del-entry').forEach(btn => {
                btn.addEventListener('click', () => { lore.entries.splice(parseInt(btn.dataset.idx), 1); renderModal(); });
            });
            overlay.querySelectorAll('.wm-edit-entry').forEach(btn => {
                btn.addEventListener('click', () => {
                    const idx = parseInt(btn.dataset.idx);
                    const entry = lore.entries[idx];
                    const key = prompt('Keywords (comma separated):', entry.key || '');
                    if (key === null) return;
                    const content = prompt('Content:', entry.content || '');
                    if (content === null) return;
                    entry.key = key;
                    entry.content = content;
                    renderModal();
                });
            });

            overlay.querySelector('#btn-wm-save').addEventListener('click', async () => {
                const newName = overlay.querySelector('#wm-name').value.trim();
                if (!newName) { showInfoModal('Error', 'Name is required.'); return; }
                const payload = {
                    name: newName,
                    description: overlay.querySelector('#wm-desc').value.trim(),
                    lorebook: lore,
                };
                if (isEdit) payload.id = editId;

                const endpoint = isEdit ? '/api/worlds/update' : '/api/worlds';
                const res = await api(endpoint, { method: 'POST', body: JSON.stringify(payload) });
                if (res && res.ok) { overlay.remove(); loadWorlds(); }
                else { showInfoModal('Error', 'Failed to save world.'); }
            });
        }

        document.body.appendChild(overlay);
        renderModal();
    }

    function initTabSwitching() {
        document.querySelectorAll('.settings-tabs').forEach(tabBar => {
            tabBar.querySelectorAll('.tab-btn').forEach(btn => {
                btn.addEventListener('click', () => {
                    // Deactivate all tabs in this group
                    tabBar.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
                    btn.classList.add('active');

                    // Show matching panel
                    const tabId = btn.dataset.tab;
                    const parent = tabBar.parentElement;
                    parent.querySelectorAll('.tab-panel').forEach(p => p.classList.remove('active'));
                    const panel = parent.querySelector(`#tab-${tabId}`);
                    if (panel) panel.classList.add('active');
                });
            });
        });
    }

    function initSettingsBindings() {
        // Slider value displays
        const bindSlider = (sliderId, displayId, format) => {
            const slider = $(sliderId);
            const display = $(displayId);
            if (slider && display) {
                slider.addEventListener('input', () => {
                    display.textContent = format(slider.value);
                });
            }
        };
        bindSlider('#setting-temperature', '#temperature-value', v => parseFloat(v).toFixed(2));
        bindSlider('#setting-min-p', '#min-p-value', v => parseFloat(v).toFixed(2));
        bindSlider('#setting-rep-pen', '#rep-pen-value', v => parseFloat(v).toFixed(2));
        bindSlider('#setting-xtc-threshold', '#xtc-threshold-value', v => parseFloat(v).toFixed(2));
        bindSlider('#setting-xtc-prob', '#xtc-prob-value', v => parseFloat(v).toFixed(2));
        bindSlider('#setting-dyntemp-range', '#dyntemp-range-value', v => parseFloat(v).toFixed(2));
        bindSlider('#setting-text-scale', '#text-scale-value', v => parseFloat(v).toFixed(1) + '×');

        // Dynamic temperature toggle
        $('#setting-dyntemp-enabled')?.addEventListener('change', () => {
            const row = $('#dyntemp-range-row');
            if (row) row.style.display = $('#setting-dyntemp-enabled').checked ? 'flex' : 'none';
        });

        // Save system prompt
        $('#btn-save-prompt')?.addEventListener('click', async () => {
            const prompt = $('#setting-system-prompt').value;
            const res = await api('/api/settings', {
                method: 'POST',
                body: JSON.stringify({ systemPrompt: prompt }),
            });
            if (res && res.ok) {
                showInfoModal('Saved', 'System prompt saved successfully.');
            }
        });

        // Save sampler settings
        $('#btn-save-samplers')?.addEventListener('click', async () => {
            const payload = {
                temperature: parseFloat($('#setting-temperature').value),
                minP: parseFloat($('#setting-min-p').value),
                maxTokens: parseInt($('#setting-max-tokens').value),
                minTokens: parseInt($('#setting-min-tokens')?.value || '0'),
                repetitionPenalty: parseFloat($('#setting-rep-pen').value),
                repeatPenaltyTokens: parseInt($('#setting-rep-pen-tokens')?.value || '64'),
                xtcThreshold: parseFloat($('#setting-xtc-threshold')?.value || '0.1'),
                xtcProbability: parseFloat($('#setting-xtc-prob')?.value || '0.5'),
                contextSize: parseInt($('#setting-context-size')?.value || '8192'),
                dynamicTempEnabled: $('#setting-dyntemp-enabled')?.checked || false,
                dynamicTempRange: parseFloat($('#setting-dyntemp-range')?.value || '0.7'),
            };
            const res = await api('/api/settings', {
                method: 'POST',
                body: JSON.stringify(payload),
            });
            if (res && res.ok) {
                showInfoModal('Saved', 'Sampler settings saved successfully.');
            }
        });

        // Text scale auto-save
        $('#setting-text-scale')?.addEventListener('change', async () => {
            await api('/api/settings', {
                method: 'POST',
                body: JSON.stringify({ textScale: parseFloat($('#setting-text-scale').value) }),
            });
        });

        // TTS engine change — show/hide engine-specific fields and reload voices
        $('#setting-tts-engine')?.addEventListener('change', async () => {
            const eng = $('#setting-tts-engine').value;
            const oaiFields = $('#openai-tts-fields');
            const elFields = $('#elevenlabs-tts-fields');
            if (oaiFields) oaiFields.style.display = eng === 'openai' ? 'block' : 'none';
            if (elFields) elFields.style.display = eng === 'elevenlabs' ? 'block' : 'none';
            // Save engine first, then reload settings to get updated voice list
            await api('/api/settings', {
                method: 'POST',
                body: JSON.stringify({ ttsEngine: eng }),
            });
            loadSettings();
        });

        // TTS speech rate slider feedback
        $('#setting-tts-rate')?.addEventListener('input', () => {
            const rv = $('#tts-rate-value');
            if (rv) rv.textContent = parseFloat($('#setting-tts-rate').value).toFixed(1) + '×';
        });

        // ElevenLabs slider feedback
        for (const [id, valId] of [['setting-el-stability', 'el-stability-value'], ['setting-el-similarity', 'el-similarity-value'], ['setting-el-style', 'el-style-value']]) {
            $(`#${id}`)?.addEventListener('input', (e) => {
                const v = $(`#${valId}`);
                if (v) v.textContent = parseFloat(e.target.value).toFixed(2);
            });
        }

        // Save TTS settings
        $('#btn-save-tts')?.addEventListener('click', async () => {
            const payload = {
                ttsEnabled: $('#setting-tts-enabled')?.checked || false,
                ttsEngine: $('#setting-tts-engine')?.value || 'kokoro',
                ttsVoice: $('#setting-tts-voice')?.value || '',
                ttsSpeechRate: parseFloat($('#setting-tts-rate')?.value || '1.0'),
                ttsConcurrency: parseInt($('#setting-tts-concurrency')?.value || '4'),
                ttsAutoPlay: $('#setting-tts-autoplay')?.checked || false,
                ttsNarrateQuotedOnly: $('#setting-tts-quotes-only')?.checked || false,
                ttsIgnoreAsterisks: $('#setting-tts-ignore-asterisks')?.checked || false,
            };
            // OpenAI TTS fields
            const oaiKey = $('#setting-openai-tts-key')?.value;
            if (oaiKey) payload.openaiTtsApiKey = oaiKey;
            payload.openaiTtsModel = $('#setting-openai-tts-model')?.value || 'tts-1';
            // ElevenLabs fields
            const elKey = $('#setting-elevenlabs-key')?.value;
            if (elKey) payload.elevenlabsApiKey = elKey;
            payload.elevenlabsModel = $('#setting-elevenlabs-model')?.value || 'eleven_flash_v2_5';
            payload.elevenlabsStability = parseFloat($('#setting-el-stability')?.value || '0.5');
            payload.elevenlabsSimilarity = parseFloat($('#setting-el-similarity')?.value || '0.75');
            payload.elevenlabsStyle = parseFloat($('#setting-el-style')?.value || '0.0');
            const res = await api('/api/settings', {
                method: 'POST',
                body: JSON.stringify(payload),
            });
            if (res && res.ok) showInfoModal('Saved', 'TTS settings saved.');
        });

        // Save Image Gen settings
        $('#btn-save-imgen')?.addEventListener('click', async () => {
            const res = await api('/api/settings', {
                method: 'POST',
                body: JSON.stringify({
                    imageGenEnabled: $('#setting-imgen-enabled')?.checked || false,
                    imageGenModel: $('#setting-imgen-model')?.value || '',
                }),
            });
            if (res && res.ok) showInfoModal('Saved', 'Image generation settings saved.');
        });

        // RAG / Memory save
        $('#btn-save-rag')?.addEventListener('click', async () => {
            const res = await api('/api/settings', {
                method: 'POST',
                body: JSON.stringify({
                    ragEnabled: $('#setting-rag-enabled')?.checked || false,
                    ragRetrievalCount: parseInt($('#setting-rag-retrieval')?.value) || 10,
                    ragWindowSize: parseInt($('#setting-rag-window')?.value) || 5,
                    ragEmbeddingSource: $('#setting-rag-source')?.value || 'auto',
                    ragEmbeddingModel: $('#setting-rag-model')?.value || '',
                    autoPersonaEnabled: $('#setting-auto-persona')?.checked || false,
                    autoPersonaInterval: parseInt($('#setting-persona-interval')?.value) || 5,
                }),
            });
            if (res && res.ok) showInfoModal('Saved', 'Memory settings saved.');
        });

        // RAG toggle — show/hide config fields
        $('#setting-rag-enabled')?.addEventListener('change', () => {
            const fields = $('#rag-config-fields');
            if (fields) fields.style.display = $('#setting-rag-enabled').checked ? 'block' : 'none';
        });

        // RAG retrieval slider — update label
        $('#setting-rag-retrieval')?.addEventListener('input', () => {
            const val = parseInt($('#setting-rag-retrieval').value);
            const label = $('#rag-retrieval-value');
            if (label) label.textContent = val === 0 ? 'All' : val;
        });

        // RAG window slider — update label
        $('#setting-rag-window')?.addEventListener('input', () => {
            const label = $('#rag-window-value');
            if (label) label.textContent = $('#setting-rag-window').value;
        });

        // Auto-persona toggle — show/hide interval
        $('#setting-auto-persona')?.addEventListener('change', () => {
            const fields = $('#auto-persona-fields');
            if (fields) fields.style.display = $('#setting-auto-persona').checked ? 'block' : 'none';
        });

        // Auto-persona interval slider — update label
        $('#setting-persona-interval')?.addEventListener('input', () => {
            const label = $('#persona-interval-value');
            if (label) label.textContent = $('#setting-persona-interval').value + ' msgs';
        });

        // Reasoning toggle
        $('#setting-reasoning-enabled')?.addEventListener('change', () => {
            const effortRow = $('#reasoning-effort-row');
            if (effortRow) effortRow.style.display = $('#setting-reasoning-enabled').checked ? 'block' : 'none';
        });

        // Save API Config (from settings page)
        const settingsApiSave = document.querySelector('#tab-settings-general #btn-save-api-config');
        if (settingsApiSave) {
            settingsApiSave.addEventListener('click', async () => {
                const payload = {};
                const backend = document.querySelector('input[name="backendMode"]:checked')?.value;
                if (backend) payload.activeBackend = backend;
                const url = $('#setting-api-url')?.value;
                if (url) payload.apiUrl = url;
                const key = $('#setting-api-key')?.value;
                if (key) payload.apiKey = key;
                const model = $('#setting-api-model')?.value;
                if (model) payload.apiModel = model;
                payload.reasoningEnabled = $('#setting-reasoning-enabled')?.checked || false;
                payload.reasoningEffort = $('#setting-reasoning-effort')?.value || 'medium';
                const res = await api('/api/settings', {
                    method: 'POST',
                    body: JSON.stringify(payload),
                });
                if (res && res.ok) showInfoModal('Saved', 'API configuration saved.');
            });
        }

        // Test Connection button
        $('#btn-test-connection')?.addEventListener('click', async () => {
            const btn = $('#btn-test-connection');
            btn.textContent = '⏳ Testing...';
            btn.disabled = true;
            try {
                // Save config first
                const key = $('#setting-api-key')?.value;
                const url = $('#setting-api-url')?.value;
                if (key || url) {
                    await api('/api/settings', {
                        method: 'POST',
                        body: JSON.stringify({
                            ...(key ? { apiKey: key } : {}),
                            ...(url ? { apiUrl: url } : {}),
                        }),
                    });
                }
                const data = await apiJson('/api/models/test-connection', { method: 'POST' });
                if (data && data.message) {
                    showInfoModal('Connection', data.message);
                }
            } catch (e) {
                showInfoModal('Error', 'Connection test failed.');
            } finally {
                btn.textContent = '📡 Test Connection';
                btn.disabled = false;
            }
        });

        // Refresh Models button
        $('#btn-refresh-models')?.addEventListener('click', async () => {
            const btn = $('#btn-refresh-models');
            btn.textContent = '⏳ Loading...';
            btn.disabled = true;
            try {
                const models = await apiJson('/api/models/list');
                const sel = $('#setting-api-model');
                const search = $('#setting-api-model-search');
                if (sel && models && Array.isArray(models)) {
                    const currentVal = sel.value;
                    sel.innerHTML = '<option value="">-- Select a model --</option>';
                    window._apiModels = models;
                    for (const m of models) {
                        const opt = document.createElement('option');
                        opt.value = m.id;
                        opt.textContent = `${m.name}${m.isFree ? ' 🟢' : ''} ${m.pricing || ''}`;
                        if (m.id === currentVal) opt.selected = true;
                        sel.appendChild(opt);
                    }
                    if (search) {
                        search.style.display = models.length > 10 ? 'block' : 'none';
                        search.value = '';
                        search.oninput = () => {
                            const q = search.value.toLowerCase();
                            for (const opt of sel.options) {
                                if (!opt.value) continue;
                                opt.hidden = q && !opt.textContent.toLowerCase().includes(q);
                            }
                        };
                    }
                    showInfoModal('Models', `Loaded ${models.length} models.`);
                }
            } catch (e) {
                showInfoModal('Error', 'Failed to load models.');
            } finally {
                btn.textContent = '🔄 Refresh Models';
                btn.disabled = false;
            }
        });
    }

    function initModelPageBindings() {
        // API key show/hide toggle
        $('#btn-toggle-key')?.addEventListener('click', () => {
            const input = $('#api-key-input');
            if (input) input.type = input.type === 'password' ? 'text' : 'password';
        });

        // Save API config
        $('#btn-save-api-config')?.addEventListener('click', async () => {
            const payload = {};
            const backend = $('#api-backend-select')?.value;
            if (backend) payload.activeBackend = backend;

            // Only send API key if user typed a new one (not the empty placeholder)
            const keyInput = $('#api-key-input');
            if (keyInput && keyInput.value.trim()) {
                payload.apiKey = keyInput.value.trim();
            }

            // Read model from dropdown if visible, otherwise from text input
            const selectEl = $('#api-model-select');
            const inputEl = $('#api-model-input');
            if (selectEl && selectEl.style.display !== 'none' && selectEl.value) {
                payload.apiModel = selectEl.value;
            } else if (inputEl) {
                payload.apiModel = inputEl.value;
            }

            const url = $('#api-url-input')?.value;
            if (url !== undefined) payload.apiUrl = url;

            const res = await api('/api/settings', {
                method: 'POST',
                body: JSON.stringify(payload),
            });
            if (res && res.ok) {
                showInfoModal('Saved', 'API configuration saved successfully.');
                loadSettings(); // Refresh display
            }
        });

        // Fetch models button
        let _allModels = [];
        $('#btn-fetch-models')?.addEventListener('click', async () => {
            const statusEl = $('#model-fetch-status');
            const selectEl = $('#api-model-select');
            const inputEl = $('#api-model-input');
            const btn = $('#btn-fetch-models');
            if (statusEl) statusEl.textContent = 'Fetching models...';
            btn.disabled = true;
            btn.textContent = 'Loading...';

            const data = await apiJson('/api/models/list');
            btn.disabled = false;
            btn.textContent = 'Fetch Models';

            if (!data || !Array.isArray(data) || data.length === 0) {
                if (statusEl) statusEl.textContent = 'No models found. Check your API key and URL, then try again.';
                return;
            }

            _allModels = data;
            const currentModel = inputEl?.value || '';

            // Build searchable model picker
            function renderModelList(filter) {
                const filtered = filter
                    ? _allModels.filter(m => (m.name || m.id).toLowerCase().includes(filter.toLowerCase()) || m.id.toLowerCase().includes(filter.toLowerCase()))
                    : _allModels;

                selectEl.innerHTML = '<option value="">— Select a model —</option>' +
                    filtered.map(m => {
                        const label = m.name || m.id;
                        const pricing = m.isFree ? ' ★ Free' : m.pricing ? ` (${m.pricing})` : '';
                        const selected = m.id === currentModel ? ' selected' : '';
                        return `<option value="${esc(m.id)}"${selected}>${esc(label)}${pricing}</option>`;
                    }).join('');

                if (statusEl) statusEl.textContent = `${filtered.length} of ${_allModels.length} models shown.`;
            }

            renderModelList('');

            // Show dropdown + search, hide text input
            selectEl.style.display = '';
            inputEl.style.display = 'none';

            // Add search input if not already present
            let searchInput = selectEl.parentElement.querySelector('#model-search-input');
            if (!searchInput) {
                searchInput = document.createElement('input');
                searchInput.id = 'model-search-input';
                searchInput.type = 'text';
                searchInput.placeholder = 'Search models...';
                searchInput.className = 'settings-text-input';
                searchInput.style.cssText = 'flex:0 0 auto;width:160px;font-size:12px;padding:6px 10px';
                selectEl.parentElement.insertBefore(searchInput, selectEl);
                searchInput.addEventListener('input', () => renderModelList(searchInput.value));
            }
            searchInput.style.display = '';
            searchInput.focus();

            // Sync selection back to text input for saving
            selectEl.onchange = () => { inputEl.value = selectEl.value; };
        });

        // Test connection button
        $('#btn-test-connection')?.addEventListener('click', async () => {
            const btn = $('#btn-test-connection');
            const origText = btn.textContent;
            btn.textContent = 'Testing...';
            btn.disabled = true;

            const data = await apiJson('/api/models/test-connection', {
                method: 'POST',
                body: JSON.stringify({}),
            });

            btn.textContent = origText;
            btn.disabled = false;

            if (data && data.message) {
                showInfoModal('Connection Test', data.message);
            } else {
                showInfoModal('Connection Test', 'Failed to test connection. Check your settings.');
            }
        });

        // Create persona button
        $('#btn-create-persona')?.addEventListener('click', showCreatePersonaModal);

        // Create world button
        $('#btn-create-world')?.addEventListener('click', () => showWorldModal(null, '', '', { entries: [] }));

        // Create character button
        $('#btn-create-character')?.addEventListener('click', async () => {
            const name = $('#cc-name')?.value.trim();
            if (!name) { showInfoModal('Error', 'Character name is required.'); return; }

            const payload = {
                name,
                description: $('#cc-desc')?.value.trim() || '',
                personality: $('#cc-personality')?.value.trim() || '',
                scenario: $('#cc-scenario')?.value.trim() || '',
                firstMessage: $('#cc-first-msg')?.value.trim() || '',
                tags: ($('#cc-tags')?.value || '').split(',').map(t => t.trim()).filter(Boolean),
            };

            const res = await api('/api/characters/create', {
                method: 'POST',
                body: JSON.stringify(payload),
            });
            if (res && res.ok) {
                showInfoModal('Created', `Character "${name}" created successfully!`);
                // Clear form
                ['#cc-name', '#cc-desc', '#cc-personality', '#cc-scenario', '#cc-first-msg', '#cc-tags'].forEach(id => {
                    const el = $(id);
                    if (el) el.value = '';
                });
                // Refresh home page
                loadCharacters();
            }
        });
    }

    // ═══════════════════════════════════════════════════════════
    // CLOUD SYNC & BACKUPS
    // ═══════════════════════════════════════════════════════════

    let syncPollTimer = null;

    async function loadSyncStatus() {
        const data = await apiJson('/api/sync/status');
        if (!data) return;

        // Pre-release lockout — show disabled banner
        if (data.isPreRelease) {
            const section = $('#sync-config-fields')?.closest('.settings-section') || document.querySelector('#page-sync .settings-section');
            if (section) {
                section.innerHTML = `
                    <div class="section-title">Cloud Sync</div>
                    <div style="text-align:center;padding:24px 16px">
                        <div style="font-size:40px;opacity:0.5;margin-bottom:12px">☁️🚫</div>
                        <div style="font-weight:600;font-size:15px;color:var(--text-primary);margin-bottom:8px">Cloud Sync Disabled</div>
                        <p style="color:#FBBF24;font-size:13px;line-height:1.6;margin:0 0 12px 0">
                            This feature is disabled due to database incompatibility with the stable release.
                            Cloud Sync will be re-enabled once ${data.stableVersionBase || '0.9.0'} goes stable.
                        </p>
                        <div style="background:rgba(59,130,246,0.1);padding:10px 14px;border-radius:8px;display:flex;align-items:center;gap:8px;text-align:left">
                            <span style="font-size:14px">ℹ️</span>
                            <span style="font-size:11px;color:#3B82F6;line-height:1.4">
                                This pre-release uses a separate database (front_porch_beta.db) to protect your stable data.
                            </span>
                        </div>
                    </div>
                `;
            }
            // Also disable backup section
            const backupBtn = $('#btn-backup-create');
            if (backupBtn) backupBtn.style.display = 'none';
            const backupList = $('#backup-list');
            if (backupList) backupList.innerHTML = '<p style="text-align:center;color:#FBBF24;padding:16px 0;font-size:13px">Backups are disabled in pre-release builds.</p>';
            return;
        }

        // Enable toggle
        const enabledEl = $('#sync-enabled');
        enabledEl.checked = data.enabled;
        $('#sync-config-fields').style.display = data.enabled ? '' : 'none';

        // Provider
        const providerEl = $('#sync-provider');
        providerEl.value = data.provider || 'none';
        updateSyncProviderUI(data.provider || 'none');

        // WebDAV fields
        if (data.provider === 'webdav') {
            $('#sync-url').value = data.url || '';
            $('#sync-username').value = data.username || '';
            $('#sync-password').value = data.passwordSet ? '' : '';
            if (data.passwordSet) $('#sync-password').placeholder = '••••••••  (saved)';
        }

        // Google Drive: update message based on connection status
        if (data.provider === 'gdrive') {
            const msg = $('#sync-gdrive-msg');
            if (data.isConnected || data.providerName) {
                msg.textContent = '✅ Google Drive is connected and ready to use from the web UI.';
                msg.parentElement.style.borderLeftColor = '#10B981';
                msg.parentElement.querySelector('span:nth-child(2)').textContent = 'Google Drive Connected';
                msg.parentElement.querySelector('span:nth-child(2)').style.color = '#10B981';
            } else {
                msg.textContent = 'Google Drive must be authorized through the desktop app first. Once signed in there, it will work here automatically.';
                msg.parentElement.style.borderLeftColor = '#FBBF24';
            }
        }

        // Status section visibility
        const hasProvider = data.provider && data.provider !== 'none';
        $('#sync-status-section').style.display = (data.enabled && hasProvider) ? '' : 'none';

        if (data.enabled && hasProvider) {
            // Provider name
            const providerNames = { 'webdav': 'Nextcloud (WebDAV)', 'gdrive': 'Google Drive' };
            $('#sync-status-provider').textContent = data.providerName || providerNames[data.provider] || data.provider;

            // Status
            const statusNames = { 'idle': '⏸️ Idle', 'syncing': '🔄 Syncing...', 'success': '✅ Last sync successful', 'error': '❌ Error' };
            $('#sync-status-state').textContent = statusNames[data.status] || data.status;

            // Last sync time
            if (data.lastSyncTime) {
                try {
                    const d = new Date(data.lastSyncTime);
                    $('#sync-status-last').textContent = d.toLocaleString();
                } catch (_) {
                    $('#sync-status-last').textContent = data.lastSyncTime;
                }
            } else {
                $('#sync-status-last').textContent = 'Never';
            }

            // Error
            if (data.lastError) {
                $('#sync-error-row').style.display = '';
                $('#sync-status-error').textContent = data.lastError;
            } else {
                $('#sync-error-row').style.display = 'none';
            }

            // Progress bar
            if (data.status === 'syncing') {
                $('#sync-progress-wrap').style.display = '';
                const pct = Math.round((data.progress || 0) * 100);
                $('#sync-progress-pct').textContent = pct + '%';
                $('#sync-progress-bar').style.width = pct + '%';
                startSyncPolling();
            } else {
                $('#sync-progress-wrap').style.display = 'none';
                stopSyncPolling();
            }
        }

        // Load backups
        loadBackups();
    }

    function updateSyncProviderUI(provider) {
        $('#sync-webdav-fields').style.display = provider === 'webdav' ? '' : 'none';
        $('#sync-gdrive-notice').style.display = provider === 'gdrive' ? '' : 'none';
    }

    function startSyncPolling() {
        stopSyncPolling();
        syncPollTimer = setInterval(async () => {
            const data = await apiJson('/api/sync/status');
            if (!data) return;

            const statusNames = { 'idle': '⏸️ Idle', 'syncing': '🔄 Syncing...', 'success': '✅ Last sync successful', 'error': '❌ Error' };
            $('#sync-status-state').textContent = statusNames[data.status] || data.status;

            if (data.status === 'syncing') {
                const pct = Math.round((data.progress || 0) * 100);
                $('#sync-progress-pct').textContent = pct + '%';
                $('#sync-progress-bar').style.width = pct + '%';
            } else {
                stopSyncPolling();
                loadSyncStatus();
            }
        }, 1500);
    }

    function stopSyncPolling() {
        if (syncPollTimer) { clearInterval(syncPollTimer); syncPollTimer = null; }
    }

    async function saveSyncConfig() {
        const provider = $('#sync-provider').value;
        const body = {
            enabled: $('#sync-enabled').checked,
            provider,
        };
        if (provider === 'webdav') {
            body.url = $('#sync-url').value;
            body.username = $('#sync-username').value;
            const pw = $('#sync-password').value;
            if (pw) body.password = pw; // only send if user typed something
        }

        const res = await api('/api/sync/config', {
            method: 'POST',
            body: JSON.stringify(body),
        });
        if (res && res.ok) {
            showSyncToast('Config saved ✅', 'success');
            loadSyncStatus();
        } else {
            showSyncToast('Failed to save config', 'error');
        }
    }

    async function testSyncConnection() {
        const btn = $('#btn-sync-test');
        btn.textContent = '⏳ Testing...';
        btn.disabled = true;

        // Save first in case user changed fields
        await saveSyncConfig();

        const data = await apiJson('/api/sync/test', { method: 'POST' });
        const resultEl = $('#sync-test-result');
        resultEl.style.display = '';

        if (data && data.ok) {
            resultEl.style.background = 'rgba(16,185,129,0.1)';
            resultEl.style.color = '#10B981';
            resultEl.textContent = '✅ Connection successful!';
        } else {
            resultEl.style.background = 'rgba(239,68,68,0.1)';
            resultEl.style.color = '#EF4444';
            resultEl.textContent = '❌ ' + (data?.error || 'Connection failed');
        }

        btn.textContent = '📡 Test Connection';
        btn.disabled = false;
        setTimeout(() => { resultEl.style.display = 'none'; }, 5000);
    }

    async function syncNow() {
        const btn = $('#btn-sync-now');
        btn.textContent = '⏳ Starting...';
        btn.disabled = true;

        const res = await api('/api/sync/now', { method: 'POST' });
        if (res && res.ok) {
            showSyncToast('Sync started...', 'success');
            startSyncPolling();
            $('#sync-progress-wrap').style.display = '';
            $('#sync-progress-bar').style.width = '0%';
            $('#sync-progress-pct').textContent = '0%';
        } else {
            showSyncToast('Failed to start sync', 'error');
        }

        btn.textContent = '🔄 Sync Now';
        btn.disabled = false;
    }

    async function forceUploadDB() {
        if (!confirm('Force upload your local database to the cloud?\n\nThis will OVERWRITE the cloud copy with your local data.')) return;

        const btn = $('#btn-sync-force-upload');
        btn.textContent = '⏳ Uploading...';
        btn.disabled = true;

        const res = await api('/api/sync/force-upload', { method: 'POST' });
        if (res && res.ok) {
            showSyncToast('Database uploaded ✅', 'success');
            loadSyncStatus();
        } else {
            showSyncToast('Upload failed', 'error');
        }

        btn.textContent = '⬆️ Force Upload DB';
        btn.disabled = false;
    }

    async function purgeCloudData() {
        if (!confirm('⚠️ DANGER: This will permanently delete ALL your data from the cloud (database + characters).\n\nYour local data will NOT be affected.\n\nAre you sure?')) return;

        const btn = $('#btn-sync-purge');
        btn.textContent = '⏳ Purging...';
        btn.disabled = true;

        const res = await api('/api/sync/purge', { method: 'POST' });
        if (res && res.ok) {
            showSyncToast('Cloud data purged', 'success');
            loadSyncStatus();
        } else {
            showSyncToast('Purge failed', 'error');
        }

        btn.textContent = '🗑️ Purge Cloud Data';
        btn.disabled = false;
    }

    async function browseCloudCharacters() {
        const data = await apiJson('/api/sync/cloud-characters');
        if (!data) {
            showSyncToast('Could not load cloud characters', 'error');
            return;
        }

        const chars = Array.isArray(data) ? data : [];

        // Build modal
        const overlay = document.createElement('div');
        overlay.className = 'modal-overlay active';
        overlay.id = 'cloud-chars-modal';

        const remoteOnly = chars.filter(c => !c.existsLocally);

        overlay.innerHTML = `
        <div class="modal" style="max-width:500px">
            <div class="modal-title">☁️ Cloud Characters (${chars.length})</div>
            <div style="max-height:400px;overflow-y:auto;margin:12px 0">
                ${chars.length === 0 ? '<p style="text-align:center;color:var(--text-muted);padding:20px">No characters found on cloud storage</p>' :
                chars.map(c => `
                    <div style="display:flex;align-items:center;justify-content:space-between;padding:8px 0;border-bottom:1px solid rgba(255,255,255,0.06)">
                        <div style="display:flex;align-items:center;gap:8px">
                            <span style="font-size:13px">${c.existsLocally ? '✅' : '☁️'}</span>
                            <span style="font-size:13px;color:var(--text-primary)">${esc(c.name.replace('.png', ''))}</span>
                        </div>
                        ${c.existsLocally
                        ? '<span style="font-size:11px;color:var(--text-muted)">Local</span>'
                        : `<button class="btn btn-sm" data-filename="${esc(c.name)}" style="font-size:11px;padding:3px 10px">Download</button>`
                    }
                    </div>
                `).join('')}
            </div>
            <div style="display:flex;gap:8px;justify-content:flex-end">
                ${remoteOnly.length > 0 ? `<button class="btn btn-primary" id="btn-dl-all-cloud" style="font-size:12px">Download All (${remoteOnly.length})</button>` : ''}
                <button class="btn btn-outlined" id="btn-close-cloud-modal">Close</button>
            </div>
        </div>
        `;

        document.body.appendChild(overlay);

        // Download individual
        overlay.querySelectorAll('[data-filename]').forEach(btn => {
            btn.addEventListener('click', async () => {
                const filename = btn.dataset.filename;
                btn.textContent = '⏳';
                btn.disabled = true;
                const res = await apiJson('/api/sync/download-characters', {
                    method: 'POST',
                    body: JSON.stringify({ filenames: [filename] }),
                });
                if (res && res.downloaded > 0) {
                    btn.textContent = '✅';
                } else {
                    btn.textContent = '❌';
                }
            });
        });

        // Download all
        overlay.querySelector('#btn-dl-all-cloud')?.addEventListener('click', async () => {
            const btn = overlay.querySelector('#btn-dl-all-cloud');
            btn.textContent = '⏳ Downloading...';
            btn.disabled = true;
            const filenames = remoteOnly.map(c => c.name);
            const res = await apiJson('/api/sync/download-characters', {
                method: 'POST',
                body: JSON.stringify({ filenames }),
            });
            if (res) {
                showSyncToast(`Downloaded ${res.downloaded} character(s)`, 'success');
                overlay.remove();
                loadCharacters();
            } else {
                btn.textContent = 'Download All';
                btn.disabled = false;
            }
        });

        // Close
        overlay.querySelector('#btn-close-cloud-modal').addEventListener('click', () => overlay.remove());
        overlay.addEventListener('click', (e) => { if (e.target === overlay) overlay.remove(); });
    }

    // ── Backups ──

    async function loadBackups() {
        const data = await apiJson('/api/backups');
        const list = $('#backup-list');
        if (!list) return;

        const backups = Array.isArray(data) ? data : [];
        if (!backups.length) {
            list.innerHTML = '<p style="text-align:center;color:var(--text-muted);padding:16px 0;font-size:13px">No backups yet</p>';
            return;
        }

        list.innerHTML = backups.map(b => {
            const date = new Date(b.modified).toLocaleString();
            return `
            <div class="info-card" style="margin-bottom:8px;display:flex;justify-content:space-between;align-items:center">
                <div>
                    <div style="font-size:13px;font-weight:500;color:var(--text-primary)">${esc(b.name)}</div>
                    <div style="font-size:11px;color:var(--text-muted)">${date} • ${b.sizeMb} MB</div>
                </div>
                <div style="display:flex;gap:6px">
                    <button class="btn btn-sm btn-outlined" data-restore-path="${esc(b.path)}" style="font-size:11px;padding:3px 8px">Restore</button>
                    <button class="btn btn-sm" data-delete-path="${esc(b.path)}" style="font-size:11px;padding:3px 8px;color:#EF4444">Delete</button>
                </div>
            </div>`;
        }).join('');

        // Restore handlers
        list.querySelectorAll('[data-restore-path]').forEach(btn => {
            btn.addEventListener('click', async () => {
                const path = btn.dataset.restorePath;
                if (!confirm('Restore this backup?\n\nThis will replace your current database. The app may need to restart.')) return;
                btn.textContent = '⏳';
                const res = await api('/api/backups/restore', {
                    method: 'POST',
                    body: JSON.stringify({ path }),
                });
                if (res && res.ok) {
                    showSyncToast('Backup restored! App may need restart.', 'success');
                } else {
                    showSyncToast('Restore failed', 'error');
                    btn.textContent = 'Restore';
                }
            });
        });

        // Delete handlers
        list.querySelectorAll('[data-delete-path]').forEach(btn => {
            btn.addEventListener('click', async () => {
                const path = btn.dataset.deletePath;
                if (!confirm('Delete this backup?')) return;
                const res = await api('/api/backups/delete', {
                    method: 'POST',
                    body: JSON.stringify({ path }),
                });
                if (res && res.ok) {
                    loadBackups();
                } else {
                    showSyncToast('Delete failed', 'error');
                }
            });
        });
    }

    async function createBackup() {
        const btn = $('#btn-backup-create');
        btn.textContent = '⏳ Creating...';
        btn.disabled = true;

        const res = await apiJson('/api/backups/create', { method: 'POST' });
        if (res && res.status === 'ok') {
            showSyncToast('Backup created ✅', 'success');
            loadBackups();
        } else {
            showSyncToast('Backup failed', 'error');
        }

        btn.textContent = '📦 Create Backup Now';
        btn.disabled = false;
    }

    function showSyncToast(msg, type) {
        const existing = document.querySelector('.sync-toast');
        if (existing) existing.remove();

        const toast = document.createElement('div');
        toast.className = 'sync-toast';
        toast.style.cssText = `
            position:fixed;bottom:24px;left:50%;transform:translateX(-50%);
            padding:10px 20px;border-radius:10px;font-size:13px;font-weight:500;
            z-index:9999;pointer-events:none;opacity:0;
            transition:opacity 0.3s ease;
            ${type === 'success'
                ? 'background:rgba(16,185,129,0.15);color:#10B981;border:1px solid rgba(16,185,129,0.3)'
                : 'background:rgba(239,68,68,0.15);color:#EF4444;border:1px solid rgba(239,68,68,0.3)'
            }
        `;
        toast.textContent = msg;
        document.body.appendChild(toast);
        requestAnimationFrame(() => { toast.style.opacity = '1'; });
        setTimeout(() => {
            toast.style.opacity = '0';
            setTimeout(() => toast.remove(), 300);
        }, 3000);
    }

    function initSyncEventListeners() {
        // Enable toggle
        $('#sync-enabled')?.addEventListener('change', () => {
            const enabled = $('#sync-enabled').checked;
            $('#sync-config-fields').style.display = enabled ? '' : 'none';
            if (!enabled) {
                $('#sync-status-section').style.display = 'none';
            }
        });

        // Provider change
        $('#sync-provider')?.addEventListener('change', () => {
            updateSyncProviderUI($('#sync-provider').value);
        });

        // Save config
        $('#btn-sync-save')?.addEventListener('click', saveSyncConfig);

        // Test connection
        $('#btn-sync-test')?.addEventListener('click', testSyncConnection);

        // Sync now
        $('#btn-sync-now')?.addEventListener('click', syncNow);

        // Force upload
        $('#btn-sync-force-upload')?.addEventListener('click', forceUploadDB);

        // Purge
        $('#btn-sync-purge')?.addEventListener('click', purgeCloudData);

        // Browse cloud characters
        $('#btn-sync-browse')?.addEventListener('click', browseCloudCharacters);

        // Create backup
        $('#btn-backup-create')?.addEventListener('click', createBackup);
    }

    // ═══════════════════════════════════════════════════════════
    // INITIALIZATION
    // ═══════════════════════════════════════════════════════════

    function init() {
        buildPinPad();
        initSidebar();
        initEventListeners();
        initTabSwitching();
        initSettingsBindings();
        initModelPageBindings();
        initSyncEventListeners();

        // Auto-login if we have a saved token
        if (token) {
            apiJson('/api/health').then(data => {
                if (data) {
                    showApp();
                } else {
                    token = null;
                    sessionStorage.removeItem('fp_token');
                    showLogin();
                }
            });
        }
    }

    init();
})();
