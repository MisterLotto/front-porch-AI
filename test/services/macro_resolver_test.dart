import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/macro_resolver.dart';

void main() {
  group('MacroResolver', () {
    late MacroResolver resolver;
    late MacroContext ctx;

    setUp(() {
      resolver = MacroResolver();
      ctx = const MacroContext(userName: 'Alex', characterName: 'Luna');
    });

    test('resolves {{char}}', () {
      expect(resolver.resolve('{{char}} is here', ctx), 'Luna is here');
    });

    test('resolves {{user}}', () {
      expect(resolver.resolve('{{user}} says hi', ctx), 'Alex says hi');
    });

    test('resolves <char> legacy syntax', () {
      expect(resolver.resolve('<char> is here', ctx), 'Luna is here');
    });

    test('resolves <user> legacy syntax', () {
      expect(resolver.resolve('<user> says hi', ctx), 'Alex says hi');
    });

    test('case insensitive', () {
      expect(
        resolver.resolve('{{CHAR}} {{User}} {{char}} {{user}}', ctx),
        'Luna Alex Luna Alex',
      );
    });

    test('unknown macros pass through', () {
      expect(
        resolver.resolve('{{unknown}} here', ctx),
        '{{unknown}} here',
      );
    });

    test('mixed known and unknown', () {
      expect(
        resolver.resolve('{{char}} {{unknown}} {{user}}', ctx),
        'Luna {{unknown}} Alex',
      );
    });

    test('multiple occurrences', () {
      expect(
        resolver.resolve('{{char}} and {{char}}', ctx),
        'Luna and Luna',
      );
    });

    test('empty input returns empty', () {
      expect(resolver.resolve('', ctx), '');
    });

    test('no macros returns same string', () {
      expect(resolver.resolve('plain text', ctx), 'plain text');
    });

    test('custom registration', () {
      resolver.register('greet', (args, ctx) => 'Hello ${ctx.userName}!');
      expect(resolver.resolve('{{greet}}', ctx), 'Hello Alex!');
    });

    test('macro with ::args', () {
      resolver.register('repeat', (args, ctx) => args.join(','));
      expect(
        resolver.resolve('{{repeat::a::b::c}}', ctx),
        'a,b,c',
      );
    });

    test('per-character {{char}} in group mode simulation', () {
      final aliceCtx = MacroContext(userName: 'User', characterName: 'Alice');
      final bobCtx = MacroContext(userName: 'User', characterName: 'Bob');

      expect(resolver.resolve('{{char}} is a cat.', aliceCtx), 'Alice is a cat.');
      expect(resolver.resolve('{{char}} is a dog.', bobCtx), 'Bob is a dog.');
    });

    test('{{user}} is same across all group member contexts', () {
      final ctx1 = MacroContext(userName: 'Player1', characterName: 'Alice');
      final ctx2 = MacroContext(userName: 'Player1', characterName: 'Bob');

      expect(
        resolver.resolve('{{user}} talks to {{char}}', ctx1),
        'Player1 talks to Alice',
      );
      expect(
        resolver.resolve('{{user}} talks to {{char}}', ctx2),
        'Player1 talks to Bob',
      );
    });

    // ── Phase 2 P0: Escape & Comments ──

    test('\\{{ escape produces literal {{', () {
      expect(resolver.resolve('\\{{char}}', ctx), '{{char}}');
    });

    test('\\{{ escape works in mixed text', () {
      expect(
        resolver.resolve('Hello \\{{char}} world', ctx),
        'Hello {{char}} world',
      );
    });

    test('{{//}} comment is stripped', () {
      expect(resolver.resolve('{{// note}}', ctx), '');
    });

    test('{{//}} comment inline is stripped', () {
      expect(
        resolver.resolve('before {{// note}} after', ctx),
        'before  after',
      );
    });

    // ── Phase 2 P0: newline, space, noop ──

    test('{{newline}} produces \\n', () {
      expect(resolver.resolve('a{{newline}}b', ctx), 'a\nb');
    });

    test('{{newline::3}} produces 3 newlines', () {
      expect(resolver.resolve('a{{newline::3}}b', ctx), 'a\n\n\nb');
    });

    test('{{newline::0}} is clamped to 1', () {
      expect(resolver.resolve('{{newline::0}}', ctx), '\n');
    });

    test('{{space}} produces single space', () {
      expect(resolver.resolve('a{{space}}b', ctx), 'a b');
    });

    test('{{space::4}} produces 4 spaces', () {
      expect(resolver.resolve('a{{space::4}}b', ctx), 'a    b');
    });

    test('{{noop}} produces empty string', () {
      expect(resolver.resolve('a{{noop}}b', ctx), 'ab');
    });

    // ── Phase 2 P0: random ──

    test('{{random::a::b::c}} always picks from given options', () {
      for (var i = 0; i < 100; i++) {
        final result = resolver.resolve('{{random::a::b::c}}', ctx);
        expect(['a', 'b', 'c'], contains(result));
      }
    });

    test('{{random::single}} picks the only option', () {
      for (var i = 0; i < 10; i++) {
        expect(resolver.resolve('{{random::single}}', ctx), 'single');
      }
    });

    test('{{random}} with no args returns empty', () {
      expect(resolver.resolve('{{random}}', ctx), '');
    });

    // ── Phase 2 P0: pick ──

    test('{{pick}} same context returns same value', () {
      final pCtx = MacroContext(
        userName: 'U', characterName: 'C',
        chatId: 'chat1', characterId: 'char1',
      );
      final r1 = resolver.resolve('{{pick::a::b::c}}', pCtx);
      final r2 = resolver.resolve('{{pick::a::b::c}}', pCtx);
      expect(r1, r2);
    });

    test('{{pick}} multiple in one resolve() vary by counter', () {
      final pCtx = MacroContext(
        userName: 'U', characterName: 'C',
        chatId: 'chat1', characterId: 'char1',
      );
      // Multiple {{pick}} within one resolve() — each gets a different counter
      final result = resolver.resolve(
        '{{pick::a::b::c}} ' * 99,
        pCtx,
      );
      final parts = result.trim().split(' ');
      // With 99 picks and 3 options, at least 2 different values should appear
      expect(parts.toSet().length, greaterThan(1));
    });

    test('{{pick}} across 300 contexts each option appears', () {
      final results = <String>{};
      for (var i = 0; i < 300; i++) {
        final c = MacroContext(
          userName: 'U', characterName: 'C',
          chatId: 'id$i', characterId: 'char$i',
        );
        results.add(resolver.resolve('{{pick::a::b::c}}', c));
      }
      for (final opt in ['a', 'b', 'c']) {
        expect(results, contains(opt));
      }
    });

    test('{{pick}} defaults to empty section matching between resolve() calls', () {
      final pCtx = MacroContext(
        userName: 'U', characterName: 'C',
        chatId: 'chat1', characterId: 'char1',
      );
      expect(
        resolver.resolve('{{pick::a::b::c}}', pCtx),
        resolver.resolve('{{pick::a::b::c}}', pCtx),
      );
    });

    test('{{pick}} empty section matches explicit section:""', () {
      final pCtx = MacroContext(
        userName: 'U', characterName: 'C',
        chatId: 'chat1', characterId: 'char1',
      );
      expect(
        resolver.resolve('{{pick::a::b::c}}', pCtx),
        resolver.resolve('{{pick::a::b::c}}', pCtx, section: ''),
      );
    });

    test('{{pick}} differs across sections with same context and position', () {
      final pCtx = MacroContext(
        userName: 'U', characterName: 'C',
        chatId: 'chat1', characterId: 'char1',
      );
      final results = <String>{};
      for (int i = 0; i < 100; i++) {
        results.add(
          resolver.resolve('{{pick::a::b::c::d::e::f}}', pCtx, section: 's$i'),
        );
      }
      // With 6 options and 100 different sections, at least 2 distinct values
      expect(results.length, greaterThan(1));
    });

    // ── Phase 2 P0: roll ──

    test('{{roll::1d20}} produces values 1-20', () {
      for (var i = 0; i < 50; i++) {
        final result = int.parse(resolver.resolve('{{roll::1d20}}', ctx));
        expect(result, inInclusiveRange(1, 20));
      }
    });

    test('{{roll::2d6+3}} produces values 5-15', () {
      for (var i = 0; i < 50; i++) {
        final result = int.parse(resolver.resolve('{{roll::2d6+3}}', ctx));
        expect(result, inInclusiveRange(5, 15));
      }
    });

    test('{{roll::bad}} passes through', () {
      expect(resolver.resolve('{{roll::bad}}', ctx), '{{roll::bad}}');
    });

    // ── ST separator parity: single-colon + comma lists + roll shorthands ──

    test('{{random:a,b,c}} single-colon comma form picks an option', () {
      for (var i = 0; i < 20; i++) {
        final result = resolver.resolve('{{random:sunny,rainy,foggy}}', ctx);
        expect(['sunny', 'rainy', 'foggy'], contains(result));
      }
    });

    test(r'comma list supports \, escape', () {
      final result = resolver.resolve(r'{{random:a\,b}}', ctx);
      expect(result, 'a,b'); // single option containing a comma
    });

    test('{{pick:a,b,c}} single-colon form is deterministic', () {
      const pCtx = MacroContext(
        userName: 'Alex',
        characterName: 'Luna',
        chatId: 'chat-1',
        characterId: 'char-1',
      );
      final r1 = resolver.resolve('{{pick:a,b,c}}', pCtx);
      final r2 = resolver.resolve('{{pick:a,b,c}}', pCtx);
      expect(r1, r2);
      expect(['a', 'b', 'c'], contains(r1));
    });

    test('{{roll:d6}} shorthand rolls 1-6', () {
      for (var i = 0; i < 30; i++) {
        final result = int.parse(resolver.resolve('{{roll:d6}}', ctx));
        expect(result, inInclusiveRange(1, 6));
      }
    });

    test('{{roll:6}} bare-number shorthand rolls 1-6', () {
      for (var i = 0; i < 30; i++) {
        final result = int.parse(resolver.resolve('{{roll:6}}', ctx));
        expect(result, inInclusiveRange(1, 6));
      }
    });

    test('{{roll d20}} space form rolls 1-20', () {
      for (var i = 0; i < 30; i++) {
        final result = int.parse(resolver.resolve('{{roll d20}}', ctx));
        expect(result, inInclusiveRange(1, 20));
      }
    });

    test('unknown single-colon macro passes through', () {
      expect(resolver.resolve('{{setvar:mood:happy}}', ctx),
          '{{setvar:mood:happy}}');
    });

    // ── Phase 2 P0: time/date ──

    test('{{time}} matches HH:mm format', () {
      expect(resolver.resolve('{{time}}', ctx), matches(RegExp(r'^\d{2}:\d{2}$')));
    });

    test('{{date}} matches yyyy-MM-dd format', () {
      expect(
        resolver.resolve('{{date}}', ctx),
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
      );
    });

    test('{{weekday}} is a valid day name', () {
      final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      expect(days, contains(resolver.resolve('{{weekday}}', ctx)));
    });

    test('{{isotime}} matches HH:mm:ss format', () {
      expect(
        resolver.resolve('{{isotime}}', ctx),
        matches(RegExp(r'^\d{2}:\d{2}:\d{2}$')),
      );
    });

    test('{{isodate}} matches yyyy-MM-dd', () {
      expect(
        resolver.resolve('{{isodate}}', ctx),
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
      );
    });

    // ── Phase 2 P0: mixed ──

    test('escaped, unknown, and newline interact correctly', () {
      expect(
        resolver.resolve('\\{{char}} {{unknown}} {{newline}}', ctx),
        '{{char}} {{unknown}} \n',
      );
    });
  });
}
