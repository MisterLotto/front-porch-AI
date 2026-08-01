/* The Stoop hub — auth views: sign in / create account + the AUP gate.
   Mirrors the desktop app's onboarding: signup captures email, display name,
   password, and date of birth (18+ enforced client- AND server-side); the
   Acceptable Use Policy is fetched live from the API and must be accepted
   before anything else works (POST /auth/accept-policy). */
(function () {
  'use strict';
  var S = window.Stoop;
  var el, Api;

  function field(labelText, input) {
    return el('label', { class: 'hub-field' }, [el('span', null, labelText), input]);
  }

  function policyBody(policy) {
    var nodes = [el('p', { class: 'hub-aup-intro' }, policy.intro)];
    (policy.sections || []).forEach(function (s) {
      nodes.push(el('h4', null, s.title));
      nodes.push(el('p', null, s.body));
    });
    return el('div', { class: 'hub-aup' }, nodes);
  }

  function showPolicyDialog() {
    Api.policy().then(function (p) {
      S.ui.dialog('Acceptable Use Policy · v' + p.version, [policyBody(p)], [{ label: 'Close', kind: 'btn-ghost' }]);
    }).catch(function (e) { S.ui.toast(e.message, 'err'); });
  }

  function ageYears(dobStr) {
    var dob = new Date(dobStr + 'T00:00:00');
    var now = new Date();
    var y = now.getFullYear() - dob.getFullYear();
    var m = now.getMonth() - dob.getMonth();
    if (m < 0 || (m === 0 && now.getDate() < dob.getDate())) y--;
    return y;
  }

  /* =============================== auth view =============================== */
  function renderAuth(mount, mode) {
    mode = mode || 'login';
    var busy = false;

    var email = el('input', { type: 'email', autocomplete: 'email', required: true, placeholder: 'you@example.com' });
    var password = el('input', { type: 'password', autocomplete: mode === 'signup' ? 'new-password' : 'current-password', required: true, minlength: '8', placeholder: mode === 'signup' ? 'At least 8 characters' : 'Your password' });
    var displayName = el('input', { type: 'text', maxlength: '40', placeholder: 'How others see you' });
    var dob = el('input', { type: 'date' });
    var totp = el('input', { type: 'text', inputmode: 'numeric', maxlength: '6', placeholder: '6-digit code' });
    var aupCheck = el('input', { type: 'checkbox' });
    var errBox = el('p', { class: 'hub-form-err', role: 'alert' });
    var totpRow = el('div', { class: 'hub-hidden' }, field('Two-factor code', totp));

    function fail(msg) { errBox.textContent = msg; busy = false; submitBtn.disabled = false; }

    var submitBtn = el('button', { class: 'btn btn-amber hub-wide', type: 'submit' },
      mode === 'signup' ? 'Create account' : 'Sign in');

    function onSubmit(e) {
      e.preventDefault();
      if (busy) return;
      errBox.textContent = '';
      if (mode === 'signup') {
        if (!displayName.value.trim() || displayName.value.trim().length < 2) return fail('Pick a display name (2–40 characters).');
        if (password.value.length < 8) return fail('Password must be at least 8 characters.');
        if (!dob.value) return fail('Enter your date of birth.');
        if (ageYears(dob.value) < 18) return fail('You must be 18 or older to use The Stoop.');
        if (!aupCheck.checked) return fail('You must read and agree to the Acceptable Use Policy.');
      }
      busy = true;
      submitBtn.disabled = true;
      var p;
      if (mode === 'signup') {
        p = Api.signup(email.value.trim(), password.value, displayName.value.trim(),
          new Date(dob.value + 'T00:00:00Z').toISOString())
          .then(function (data) {
            // The AUP was shown + agreed on this form — record it right away.
            return Api.acceptPolicy(data.policyVersion);
          });
      } else {
        p = Api.login(email.value.trim(), password.value, totp.value.trim() || undefined);
      }
      p.then(function () {
        // Confirmation email is on its way; sharing needs it, browsing doesn't.
        if (mode === 'signup') {
          S.ui.toast('Welcome! Check your email to confirm your address — you’ll need it to share cards.');
        }
        S.app.onAuthed();
      })
        .catch(function (err) {
          if (err.code === 'two_factor_required') {
            totpRow.classList.remove('hub-hidden');
            totp.focus();
            fail(totp.value ? 'That code didn’t match — try again.' : 'Enter the 6-digit code from your authenticator app.');
          } else fail(err.message);
        });
    }

    var form = el('form', { class: 'hub-auth-form', onsubmit: onSubmit }, [
      field('Email', email),
      mode === 'signup' ? field('Display name', displayName) : null,
      field('Password', password),
      mode === 'signup' ? field('Date of birth', dob) : null,
      mode === 'login' ? totpRow : null,
      mode === 'signup'
        ? el('label', { class: 'hub-aup-check' }, [
            aupCheck,
            el('span', null, [
              'I am 18 or older and I have read and agree to The Stoop’s ',
              el('a', { href: '#', onclick: function (e) { e.preventDefault(); showPolicyDialog(); } }, 'Acceptable Use Policy'),
              '.',
            ]),
          ])
        : null,
      errBox,
      submitBtn,
    ]);

    var switchLine = mode === 'signup'
      ? el('p', { class: 'hub-auth-switch' }, ['Already have an account? ',
          el('a', { href: '#/login' }, 'Sign in')])
      : el('p', { class: 'hub-auth-switch' }, ['New to the porch? ',
          el('a', { href: '#/signup' }, 'Create an account'),
          ' · ',
          el('a', { href: '#/forgot' }, 'Forgot password?')]);

    mount.replaceChildren(el('div', { class: 'hub-auth' }, [
      el('div', { class: 'hub-auth-panel' }, [
        el('div', { class: 'hub-auth-brand' }, [
          el('h2', null, mode === 'signup' ? 'Pull up a chair' : 'Welcome back to the porch'),
          el('p', { class: 'hub-dim' },
            'The Stoop is the Front Porch AI community character hub — browse, share, and download character cards right from your browser. One account works here and in the app.'),
        ]),
        form,
        switchLine,
        el('div', { class: 'hub-guest-line' }, [
          el('span', { class: 'hub-guest-or' }, 'or'),
          el('button', { class: 'hub-linklike', type: 'button', onclick: function () { S.app.enterGuest(); } }, 'Just browse & download as a guest →'),
        ]),
        el('p', { class: 'hub-auth-fine' }, '18+ only · one account works everywhere in Front Porch'),
      ]),
    ]));
  }

  /* =========================== password recovery =========================== */
  // Ask for a reset email. The answer is deliberately the same whether or not
  // the address has an account — this form can't be used to probe for accounts.
  function renderForgot(mount) {
    var email = el('input', { type: 'email', autocomplete: 'email', required: true, placeholder: 'you@example.com' });
    var errBox = el('p', { class: 'hub-form-err', role: 'alert' });
    var sendBtn = el('button', { class: 'btn btn-amber hub-wide', type: 'submit' }, 'Email me a reset link');

    function onSubmit(e) {
      e.preventDefault();
      if (!email.value.trim()) { errBox.textContent = 'Enter your account email.'; return; }
      sendBtn.disabled = true;
      errBox.textContent = '';
      Api.forgot(email.value.trim())
        .then(function () {
          mount.replaceChildren(el('div', { class: 'hub-auth' }, [
            el('div', { class: 'hub-auth-panel' }, [
              el('h2', null, '📮 Check your mail'),
              el('p', { class: 'hub-dim' },
                'If that address has a Stoop account, a reset link is on its way. It works once, for 45 minutes. No email? Check spam, then try again in a couple of minutes.'),
              el('p', { class: 'hub-auth-switch' }, [el('a', { href: '#/login' }, '← Back to sign in')]),
            ]),
          ]));
        })
        .catch(function (err) { errBox.textContent = err.message; sendBtn.disabled = false; });
    }

    mount.replaceChildren(el('div', { class: 'hub-auth' }, [
      el('div', { class: 'hub-auth-panel' }, [
        el('h2', null, 'Locked out?'),
        el('p', { class: 'hub-dim' }, 'Enter your account email and we’ll send a link to choose a new password.'),
        el('form', { class: 'hub-auth-form', onsubmit: onSubmit }, [
          field('Email', email), errBox, sendBtn,
        ]),
        el('p', { class: 'hub-auth-switch' }, [el('a', { href: '#/login' }, '← Back to sign in')]),
      ]),
    ]));
  }

  // Land here from the emailed link (#/reset?token=…). Accounts with 2FA still
  // need their code — a stolen inbox alone must not beat the second factor.
  function renderReset(mount, hash) {
    var m = (hash || '').match(/[?&]token=([0-9a-fA-F]+)/);
    var token = m ? m[1] : '';
    if (!token) {
      mount.replaceChildren(el('div', { class: 'hub-auth' }, [
        el('div', { class: 'hub-auth-panel' }, [
          el('h2', null, 'Hmm — that link is incomplete'),
          el('p', { class: 'hub-dim' }, 'Open the reset link from your email again, or request a new one.'),
          el('p', { class: 'hub-auth-switch' }, [el('a', { href: '#/forgot' }, 'Request a new link')]),
        ]),
      ]));
      return;
    }

    var pw1 = el('input', { type: 'password', autocomplete: 'new-password', required: true, minlength: '8', placeholder: 'At least 8 characters' });
    var pw2 = el('input', { type: 'password', autocomplete: 'new-password', required: true, placeholder: 'Same password again' });
    var totp = el('input', { type: 'text', inputmode: 'numeric', maxlength: '6', placeholder: '6-digit code' });
    var totpRow = el('div', { class: 'hub-hidden' }, field('Two-factor code', totp));
    var errBox = el('p', { class: 'hub-form-err', role: 'alert' });
    var saveBtn = el('button', { class: 'btn btn-amber hub-wide', type: 'submit' }, 'Set new password');

    function onSubmit(e) {
      e.preventDefault();
      errBox.textContent = '';
      if (pw1.value.length < 8) { errBox.textContent = 'Password must be at least 8 characters.'; return; }
      if (pw1.value !== pw2.value) { errBox.textContent = 'Those passwords don’t match.'; return; }
      saveBtn.disabled = true;
      Api.resetPassword(token, pw1.value, totp.value.trim() || undefined)
        .then(function () {
          mount.replaceChildren(el('div', { class: 'hub-auth' }, [
            el('div', { class: 'hub-auth-panel' }, [
              el('h2', null, '🏡 You’re back in'),
              el('p', { class: 'hub-dim' }, 'Your password is set and every old session was signed out. Sign in with the new one — here or in the app.'),
              el('p', { class: 'hub-auth-switch' }, [el('a', { class: 'btn btn-amber', href: '#/login' }, 'Sign in')]),
            ]),
          ]));
        })
        .catch(function (err) {
          saveBtn.disabled = false;
          if (err.code === 'two_factor_required') {
            totpRow.classList.remove('hub-hidden');
            totp.focus();
            errBox.textContent = totp.value ? 'That code didn’t match — try again.' : 'This account has two-factor on — enter the 6-digit code.';
          } else {
            errBox.textContent = err.message;
          }
        });
    }

    mount.replaceChildren(el('div', { class: 'hub-auth' }, [
      el('div', { class: 'hub-auth-panel' }, [
        el('h2', null, 'Choose a new password'),
        el('form', { class: 'hub-auth-form', onsubmit: onSubmit }, [
          field('New password', pw1),
          field('Repeat it', pw2),
          totpRow,
          errBox,
          saveBtn,
        ]),
        el('p', { class: 'hub-auth-switch' }, [el('a', { href: '#/forgot' }, 'Link expired? Request a new one')]),
      ]),
    ]));
  }

  /* ============================== policy gate ============================== */
  function renderPolicyGate(mount) {
    mount.replaceChildren(S.ui.spinner('Fetching the house rules…'));
    Api.policy().then(function (p) {
      var check = el('input', { type: 'checkbox' });
      var agreeBtn = el('button', { class: 'btn btn-amber', type: 'button', disabled: true, onclick: onAgree }, 'Agree & continue');
      check.addEventListener('change', function () { agreeBtn.disabled = !check.checked; });

      function onAgree() {
        agreeBtn.disabled = true;
        Api.acceptPolicy(p.version)
          .then(function () { S.app.onAuthed(); })
          .catch(function (e) {
            S.ui.toast(e.message, 'err');
            agreeBtn.disabled = false;
            if (e.code === 'version_mismatch') renderPolicyGate(mount);
          });
      }

      mount.replaceChildren(el('div', { class: 'hub-gate' }, [
        el('h2', null, 'Before you come in'),
        el('p', { class: 'hub-dim' }, 'The Acceptable Use Policy has been updated (v' + p.version + '). Please read it and agree to keep using The Stoop.'),
        el('div', { class: 'hub-gate-scroll' }, policyBody(p)),
        el('label', { class: 'hub-aup-check' }, [
          check,
          el('span', null, 'I am 18 or older and I have read and agree to The Stoop’s Acceptable Use Policy.'),
        ]),
        el('div', { class: 'hub-gate-actions' }, [
          el('button', { class: 'btn btn-ghost', type: 'button', onclick: function () { Api.logout().then(function () { S.app.onLoggedOut(); }); } }, 'Decline & sign out'),
          agreeBtn,
        ]),
      ]));
    }).catch(function (e) {
      mount.replaceChildren(S.ui.emptyState('🌫️', 'Couldn’t load the policy', e.message));
    });
  }

  window.Stoop.viewsAuth = {
    renderAuth: function (m, mode) { el = S.ui.el; Api = S.api; renderAuth(m, mode); },
    renderForgot: function (m) { el = S.ui.el; Api = S.api; renderForgot(m); },
    renderReset: function (m, h) { el = S.ui.el; Api = S.api; renderReset(m, h); },
    renderPolicyGate: function (m) { el = S.ui.el; Api = S.api; renderPolicyGate(m); },
    showPolicyDialog: function () { el = S.ui.el; Api = S.api; showPolicyDialog(); },
  };
})();
