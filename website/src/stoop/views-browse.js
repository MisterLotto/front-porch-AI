/* The Stoop hub — browse grid, card detail, creator profile.
   Live score/download counters ride the ws 'cardStats' frames via the
   data-stats-* attributes every counter renders with. */
(function () {
  'use strict';
  var S = window.Stoop;
  var el, ui, Api;

  var TAKE = 24;
  // Solo and group casts are kept strictly apart — a group never shows up in the
  // solo grid. Groups get their own tab (with a loud FPAI-only warning).
  var FILTERS = [
    { key: 'solo', label: 'Solo characters', type: 'solo' },
    { key: 'group', label: '👥 Group casts', type: 'group' },
    { key: 'world', label: '🏞️ Worlds', type: 'world' },
    { key: 'following', label: '☆ Following', type: 'all' },
  ];
  var SORTS = [
    { key: 'newest', label: 'Newest' },
    { key: 'top', label: 'Top rated' },
    { key: 'downloads', label: 'Most downloaded' },
  ];

  // Sticky controls so leaving to a detail page and coming back feels stable.
  var browseState = { filter: 'solo', sort: 'newest', q: '' };

  function nsfwOn() {
    return Api.state.user ? !!Api.state.user.nsfwEnabled : !!Api.state.guestAdult;
  }

  /* ---- share links ----
     Path-based URLs (no #) so Discord/Slack crawlers hit the server-side OG
     page (Caddy maps /card/* + /creator/* onto the API's /share/ routes) and
     unfurl the card's real name, summary, and art instead of the site logo. */
  var HUB_ORIGIN = location.hostname === 'hub.frontporchai.app' ? location.origin : 'https://hub.frontporchai.app';

  // Prefer the display name in creator URLs (vanity: #/creator/SosukeAizen).
  // Names are unique server-side (claimed first-come), but only route-safe
  // ones fit the hash routes — anything else falls back to the immutable id.
  function creatorRef(c) {
    var name = c && c.displayName;
    return name && /^[\w-]{2,40}$/.test(name) ? name : (c && c.id) || '';
  }

  function shareBtn(kind, id) {
    var url = HUB_ORIGIN + '/' + kind + '/' + id;
    var btn = el('button', { class: 'hub-linklike', type: 'button', title: 'Copy a link that unfurls nicely in Discord & friends' }, '🔗 Share');
    btn.addEventListener('click', function () {
      var done = function () { ui.toast('Link copied — paste it anywhere.'); };
      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(url).then(done, function () { window.prompt('Copy this link:', url); });
      } else {
        window.prompt('Copy this link:', url);
      }
    });
    return btn;
  }

  /* ================================ browse ================================ */
  function renderBrowse(mount) {
    var page = 0;
    var grid = el('div', { class: 'hub-grid' });
    var moreBtn = el('button', { class: 'btn btn-ghost hub-more', type: 'button', onclick: function () { load(page + 1); } }, 'Load more');
    var moreWrap = el('div', { class: 'hub-more-wrap hub-hidden' }, moreBtn);
    var status = el('div');
    var showcase = el('div', { class: 'hub-showcase' });     // Mod's Picks hero + carousel
    var followRow = el('div', { class: 'hub-followrow' });     // "From your porch" (followed creators)
    var groupWarn = el('div');                                 // strong FPAI-only warning

    function activeFilter() {
      return FILTERS.filter(function (f) { return f.key === browseState.filter; })[0] || FILTERS[0];
    }

    function params(p) {
      var f = activeFilter();
      return {
        sort: browseState.sort,
        type: f.type,
        // The hub understands worlds, so the personal Following feed opts in
        // to the mixed view (worlds stay invisible to clients that don't).
        types: browseState.filter === 'following' ? 'solo,group,world' : undefined,
        following: browseState.filter === 'following' ? 'true' : undefined,
        q: browseState.q || undefined,
        page: p,
        take: TAKE,
      };
    }

    // The Mod's Picks hero belongs on the main (solo) discovery view only — not
    // on the group tab, a search, or the personal Following feed. Cleared
    // synchronously first so a stale hero never lingers through a tab switch.
    function refreshChrome() {
      var f = browseState.filter;
      showcase.replaceChildren();
      followRow.replaceChildren();
      if (!browseState.q && f === 'solo') {
        S.viewsPicks.renderPicksShowcase(showcase, 'solo');
        renderFollowRow(followRow);
      }
      ui.mountChildren(groupWarn, f === 'group' ? groupWarning() : f === 'world' ? worldNote() : null);
    }

    // "From your porch": the newest cards from creators you follow, tucked
    // right under Mod's Picks — following someone actually changes your porch.
    // Signed-in only, and the row vanishes entirely when there's nothing in it
    // (guests and non-followers see the browse they've always seen).
    function renderFollowRow(container) {
      if (!Api.state.user) return;
      Api.browse({ following: 'true', types: 'solo,group,world', sort: 'newest', take: 8, page: 0 })
        .then(function (res) {
          var items = res.items || [];
          if (!items.length) { container.replaceChildren(); return; }
          ui.mountChildren(container, [
            el('div', { class: 'hub-pick-head' }, [
              el('span', { class: 'hub-pick-eyebrow hub-follow-eyebrow' }, '🪑 From your porch'),
              el('span', { class: 'hub-dim hub-small' }, 'New cards from creators you follow'),
            ]),
            el('div', { class: 'hub-pickrow' }, items.map(followTile)),
          ]);
        })
        .catch(function () { container.replaceChildren(); });
    }

    function followTile(card) {
      return el('a', { class: 'hub-picktile', href: '#/card/' + card.id }, [
        el('div', { class: 'hub-picktile-art' }, [ui.avatarImg(card.primaryAssetId, card.name, 'hub-picktile-img')]),
        el('div', { class: 'hub-picktile-badges' }, [
          card.type === 'GROUP' ? el('span', { class: 'hub-badge hub-badge-group' }, '👥') : null,
          card.type === 'WORLD' ? el('span', { class: 'hub-badge hub-badge-world' }, '🏞️') : null,
          card.nsfw ? el('span', { class: 'hub-badge hub-badge-nsfw' }, '18+') : null,
        ]),
        el('div', { class: 'hub-picktile-name' }, card.name),
        card.creator ? el('div', { class: 'hub-followrow-by' }, '@' + card.creator.displayName) : null,
      ]);
    }

    function load(p) {
      page = p;
      if (p === 0) {
        grid.replaceChildren();
        status.replaceChildren(ui.spinner('Looking around the porch…'));
        refreshChrome();
      }
      moreBtn.disabled = true;
      Api.browse(params(p)).then(function (res) {
        status.replaceChildren();
        var items = res.items || [];
        items.forEach(function (c) { grid.appendChild(ui.cardTile(c)); });
        if (p === 0 && !items.length) {
          status.replaceChildren(ui.emptyState('🪑', 'Nothing here yet',
            browseState.q ? 'No cards match that search. Try @creator or #tag.' :
            browseState.filter === 'following' ? 'Follow some creators and their new cards will show up here.' :
            browseState.filter === 'world' ? 'No worlds on the porch yet — be the first to share a place.' :
            'Check back soon — the neighbours are still writing.'));
          if (browseState.filter === 'world' && !browseState.q && Api.state.user) {
            status.appendChild(el('div', { class: 'hub-empty-cta' },
              el('a', { class: 'btn btn-amber', href: '#/submit-world' }, '🏞️ Share a world')));
          }
        }
        moreWrap.classList.toggle('hub-hidden', items.length < TAKE);
        moreBtn.disabled = false;
      }).catch(function (e) {
        status.replaceChildren(ui.emptyState('🌫️', 'Couldn’t load cards', e.message));
      });
    }

    var search = el('input', {
      class: 'hub-search', type: 'search', value: browseState.q,
      placeholder: 'Search cards… (@creator, #tag)',
      onkeydown: function (e) { if (e.key === 'Enter') { browseState.q = search.value.trim(); load(0); } },
    });
    var sortSel = el('select', { class: 'hub-select', onchange: function () { browseState.sort = sortSel.value; load(0); } },
      SORTS.map(function (s) {
        var o = el('option', { value: s.key }, s.label);
        if (s.key === browseState.sort) o.selected = true;
        return o;
      }));

    // NSFW toggle right on the bar — works for accounts (persisted server-side)
    // and guests (18+ self-cert). Fixes the "can't turn NSFW off" complaint.
    var nsfwBtn = el('button', { class: 'hub-nsfw-toggle', type: 'button' });
    function paintNsfw() {
      var on = nsfwOn();
      nsfwBtn.textContent = on ? '🔞 18+ on' : '🔞 18+ off';
      nsfwBtn.classList.toggle('on', on);
      nsfwBtn.title = on ? 'NSFW cards are showing — click to hide' : 'Show NSFW cards (18+)';
    }
    nsfwBtn.addEventListener('click', function () {
      if (Api.state.user) {
        var next = !Api.state.user.nsfwEnabled;
        nsfwBtn.disabled = true;
        Api.setNsfw(next).then(function () {
          paintNsfw(); load(0);
          ui.toast(next ? '18+ cards are now showing.' : '18+ cards are hidden.');
        }).catch(function (e) { ui.toast(e.message, 'err'); })
          .finally(function () { nsfwBtn.disabled = false; });
      } else if (Api.state.guestAdult) {
        Api.setGuestAdult(false); paintNsfw(); load(0);
        ui.toast('18+ cards are hidden.');
      } else {
        ui.confirmAdult(function () { Api.setGuestAdult(true); paintNsfw(); load(0); });
      }
    });
    paintNsfw();

    var chipRow = el('div', { class: 'hub-chips' }, FILTERS.map(function (f) {
      return el('button', {
        class: 'hub-chip' + (browseState.filter === f.key ? ' on' : ''),
        type: 'button',
        onclick: function (e) {
          browseState.filter = f.key;
          chipRow.querySelectorAll('.hub-chip').forEach(function (c) { c.classList.remove('on'); });
          e.currentTarget.classList.add('on');
          load(0);
        },
      }, f.label);
    }));

    ui.mountChildren(mount, [
      ui.fpaiBanner(),
      el('div', { class: 'hub-controls' }, [search, sortSel, nsfwBtn]),
      chipRow,
      showcase,
      followRow,
      groupWarn,
      status,
      grid,
      moreWrap,
    ]);
    load(0);
  }

  // The loud, unmissable group warning shown on the Groups tab.
  function groupWarning() {
    return el('div', { class: 'hub-groupwarn' }, [
      el('span', { class: 'hub-groupwarn-ico' }, '⚠️'),
      el('div', null, [
        el('strong', null, 'Group casts open ONLY in Front Porch AI.'),
        el('p', null, [
          'A group card bundles multiple characters, their lorebooks, and shared Realism state. ',
          el('strong', null, 'No other app can read it'),
          ' — not SillyTavern, not Backyard, nothing. Download one only if you use Front Porch AI. ',
          el('a', { href: 'https://frontporchai.app/#get', target: '_blank', rel: 'noopener' }, 'Get the app →'),
        ]),
      ]),
    ]);
  }

  // The Worlds tab intro — what a .fpworld is and where it goes after download.
  function worldNote() {
    return el('div', { class: 'hub-groupwarn hub-worldnote' }, [
      el('span', { class: 'hub-groupwarn-ico' }, '🏞️'),
      el('div', null, [
        el('strong', null, 'Worlds are complete places for Front Porch AI.'),
        el('p', null, [
          'One .fpworld file carries the cover art, lore, custom climate, and place traits. ',
          'Download one, then import it in the app under ',
          el('strong', null, 'Worlds → Import Place'),
          ' and attach it to any character or chat. ',
          el('a', { href: 'https://frontporchai.app/#get', target: '_blank', rel: 'noopener' }, 'Get the app →'),
        ]),
        el('p', null, [
          '⚠️ ',
          el('strong', null, 'Needs Front Porch AI 1.2 or newer'),
          ' — the portable .fpworld file arrived in 1.2, so older versions can’t open one. Update the app first, then import.',
        ]),
      ]),
    ]);
  }

  /* ============================== card detail ============================== */
  var REPORT_CATEGORIES = [
    { key: 'SPAM', label: 'Spam' },
    { key: 'MISLABELED', label: 'Wrong / missing NSFW label' },
    { key: 'ILLEGAL', label: 'Illegal content' },
    { key: 'STOLEN', label: 'Stolen / uncredited' },
    { key: 'LOW_EFFORT', label: 'Low effort' },
    { key: 'PROHIBITED_IMAGE', label: 'Prohibited image' },
    { key: 'OTHER', label: 'Other' },
  ];

  function textSection(title, text, open) {
    if (!text) return null;
    return el('details', { class: 'hub-sect', open: !!open }, [
      el('summary', null, title),
      el('pre', { class: 'hub-sect-text' }, text),
    ]);
  }

  /* ---- card-authored identity: Ambitions, Likes & Dislikes, Pockets ----
     These live in the card blob the API already returns verbatim, under
     extensions.front_porch.realism_engine — no backend field is involved, the
     hub was simply dropping them. Deliberately NOT gated on the engine's
     `enabled` flag: ambitions, likes and a wardrobe are identity, they travel
     with the card and work the moment it is downloaded, so copying that guard
     would hide real authored content on every card whose creator left the
     Realism Engine off.

     The 18+ pair (intimate_preferences) is deliberately NOT rendered — guests
     reach this page, and opening a card is not opting into 18+ content. The
     desktop panel and the app's PWA omit it for the same reason.

     Bounds are not decoration: a card is a stranger's upload, and a list with
     fifty thousand entries or a multi-megabyte phrase would freeze the page of
     whoever opened it. Same caps as the other two clients. */
  var MAX_PHRASES = 24;
  var MAX_PHRASE_CHARS = 160;
  var MAX_ITEMS = 8;      // per inventory list, applied to the RAW list
  var MAX_ITEM_CHARS = 60;
  // Members rendered with their three identity sections. The loop used to be
  // unbounded, and a hostile cast that still fits under the 24 MB upload ceiling
  // measured ~5.2 million DOM nodes — a dead tab for whoever opened the card.
  // 24 is far past any real group (the desktop panel shows one member at a time
  // through a carousel); past it the page says how many more there are, because
  // silently dropping members on a page moderators read is worse than the wall.
  var MAX_MEMBERS = 24;
  // How far into the two cast lists the union walk looks at all. Bounds the
  // dedupe pass the same way; beyond it the count is reported as "N+".
  var MAX_MEMBER_SCAN = 400;

  /** extensions -> front_porch -> realism_engine, or {} at the first bad hop.
      Fed through the shared unwrapCard so a V2 card that nests everything
      under `data` resolves the same way the completeness gate sees it. */
  function realismBlock(cardJson) {
    var node = S.completeness.unwrapCard(cardJson);
    var hops = ['extensions', 'front_porch', 'realism_engine'];
    for (var i = 0; i < hops.length; i++) {
      if (!node || typeof node !== 'object') return {};
      node = node[hops[i]];
    }
    return node && typeof node === 'object' && !Array.isArray(node) ? node : {};
  }

  function tidy(s, cap) {
    var t = (typeof s === 'string' ? s : '').replace(/\s+/g, ' ').trim();
    return t.length <= cap ? t : t.slice(0, cap).replace(/\s+$/, '');
  }

  /** One authored phrase list (ambitions / likes / dislikes), bounded.
      Array.isArray and typeof rather than casts: a present-but-wrong-typed
      field must cost that one section, never the whole page. */
  function cardPhrases(raw) {
    var out = [];
    (Array.isArray(raw) ? raw : []).forEach(function (a) {
      if (out.length >= MAX_PHRASES || typeof a !== 'string') return;
      var s = a.replace(/\s+/g, ' ').trim();
      if (!s) return;
      out.push(s.length > MAX_PHRASE_CHARS ? tidy(s, MAX_PHRASE_CHARS) + '…' : s);
    });
    return out;
  }

  /** One inventory list as display text — `name` or `name (state)`. Entries are
      either a bare string or {name, state}, which is why the phrase reader
      cannot be reused here (it would return [] for every card, silently). The
      RAW list is sliced first so a hostile 50k-entry list costs 8 conversions,
      mirroring Pockets.fromJson in the app. */
  function cardItems(raw) {
    return (Array.isArray(raw) ? raw : []).slice(0, MAX_ITEMS).map(function (e) {
      if (typeof e === 'string') return tidy(e, MAX_ITEM_CHARS);
      if (!e || typeof e !== 'object') return '';
      var name = tidy(e.name, MAX_ITEM_CHARS);
      var state = tidy(e.state, MAX_ITEM_CHARS);
      if (!name) return '';
      return state ? name + ' (' + state + ')' : name;
    }).filter(Boolean);
  }

  /** The one section shape all three share: a collapsible whose summary carries
      the total count, and per group an optional uppercase sub-label plus one
      glyphed line per item. Null when every group is empty, so an absent
      section costs nothing. */
  function glyphSection(title, groups) {
    var rows = [];
    var total = 0;
    groups.forEach(function (g) {
      if (!g.items.length) return;
      total += g.items.length;
      if (g.subLabel) rows.push(el('div', { class: 'hub-sublabel' }, g.subLabel));
      g.items.forEach(function (item) {
        rows.push(el('div', null, g.glyph + ' ' + item));
      });
    });
    if (!total) return null;
    return el('details', { class: 'hub-sect' }, [
      el('summary', null, title + ' (' + total + ')'),
      el('div', { class: 'hub-glyphlist' }, rows),
    ]);
  }

  /** The three identity sections for one character. Used for the card itself
      and, unchanged, for every member of a group cast — a cast's ambitions and
      wardrobe live per member, never at the group root. */
  function identitySections(re) {
    var inv = re.inventory && typeof re.inventory === 'object' ? re.inventory : {};
    var likes = cardPhrases(re.likes);
    var dislikes = cardPhrases(re.dislikes);
    var worn = cardItems(inv.worn);
    var carrying = cardItems(inv.carrying);
    return [
      glyphSection('Ambitions', [{ glyph: '🧭', items: cardPhrases(re.ambitions) }]),
      glyphSection('Likes & Dislikes', [
        { subLabel: 'Drawn to', glyph: '♥', items: likes },
        { subLabel: 'Put off by', glyph: '✕', items: dislikes },
      ]),
      glyphSection('Pockets & Wardrobe', [
        { subLabel: 'Wearing', glyph: '🧥', items: worn },
        { subLabel: 'Carrying', glyph: '🎒', items: carrying },
      ]),
    ];
  }

  /** Identity for de-duplication only: name plus the opening of the description,
      normalised. Sliced BEFORE the whitespace collapse so a hostile
      multi-megabyte description costs a short scan instead of a copy of itself. */
  function memberKey(m) {
    return tidy(typeof m.name === 'string' ? m.name.slice(0, 80) : '', 80).toLowerCase()
      + '\u0000'
      + tidy(typeof m.description === 'string' ? m.description.slice(0, 200) : '', 64).toLowerCase();
  }

  /** A group's cast as the UNION of both spellings, deduped and bounded.
      A card carries its members under `members` AND `raw_member_data`, and a
      member present in only one of them is still part of the cast — the same
      reason the 18+ predicate scans both. `raw_member_data` goes first because
      it is the high-fidelity list every importer and the desktop panel read, so
      the page shows what a downloader actually gets.
      Genuine exports write the SAME cast into both lists, so a plain concat
      would show every member twice; entries from `members` are therefore kept
      only when nothing in `raw_member_data` matched their name + description.
      Duplicates WITHIN a list are left alone — a cast really can hold two
      characters with one name, and dropping one silently is not this page's
      call to make.
      Returns the members to draw from plus an honest total: `exact` is false
      only when both lists are populated AND one of them runs past the scan cap,
      because that is the only case where the size of the union isn't knowable
      without walking it. One-list casts — every real card, and every hostile
      one seen so far — count off `.length`, which is free. */
  function castOf(card) {
    var raw = Array.isArray(card.raw_member_data) ? card.raw_member_data : [];
    var mem = Array.isArray(card.members) ? card.members : [];
    var rawN = Math.min(raw.length, MAX_MEMBER_SCAN);
    var memN = Math.min(mem.length, MAX_MEMBER_SCAN);
    var out = [];
    var seen = {};
    var i, m;
    for (i = 0; i < rawN; i++) {
      m = S.completeness.unwrapCard(raw[i]);
      seen['k:' + memberKey(m)] = true;   // prefixed: a member named "constructor" is not a hit
      out.push(m);
    }
    for (i = 0; i < memN; i++) {
      m = S.completeness.unwrapCard(mem[i]);
      if (seen['k:' + memberKey(m)]) continue;
      out.push(m);
    }
    var oneList = !raw.length || !mem.length;
    return {
      members: out,
      total: oneList ? Math.max(raw.length, mem.length) : out.length,
      exact: oneList || (raw.length === rawN && mem.length === memN),
    };
  }

  /* V2 character_book — the section the detail page silently dropped (a card
     with lore looked loreless on the hub). Disabled entries stay hidden; an
     entry with no trigger keys is constant/always-active lore. */
  function lorebookSection(book) {
    var entries = (book && Array.isArray(book.entries)) ? book.entries : [];
    entries = entries.filter(function (e) { return e && e.enabled !== false; });
    if (!entries.length) return null;
    return el('details', { class: 'hub-sect' }, [
      el('summary', null, 'Lorebook (' + entries.length + (entries.length === 1 ? ' entry' : ' entries') + ')'),
      el('div', { class: 'hub-lore' }, entries.map(function (e) {
        var label = e.name || e.comment || '';
        var keys = Array.isArray(e.keys) ? e.keys.filter(Boolean) : [];
        var trigger = keys.length ? 'triggers: ' + keys.join(', ') : 'always active';
        return el('div', { class: 'hub-lore-entry' }, [
          el('div', { class: 'hub-lore-head' }, [
            el('strong', null, label || (keys.length ? keys.join(', ') : 'Entry')),
            el('span', { class: 'hub-dim hub-small' }, ' · ' + trigger),
          ]),
          el('pre', { class: 'hub-sect-text' }, e.content || ''),
        ]);
      })),
    ]);
  }

  /* .fpworld envelope detail — about / climate / traits / lore. The envelope
     keys the lorebook `lorebook` (not V2's `character_book`); entry shape is
     the same, so lorebookSection renders it unchanged. */
  function worldSections(card) {
    var biome = card.biome || {};
    var climate = [biome.displayName, biome.feel, biome.description]
      .filter(function (v) { return typeof v === 'string' && v.trim(); }).join('\n\n');
    var traits = card.place_traits || {};
    var traitBits = ['atmosphere', 'gravity'].filter(function (k) {
      return typeof traits[k] === 'string' && traits[k].trim();
    }).map(function (k) { return k + ': ' + traits[k]; }).join('\n');
    return [
      textSection('About this place', card.description, true),
      textSection('Climate', climate, true),
      textSection('Place traits', traitBits),
      lorebookSection(card.lorebook),
    ];
  }

  function renderCard(mount, id) {
    mount.replaceChildren(ui.spinner());
    Api.cardDetail(id).then(function (c) {
      var isGroup = c.type === 'GROUP';
      var isWorld = c.type === 'WORLD';
      var card = c.card || {};
      var signedIn = !!Api.state.user;

      /* --- votes (account only) --- */
      var myVote = c.myVote || 0;
      var upBtn = el('button', { class: 'hub-vote', type: 'button', title: 'Upvote' }, '▲');
      var dnBtn = el('button', { class: 'hub-vote', type: 'button', title: 'Downvote' }, '▼');
      function paintVotes() {
        upBtn.classList.toggle('on', myVote === 1);
        dnBtn.classList.toggle('dn', myVote === -1);
      }
      function castVote(v) {
        var next = myVote === v ? 0 : v;
        Api.vote(id, next).then(function (r) {
          myVote = r.myVote;
          paintVotes();
          document.querySelectorAll('[data-stats-score="' + id + '"]').forEach(function (n) { n.textContent = ui.num(r.score); });
        }).catch(function (e) { ui.toast(e.message, 'err'); });
      }
      upBtn.addEventListener('click', function () { castVote(1); });
      dnBtn.addEventListener('click', function () { castVote(-1); });
      paintVotes();

      /* --- download (everyone, incl. guests) --- */
      var dlBtn = el('button', { class: 'btn btn-amber', type: 'button' }, isWorld ? '⤓ Download world' : '⤓ Download card');
      dlBtn.addEventListener('click', function () {
        ui.downloadCard({ id: id, name: c.name, type: c.type, primaryAssetId: c.primaryAssetId }, dlBtn);
      });

      /* --- report: signed-in + email-verified only; reason required --- */
      var me = Api.state.user;
      var canReport = !!me && me.emailVerified !== false;
      function showReport() {
        if (!canReport) return;
        var sel = el('select', { class: 'hub-select hub-wide' }, REPORT_CATEGORIES.map(function (r) {
          return el('option', { value: r.key }, r.label);
        }));
        var reason = el('textarea', {
          class: 'hub-textarea',
          rows: '3',
          maxlength: '500',
          required: true,
          placeholder: 'What’s wrong? (required)',
        });
        ui.dialog('Report “' + c.name + '”', [
          el('p', { class: 'hub-dim' }, 'Reports go straight to the moderators. Honest reports only — see the AUP. A written reason is required.'),
          sel, reason,
        ], [
          { label: 'Cancel', kind: 'btn-ghost' },
          {
            label: 'Send report', kind: 'btn-danger',
            onclick: function () {
              var text = reason.value.trim();
              if (!text) {
                ui.toast('Please add a reason.', 'err');
                return false;
              }
              return Api.report(id, sel.value, text)
                .then(function () { ui.toast('Report sent. Thank you for keeping the porch clean.'); })
                .catch(function (e) { ui.toast(e.message, 'err'); });
            },
          },
        ]);
      }

      /* --- group members --- */
      var membersBlock = null;
      if (isGroup) {
        var cast = castOf(card);
        var shown = cast.members.slice(0, MAX_MEMBERS);
        var castLabel = cast.total + (cast.exact ? '' : '+');
        membersBlock = el('div', { class: 'hub-members' }, [
          el('h3', null, 'The cast (' + castLabel + ')'),
          // Each member is a full character card map with its own extensions,
          // so the cast gets the same identity sections the solo card does —
          // a root-only read would show nothing for a group. Collapsed, so a
          // twelve-hander costs nothing until someone opens one. Unwrapped ONCE
          // per member: the name and description have to come off the same node
          // the realism block does, or a V2-nested member reads "Unnamed / —"
          // while its ambitions render right underneath.
          el('div', { class: 'hub-member-list' }, shown.map(function (m) {
            var desc = typeof m.description === 'string' ? m.description : '';
            return el('div', { class: 'hub-member' }, [
              el('b', null, (typeof m.name === 'string' && m.name) || 'Unnamed'),
              el('span', { class: 'hub-dim' }, desc.slice(0, 140) || '—'),
            ].concat(identitySections(realismBlock(m))));
          })),
          shown.length < cast.total || !cast.exact
            ? el('p', { class: 'hub-dim hub-small' },
                'Showing the first ' + shown.length + ' of ' + castLabel
                + ' — the whole cast is in the card and comes with the download.')
            : null,
        ]);
      }

      var caveat = isWorld
        ? el('div', { class: 'hub-caveat group' }, [
            el('span', { class: 'hub-caveat-ico' }, '🏞️'),
            el('div', null, [
              el('strong', null, 'This is a world for Front Porch AI. '),
              'The .fpworld file carries the cover art, lore, custom climate, and place traits. ',
              'Import it in the app under ',
              el('strong', null, 'Worlds → Import Place'),
              ', then attach it to any character or chat. ',
              el('strong', null, '⚠️ Needs Front Porch AI 1.2 or newer'),
              ' — the portable .fpworld file arrived in 1.2, so older versions can’t open one.',
            ]),
          ])
        : isGroup
        ? el('div', { class: 'hub-caveat group' }, [
            el('span', { class: 'hub-caveat-ico' }, '⚠️'),
            el('div', null, [
              el('strong', null, 'This group cast opens ONLY in Front Porch AI. '),
              'A group card bundles multiple characters, their lorebooks, and shared Realism state into one file. ',
              el('strong', null, 'No other app can read it'),
              ' — not SillyTavern, not Backyard, nothing. Only download it if you use Front Porch AI, where it imports in one tap.',
            ]),
          ])
        : el('div', { class: 'hub-caveat' }, [
            el('strong', null, '🛋️ Best experienced in Front Porch AI. '),
            'This card works in any V2-compatible app, but its Realism & Needs data (moods, bond, trust) only comes alive in FPAI — the recommended app for every card on The Stoop.',
          ]);

      // Guests can download but not vote/report. Reporting also needs a
      // confirmed email so throwaway signups cannot flood the queue.
      var reportControl = !signedIn
        ? null
        : canReport
          ? el('button', { class: 'hub-linklike', type: 'button', onclick: showReport }, '⚑ Report')
          : el('a', { class: 'hub-signin-nudge', href: '#/account' }, 'Confirm email to report');
      var actionExtras = signedIn
        ? [
            el('span', { class: 'hub-votebox' }, [upBtn, dnBtn]),
            shareBtn('card', id),
            reportControl,
          ]
        : [shareBtn('card', id), el('a', { class: 'hub-signin-nudge', href: '#/signin' }, 'Sign in to vote, follow & report')];

      var alts = Array.isArray(card.alternate_greetings) ? card.alternate_greetings.filter(Boolean).join('\n\n———\n\n') : '';
      // Read once and share — the three identity sections all come out of the
      // same block, and unwrapping a V2 card three times would be waste.
      var re = realismBlock(c.card);

      mount.replaceChildren(el('div', { class: 'hub-detail' }, [
        el('a', { class: 'hub-back', href: '#/' }, '← Back to browsing'),
        el('div', { class: 'hub-detail-top' }, [
          el('div', { class: 'hub-detail-art' }, [ui.avatarImg(c.primaryAssetId, c.name, 'hub-detail-img')]),
          el('div', { class: 'hub-detail-info' }, [
            el('div', { class: 'hub-detail-badges' }, [
              isWorld ? el('span', { class: 'hub-badge hub-badge-world' }, '🏞️ World') : null,
              isGroup ? el('span', { class: 'hub-badge hub-badge-group' }, '👥 Group cast') : null,
              c.nsfw ? el('span', { class: 'hub-badge hub-badge-nsfw' }, '18+') : null,
              c.modPick ? el('span', { class: 'hub-badge hub-badge-pick' }, '★ Mod’s Pick') : null,
            ]),
            el('h2', { class: 'hub-detail-name' }, c.name),
            c.creator ? el('a', { class: 'hub-detail-creator', href: '#/creator/' + creatorRef(c.creator) }, (c.originalCreator ? 'uploaded by ' : 'by ') + c.creator.displayName + ' →') : null,
            c.originalCreator ? el('div', { class: 'hub-detail-origcreator' }, 'created by ' + c.originalCreator) : null,
            el('p', { class: 'hub-detail-summary' }, c.summary || ''),
            (c.tags && c.tags.length)
              ? el('div', { class: 'hub-tags' }, c.tags.map(function (t) {
                  return el('a', { class: 'hub-tag', href: '#/', onclick: function () { browseState.q = '#' + t; } }, '#' + t);
                }))
              : null,
            el('div', { class: 'hub-detail-stats' }, [
              ui.statsSpan(c),
              el('span', { class: 'hub-dim' }, 'v' + (c.version || 1) + (c.tokenCount ? ' · ~' + ui.num(c.tokenCount) + ' tokens' : '')),
            ]),
            el('div', { class: 'hub-detail-actions' }, [dlBtn].concat(actionExtras)),
            caveat,
          ]),
        ]),
        membersBlock,
        el('div', { class: 'hub-sects' }, isWorld ? worldSections(card) : [
          textSection('Description', card.description, true),
          textSection('Personality', card.personality),
          textSection('Scenario', card.scenario),
          textSection('First message', card.first_mes || card.first_message),
          textSection('Alternate greetings', alts),
          textSection('Example dialogue', card.mes_example),
        ].concat(identitySections(re), lorebookSection(card.character_book))),
      ]));
    }).catch(function (e) {
      mount.replaceChildren(ui.emptyState('🌫️', 'Couldn’t load that card', e.message));
    });
  }

  /* ============================ creator profile ============================ */
  function renderCreator(mount, id) {
    mount.replaceChildren(ui.spinner());
    Api.creator(id).then(function (cr) {
      var followBtn = null;
      if (!Api.state.user) {
        followBtn = el('a', { class: 'hub-signin-nudge', href: '#/signin' }, 'Sign in to follow');
      } else if (!cr.isMe) {
        followBtn = el('button', { class: 'btn ' + (cr.following ? 'btn-ghost' : 'btn-amber'), type: 'button' },
          cr.following ? '✓ Following' : '+ Follow');
        followBtn.addEventListener('click', function () {
          // Always follow by the resolved user id — the route param may be a
          // vanity display name, which the follow endpoints don't accept.
          var call = cr.following ? Api.unfollow(cr.id) : Api.follow(cr.id);
          call.then(function (r) {
            cr.following = r.following;
            cr.followers = r.followers;
            followBtn.textContent = cr.following ? '✓ Following' : '+ Follow';
            followBtn.className = 'btn ' + (cr.following ? 'btn-ghost' : 'btn-amber');
            followers.textContent = ui.num(cr.followers) + ' follower' + (cr.followers === 1 ? '' : 's');
          }).catch(function (e) { ui.toast(e.message, 'err'); });
        });
      }
      var followers = el('span', { class: 'hub-dim' }, ui.num(cr.followers) + ' follower' + (cr.followers === 1 ? '' : 's'));
      var cards = cr.cards || [];

      // Lifetime stats over every approved card (server-side, not the visible
      // slice) so SFW-only viewers see the same numbers.
      var stats = cr.stats || {};
      var totalCards = stats.cards != null ? stats.cards : cards.length;
      var statLine = el('span', { class: 'hub-dim' },
        ui.num(totalCards) + ' cards · ' +
        ui.num(stats.downloads || 0) + ' downloads · ' +
        ui.num(stats.score || 0) + ' net votes' +
        (cards.length < totalCards ? ' · some hidden (18+ off)' : ''));

      // Bio + external links (creator-controlled; the server only accepts
      // http(s) URLs). Links double as public self-attribution for creators
      // cross-posting their own catalogs from chub/Backyard.
      var bioBlock = (cr.bio || '').trim()
        ? el('p', { class: 'hub-creator-bio' }, cr.bio.trim())
        : null;
      var creatorLinks = cr.links || cr.profileLinks || [];
      var linkList = creatorLinks.length
        ? el('div', { class: 'hub-creator-links' }, creatorLinks.map(function (u) {
            var label = u.replace(/^https?:\/\//, '').replace(/\/$/, '');
            if (label.length > 42) label = label.slice(0, 40) + '…';
            return el('a', { href: u, target: '_blank', rel: 'noopener nofollow' }, '🔗 ' + label);
          }))
        : null;

      // Profile avatar when the creator set one; their amber monogram otherwise.
      var ava = cr.avatarAssetId
        ? el('div', { class: 'hub-creator-ava' }, [ui.avatarImg(cr.avatarAssetId, cr.displayName, 'hub-creator-ava-img')])
        : el('div', { class: 'hub-creator-ava hub-creator-mono' }, (cr.displayName || '?').charAt(0).toUpperCase());

      mount.replaceChildren(el('div', null, [
        el('a', { class: 'hub-back', href: '#/' }, '← Back to browsing'),
        el('div', { class: 'hub-creator-head' }, [
          ava,
          el('h2', null, cr.displayName),
          followers,
          statLine,
          followBtn,
          shareBtn('creator', creatorRef(cr)),
        ]),
        bioBlock,
        linkList,
        cards.length
          ? el('div', { class: 'hub-grid' }, cards.map(ui.cardTile))
          : ui.emptyState('🪑', 'No public cards yet'),
      ]));
    }).catch(function (e) {
      mount.replaceChildren(ui.emptyState('🌫️', 'Couldn’t load that creator', e.message));
    });
  }

  window.Stoop.viewsBrowse = {
    renderBrowse: function (m) { el = S.ui.el; ui = S.ui; Api = S.api; renderBrowse(m); },
    renderCard: function (m, id) { el = S.ui.el; ui = S.ui; Api = S.api; renderCard(m, id); },
    renderCreator: function (m, id) { el = S.ui.el; ui = S.ui; Api = S.api; renderCreator(m, id); },
  };
})();
