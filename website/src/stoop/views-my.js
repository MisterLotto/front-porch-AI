/* The Stoop hub — "My cards" (uploads + status + downloads) and Submit.
   Submitting from the browser starts from a card FILE (the PNG or JSON your
   app exports): we read the embedded 'chara' / 'fpa_group' data client-side,
   prefill the form, and ship the same multipart payload the desktop app sends. */
(function () {
  'use strict';
  var S = window.Stoop;
  var el, ui, Api;

  var STATUS_META = {
    PENDING: { label: 'Pending review', cls: 'pending' },
    APPROVED: { label: 'Live on The Stoop', cls: 'approved' },
    REJECTED: { label: 'Not approved', cls: 'rejected' },
    TAKEN_DOWN: { label: 'Taken down', cls: 'rejected' },
  };

  /* ================================ my cards ================================ */
  function renderMine(mount) {
    mount.replaceChildren(ui.spinner());
    Promise.all([Api.myCharacters(), Api.myDownloads().catch(function () { return { items: [] }; })])
      .then(function (res) {
        var mine = res[0].items || [];
        var downloads = res[1].items || [];

        var uploadRows = mine.map(function (ch) {
          var meta = STATUS_META[ch.status] || { label: ch.status, cls: 'pending' };
          return el('div', { class: 'hub-mycard' }, [
            ui.avatarImg(ch.primaryAssetId, ch.name, 'hub-mycard-img'),
            el('div', { class: 'hub-mycard-info' }, [
              el('div', { class: 'hub-mycard-head' }, [
                el('b', null, ch.name),
                ch.type === 'GROUP' ? el('span', { class: 'hub-badge hub-badge-group' }, '👥') : null,
                ch.type === 'WORLD' ? el('span', { class: 'hub-badge hub-badge-world' }, '🏞️') : null,
                ch.nsfw ? el('span', { class: 'hub-badge hub-badge-nsfw' }, '18+') : null,
                el('span', { class: 'hub-status ' + meta.cls }, meta.label),
              ]),
              el('p', { class: 'hub-dim' }, ch.summary || ''),
              ch.rejectionNote ? el('p', { class: 'hub-reject-note' }, ['Moderator note: ', ch.rejectionNote]) : null,
              el('p', { class: 'hub-dim hub-small' }, 'v' + (ch.version || 1) + ' · ' + ui.num(ch.downloadCount) + ' downloads'),
            ]),
            el('div', { class: 'hub-mycard-actions' }, [
              ch.status === 'APPROVED' ? el('a', { class: 'hub-linklike', href: '#/card/' + ch.id }, 'View') : null,
              // Worlds are new-upload-only for v1 (matches the app's hidden
              // Update button) — re-share the place instead.
              ch.type === 'WORLD' ? null : el('button', {
                class: 'hub-linklike', type: 'button',
                onclick: function () { location.hash = '#/submit/' + ch.id; },
              }, 'Update'),
              el('button', {
                class: 'hub-linklike danger', type: 'button',
                onclick: function () {
                  ui.confirmDialog('Remove “' + ch.name + '”?',
                    'This takes the card off The Stoop for everyone. Copies people already downloaded stay with them.',
                    'Remove card',
                    function () {
                      Api.deleteCharacter(ch.id)
                        .then(function () { ui.toast('Card removed.'); renderMine(mount); })
                        .catch(function (e) { ui.toast(e.message, 'err'); });
                    }, true);
                },
              }, 'Delete'),
            ]),
          ]);
        });

        mount.replaceChildren(el('div', null, [
          ui.verifyBanner(function () { renderMine(mount); }),
          el('div', { class: 'hub-head-row' }, [
            el('h2', null, 'My cards'),
            el('div', { class: 'hub-head-actions' }, [
              el('a', { class: 'btn btn-ghost', href: '#/submit-world' }, '🏞️ Share a world'),
              el('a', { class: 'btn btn-amber', href: '#/submit' }, '+ Share a card'),
            ]),
          ]),
          mine.length ? el('div', { class: 'hub-mylist' }, uploadRows)
            : ui.emptyState('🎴', 'Nothing shared yet', 'Share a character or group card and it shows up here with its review status.'),
          el('h2', { class: 'hub-h2-space' }, 'My downloads'),
          downloads.length
            ? el('div', { class: 'hub-grid' }, downloads.map(ui.cardTile))
            : el('p', { class: 'hub-dim' }, 'Cards you download show up here for easy re-downloading.'),
        ]));
      })
      .catch(function (e) { mount.replaceChildren(ui.emptyState('🌫️', 'Couldn’t load your cards', e.message)); });
  }

  /* ================================= submit ================================= */
    function renderCompletenessPanel(host, comp) {
      if (!host) return;
      host.replaceChildren();
      if (!comp) {
        host.className = 'hub-completeness hub-hidden';
        return;
      }
      host.className = 'hub-completeness ' + (comp.incomplete ? 'hot' : 'cool');
      var rows = (comp.fields || []).map(function (f) {
        return el('div', { class: 'hub-comp-row ' + (f.present ? 'ok' : f.critical ? 'bad' : 'warn') }, [
          el('span', { class: 'hub-comp-mark' }, f.present ? '✓' : f.critical ? '✕' : '·'),
          el('span', { class: 'hub-comp-label' }, f.label),
          el('span', { class: 'hub-comp-meta' }, f.present
            ? ((f.chars || 0).toLocaleString() + ' chars')
            : (f.critical ? 'required' : 'optional')),
        ]);
      });
      var kids = [
        el('div', { class: 'hub-completeness-title' },
          comp.incomplete ? 'Incomplete card — can’t submit yet' : 'Looks complete'),
        el('div', { class: 'hub-completeness-msg' },
          comp.incomplete
            ? ('Missing required fields: ' + (comp.missingCritical || []).join(', ') +
              '. Open the card in Front Porch AI (or your editor), fill those fields, re-export, and drop the new file here.')
            : 'Core greeting and identity fields are present. Double-check the text and art before sending.'),
        el('div', { class: 'hub-completeness-grid' }, rows),
      ];
      (comp.notes || []).forEach(function (n) {
        kids.push(el('div', { class: 'hub-completeness-note' }, n));
      });
      host.replaceChildren(el('div', null, kids));
    }

    function renderSubmit(mount, updateId) {
      var parsed = null; // { type, card, pngBytes }
      var avatarOverride = null; // File (required for .json uploads)
      var completeness = null;

      var nameIn = el('input', { type: 'text', maxlength: '80', placeholder: 'Card name' });
      var summaryIn = el('textarea', { class: 'hub-textarea', rows: '2', maxlength: '280', placeholder: 'One or two lines that sell the character (required)' });
      var tagsIn = el('input', { type: 'text', placeholder: 'Comma-separated tags, e.g. fantasy, slow-burn' });
      var creatorIn = el('input', { type: 'text', maxlength: '120', placeholder: 'Leave blank if this is your own work' });
      var nsfwIn = el('input', { type: 'checkbox' });
      var changelogIn = el('textarea', { class: 'hub-textarea', rows: '2', maxlength: '500', placeholder: updateId ? 'What changed in this version?' : 'Anything reviewers should know? (optional)' });
      var errBox = el('p', { class: 'hub-form-err', role: 'alert' });
      var fileInfo = el('p', { class: 'hub-dim' }, 'No card loaded yet.');
      var preview = el('div', { class: 'hub-submit-preview' });
      var completenessHost = el('div', { class: 'hub-completeness hub-hidden' });
      var avatarRow = el('div', { class: 'hub-hidden' });

      var fileIn = el('input', { type: 'file', accept: '.png,.json', class: 'hub-hidden' });
      var avatarIn = el('input', { type: 'file', accept: 'image/png,image/jpeg,image/webp', class: 'hub-hidden' });

      var submitBtn = el('button', { class: 'btn btn-amber', type: 'button', disabled: true, onclick: doSubmit },
        updateId ? 'Publish new version' : 'Submit for review');

      function setError(msg) { errBox.textContent = msg || ''; }

      function refreshSubmitEnabled() {
        // Submit stays off until a card loads AND required definition fields exist.
        // Avatar may still be pending for JSON uploads — doSubmit checks that.
        var ok = !!parsed && !(completeness && completeness.incomplete);
        submitBtn.disabled = !ok;
      }

      fileIn.addEventListener('change', function () {
        var f = fileIn.files && fileIn.files[0];
        if (!f) return;
        setError('');
        S.png.parseCardFile(f).then(function (res) {
          parsed = res;
          var card = res.card || {};
          completeness = S.completeness.assess(card, res.type);
          renderCompletenessPanel(completenessHost, completeness);
          if (!nameIn.value) nameIn.value = card.name || '';
          // Card files often carry the author in their V2 `creator` field —
          // prefill the credit when it isn't the signed-in user's own handle.
          var embedded = typeof card.creator === 'string' ? card.creator.trim() : '';
          var myName = (Api.state.user && Api.state.user.displayName) || '';
          if (!creatorIn.value && embedded && embedded.toLowerCase() !== myName.toLowerCase()) {
            creatorIn.value = embedded;
          }
          fileInfo.textContent = f.name + ' · ' + (res.type === 'GROUP' ? 'Group cast ('
            + ((card.raw_member_data || card.members || []).length) + ' members)' : 'Solo character')
            + (completeness.incomplete ? ' · incomplete' : '');
          preview.replaceChildren();
          if (res.pngBytes) {
            var img = el('img', { class: 'hub-submit-img', alt: 'Card art' });
            img.src = URL.createObjectURL(new Blob([res.pngBytes], { type: 'image/png' }));
            preview.appendChild(img);
            avatarRow.classList.add('hub-hidden');
            avatarOverride = null;
          } else {
            avatarRow.classList.remove('hub-hidden'); // JSON card → needs separate art
          }
          if (completeness.incomplete) {
            setError(S.completeness.message(completeness));
          }
          refreshSubmitEnabled();
        }).catch(function (e) {
          parsed = null;
          completeness = null;
          renderCompletenessPanel(completenessHost, null);
          submitBtn.disabled = true;
          setError(e.message);
        });
      });

      avatarIn.addEventListener('change', function () {
        avatarOverride = (avatarIn.files && avatarIn.files[0]) || null;
        preview.replaceChildren();
        if (avatarOverride) {
          var img = el('img', { class: 'hub-submit-img', alt: 'Card art' });
          img.src = URL.createObjectURL(avatarOverride);
          preview.appendChild(img);
        }
      });

      function doSubmit() {
        if (!parsed) return setError('Load a card file first.');
        completeness = S.completeness.assess(parsed.card, parsed.type);
        renderCompletenessPanel(completenessHost, completeness);
        if (completeness.incomplete) {
          refreshSubmitEnabled();
          return setError(S.completeness.message(completeness));
        }
        var name = nameIn.value.trim();
        var summary = summaryIn.value.trim();
        if (!name) return setError('Give the card a name.');
        if (!summary) return setError('Write a short summary — it’s what people see while browsing.');
        var avatarBlob = avatarOverride
          || (parsed.pngBytes ? new Blob([parsed.pngBytes], { type: 'image/png' }) : null);
        if (!avatarBlob) return setError('Add card art (PNG, JPEG, or WebP).');
        var tags = tagsIn.value.split(',').map(function (t) { return t.trim().toLowerCase(); })
          .filter(Boolean).slice(0, 20);
        var payload = {
          name: name,
          summary: summary,
          type: parsed.type,
          nsfw: nsfwIn.checked,
          tags: tags,
          card: parsed.card,
          changelog: changelogIn.value.trim() || (updateId ? 'Updated' : 'Initial upload'),
          // Attribution ('' = own work; on update, '' clears an old credit).
          originalCreator: creatorIn.value.trim(),
        };
        setError('');
        submitBtn.disabled = true;
        submitBtn.textContent = 'Sending to the porch…';
        var call = updateId
          ? Api.uploadVersion(updateId, payload, avatarBlob, 'avatar.png')
          : Api.uploadCharacter(payload, avatarBlob, 'avatar.png');
        call.then(function () {
          mount.replaceChildren(el('div', { class: 'hub-submitted' }, [
            el('div', { class: 'hub-empty-ico' }, '🏡'),
            el('h2', null, 'It’s on the porch!'),
            el('p', { class: 'hub-dim' }, 'Every card is reviewed by a moderator before it goes public. You’ll get a notification here (and in the app) once it’s approved — or a note explaining what needs a tweak.'),
            el('div', { class: 'hub-gate-actions' }, [
              el('a', { class: 'btn btn-ghost', href: '#/mine' }, 'My cards'),
              el('a', { class: 'btn btn-amber', href: '#/' }, 'Keep browsing'),
            ]),
          ]));
        }).catch(function (e) {
          submitBtn.disabled = false;
          submitBtn.textContent = updateId ? 'Publish new version' : 'Submit for review';
          refreshSubmitEnabled();
          if (e.code === 'email_not_verified') {
            setError('Confirm your email address first — check your inbox for the link, or use “Send it again” on My cards.');
          } else if (e.code === 'incomplete_card') {
            setError(e.message || S.completeness.message(completeness));
          } else {
            setError(e.message);
          }
        });
      }

      avatarRow.appendChild(el('div', { class: 'hub-filebtn-row' }, [
        el('button', { class: 'btn btn-ghost', type: 'button', onclick: function () { avatarIn.click(); } }, 'Choose card art…'),
        el('span', { class: 'hub-dim hub-small' }, 'JSON cards need a separate image (non-pornographic — see the AUP).'),
      ]));

      mount.replaceChildren(el('div', { class: 'hub-submit' }, [
        el('a', { class: 'hub-back', href: '#/mine' }, '← My cards'),
        // Say it up front rather than letting them fill the whole form and hit a
        // 403 at the end.
        ui.verifyBanner(),
        el('h2', null, updateId ? 'Update your card' : 'Share a card on The Stoop'),
        el('p', { class: 'hub-dim' }, [
          'Start from a card file: a character PNG (V2 “chara” cards from Front Porch AI, SillyTavern, and friends), a Front Porch ',
          el('code', null, '.group.png'),
          ' group card, or a raw JSON card. Cards need a first message plus description/personality and scenario — empty template shells are rejected before review. Everything is moderated — the ',
          el('a', { href: '#', onclick: function (e) { e.preventDefault(); S.viewsAuth.showPolicyDialog(); } }, 'content standards'),
          ' apply.',
        ]),
        el('div', { class: 'hub-dropzone', onclick: function () { fileIn.click(); },
          ondragover: function (e) { e.preventDefault(); e.currentTarget.classList.add('over'); },
          ondragleave: function (e) { e.currentTarget.classList.remove('over'); },
          ondrop: function (e) {
            e.preventDefault();
            e.currentTarget.classList.remove('over');
            if (e.dataTransfer.files && e.dataTransfer.files[0]) {
              fileIn.files = e.dataTransfer.files;
              fileIn.dispatchEvent(new Event('change'));
            }
          },
        }, [el('span', { class: 'hub-drop-ico' }, '🎴'), el('span', null, 'Drop a card file here, or click to choose'), fileInfo]),
        fileIn, avatarIn, avatarRow, preview, completenessHost,
        el('div', { class: 'hub-form' }, [
          el('label', { class: 'hub-field' }, [el('span', null, 'Name'), nameIn]),
          el('label', { class: 'hub-field' }, [el('span', null, 'Summary'), summaryIn]),
          el('label', { class: 'hub-field' }, [el('span', null, 'Tags'), tagsIn]),
          el('label', { class: 'hub-field' }, [
            el('span', null, 'Original creator (optional)'),
            creatorIn,
            el('span', { class: 'hub-dim hub-small' },
              'Sharing someone else’s character? Credit them here — the card will show “created by …”. The AUP requires this for reposts.'),
          ]),
          el('label', { class: 'hub-aup-check' }, [nsfwIn, el('span', null, 'This card is NSFW (mislabeling is an AUP violation)')]),
          el('label', { class: 'hub-field' }, [el('span', null, updateId ? 'Changelog' : 'Note to reviewers'), changelogIn]),
          errBox,
          submitBtn,
        ]),
      ]));

      // Update mode: pull the post's current credit so re-publishing keeps it
      // unless the field is deliberately cleared.
      if (updateId) {
        Api.cardDetail(updateId).then(function (d) {
          if (!creatorIn.value && d && d.originalCreator) creatorIn.value = d.originalCreator;
        }).catch(function () { /* prefill only — the form still works without it */ });
      }
    }

  /* ============================== submit a world ============================== */
  // The .fpworld envelope embeds its cover as a data URL — decode it for the
  // required avatar upload (moderators review it like any card art).
  function coverBlobFromEnvelope(env) {
    var m = /^data:(image\/(?:png|jpeg|webp));base64,(.*)$/.exec(String(env.cover || ''));
    if (!m) return null;
    try {
      var bin = atob(m[2]);
      var bytes = new Uint8Array(bin.length);
      for (var i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
      return {
        blob: new Blob([bytes], { type: m[1] }),
        name: 'cover.' + (m[1] === 'image/png' ? 'png' : m[1] === 'image/webp' ? 'webp' : 'jpg'),
      };
    } catch (e) { return null; }
  }

  function renderSubmitWorld(mount) {
      var envelope = null; // the parsed .fpworld JSON
      var cover = null; // { blob, name }
      var completeness = null;

      var nameIn = el('input', { type: 'text', maxlength: '80', placeholder: 'World name' });
      var summaryIn = el('textarea', { class: 'hub-textarea', rows: '2', maxlength: '280', placeholder: 'One or two lines that sell the place (required)' });
      var tagsIn = el('input', { type: 'text', placeholder: 'Comma-separated tags, e.g. sci-fi, volcanic' });
      var creatorIn = el('input', { type: 'text', maxlength: '120', placeholder: 'Leave blank if this is your own work' });
      var nsfwIn = el('input', { type: 'checkbox' });
      var changelogIn = el('textarea', { class: 'hub-textarea', rows: '2', maxlength: '500', placeholder: 'Anything reviewers should know? (optional)' });
      var errBox = el('p', { class: 'hub-form-err', role: 'alert' });
      var fileInfo = el('p', { class: 'hub-dim' }, 'No world loaded yet.');
      var preview = el('div', { class: 'hub-submit-preview' });
      var completenessHost = el('div', { class: 'hub-completeness hub-hidden' });
      var fileIn = el('input', { type: 'file', accept: '.fpworld,.json', class: 'hub-hidden' });
      var submitBtn = el('button', { class: 'btn btn-amber', type: 'button', disabled: true, onclick: doSubmit }, 'Submit for review');

      function setError(msg) { errBox.textContent = msg || ''; }
      function isObj(v) { return !!v && typeof v === 'object' && !Array.isArray(v); }
      function refreshSubmitEnabled() {
        submitBtn.disabled = !(envelope && cover && !(completeness && completeness.incomplete));
      }

      fileIn.addEventListener('change', function () {
        var f = fileIn.files && fileIn.files[0];
        if (!f) return;
        setError('');
        // Size gate BEFORE reading — someone dropping a video shouldn't have the
        // tab chew through gigabytes just to fail JSON.parse. The server caps
        // world cards at 8 MB; 10 MB here leaves slack for formatting.
        if (f.size > 10 * 1024 * 1024) {
          envelope = null; cover = null; completeness = null;
          renderCompletenessPanel(completenessHost, null);
          submitBtn.disabled = true;
          preview.replaceChildren();
          fileInfo.textContent = 'No world loaded yet.';
          return setError('That file is too big to be a world (' + Math.round(f.size / 1024 / 1024) + ' MB) — .fpworld files top out around 8 MB.');
        }
        f.text().then(function (text) {
          var j;
          try { j = JSON.parse(text); } catch (e) { throw new Error('That file isn’t a valid .fpworld (couldn’t read it as JSON).'); }
          if (!isObj(j) || !(isObj(j.lorebook) || isObj(j.biome) || isObj(j.place_traits))) {
            throw new Error('That JSON isn’t a Front Porch world — export the place from the app (Worlds → the card’s Export button).');
          }
          cover = coverBlobFromEnvelope(j);
          if (!cover) {
            throw new Error('This place has no cover image. Add one in the app (worlds need cover art to be shared), re-export, and try again.');
          }
          envelope = j;
          completeness = S.completeness.assess(j, 'WORLD');
          renderCompletenessPanel(completenessHost, completeness);
          if (!nameIn.value) nameIn.value = String(j.name || '');
          if (!summaryIn.value && typeof j.description === 'string') summaryIn.value = j.description.slice(0, 280);
          var entries = (isObj(j.lorebook) && Array.isArray(j.lorebook.entries)) ? j.lorebook.entries.length : 0;
          var climate = isObj(j.biome) ? (j.biome.displayName || 'custom climate') : 'standard climate';
          fileInfo.textContent = f.name + ' · ' + entries + (entries === 1 ? ' lore entry' : ' lore entries') + ' · ' + climate
            + (completeness.incomplete ? ' · incomplete' : '');
          preview.replaceChildren();
          var img = el('img', { class: 'hub-submit-img', alt: 'World cover' });
          img.src = URL.createObjectURL(cover.blob);
          preview.appendChild(img);
          if (completeness.incomplete) setError(S.completeness.message(completeness));
          refreshSubmitEnabled();
        }).catch(function (e) {
          envelope = null;
          cover = null;
          completeness = null;
          renderCompletenessPanel(completenessHost, null);
          submitBtn.disabled = true;
          preview.replaceChildren();
          // Reset the dropzone caption too — a stale "Cindermaw.fpworld · 5 lore
          // entries" line next to an error would read as still-loaded.
          fileInfo.textContent = 'No world loaded yet.';
          setError(e.message);
        });
      });

      function doSubmit() {
        if (!envelope || !cover) return setError('Load a .fpworld file first.');
        completeness = S.completeness.assess(envelope, 'WORLD');
        renderCompletenessPanel(completenessHost, completeness);
        if (completeness.incomplete) {
          refreshSubmitEnabled();
          return setError(S.completeness.message(completeness));
        }
        var name = nameIn.value.trim();
        var summary = summaryIn.value.trim();
        if (!name) return setError('Give the world a name.');
        if (!summary) return setError('Write a short summary — it’s what people see while browsing.');
        var tags = tagsIn.value.split(',').map(function (t) { return t.trim().toLowerCase(); })
          .filter(Boolean).slice(0, 20);
        setError('');
        submitBtn.disabled = true;
        submitBtn.textContent = 'Sending to the porch…';
        Api.uploadCharacter({
          name: name,
          summary: summary,
          type: 'WORLD',
          nsfw: nsfwIn.checked,
          tags: tags,
          card: envelope,
          changelog: changelogIn.value.trim() || 'Initial upload',
          originalCreator: creatorIn.value.trim(),
        }, cover.blob, cover.name).then(function () {
          mount.replaceChildren(el('div', { class: 'hub-submitted' }, [
            el('div', { class: 'hub-empty-ico' }, '🏞️'),
            el('h2', null, 'Your world is on the porch!'),
            el('p', { class: 'hub-dim' }, 'Every world is reviewed by a moderator before it goes public — you’ll get a notification here (and in the app) once it’s approved, or a note explaining what needs a tweak.'),
            el('div', { class: 'hub-gate-actions' }, [
              el('a', { class: 'btn btn-ghost', href: '#/mine' }, 'My cards'),
              el('a', { class: 'btn btn-amber', href: '#/' }, 'Keep browsing'),
            ]),
          ]));
        }).catch(function (e) {
          submitBtn.disabled = false;
          submitBtn.textContent = 'Submit for review';
          refreshSubmitEnabled();
          setError(e.code === 'email_not_verified'
            ? 'Confirm your email address first — check your inbox for the link, or use “Send it again” on My cards.'
            : e.message);
        });
      }

      mount.replaceChildren(el('div', { class: 'hub-submit' }, [
        el('a', { class: 'hub-back', href: '#/mine' }, '← My cards'),
        ui.verifyBanner(),
        el('h2', null, '🏞️ Share a world on The Stoop'),
        el('p', { class: 'hub-dim' }, [
          'Start from a ',
          el('code', null, '.fpworld'),
          ' file exported from Front Porch AI (Worlds → the place’s Export button). It carries the cover art, lore, custom climate, and place traits — everything a downloader needs. Empty shells without climate/lore are rejected. Reviewed before it goes public — the ',
          el('a', { href: '#', onclick: function (e) { e.preventDefault(); S.viewsAuth.showPolicyDialog(); } }, 'content standards'),
          ' apply.',
        ]),
        el('div', { class: 'hub-dropzone', onclick: function () { fileIn.click(); },
          ondragover: function (e) { e.preventDefault(); e.currentTarget.classList.add('over'); },
          ondragleave: function (e) { e.currentTarget.classList.remove('over'); },
          ondrop: function (e) {
            e.preventDefault();
            e.currentTarget.classList.remove('over');
            if (e.dataTransfer.files && e.dataTransfer.files[0]) {
              fileIn.files = e.dataTransfer.files;
              fileIn.dispatchEvent(new Event('change'));
            }
          },
        }, [el('span', { class: 'hub-drop-ico' }, '🏞️'), el('span', null, 'Drop a .fpworld file here, or click to choose'), fileInfo]),
        fileIn, preview, completenessHost,
        el('div', { class: 'hub-form' }, [
          el('label', { class: 'hub-field' }, [el('span', null, 'Name'), nameIn]),
          el('label', { class: 'hub-field' }, [el('span', null, 'Summary'), summaryIn]),
          el('label', { class: 'hub-field' }, [el('span', null, 'Tags'), tagsIn]),
          el('label', { class: 'hub-field' }, [
            el('span', null, 'Original creator (optional)'),
            creatorIn,
            el('span', { class: 'hub-dim hub-small' },
              'Sharing someone else’s world? Credit them here — the AUP requires this for reposts.'),
          ]),
          el('label', { class: 'hub-aup-check' }, [nsfwIn, el('span', null, 'This world is NSFW — suggestive cover art or 18+ themes in its lore (mislabeling is an AUP violation)')]),
          el('label', { class: 'hub-field' }, [el('span', null, 'Note to reviewers'), changelogIn]),
          errBox,
          submitBtn,
        ]),
      ]));
    }

  window.Stoop.viewsMy = {
    renderMine: function (m) { el = S.ui.el; ui = S.ui; Api = S.api; renderMine(m); },
    renderSubmit: function (m, updateId) { el = S.ui.el; ui = S.ui; Api = S.api; renderSubmit(m, updateId); },
    renderSubmitWorld: function (m) { el = S.ui.el; ui = S.ui; Api = S.api; renderSubmitWorld(m); },
  };
})();
