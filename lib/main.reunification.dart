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

part of 'main.dart';

/// The v0.8→v0.9.0 beta+stable database merge ("reunification") flow and its
/// progress/import-choice overlay, extracted verbatim from `_MyAppState`
/// (god-file elimination, Tranche C).
extension _MainReunification on _MyAppState {
  // ── Reunification ──────────────────────────────────────────────────

  Future<void> _runReunificationIfNeeded() async {
    final dbDir = AppDatabase.dbDirPath;
    if (dbDir == null) return;
    if (await DbReunificationService.isComplete()) return;

    // Check if the stable backup exists (created by database.dart during promoteBetaDb)
    final stableBackupExists = File(
      '$dbDir/front_porch.db.pre-0.9.0-backup',
    ).existsSync();
    if (!stableBackupExists) return;

    _rebuild(() {
      _isReunifying = true;
      _reunifyStep = 'Backing up your databases...';
      _reunifyCurrent = 1;
    });

    try {
      // Step 1: Backups (already done in database.dart, but show the step)
      await Future.wait([
        Future.value(), // backups already created
        Future.delayed(const Duration(seconds: 3)),
      ]);

      // Step 2: Preparing data
      if (mounted) {
        _rebuild(() {
          _reunifyStep = 'Preparing your data...';
          _reunifyCurrent = 2;
        });
      }
      final db = liveDatabase(context);
      await Future.wait([
        BackupService.purgeAllBackups(), // purge old v1/v2 schema backups
        db.purgeDeletedRows(), // hard-delete soft-deleted bloat + VACUUM
        Future.delayed(const Duration(seconds: 3)),
      ]);

      // Step 3: Scanning for unique data
      if (mounted) {
        _rebuild(() {
          _reunifyStep = 'Scanning for unique data...';
          _reunifyCurrent = 3;
        });
      }

      late final ReunificationDiff diff;
      await Future.wait([
        DbReunificationService.diffStableOnly(db, dbDir).then((d) => diff = d),
        Future.delayed(const Duration(seconds: 3)),
      ]);

      if (diff.isEmpty) {
        // Nothing to import — show success and finish
        if (mounted) {
          _rebuild(() {
            _reunifyStep = 'All data accounted for ✅';
            _reunifyCurrent = 5;
          });
        }
        await Future.delayed(const Duration(seconds: 3));
        await DbReunificationService.markComplete();
        if (mounted) _rebuild(() => _isReunifying = false);
        return;
      }

      // Step 4: Show import dialog
      if (mounted) {
        _rebuild(() {
          _reunifyStep = 'Found unique data in your stable install';
          _reunifyCurrent = 4;
        });
      }

      // Build the description of what was found
      final items = <String>[];
      if (diff.characters.isNotEmpty) {
        final names = diff.characters.map((c) => c.name).join(', ');
        final sessions = diff.characters.fold<int>(
          0,
          (sum, c) => sum + c.sessionCount,
        );
        items.add('${diff.characters.length} character(s): $names');
        if (sessions > 0) items.add('$sessions chat session(s)');
      }
      if (diff.groups.isNotEmpty) {
        items.add('${diff.groups.length} group(s): ${diff.groups.join(', ')}');
      }
      if (diff.personas.isNotEmpty) {
        items.add(
          '${diff.personas.length} persona(s): ${diff.personas.join(', ')}',
        );
      }
      if (diff.worlds.isNotEmpty) {
        items.add('${diff.worlds.length} world(s): ${diff.worlds.join(', ')}');
      }

      // Show inline import choice inside the overlay (not showDialog)
      final completer = Completer<bool>();
      if (mounted) {
        _rebuild(() {
          _importItems = items;
          _importChoiceCompleter = completer;
        });
      }
      final shouldImport = await completer.future;

      // Step 5: Import or finish
      // Clear the choice UI first
      if (mounted) {
        _rebuild(() {
          _importChoiceCompleter = null;
          _importItems = [];
        });
      }

      if (shouldImport) {
        if (mounted) {
          final totalItems = diff.totalItems;
          _rebuild(() {
            _reunifyStep = 'Importing $totalItems item(s)...';
            _reunifyCurrent = 5;
          });
        }

        await Future.wait([
          DbReunificationService.importStableItems(db, dbDir, diff),
          Future.delayed(const Duration(seconds: 3)),
        ]);

        // Reload all repositories
        if (mounted) {
          final charRepo = Provider.of<CharacterRepository>(
            context,
            listen: false,
          );
          final folderService = Provider.of<FolderService>(
            context,
            listen: false,
          );
          final personaService = Provider.of<UserPersonaService>(
            context,
            listen: false,
          );
          final groupRepo = Provider.of<GroupChatRepository>(
            context,
            listen: false,
          );
          final worldRepo = Provider.of<WorldRepository>(
            context,
            listen: false,
          );
          final chatService = Provider.of<ChatService>(context, listen: false);
          await charRepo.loadCharacters();
          await charRepo.cleanOrphanedPngs();
          await folderService.reload();
          await personaService.reload();
          await groupRepo.reload();
          await worldRepo.loadWorlds();
          await chatService.reloadCurrentSession();
        }

        if (mounted) {
          _rebuild(() => _reunifyStep = 'Import complete ✅');
        }
        await Future.delayed(const Duration(seconds: 3));
      } else {
        if (mounted) {
          _rebuild(() {
            _reunifyStep = 'Finishing up...';
            _reunifyCurrent = 5;
          });
        }
        await Future.delayed(const Duration(seconds: 2));
      }

      await DbReunificationService.markComplete();
    } catch (e) {
      debugPrint('[Reunification] Error: $e');
      // Mark complete anyway to avoid infinite retry loops
      await DbReunificationService.markComplete();
    } finally {
      if (mounted) _rebuild(() => _isReunifying = false);
    }
  }

  Widget _buildReunificationOverlay() {
    return Positioned.fill(
      child: Material(
        color: const Color(0xFF0F172A),
        child: Center(
          child: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // App icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.porchAmberLight,
                        AppColors.porchAmber,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.formMasterAccent.withValues(alpha: 0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.merge_type_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Upgrading to v0.9.0',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Merging your beta and stable databases\ninto a single unified database.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                // Inline import choice (shown at step 4)
                if (_importChoiceCompleter != null) ...[
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.formMasterAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Import Stable Data?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'We found data in your stable v0.8 install that isn\'t in your v0.9 database:',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._importItems.map(
                          (item) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '• ',
                                  style: TextStyle(
                                    color: AppColors.formMasterAccent,
                                    fontSize: 13,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    item,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your v0.9 data is safe regardless of your choice.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 11,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () =>
                                  _importChoiceCompleter?.complete(false),
                              child: const Text(
                                'Skip',
                                style: TextStyle(color: Colors.white38),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _importChoiceCompleter?.complete(true),
                              icon: const Icon(
                                Icons.download_rounded,
                                size: 18,
                              ),
                              label: const Text('Import'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.formMasterAccent,
                                foregroundColor: AppColors.onChaosAccent,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Step name
                  Text(
                    _reunifyStep,
                    style: TextStyle(
                      color: AppColors.porchAmber,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Progress bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: _reunifyTotal > 0
                          ? _reunifyCurrent / _reunifyTotal
                          : null,
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.formMasterAccent,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Step counter
                  Text(
                    'Step $_reunifyCurrent of $_reunifyTotal',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
