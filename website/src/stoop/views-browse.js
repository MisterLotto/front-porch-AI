/* The Stoop hub — browse grid, card detail, creator profile.
   Live score/download counters ride the ws 'cardStats' frames via the
   data-stats-* attributes every counter renders with. */
(function () {
  'use strict';
  var S = window.Stoop;
  var el, ui, Api;

  var TAKE = 24;
  var FILTERS = [
    { key: 'all', label: 'All' },
    { key: 'solo', label: 'Solo' },
    { key: 'group', label: '👥 Groups' },
    { key: 'picks', label: '★ Mod’s Picks' },
    { key: 'following', label: 'Following' },
  ];
  var SORTS = [
    { key: 'newest', label: 'Newest' },
    { key: 'top', label: 'Top rated' },
    { key: 'downloads', label: 'Most downloaded' },
  ];

  // Sticky controls so leaving to a detail page and coming back feels stable.
  var browseState = { filter: 'all', sort: 'newest', q: '' };

  /* ================================ browse ================================ */
  function renderBrowse(mount) {
    var page = 0;
    var grid = el('div', { class: 'hub-grid' });
    var moreBtn = el('button', { class: 'btn btn-ghost hub-more', type: 'button', onclick: function () { load(page + 1); } }, 'Load more');
    var moreWrap = el('div', { class: 'hub-more-wrap hub-hidden' }, moreBtn);
    var status = el('div');

    function params(p) {
      var f = browseState.filter;
      return {
        sort: browseState.sort,
        type: f === 'solo' ? 'solo' : f === 'group' ? 'group' : 'all',
        pick: f === 'picks' ? 'true' : undefined,
        following: f === 'following' ? 'true' : undefined,
        q: browseState.q || undefined,
        page: p,
        take: TAKE,
      };
    }

    function load(p) {
      page = p;
      if (p === 0) {
        grid.replaceChildren();
        status.replaceChildren(ui.spinner('Looking around the porch…'));
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
            'Check back soon — the neighbours are still writing.'));
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

    var nsfwNote = null;
    if (Api.state.user && !Api.state.user.nsfwEnabled) {
      nsfwNote = el('p', { class: 'hub-nsfw-note' }, [
        'NSFW cards are hidden. You can turn them on in ',
        el('a', { href: '#/account' }, 'Account'), '.',
      ]);
    }

    mount.replaceChildren(
      ui.fpaiBanner(),
      el('div', { class: 'hub-controls' }, [search, sortSel]),
      chipRow,
      nsfwNote,
      status,
      grid,
      moreWrap
    );
    load(0);
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

  function renderCard(mount, id) {
    mount.replaceChildren(ui.spinner());
    Api.cardDetail(id).then(function (c) {
      var isGroup = c.type === 'GROUP';
      var card = c.card || {};

      /* --- votes --- */
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

      /* --- download --- */
      var dlBtn = el('button', { class: 'btn btn-amber', type: 'button', onclick: doDownload }, '⤓ Download card');
      function doDownload() {
        dlBtn.disabled = true;
        dlBtn.textContent = 'Packing it up…';
        Api.download(id).then(function (res) {
          var json = res.card || card;
          var assetId = res.primaryAssetId || c.primaryAssetId;
          var safe = (c.name || 'character').replace(/[^\w. -]+/g, '_').trim() || 'character';
          var finish = function () {
            dlBtn.disabled = false;
            dlBtn.textContent = '⤓ Download card';
            ui.toast(isGroup
              ? 'Group card saved — import it in Front Porch AI (group casts only work there).'
              : 'Card saved! For the full Realism experience, import it into Front Porch AI.');
          };
          var jsonFallback = function () {
            if (isGroup) ui.saveFile(JSON.stringify(json, null, 2), safe + '.group.json', 'application/json');
            else ui.saveFile(JSON.stringify({ spec: 'chara_card_v2', spec_version: '2.0', data: json }, null, 2), safe + '.json', 'application/json');
            finish();
          };
          if (!assetId) return jsonFallback();
          Api.assetBlob(assetId)
            .then(S.png.toPngBytes)
            .then(function (pngBytes) {
              if (isGroup) {
                var bytes = S.png.writeTextChunk(pngBytes, 'fpa_group', S.png.jsonToBase64(json));
                ui.saveFile(bytes, safe + '.group.png', 'image/png');
              } else {
                var envelope = { spec: 'chara_card_v2', spec_version: '2.0', data: json };
                var solo = S.png.writeTextChunk(pngBytes, 'chara', S.png.jsonToBase64(envelope));
                ui.saveFile(solo, safe + '.png', 'image/png');
              }
              finish();
            })
            .catch(jsonFallback);
        }).catch(function (e) {
          dlBtn.disabled = false;
          dlBtn.textContent = '⤓ Download card';
          ui.toast(e.message, 'err');
        });
      }

      /* --- report --- */
      function showReport() {
        var sel = el('select', { class: 'hub-select hub-wide' }, REPORT_CATEGORIES.map(function (r) {
          return el('option', { value: r.key }, r.label);
        }));
        var reason = el('textarea', { class: 'hub-textarea', rows: '3', maxlength: '500', placeholder: 'What’s wrong? (optional, but it helps)' });
        ui.dialog('Report “' + c.name + '”', [
          el('p', { class: 'hub-dim' }, 'Reports go straight to the moderators. Honest reports only — see the AUP.'),
          sel, reason,
        ], [
          { label: 'Cancel', kind: 'btn-ghost' },
          {
            label: 'Send report', kind: 'btn-danger',
            onclick: function () {
              Api.report(id, sel.value, reason.value.trim())
                .then(function () { ui.toast('Report sent. Thank you for keeping the porch clean.'); })
                .catch(function (e) { ui.toast(e.message, 'err'); });
            },
          },
        ]);
      }

      /* --- group members --- */
      var membersBlock = null;
      if (isGroup) {
        var members = card.raw_member_data || card.members || [];
        membersBlock = el('div', { class: 'hub-members' }, [
          el('h3', null, 'The cast (' + members.length + ')'),
          el('div', { class: 'hub-member-list' }, members.map(function (m) {
            return el('div', { class: 'hub-member' }, [
              el('b', null, m.name || 'Unnamed'),
              el('span', { class: 'hub-dim' }, (m.description || '').slice(0, 140) || '—'),
            ]);
          })),
        ]);
      }

      var caveat = el('div', { class: 'hub-caveat' + (isGroup ? ' warn' : '') },
        isGroup
          ? [el('strong', null, '👥 Group cast — Front Porch AI only. '),
             'No other app can open a group card. Members, lorebooks, and their living Realism state import in one tap in FPAI.']
          : [el('strong', null, '🛋️ Best experienced in Front Porch AI. '),
             'This card works in any V2-compatible app, but its Realism & Needs data (moods, bond, trust) only comes alive in FPAI — the recommended app for every card on The Stoop.']);

      var alts = Array.isArray(card.alternate_greetings) ? card.alternate_greetings.filter(Boolean).join('\n\n———\n\n') : '';

      mount.replaceChildren(el('div', { class: 'hub-detail' }, [
        el('a', { class: 'hub-back', href: '#/' }, '← Back to browsing'),
        el('div', { class: 'hub-detail-top' }, [
          el('div', { class: 'hub-detail-art' }, [ui.avatarImg(c.primaryAssetId, c.name, 'hub-detail-img')]),
          el('div', { class: 'hub-detail-info' }, [
            el('div', { class: 'hub-detail-badges' }, [
              isGroup ? el('span', { class: 'hub-badge hub-badge-group' }, '👥 Group cast') : null,
              c.nsfw ? el('span', { class: 'hub-badge hub-badge-nsfw' }, '18+') : null,
              c.modPick ? el('span', { class: 'hub-badge hub-badge-pick' }, '★ Mod’s Pick') : null,
            ]),
            el('h2', { class: 'hub-detail-name' }, c.name),
            c.creator ? el('a', { class: 'hub-detail-creator', href: '#/creator/' + c.creator.id }, 'by ' + c.creator.displayName + ' →') : null,
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
            el('div', { class: 'hub-detail-actions' }, [
              dlBtn,
              el('span', { class: 'hub-votebox' }, [upBtn, dnBtn]),
              el('button', { class: 'hub-linklike', type: 'button', onclick: showReport }, '⚑ Report'),
            ]),
            caveat,
          ]),
        ]),
        membersBlock,
        el('div', { class: 'hub-sects' }, [
          textSection('Description', card.description, true),
          textSection('Personality', card.personality),
          textSection('Scenario', card.scenario),
          textSection('First message', card.first_mes || card.first_message),
          textSection('Alternate greetings', alts),
          textSection('Example dialogue', card.mes_example),
        ]),
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
      if (!cr.isMe) {
        followBtn = el('button', { class: 'btn ' + (cr.following ? 'btn-ghost' : 'btn-amber'), type: 'button' },
          cr.following ? '✓ Following' : '+ Follow');
        followBtn.addEventListener('click', function () {
          var call = cr.following ? Api.unfollow(id) : Api.follow(id);
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
      mount.replaceChildren(el('div', null, [
        el('a', { class: 'hub-back', href: '#/' }, '← Back to browsing'),
        el('div', { class: 'hub-creator-head' }, [
          el('h2', null, cr.displayName),
          followers,
          followBtn,
        ]),
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
