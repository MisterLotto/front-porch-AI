# hunspell — vendored

Third-party code. **Do not edit the files in `src/`.** They are an unmodified
copy of upstream; local changes would be silently lost the next time this is
updated, and would make the checksum below meaningless.

## Why it is here

Spell check on macOS and Windows uses the OS's own checker (`NSSpellChecker`,
`ISpellChecker`). Linux has no such guarantee. The first Linux implementation
loaded Enchant at runtime with `dlopen`, which worked but left the feature
standing on three moving parts none of which this project controls: Enchant
itself (a 51 KB broker shim), the hunspell engine it loads behind that, and
whatever dictionary the distribution happened to install. A user with none of
them got no spell check and no explanation.

Vendoring the engine removes all three. hunspell is compiled directly into the
`front_porch_ai` binary — there is no shared library to find, no plugin
directory to probe, and **no separate process of any kind**. It is the same
pattern the app already uses for TTS, STT, expression classification and RAG
embeddings: third-party native code compiled in and called in-process, with its
data shipped alongside. See `docs/design/sidecar-retirement.md`.

## Provenance

| | |
|---|---|
| Upstream | https://github.com/hunspell/hunspell |
| Version | **1.7.3** |
| Obtained from | `http://archive.ubuntu.com/ubuntu/pool/main/h/hunspell/hunspell_1.7.3+really1.7.3.orig.tar.gz` |
| SHA-256 | `933be3dac6fd55f6e752331a170efb7e33800e40fae1156d8434cc8c85379a1b` |
| Verified against | the SHA-256 in Ubuntu's signed `hunspell_1.7.3+really1.7.3-5.dsc`, which matches exactly |
| Vendored on | 2026-08-05 |

Taken: every file from `src/hunspell/` (the engine library — the `Makefile.am`
`libhunspell_1_7_la_SOURCES` list, plus headers). Nothing else — not the CLI
tools, the test suite, the autotools scaffolding, or the bundled dictionaries.

Local modifications: **none**, with one generated file added. `hunvisapi.h` is
normally produced by `configure` from `hunvisapi.h.in`; it is checked in here
with `@HAVE_VISIBILITY@` substituted to `1`, because we build with CMake and
never run `configure`. `HUNSPELL_STATIC` is defined by our CMake target, so that
header resolves to empty visibility attributes either way.

## Licence

hunspell is tri-licensed **MPL 1.1 / GPL 2.0 / LGPL 2.1**. Front Porch AI is
AGPL-3.0-or-later and uses it under the **LGPL-2.1-or-later** arm, which permits
combination with a GPL-3-family work. All three licence texts ship here
(`COPYING`, `COPYING.LESSER`, `COPYING.MPL`) along with upstream's own
`license.hunspell` and `license.myspell` attribution files. Do not delete them —
they are the condition on which this code may be distributed.

The bundled `en_US` dictionary is **not** part of hunspell and is licensed
separately; it lives in `linux/dictionaries/` with its own copyright notice.

## Updating

1. Download the new `.orig.tar.gz` and verify its SHA-256 against the `.dsc`
   from the same archive (or upstream's release signature). Record both here.
2. Replace everything in `src/` wholesale. Do not merge — there are no local
   changes to preserve.
3. Regenerate `hunvisapi.h` from the new `hunvisapi.h.in` the same way.
4. Re-run `flutter test integration_test/spell_check_test.dart -d linux`. That
   suite exercises the engine through the real method channel and will catch a
   bad or partial copy.
5. Check whether the new version raised its C++ standard — 1.7.3 needs C++20
   for `<bit>`, which `CMakeLists.txt` sets on this target alone.
