// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

/// A creator reference as it appears on a card (`@handle`).
class StoopCreatorRef {
  final String id;
  final String displayName;
  const StoopCreatorRef({required this.id, required this.displayName});

  factory StoopCreatorRef.fromJson(Map<String, dynamic> j) => StoopCreatorRef(
    id: j['id'] as String? ?? '',
    displayName: j['displayName'] as String? ?? '',
  );
}

/// A card as it appears in browse grids, carousels, and creator profiles.
class StoopCard {
  final String id;
  final String name;
  final String summary;

  /// `SOLO` or `GROUP`.
  final String type;
  final bool nsfw;

  /// Net vote score (up minus down).
  final int score;
  final int downloadCount;
  final bool modPick;
  final StoopCreatorRef? creator;
  final String? primaryAssetId;

  const StoopCard({
    required this.id,
    required this.name,
    required this.summary,
    required this.type,
    required this.nsfw,
    required this.score,
    required this.downloadCount,
    required this.modPick,
    required this.creator,
    required this.primaryAssetId,
  });

  bool get isGroup => type == 'GROUP';

  factory StoopCard.fromJson(Map<String, dynamic> j) => StoopCard(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    summary: j['summary'] as String? ?? '',
    type: j['type'] as String? ?? 'SOLO',
    nsfw: j['nsfw'] as bool? ?? false,
    score: (j['score'] as num?)?.toInt() ?? 0,
    downloadCount: (j['downloadCount'] as num?)?.toInt() ?? 0,
    modPick: j['modPick'] as bool? ?? false,
    creator: j['creator'] is Map<String, dynamic>
        ? StoopCreatorRef.fromJson(j['creator'] as Map<String, dynamic>)
        : null,
    primaryAssetId: j['primaryAssetId'] as String?,
  );
}

/// A page of browse results.
class StoopBrowsePage {
  final int total;
  final int page;
  final List<StoopCard> items;
  const StoopBrowsePage({
    required this.total,
    required this.page,
    required this.items,
  });

  factory StoopBrowsePage.fromJson(Map<String, dynamic> j) => StoopBrowsePage(
    total: (j['total'] as num?)?.toInt() ?? 0,
    page: (j['page'] as num?)?.toInt() ?? 0,
    items: ((j['items'] as List?) ?? const [])
        .map((e) => StoopCard.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

/// The full card detail — everything the card ships with, for the detail page.
class StoopCardDetail {
  final String id;
  final String name;
  final String summary;
  final String type;
  final bool nsfw;
  final int score;
  final int downloadCount;
  final int version;
  final StoopCreatorRef? creator;

  /// The V2/V2.5 card payload (description, personality, scenario, first_mes,
  /// alternate_greetings, mes_example, character_book, etc.).
  final Map<String, dynamic> card;
  final List<String> tags;
  final String? primaryAssetId;

  /// The caller's current vote: 1, -1, or 0.
  final int myVote;

  const StoopCardDetail({
    required this.id,
    required this.name,
    required this.summary,
    required this.type,
    required this.nsfw,
    required this.score,
    required this.downloadCount,
    required this.version,
    required this.creator,
    required this.card,
    required this.tags,
    required this.primaryAssetId,
    required this.myVote,
  });

  bool get isGroup => type == 'GROUP';

  factory StoopCardDetail.fromJson(Map<String, dynamic> j) => StoopCardDetail(
    id: j['id'] as String? ?? '',
    name: j['name'] as String? ?? '',
    summary: j['summary'] as String? ?? '',
    type: j['type'] as String? ?? 'SOLO',
    nsfw: j['nsfw'] as bool? ?? false,
    score: (j['score'] as num?)?.toInt() ?? 0,
    downloadCount: (j['downloadCount'] as num?)?.toInt() ?? 0,
    version: (j['version'] as num?)?.toInt() ?? 1,
    creator: j['creator'] is Map<String, dynamic>
        ? StoopCreatorRef.fromJson(j['creator'] as Map<String, dynamic>)
        : null,
    card: (j['card'] as Map<String, dynamic>?) ?? const {},
    tags: ((j['tags'] as List?) ?? const []).map((e) => e.toString()).toList(),
    primaryAssetId: j['primaryAssetId'] as String?,
    myVote: (j['myVote'] as num?)?.toInt() ?? 0,
  );
}
