// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Invert one deleted turn's unique item moves on live kits. Tail-delete
// still uses the full before-stamp; a buried stamp is not an inverse.

import 'pockets.dart';

enum _Slot { worn, carrying, setAside }

class _Loc {
  const _Loc(this.charId, this.slot, this.item);
  final String charId;
  final _Slot slot;
  final PocketItem item;
}

({_Slot slot, PocketItem item})? _locate(Pockets p, String name) {
  for (final i in p.worn) {
    if (sameItem(i.name, name)) return (slot: _Slot.worn, item: i);
  }
  for (final i in p.carrying) {
    if (sameItem(i.name, name)) return (slot: _Slot.carrying, item: i);
  }
  for (final e in p.setAside) {
    if (sameItem(e.item.name, name)) {
      return (slot: _Slot.setAside, item: e.item);
    }
  }
  return null;
}

_Loc? _owner(Map<String, Pockets> kits, String name) {
  for (final e in kits.entries) {
    final hit = _locate(e.value, name);
    if (hit != null) return _Loc(e.key, hit.slot, hit.item);
  }
  return null;
}

void _pull(Pockets p, String name) {
  p.worn.removeWhere((i) => sameItem(i.name, name));
  p.carrying.removeWhere((i) => sameItem(i.name, name));
  p.setAside.removeWhere((e) => sameItem(e.item.name, name));
}

void _place(Pockets p, PocketItem item, _Slot slot) {
  _pull(p, item.name);
  switch (slot) {
    case _Slot.worn:
      p.worn.add(item);
      while (p.worn.length > kMaxWorn) {
        p.worn.removeAt(0);
      }
    case _Slot.carrying:
      p.carrying.add(item);
      while (p.carrying.length > kMaxCarrying) {
        p.carrying.removeAt(0);
      }
    case _Slot.setAside:
      p.setAside.add(SetAsideItem(item, clothing: false));
      while (p.setAside.length > kMaxSetAside) {
        p.setAside.removeAt(0);
      }
  }
}

void _collectNames(Pockets p, List<String> into) {
  void add(String n) {
    if (n.isEmpty) return;
    if (into.any((s) => sameItem(s, n))) return;
    into.add(n);
  }

  for (final i in p.worn) {
    add(i.name);
  }
  for (final i in p.carrying) {
    add(i.name);
  }
  for (final e in p.setAside) {
    add(e.item.name);
  }
}

/// Shared `pockets_before` can exist on a later no-op swipe that never
/// wrote swipe-scoped `pockets_after`. [Pockets.fromJson] treats null as
/// empty, which invert would read as "everything in before left the world".
Pockets? pocketsStamp(Object? raw) => raw is Map ? Pockets.fromJson(raw) : null;

/// Mutates [live]. Unique items whose owner or section changed on the
/// deleted turn are pulled off whoever holds them now and put back where
/// they were before that turn. Later ops on other items are kept.
///
/// [speakerAfter] null means the active swipe has no after-stamp — unknown,
/// not empty. No-op so a nod-over-a-give cannot steal later holdings.
void invertDeletedPocketTurn({
  required String speakerId,
  required Pockets speakerBefore,
  required Pockets? speakerAfter,
  required Map<String, Pockets> othersBefore,
  required Map<String, Pockets> othersAfter,
  required Map<String, Pockets> live,
}) {
  if (speakerAfter == null) return;
  final before = <String, Pockets>{speakerId: speakerBefore, ...othersBefore};
  final after = <String, Pockets>{speakerId: speakerAfter, ...othersAfter};
  final names = <String>[];
  for (final p in [...before.values, ...after.values]) {
    _collectNames(p, names);
  }
  for (final name in names) {
    final b = _owner(before, name);
    final a = _owner(after, name);
    if (b != null && a != null && b.charId == a.charId && b.slot == a.slot) {
      continue;
    }
    for (final kit in live.values) {
      _pull(kit, name);
    }
    if (b != null) {
      _place(live[b.charId] ??= Pockets(), b.item, b.slot);
    }
  }
}
