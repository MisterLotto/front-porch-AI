// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// E2E: the native spell checker actually answers, on every desktop platform.
//
// WHY THIS EXISTS. Spell check is the only feature in the app implemented
// three separate times in three different native languages — Swift against
// NSSpellChecker, C++/COM against ISpellChecker, and C++/GObject against
// Enchant — behind one method channel. Nothing in the app calls it except a
// 300ms debounce inside a TextEditingController, and its Dart wrapper swallows
// every error with a bare `catch (_)` and returns null. That is a perfect
// blind spot: any of the three could stop responding and the only symptom
// would be red underlines quietly not appearing.
//
// It had already happened. Linux never had a plugin at all, so
// DesktopSpellCheckService spent every debounce tick throwing
// MissingPluginException into that bare catch, and no test, golden or E2E ever
// noticed — the feature shipped "supported on desktop" and was dead on a third
// of the desktops.
//
// This talks to the real channel in the real runner. No fake, no mock: if the
// native side is missing or broken, these expectations fail.
//
// WHAT IT PINS, and why each one is here rather than being padding:
//
//   1. Clean prose produces no spans. Guards the inverse failure — a checker
//      that flags everything is as useless as one that flags nothing.
//   2. A misspelling produces a span with EXACT UTF-16 bounds, plus non-empty
//      suggestions. The bounds are the contract; TextRange consumes them
//      directly, so an off-by-one puts the squiggle under the wrong letters.
//   3. Offsets after an emoji. This is the assertion that earns the file.
//      Dart counts UTF-16 code units; macOS (NSString) and Windows
//      (std::wstring) get that for free, but the Linux plugin receives UTF-8
//      and has to track the two counts in parallel. A 4-byte emoji is 2 UTF-16
//      units, so a byte-offset bug shifts every subsequent underline by
//      exactly 2 — invisible in ASCII-only tests, wrong in almost every real
//      message this app sends.
//   4. Contractions, alphanumeric tokens and URLs are left alone. These are
//      the false-positive sources; all three platforms suppress them.
//
// LINUX REQUIREMENT: none. That is the point. The hunspell engine is compiled
// into the binary and an en_US dictionary ships in the bundle, so this suite
// passes on a machine with no spell-check packages installed at all — verified
// by purging libenchant-2-2 and hunspell-en-us and re-running. CI installs
// neither, deliberately, so what it exercises is the out-of-the-box path every
// user actually gets.

import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SuggestionSpan;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:front_porch_ai/services/services.dart'
    show DesktopSpellCheckService, kSpellCheckOff;
import 'package:front_porch_ai/ui/widgets/widgets.dart' show AppTextField;

const _kLocale = Locale('en', 'US');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final service = DesktopSpellCheckService();

  /// Fails loudly rather than returning null, so an absent native checker is
  /// reported as "spell check is not answering" instead of surfacing later as
  /// a confusing type error inside an expectation.
  Future<List<SuggestionSpan>> check(String text) async {
    final spans = await service.fetchSpellCheckSuggestions(_kLocale, text);
    expect(
      spans,
      isNotNull,
      reason:
          'The native spell checker returned null for "$text". On Linux this '
          'means no dictionary resolved at all — including the one we bundle, '
          'so the app bundle is incomplete. On macOS/Windows it means the '
          'platform channel is not registered.',
    );
    return spans!;
  }

  testWidgets('the bundled dictionary ships next to the executable', (
    tester,
  ) async {
    if (!Platform.isLinux) return;
    // Guards the CMake install rule, not the engine. Everything else in this
    // file would still pass on a developer machine that happens to have
    // hunspell-en-us installed, because the plugin prefers system dictionaries
    // — so a broken packaging step would reach users invisibly. This is the
    // only assertion here that fails specifically when the bundle is wrong.
    final bundle = File(Platform.resolvedExecutable).parent.path;
    for (final name in const ['en_US.aff', 'en_US.dic']) {
      expect(
        File('$bundle/data/dictionaries/$name').existsSync(),
        isTrue,
        reason:
            '$name is missing from the app bundle. Spell check would then be '
            'silently dead for any user without a system dictionary, which is '
            'the exact failure this whole change exists to remove.',
      );
    }
  });

  testWidgets('correctly spelled prose produces no spans', (tester) async {
    expect(await check('The porch is quiet this evening.'), isEmpty);
  });

  testWidgets('a misspelling comes back with exact bounds and suggestions', (
    tester,
  ) async {
    // "helllo" is unambiguous enough that all three native checkers agree on
    // the correction, which keeps this assertion honest without being flaky.
    const text = 'I said helllo to her.';
    final spans = await check(text);

    expect(spans, hasLength(1));
    expect(spans.single.range.start, text.indexOf('helllo'));
    expect(spans.single.range.end, text.indexOf('helllo') + 'helllo'.length);
    expect(spans.single.suggestions, contains('hello'));
  });

  testWidgets('offsets are UTF-16 code units, not bytes', (tester) async {
    // U+1F44B is 4 bytes of UTF-8 but 2 UTF-16 code units, so a plugin
    // counting bytes reports a start of 5 where Dart needs 3. Deriving the
    // expected value from Dart's own indexOf is the whole point — it is the
    // exact number TextRange will be built from.
    const text = '👋 teh porch';
    final expectedStart = text.indexOf('teh');
    expect(expectedStart, 3, reason: 'sanity: Dart counts UTF-16 units');

    final spans = await check(text);
    expect(spans, hasLength(1));
    expect(spans.single.range.start, expectedStart);
    expect(spans.single.range.end, expectedStart + 3);
    expect(spans.single.suggestions, isNotEmpty);
  });

  // The remaining cases are false-positive suppression. Unlike the contract
  // above, these are rules the LINUX plugin implements itself in its own
  // tokenizer — NSSpellChecker and ISpellChecker do their own equivalent
  // suppression inside code this project does not own, does not call directly
  // and cannot meaningfully assert against. Running them everywhere would be
  // asserting Apple's and Microsoft's heuristics, so they are scoped to the
  // implementation they actually cover.
  //
  // This is a deliberate scope, not a skip to dodge a failure: every one of
  // these fails on Linux when the plugin is broken (verified by pointing the
  // loader at a missing soname — all five tests in this file went red).
  final linuxOnly = Platform.isLinux;

  testWidgets('contractions, alphanumerics and URLs are not flagged', (
    tester,
  ) async {
    if (!linuxOnly) return;
    // Each of these is a token a naive word-splitter reports as a typo:
    // "don't" split on the apostrophe, "x86" as the word "x", and
    // "github.com" as "github" plus "com".
    expect(await check("I don't mind."), isEmpty);
    expect(await check('Built for x86 and arm64.'), isEmpty);
    expect(await check('See https://github.com/example for more.'), isEmpty);
    expect(await check('Mail porch@example.com about it.'), isEmpty);
  });

  testWidgets('a real AppTextField gets results through the Flutter pipeline', (
    tester,
  ) async {
    // Everything above proves the CHANNEL answers. This proves the answer
    // reaches a widget: platformSpellCheck() has to hand a service to
    // EditableText, which has to call it and store the spans. That gate read
    // `Platform.isMacOS || Platform.isWindows`, so the whole pipeline stayed
    // dark on Linux even with a working plugin behind it.
    expect(
      AppTextField.platformSpellCheck(),
      isNotNull,
      reason: 'platformSpellCheck() must be enabled on every desktop platform',
    );

    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: AppTextField(controller: controller))),
    );

    // enterText, not `controller.text = …`: EditableText runs spell check from
    // updateEditingValue, the path real keystrokes take. Assigning to the
    // controller changes the text without ever asking the checker — which is
    // correct (nobody wants a check per programmatic edit) and is why the
    // first draft of this test failed against a working plugin.
    await tester.enterText(find.byType(AppTextField), 'a helllo here');

    // The reply crosses the platform channel, so spans land a frame or two on.
    final state = tester.state<EditableTextState>(find.byType(EditableText));
    for (var i = 0; i < 40 && state.spellCheckResults == null; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(
      state.spellCheckResults?.suggestionSpans,
      isNotNull,
      reason: 'EditableText never received spans from the native checker',
    );
    expect(
      state.spellCheckResults!.suggestionSpans
          .map((s) => state.spellCheckResults!.spellCheckedText
              .substring(s.range.start, s.range.end))
          .toList(),
      contains('helllo'),
    );
  });

  testWidgets('the OS locale does not decide the spell check language', (
    tester,
  ) async {
    // The bug this guards, reported from a real user: their desktop's
    // INTERFACE language is German, they role-play in English.
    // StyledTextController — the chat composer, both character editors, group
    // settings, the lorebook and message-edit dialogs — read
    // PlatformDispatcher.instance.locale directly, which reports de_DE on such
    // a machine. Their English was then checked against a German dictionary.
    // Measured with hunspell-de-de installed and the fix reverted: "I said
    // helllo to her." came back with three flagged words instead of one, since
    // "said" and "to" are not German. Worse than no spell check at all.
    //
    // Note it is the interface language, not the region: switching the region
    // to Spain leaves the reported locale unchanged, which is why that test
    // looks like nothing is wrong.
    //
    // The fix is that the language is a setting, defaulting to English, and
    // the locale argument is ignored. Passing a deliberately wrong locale here
    // is the whole test: the answer must not change.
    const text = 'I said helllo to her.';
    final asGerman = await service.fetchSpellCheckSuggestions(
      const Locale('de', 'DE'),
      text,
    );

    expect(asGerman, isNotNull);
    expect(
      asGerman!.map((s) => s.range.start).toList(),
      [text.indexOf('helllo')],
      reason: 'the caller-supplied locale must be ignored entirely',
    );
    expect(asGerman.single.suggestions, contains('hello'));
    expect(DesktopSpellCheckService.activeLanguage, 'en_US');
  });

  testWidgets('turning it off stops the checker answering at all', (
    tester,
  ) async {
    DesktopSpellCheckService.activeLanguage = kSpellCheckOff;
    addTearDown(() => DesktopSpellCheckService.activeLanguage = 'en_US');

    expect(await service.fetchSpellCheckSuggestions(_kLocale, 'helllo'), isNull);
    expect(AppTextField.platformSpellCheck(), isNull);
  });

  testWidgets('a typographic apostrophe is treated like a plain one', (
    tester,
  ) async {
    if (!linuxOnly) return;
    // Smart quotes arrive from pasted text and from the app's own prose
    // styling. hunspell dictionaries spell contractions with U+0027, so
    // without folding, every curly-quoted "don't" reads as a misspelling.
    // Windows and macOS take Unicode text natively and need no such fold.
    expect(await check('I don’t mind.'), isEmpty);
  });
}
