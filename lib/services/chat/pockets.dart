// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

/// Pockets & Wardrobe — what a character is wearing and carrying.
/// Design: docs/design/pockets-and-preferences.md Part 1.
///
/// No AI chat app keeps clothing and carried-item state straight, because
/// nothing STORES it: an outfit is a sentence of prose that scrolls out of
/// context by turn thirty, and then the character is barefoot in a scene they
/// put boots on for. This app already solves that shape of problem three times
/// over — Needs, the Journal, the story clock — the same way each time: keep a
/// real record, inject it every turn, apply deltas. This is the fourth.
///
/// Strictly session-scoped, exactly like Journal cards: a chat's pockets belong
/// to that chat and die with it. Nothing here crosses conversations.
///
/// This file is the PURE core — the item, the op grammar, and the ONE applier.
/// No I/O, no LLM, no Flutter. Everything that decides *what* happened lives in
/// the eval; everything that decides *how state changes* lives here, where it
/// can be tested without a model.
library;

/// Longest item name and condition that will be kept. Items are things, not
/// paragraphs; a condition is a phrase ("half-eaten", "rain-soaked").
const kMaxItemNameChars = 60;
const kMaxItemStateChars = 60;

/// How many items a character may have in each list. The cap protects the
/// prompt, so it trims the COLDEST end (oldest) rather than refusing new ones:
/// a character who picks up a ninth thing should be holding it, and the first
/// thing they forgot about is what falls out.
const kMaxWorn = 8;
const kMaxCarrying = 8;

/// One thing, worn or carried.
///
/// [state] is deliberately FREE TEXT and deliberately optional — "half-eaten",
/// "rain-soaked, muddy hem", "notched, needs sharpening". The maintainer asked
/// for condition; what was explicitly NOT asked for, and is a stated non-goal,
/// is an RPG stat system: no durability bars, no damage math, no per-category
/// schemas. The model narrates a sword getting notched anyway, and a phrase is
/// exactly as expressive as a story needs. A number would be less.
class PocketItem {
  final String name;
  final String state;

  const PocketItem(this.name, {this.state = ''});

  /// Trimmed, whitespace-collapsed and length-capped. Whitespace collapsing is
  /// not cosmetic: these strings are written by a model and land inside a
  /// prompt, so a newline would let an item name open what looks like a new
  /// prompt section (the same hardening preference_phrases.dart applies).
  factory PocketItem.clean(String name, {String state = ''}) => PocketItem(
    _tidy(name, kMaxItemNameChars),
    state: _tidy(state, kMaxItemStateChars),
  );

  bool get isEmpty => name.isEmpty;

  /// "iron sword (notched)" — how the item reads in a prompt and in the UI.
  String get display => state.isEmpty ? name : '$name ($state)';

  PocketItem withState(String s) =>
      PocketItem(name, state: _tidy(s, kMaxItemStateChars));

  Map<String, dynamic> toJson() => {
    'name': name,
    if (state.isNotEmpty) 'state': state,
  };

  static PocketItem? fromJson(Object? raw) {
    if (raw is String) {
      final i = PocketItem.clean(raw);
      return i.isEmpty ? null : i;
    }
    if (raw is! Map) return null;
    final i = PocketItem.clean(
      (raw['name'] ?? '').toString(),
      state: (raw['state'] ?? '').toString(),
    );
    return i.isEmpty ? null : i;
  }

  @override
  bool operator ==(Object other) =>
      other is PocketItem && other.name == name && other.state == state;

  @override
  int get hashCode => Object.hash(name, state);

  @override
  String toString() => display;
}

String _tidy(String s, int cap) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length <= cap ? t : t.substring(0, cap).trimRight();
}

/// What the eval is allowed to say happened.
enum PocketOpKind {
  wear,
  remove,
  pickup,
  drop,
  give,
  update,
  transform;

  static PocketOpKind? parse(String raw) {
    final s = raw.trim().toLowerCase();
    for (final v in PocketOpKind.values) {
      if (v.name == s) return v;
    }
    // A local model will reach for the obvious synonym; accepting a handful
    // costs nothing and is the same forgiving-floor posture the Journal's XML
    // transport takes.
    return const {
      'put_on': PocketOpKind.wear,
      'puton': PocketOpKind.wear,
      'equip': PocketOpKind.wear,
      'take_off': PocketOpKind.remove,
      'takeoff': PocketOpKind.remove,
      'unequip': PocketOpKind.remove,
      'take': PocketOpKind.pickup,
      'pick_up': PocketOpKind.pickup,
      'get': PocketOpKind.pickup,
      'discard': PocketOpKind.drop,
      'lose': PocketOpKind.drop,
      'hand': PocketOpKind.give,
      'become': PocketOpKind.transform,
      'becomes': PocketOpKind.transform,
    }[s];
  }
}

/// One reported change. [to] names the recipient of a `give`; [state] carries
/// the new condition for `update`, or what the item BECAME for `transform`.
class PocketOpReport {
  final PocketOpKind kind;
  final String item;
  final String to;
  final String state;

  const PocketOpReport({
    required this.kind,
    required this.item,
    this.to = '',
    this.state = '',
  });

  /// Forgiving parse of one eval-reported op. Returns null for anything
  /// unusable — a missing verb, an empty item — rather than throwing, because
  /// one malformed entry in a list of five must cost that entry and not the
  /// turn.
  static PocketOpReport? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final kind = PocketOpKind.parse((raw['op'] ?? '').toString());
    if (kind == null) return null;
    final item = _tidy((raw['item'] ?? '').toString(), kMaxItemNameChars);
    if (item.isEmpty) return null;
    return PocketOpReport(
      kind: kind,
      item: item,
      to: _tidy((raw['to'] ?? '').toString(), kMaxItemNameChars),
      state: _tidy((raw['state'] ?? '').toString(), kMaxItemStateChars),
    );
  }
}

/// A single character's pockets in a single chat.
class Pockets {
  final List<PocketItem> worn;
  final List<PocketItem> carrying;

  Pockets({List<PocketItem>? worn, List<PocketItem>? carrying})
    : worn = worn ?? [],
      carrying = carrying ?? [];

  bool get isEmpty => worn.isEmpty && carrying.isEmpty;

  Pockets copy() => Pockets(worn: [...worn], carrying: [...carrying]);

  Map<String, dynamic> toJson() => {
    'worn': [for (final i in worn) i.toJson()],
    'carrying': [for (final i in carrying) i.toJson()],
  };

  /// Tolerates both the rich `{name, state}` shape and the plain-string shape a
  /// card author writes by hand in `frontPorchExtensions.inventory`.
  static Pockets fromJson(Object? raw) {
    if (raw is! Map) return Pockets();
    // Capped on the way IN, not only in the applier. A card is a stranger's
    // upload: without this a hostile or careless `inventory` with hundreds of
    // entries would load whole into session state and be re-serialised every
    // turn. The applier's own cap only ever ran on ops. (Grok, 2026-08-07.)
    List<PocketItem> list(Object? v, int max) => [
      for (final e in (v is List ? v : const []).take(max))
        ?PocketItem.fromJson(e),
    ];
    return Pockets(
      worn: list(raw['worn'], kMaxWorn),
      carrying: list(raw['carrying'], kMaxCarrying),
    );
  }
}

/// Did two item names mean the same thing?
///
/// The model will not say "car keys" twice running — it says "the keys", then
/// "her car keys". Exact matching would leave a character carrying three sets
/// of keys, which is the failure that makes an inventory feature worse than no
/// inventory feature. Token overlap is the same rule the promise ledger uses to
/// decide whether a promise is the one already on file.
/// Which of [names] did the model mean by [to]?
///
/// Returns the matched name, or null when nothing matches confidently — and
/// null is a real answer, not a failure. The whole reason `give` shipped
/// without transfers was that guessing wrong puts an item in the WRONG
/// character's pocket, which is invisible and wrong rather than merely
/// incomplete. So this refuses anything it is not sure about, and the caller
/// falls back to the old behaviour: the item leaves the giver and goes nowhere.
///
/// Deliberately NOT fuzzy. Three passes, each of which can only produce one
/// answer:
///   1. exact, case-insensitive ("bob" -> "Bob")
///   2. first name, when it is unambiguous across the roster ("Bob" -> "Bob
///      Vance"); skipped entirely if two members share a first name
///   3. nothing else. Pronouns ("him"), roles ("the barkeep"), the user, and
///      anyone off-screen all resolve to null on purpose.
///
/// Substring matching is what this must never do: "Ann" would match "Joanne",
/// and a longest-common-prefix rule would hand "Sam"'s coat to "Samantha".
String? resolveRecipient(String to, List<String> names) {
  final t = to.trim().toLowerCase();
  if (t.isEmpty || names.isEmpty) return null;

  for (final n in names) {
    if (n.trim().toLowerCase() == t) return n;
  }

  // First names, only where they are unique. A roster with two Bobs gets no
  // first-name pass at all rather than an arbitrary winner.
  final firsts = <String, List<String>>{};
  for (final n in names) {
    final f = n.trim().split(RegExp(r'\s+')).first.toLowerCase();
    if (f.isNotEmpty) (firsts[f] ??= []).add(n);
  }
  final hit = firsts[t];
  if (hit != null && hit.length == 1) return hit.single;

  return null;
}

bool sameItem(String a, String b) {
  String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), '');
  final an = norm(a), bn = norm(b);
  if (an.isEmpty || bn.isEmpty) return false;
  if (an == bn) return true;

  const filler = {'a', 'an', 'the', 'her', 'his', 'their', 'my', 'your', 'of'};
  Set<String> toks(String s) =>
      s.split(' ').where((t) => t.isNotEmpty && !filler.contains(t)).toSet();
  final at = toks(an), bt = toks(bn);
  if (at.isEmpty || bt.isEmpty) return false;

  // CONTAINMENT ONLY — deliberately not a shared-token ratio.
  //
  // The first draft counted overlap and matched when shared tokens were at
  // least half the shorter name. That looked reasonable and was wrong on the
  // most ordinary case there is: "car keys" and "house keys" share "keys",
  // which is half of two, so a character could never hold both. Caught by the
  // applier tests before any of this was wired to anything.
  //
  // Containment covers what actually needs covering — "the car keys" and "her
  // car keys" reduce to the same token set, and "satchel" is contained by
  // "worn leather satchel" — while leaving genuinely different things apart.
  // A bare "keys" said while holding two kinds resolves to whichever is
  // listed first; ambiguous, but far better than inventing a third set.
  return at.containsAll(bt) || bt.containsAll(at);
}

/// THE applier. Every change to a character's pockets goes through here —
/// the eval, the sidebar's hand edits, and the card seed all end up in this one
/// function, so there is one place where "what happens when you wear something
/// you are already wearing" is decided.
///
/// Returns a human-readable receipt line per applied op ("picked up: car
/// keys"), in order, for the message chips. An op that changes nothing returns
/// nothing — a model reporting that she is still wearing the dress she was
/// already wearing should not produce a chip.
/// Apply [ops] to [p] in place and return the receipt lines for the chips.
///
/// [onTransfer] fires when a `give` names a recipient and the item was really
/// in the giver's possession — it hands over the ITEM AS IT WAS, condition and
/// all, so a rain-soaked coat arrives rain-soaked. It stays a callback rather
/// than a return value because this function owns exactly one character's
/// record; who the other side is, and whether that name resolves to anyone, is
/// the caller's business (see ChatService._runPocketsPass).
///
/// A `give` with no recipient, or with one nobody can resolve, still removes
/// the item from the giver. That is the floor and it is deliberate: the giver
/// no longer holding what she handed over is true regardless of whether the
/// app can work out who took it.
List<String> applyPocketOps(
  Pockets p,
  Iterable<PocketOpReport> ops, {
  void Function(String to, PocketItem item)? onTransfer,
}) {
  final receipts = <String>[];

  int find(List<PocketItem> list, String name) =>
      list.indexWhere((i) => sameItem(i.name, name));

  void capTo(List<PocketItem> list, int max) {
    // Trim the OLDEST, not the newest: the thing just picked up is the thing
    // the scene is about.
    while (list.length > max) {
      list.removeAt(0);
    }
  }

  for (final op in ops) {
    switch (op.kind) {
      case PocketOpKind.wear:
        final alreadyWorn = find(p.worn, op.item);
        if (alreadyWorn != -1) {
          // Already on — but the model may be reporting a CHANGE to it ("her
          // dress is now torn"), and dropping that on the floor was silent
          // data loss (Grok, 2026-08-07). Nothing to say without a state.
          if (op.state.isNotEmpty && p.worn[alreadyWorn].state != op.state) {
            p.worn[alreadyWorn] = p.worn[alreadyWorn].withState(op.state);
            receipts.add('${op.item}: ${op.state}');
          }
          break;
        }
        final c = find(p.carrying, op.item);
        final item = c != -1
            ? p.carrying.removeAt(c)
            : PocketItem.clean(op.item, state: op.state);
        p.worn.add(op.state.isEmpty ? item : item.withState(op.state));
        capTo(p.worn, kMaxWorn);
        receipts.add('put on: ${op.item}');

      case PocketOpKind.remove:
        final w = find(p.worn, op.item);
        if (w == -1) break;
        // Taking something off does not make it vanish — she is holding it.
        p.carrying.add(p.worn.removeAt(w));
        capTo(p.carrying, kMaxCarrying);
        receipts.add('took off: ${op.item}');

      case PocketOpKind.pickup:
        if (find(p.carrying, op.item) != -1 || find(p.worn, op.item) != -1) {
          break;
        }
        p.carrying.add(PocketItem.clean(op.item, state: op.state));
        capTo(p.carrying, kMaxCarrying);
        receipts.add('picked up: ${op.item}');

      // `give` used to be half a transfer: the item left the giver and reached
      // nobody, so Alice handing Bob the keys left Bob's record untouched. The
      // reason was real — resolving a free-text name the model chose to a
      // member record, and putting the keys in the WRONG character's pocket, is
      // a worse failure than not moving them, because it is invisible AND
      // wrong. The fix is not to guess better; it is to only accept a name the
      // caller can match to a real member, and otherwise keep the old floor.
      case PocketOpKind.drop:
      case PocketOpKind.give:
        final c = find(p.carrying, op.item);
        final w = find(p.worn, op.item);
        if (c == -1 && w == -1) break;
        // Take the item as it stands, so its condition travels with it.
        final taken = c != -1 ? p.carrying.removeAt(c) : p.worn.removeAt(w);
        if (op.kind == PocketOpKind.give && op.to.isNotEmpty) {
          onTransfer?.call(op.to, taken);
        }
        receipts.add(
          op.kind == PocketOpKind.give && op.to.isNotEmpty
              ? 'gave ${op.item} to ${op.to}'
              : 'dropped: ${op.item}',
        );

      case PocketOpKind.update:
        if (op.state.isEmpty) break;
        for (final list in [p.worn, p.carrying]) {
          final i = find(list, op.item);
          if (i == -1) continue;
          if (list[i].state == op.state) break;
          list[i] = list[i].withState(op.state);
          receipts.add('${op.item}: ${op.state}');
          break;
        }

      case PocketOpKind.transform:
        // A candy bar becomes a wrapper. The item is REPLACED, not annotated,
        // because what she is holding is genuinely a different thing now.
        if (op.state.isEmpty) break;
        for (final list in [p.worn, p.carrying]) {
          final i = find(list, op.item);
          if (i == -1) continue;
          list[i] = PocketItem.clean(op.state);
          receipts.add('${op.item} → ${op.state}');
          break;
        }
    }
  }
  return receipts;
}
