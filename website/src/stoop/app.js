/* The Stoop hub — router + boot.
   Hash-routed single page: everything renders into #stoop-app. Auth-walled by
   design — the API only serves cards to signed-in, policy-accepted adults,
   exactly like the hub inside the desktop app. */
(function () {
  'use strict';
  var S = window.Stoop;
  var el, ui, Api;

  var root = null;      // #stoop-app
  var headerBar = null; // in-app tab bar
  var viewMount = null;
  var unreadBadge = null;
  var unread = 0;

  var app = {
    setUnread: function (n) {
      unread = Math.max(0, n | 0);
      if (!unreadBadge) return;
      unreadBadge.textContent = unread ? String(unread) : '';
      unreadBadge.classList.toggle('hub-hidden', !unread);
    },
    paintHeader: paintHeader,
    onAuthed: onAuthed,
    onLoggedOut: onLoggedOut,
  };
  S.app = app;

  var TABS = [
    { hash: '#/', label: 'Browse', match: function (h) { return h === '#/' || h.indexOf('#/card/') === 0 || h.indexOf('#/creator/') === 0; } },
    { hash: '#/mine', label: 'My cards', match: function (h) { return h.indexOf('#/mine') === 0 || h.indexOf('#/submit') === 0; } },
    { hash: '#/inbox', label: 'Inbox', match: function (h) { return h.indexOf('#/inbox') === 0; } },
    { hash: '#/account', label: 'Account', match: function (h) { return h.indexOf('#/account') === 0; } },
  ];

  function paintHeader() {
    if (!headerBar) return;
    var u = Api.state.user;
    if (!u) { headerBar.classList.add('hub-hidden'); return; }
    headerBar.classList.remove('hub-hidden');
    var h = location.hash || '#/';
    headerBar.replaceChildren(
      el('div', { class: 'hub-tabs' }, TABS.map(function (t) {
        var extra = null;
        if (t.label === 'Inbox') {
          unreadBadge = el('span', { class: 'hub-unread' + (unread ? '' : ' hub-hidden') }, unread ? String(unread) : '');
          extra = unreadBadge;
        }
        return el('a', { class: 'hub-tab-link' + (t.match(h) ? ' on' : ''), href: t.hash }, [t.label, extra]);
      })),
      el('div', { class: 'hub-user' }, [
        el('a', { class: 'btn btn-amber hub-share-btn', href: '#/submit' }, '+ Share a card'),
        el('span', { class: 'hub-user-name', title: u.email || '' }, u.displayName || ''),
      ])
    );
  }

  /* ------------------------------- routing ------------------------------- */
  function route() {
    var h = location.hash || '#/';
    var authed = !!Api.state.user;

    if (!authed) {
      headerBar.classList.add('hub-hidden');
      if (h === '#/signup') S.viewsAuth.renderAuth(viewMount, 'signup');
      else S.viewsAuth.renderAuth(viewMount, 'login');
      return;
    }
    if (needsPolicy()) {
      headerBar.classList.add('hub-hidden');
      S.viewsAuth.renderPolicyGate(viewMount);
      return;
    }
    paintHeader();
    window.scrollTo(0, 0);

    var m;
    if ((m = h.match(/^#\/card\/([\w-]+)/))) return S.viewsBrowse.renderCard(viewMount, m[1]);
    if ((m = h.match(/^#\/creator\/([\w-]+)/))) return S.viewsBrowse.renderCreator(viewMount, m[1]);
    if ((m = h.match(/^#\/submit\/([\w-]+)/))) return S.viewsMy.renderSubmit(viewMount, m[1]);
    if (h.indexOf('#/submit') === 0) return S.viewsMy.renderSubmit(viewMount, null);
    if (h.indexOf('#/mine') === 0) return S.viewsMy.renderMine(viewMount);
    if (h.indexOf('#/inbox') === 0) return S.viewsInbox.renderInbox(viewMount);
    if (h.indexOf('#/account') === 0) return S.viewsInbox.renderAccount(viewMount);
    if (h === '#/login' || h === '#/signup') { location.hash = '#/'; return; }
    return S.viewsBrowse.renderBrowse(viewMount);
  }

  function needsPolicy() {
    var u = Api.state.user;
    return !!(u && Api.state.policyVersion && u.acceptedPolicyVersion !== Api.state.policyVersion);
  }

  /* ------------------------------ auth flow ------------------------------ */
  function onAuthed() {
    connectLive();
    Api.unread().then(function (r) { app.setUnread(r.count || 0); }).catch(function () {});
    if (location.hash === '#/login' || location.hash === '#/signup' || !location.hash) {
      location.hash = '#/'; // triggers route()
    } else {
      route();
    }
  }

  function onLoggedOut() {
    Api.ws.close();
    app.setUnread(0);
    location.hash = '#/login';
    route();
  }

  var liveWired = false;
  function connectLive() {
    Api.ws.connect();
    if (liveWired) return;
    liveWired = true;
    Api.ws.on('cardStats', ui.applyCardStats);
    Api.ws.on('message', function (f) {
      var m = f.message;
      if (!m || !m.fromMod) return;
      if ((location.hash || '').indexOf('#/inbox') === 0) return; // inbox handles it
      app.setUnread(unread + 1);
      ui.toast(m.kind === 'SYSTEM' ? '📣 ' + m.body : '💬 New message from the moderators');
    });
  }

  /* --------------------------------- boot --------------------------------- */
  function boot() {
    el = S.ui.el;
    ui = S.ui;
    Api = S.api;
    root = document.getElementById('stoop-app');
    if (!root) return;

    headerBar = el('div', { class: 'hub-bar hub-hidden' });
    viewMount = el('div', { class: 'hub-view' });
    root.replaceChildren(headerBar, viewMount);

    window.addEventListener('hashchange', route);

    if (Api.state.access || Api.state.refresh) {
      viewMount.replaceChildren(ui.spinner('Unlocking the door…'));
      Api.me()
        .then(function () { onAuthed(); })
        .catch(function () { route(); }); // tokens dead → login
    } else {
      route();
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot);
  else boot();
})();
