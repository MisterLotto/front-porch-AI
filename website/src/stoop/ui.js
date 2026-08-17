/* The Stoop hub — DOM helpers + shared components.
   Everything server-sourced is inserted as text nodes (never innerHTML), so a
   hostile card name or message body can't script the page. */
(function () {
  'use strict';
  window.Stoop = window.Stoop || {};
  var Api = null; // resolved lazily (api.js loads first, but be safe)

  /** el('div', {class:'x', onclick:fn}, [children|string]) — strings become text nodes. */
  function el(tag, attrs, children) {
    var node = document.createElement(tag);
    if (attrs) {
      Object.keys(attrs).forEach(function (k) {
        var v = attrs[k];
        if (v === undefined || v === null || v === false) return;
        if (k.indexOf('on') === 0 && typeof v === 'function') node.addEventListener(k.slice(2), v);
        else if (k === 'class') node.className = v;
        else if (k === 'dataset') Object.keys(v).forEach(function (d) { node.dataset[d] = v[d]; });
        else if (v === true) node.setAttribute(k, '');
        else node.setAttribute(k, v);
      });
    }
    appendAll(node, children);
    return node;
  }
  function appendAll(node, children) {
    if (children === undefined || children === null) return;
    (Array.isArray(children) ? children : [children]).forEach(function (c) {
      if (c === undefined || c === null || c === false) return;
      node.appendChild(typeof c === 'string' || typeof c === 'number' ? document.createTextNode(String(c)) : c);
    });
  }

  /** Replace a node's children, skipping null/undefined/false (unlike the raw
      DOM replaceChildren, which stringifies null into a literal "null" node). */
  function mountChildren(node, children) {
    node.replaceChildren();
    appendAll(node, children);
  }

  /* ---- toasts ---- */
  var toastBox = null;
  function toast(msg, kind) {
    if (!toastBox) {
      toastBox = el('div', { class: 'hub-toasts', 'aria-live': 'polite' });
      document.body.appendChild(toastBox);
    }
    var t = el('div', { class: 'hub-toast' + (kind ? ' ' + kind : '') }, msg);
    toastBox.appendChild(t);
    requestAnimationFrame(function () { t.classList.add('in'); });
    setTimeout(function () {
      t.classList.remove('in');
      setTimeout(function () { t.remove(); }, 350);
    }, kind === 'err' ? 5200 : 3200);
  }

  /* ---- modal dialog ---- */
  function dialog(title, bodyNodes, actions) {
    var overlay;
    function close() { overlay.remove(); document.removeEventListener('keydown', onKey); }
    function onKey(e) { if (e.key === 'Escape') close(); }
    var card = el('div', { class: 'hub-modal', role: 'dialog', 'aria-modal': 'true' }, [
      el('div', { class: 'hub-modal-head' }, [
        el('h3', null, title),
        el('button', { class: 'hub-x', type: 'button', 'aria-label': 'Close', onclick: close }, '✕'),
      ]),
      el('div', { class: 'hub-modal-body' }, bodyNodes),
      actions && actions.length
        ? el('div', { class: 'hub-modal-actions' }, actions.map(function (a) {
            return el('button', {
              class: 'btn ' + (a.kind || 'btn-ghost'),
              type: 'button',
              onclick: function () { var r = a.onclick && a.onclick(close); if (r !== false && a.autoClose !== false) close(); },
            }, a.label);
          }))
        : null,
    ]);
    overlay = el('div', {
      class: 'hub-overlay',
      onclick: function (e) { if (e.target === overlay) close(); },
    }, card);
    document.addEventListener('keydown', onKey);
    document.body.appendChild(overlay);
    return { close: close, root: card };
  }

  function confirmDialog(title, message, confirmLabel, onConfirm, danger) {
    dialog(title, [el('p', { class: 'hub-dim' }, message)], [
      { label: 'Cancel', kind: 'btn-ghost' },
      { label: confirmLabel, kind: danger ? 'btn-danger' : 'btn-amber', onclick: onConfirm },
    ]);
  }

  /* ---- formatters ---- */
  function timeAgo(iso) {
    var d = new Date(iso);
    var s = Math.max(0, (Date.now() - d.getTime()) / 1000);
    if (s < 60) return 'just now';
    if (s < 3600) return Math.floor(s / 60) + 'm ago';
    if (s < 86400) return Math.floor(s / 3600) + 'h ago';
    if (s < 86400 * 30) return Math.floor(s / 86400) + 'd ago';
    return d.toLocaleDateString();
  }
  function num(n) {
    n = n || 0;
    if (n >= 1000) return (n / 1000).toFixed(n >= 10000 ? 0 : 1) + 'k';
    return String(n);
  }

  /* ---- avatar image with authed blob loading ---- */
  function avatarImg(assetId, alt, cls) {
    Api = Api || window.Stoop.api;
    var img = el('img', { class: cls || 'hub-avatar', alt: alt || '', loading: 'lazy' });
    img.style.opacity = '0';
    if (assetId) {
      Api.avatarUrl(assetId).then(function (url) {
        if (url) { img.src = url; img.style.opacity = ''; }
        else img.classList.add('hub-avatar-missing');
      });
    } else {
      img.classList.add('hub-avatar-missing');
    }
    return el('div', { class: 'hub-avatar-frame' }, img);
  }

  /* ---- live stats (score + downloads) — patched app-wide by ws cardStats ---- */
  function statsSpan(card) {
    return el('span', { class: 'hub-stats' }, [
      el('span', { class: 'hub-stat', title: 'Score' }, [
        '▲ ',
        el('b', { dataset: { statsScore: card.id } }, num(card.score)),
      ]),
      el('span', { class: 'hub-stat', title: 'Downloads' }, [
        '⤓ ',
        el('b', { dataset: { statsDl: card.id } }, num(card.downloadCount)),
      ]),
    ]);
  }
  function applyCardStats(f) {
    document.querySelectorAll('[data-stats-score="' + f.cardId + '"]').forEach(function (n) {
      n.textContent = num(f.score);
      flash(n);
    });
    document.querySelectorAll('[data-stats-dl="' + f.cardId + '"]').forEach(function (n) {
      n.textContent = num(f.downloadCount);
      flash(n);
    });
  }
  function flash(n) {
    n.classList.remove('hub-tick');
    void n.offsetWidth; // restart the animation
    n.classList.add('hub-tick');
  }

  /* ---- card grid tile ---- */
  function cardTile(card) {
    var badges = el('div', { class: 'hub-tile-badges' }, [
      card.type === 'GROUP' ? el('span', { class: 'hub-badge hub-badge-group', title: 'Group cast — Front Porch AI only' }, '👥 Group') : null,
      card.type === 'WORLD' ? el('span', { class: 'hub-badge hub-badge-world', title: 'World — a Front Porch AI place (.fpworld)' }, '🏞️ World') : null,
      card.nsfw ? el('span', { class: 'hub-badge hub-badge-nsfw' }, '18+') : null,
      card.modPick ? el('span', { class: 'hub-badge hub-badge-pick', title: 'Mod’s Pick' }, '★ Pick') : null,
    ]);
    return el('a', { class: 'hub-tile' + (card.type === 'WORLD' ? ' hub-tile-world' : ''), href: '#/card/' + card.id }, [
      el('div', { class: 'hub-tile-art' }, [avatarImg(card.primaryAssetId, card.name, 'hub-tile-img'), badges]),
      el('div', { class: 'hub-tile-body' }, [
        el('div', { class: 'hub-tile-name' }, card.name),
        el('div', { class: 'hub-tile-creator' },
        (card.creator ? 'by ' + card.creator.displayName : '')
        + (card.originalCreator ? (card.creator ? ' · ' : '') + '✎ ' + card.originalCreator : '')),
        el('p', { class: 'hub-tile-summary' }, card.summary || ''),
        el('div', { class: 'hub-tile-foot' }, [
          statsSpan(card),
          card.tokenCount ? el('span', { class: 'hub-tokens', title: 'Approximate prompt tokens' }, num(card.tokenCount) + ' tok') : null,
        ]),
      ]),
    ]);
  }

  /* ---- misc ---- */
  function spinner(label) {
    return el('div', { class: 'hub-loading' }, [el('div', { class: 'hub-lamp' }), el('p', null, label || 'Lighting the porch…')]);
  }
  function emptyState(emoji, title, sub) {
    return el('div', { class: 'hub-empty' }, [
      el('div', { class: 'hub-empty-ico' }, emoji),
      el('h3', null, title),
      sub ? el('p', { class: 'hub-dim' }, sub) : null,
    ]);
  }

  /** Trigger a browser download of bytes/blob. */
  function saveFile(data, filename, mime) {
    var blob = data instanceof Blob ? data : new Blob([data], { type: mime || 'application/octet-stream' });
    var url = URL.createObjectURL(blob);
    var a = el('a', { href: url, download: filename });
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 4000);
  }

  /** Download a card to a real file (shared by the picks hero and card detail).
      `item` needs {id, name, type, primaryAssetId?}. Assembles a byte-compatible
      chara / fpa_group PNG, JSON only as a fallback. `btn` (optional) shows
      progress. Returns a Promise. */
  function downloadCard(item, btn) {
    var isGroup = item.type === 'GROUP';
    var isWorld = item.type === 'WORLD';
    var label = btn ? btn.textContent : '';
    if (btn) { btn.disabled = true; btn.textContent = 'Packing it up…'; }
    var restore = function () { if (btn) { btn.disabled = false; btn.textContent = label; } };
    var Api = window.Stoop.api;
    var png = window.Stoop.png;
    return Api.download(item.id).then(function (res) {
      var json = res.card;
      var assetId = res.primaryAssetId || item.primaryAssetId;
      var safe = (item.name || 'character').replace(/[^\w. -]+/g, '_').trim() || 'character';
      // Worlds ARE their card JSON — the .fpworld envelope already embeds the
      // cover image, so no PNG assembly: hand it over as <name>.fpworld.
      if (isWorld) {
        if (!json) { restore(); toast('That world couldn’t be downloaded.', 'err'); return; }
        saveFile(JSON.stringify(json, null, 2), safe + '.fpworld', 'application/json');
        restore();
        toast('World saved! Import it under Worlds → Import Place — needs Front Porch AI 1.2 or newer.');
        return;
      }
      var done = function () {
        restore();
        toast(isGroup
          ? 'Group card saved — it only imports in Front Porch AI (group casts don’t work anywhere else).'
          : 'Card saved! For the full Realism experience, import it into Front Porch AI.');
      };
      if (!json) { restore(); toast('That card couldn’t be downloaded.', 'err'); return; }
      var envelope = { spec: 'chara_card_v2', spec_version: '2.0', data: json };
      var jsonFallback = function () {
        if (isGroup) saveFile(JSON.stringify(json, null, 2), safe + '.group.json', 'application/json');
        else saveFile(JSON.stringify(envelope, null, 2), safe + '.json', 'application/json');
        done();
      };
      if (!assetId) return jsonFallback();
      return Api.assetBlob(assetId).then(png.toPngBytes).then(function (pngBytes) {
        if (isGroup) saveFile(png.writeTextChunk(pngBytes, 'fpa_group', png.jsonToBase64(json)), safe + '.group.png', 'image/png');
        else saveFile(png.writeTextChunk(pngBytes, 'chara', png.jsonToBase64(envelope)), safe + '.png', 'image/png');
        done();
      }).catch(jsonFallback);
    }).catch(function (e) { restore(); toast(e.message, 'err'); });
  }

  /** 18+ self-certification gate for guests who want to see NSFW cards. Calls
      onConfirm() only if they affirm they're an adult. */
  function confirmAdult(onConfirm) {
    dialog('Adults only (18+)', [
      el('p', { class: 'hub-dim' },
        'The Stoop is strictly for adults. NSFW cards can include adult writing and suggestive art. ' +
        'By continuing you confirm that you are 18 years of age or older.'),
      el('p', { class: 'hub-dim hub-small' },
        'Making a free account remembers this and unlocks voting, following, and — once you ' +
        'confirm your email — sharing your own cards.'),
    ], [
      { label: 'Cancel', kind: 'btn-ghost' },
      { label: 'I’m 18 or older — show NSFW', kind: 'btn-amber', onclick: function () { onConfirm(); } },
    ]);
  }

  /** Banner for a signed-in user whose address isn't confirmed yet. Sharing,
      reporting a character, and setting a profile picture stay locked until
      they confirm. Browsing and downloading stay open. Returns null when
      there's nothing to say (verified, or an older server that doesn't
      report the field at all). */
  function verifyBanner(onVerified) {
    Api = Api || window.Stoop.api;
    var u = Api.state.user;
    if (!u || u.emailVerified !== false) return null;
    var btn = el('button', { class: 'btn btn-amber', type: 'button' }, 'Send it again');
    btn.addEventListener('click', function () {
      btn.disabled = true;
      Api.resendVerification()
        .then(function (r) {
          if (r && r.alreadyVerified) {
            toast('Already confirmed \u2014 you\u2019re good to go.');
            if (onVerified) onVerified();
          } else {
            toast('Sent. Check your inbox, and the spam folder just in case.');
          }
        })
        .catch(function (e) {
          toast(e.code === 'resend_too_soon'
            ? 'One just went out \u2014 give it a couple of minutes before asking again.'
            : e.message, 'err');
        })
        .finally(function () { btn.disabled = false; });
    });
    return el('div', { class: 'hub-verify-banner' }, [
      el('span', { class: 'hub-verify-ico' }, '\u2709\uFE0F'),
      el('div', { class: 'hub-verify-text' }, [
        el('strong', null, 'Confirm your email to share cards, report characters, and set a profile photo.'),
        el('p', null, 'I sent a link to ' + (u.email || 'your address') +
          '. Browsing and downloading work without it \u2014 confirming is what unlocks ' +
          'sharing, reporting, and a profile photo.'),
      ]),
      btn,
    ]);
  }

  /** The "plays best in Front Porch AI" strip used on browse + detail. */
  function fpaiBanner(compact) {
    return el('div', { class: 'hub-fpai' + (compact ? ' compact' : '') }, [
      el('span', null, [
        '🛋️ Cards play best in ',
        el('strong', null, 'Front Porch AI'),
        ' — Realism, Needs & group casts only come alive there.',
      ]),
      el('a', { class: 'hub-fpai-link', href: 'https://frontporchai.app/#get', target: '_blank', rel: 'noopener' }, 'Get the app →'),
    ]);
  }

  window.Stoop.ui = {
    el: el,
    appendAll: appendAll,
    mountChildren: mountChildren,
    toast: toast,
    dialog: dialog,
    confirmDialog: confirmDialog,
    timeAgo: timeAgo,
    num: num,
    avatarImg: avatarImg,
    statsSpan: statsSpan,
    applyCardStats: applyCardStats,
    cardTile: cardTile,
    spinner: spinner,
    emptyState: emptyState,
    saveFile: saveFile,
    downloadCard: downloadCard,
    confirmAdult: confirmAdult,
    fpaiBanner: fpaiBanner,
    verifyBanner: verifyBanner,
  };
})();
