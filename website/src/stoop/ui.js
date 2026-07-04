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
      card.nsfw ? el('span', { class: 'hub-badge hub-badge-nsfw' }, '18+') : null,
      card.modPick ? el('span', { class: 'hub-badge hub-badge-pick', title: 'Mod’s Pick' }, '★ Pick') : null,
    ]);
    return el('a', { class: 'hub-tile', href: '#/card/' + card.id }, [
      el('div', { class: 'hub-tile-art' }, [avatarImg(card.primaryAssetId, card.name, 'hub-tile-img'), badges]),
      el('div', { class: 'hub-tile-body' }, [
        el('div', { class: 'hub-tile-name' }, card.name),
        el('div', { class: 'hub-tile-creator' }, card.creator ? 'by ' + card.creator.displayName : ''),
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
    fpaiBanner: fpaiBanner,
  };
})();
