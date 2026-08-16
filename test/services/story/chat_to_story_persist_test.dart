// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// CHAT-TO-STORY MUST ACTUALLY PERSIST (1.3 sweep, 2026-08-15).
//
// buildChatStoryProject returns a fresh StoryProject with dbId == null, and
// StoryRepository.saveProject used to open with `if (project.dbId == null)
// return;` — a silent no-op. The desktop dialog then crashed on
// `project.dbId!` while pushing the dashboard route, and the web facade twin
// (chat_tools_facade.toStory) returned `{'id': null}` with no row inserted.
// The entire "Turn this chat into a story…" feature was dead on both
// surfaces, and the only existing test exercised the pure builder.
//
// saveProject now INSERTS a never-persisted project (assigning its dbId and
// registering it in the in-memory list) and keeps the plain update path for
// projects that already have one.

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/database/database.dart' hide World;
import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/story/story.dart';
import 'package:front_porch_ai/services/story_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saveProject inserts a fresh chat-to-story project and assigns dbId',
      () async {
    final db = AppDatabase.forTesting(sameIsolate: true);
    addTearDown(db.close);
    final repo = StoryRepository(db);

    final project = buildChatStoryProject(
      sessionId: 'session-1',
      character: CharacterCard(name: 'Senjumaru'),
      characterId: 'Senjumaru_123',
      userName: 'Linus',
      recap: 'Where we are',
      faithful: true,
      length: 'Novella',
      pov: 'Third Person Limited',
    );
    expect(project.dbId, isNull, reason: 'builder must not fake a dbId');

    await repo.saveProject(project);

    expect(project.dbId, isNotNull,
        reason: 'a never-persisted project must be inserted, not dropped — '
            'the dialog does StoryDashboardPage(projectId: project.dbId!)');
    final row = await db.getStoryProjectById(project.dbId!);
    expect(row, isNotNull, reason: 'the row must really be in the DB');
    expect(repo.projects.any((p) => p.dbId == project.dbId), isTrue,
        reason: 'the dashboard resolves projects from the in-memory list');
  });

  test('saveProject still updates (not duplicates) an existing project',
      () async {
    final db = AppDatabase.forTesting(sameIsolate: true);
    addTearDown(db.close);
    final repo = StoryRepository(db);

    final created = await repo.createProject(title: 'Original');
    created.title = 'Renamed';
    await repo.saveProject(created);

    final all = await db.getAllStoryProjects();
    expect(all.length, 1, reason: 'update path must not insert a second row');
    expect(all.single.title, 'Renamed');
  });
}
