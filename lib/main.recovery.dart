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

/// DB health check, corrupt-DB restore overlay, the DB-rebind helper, and
/// the beta-first-launch stable-DB import — extracted verbatim from
/// `_MyAppState` (god-file elimination, Tranche C). All intra-file callers
/// (`_buildCorruptionOverlay` → `_restoreBackup` → `_rebindAfterDatabaseSwap`,
/// `_showStableDbImportIfNeeded` → `_rebindAfterDatabaseSwap`) live in this
/// SAME extension, so every call below is unqualified and resolves via
/// implicit `this`.
extension _MainDbRecovery on _MyAppState {
  // ── DB Health Check ─────────────────────────────────────────────────

  Future<void> _checkDbHealth() async {
    // The full quick_check runs HERE, after first paint (see main() — only a
    // cheap open-probe runs before the window shows). A corrupt DB now
    // surfaces its restore overlay a moment after launch instead of holding
    // the whole window hostage while the file is validated.
    if (_dbHealthy) {
      try {
        final db = await AppDatabase.instance();
        _dbHealthy = await db.integrityCheck();
      } catch (_) {
        _dbHealthy = false;
      }
    }
    if (_dbHealthy) return;

    // DB is corrupt — load available backups and show overlay
    final backups = await BackupService.listBackups();
    if (mounted) {
      _rebuild(() {
        _isDbCorrupt = true;
        _availableBackups = backups;
      });
    }
  }

  Widget _buildCorruptionOverlay() {
    return Positioned.fill(
      child: Material(
        color: const Color(0xFF0F172A),
        child: Center(
          child: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red.shade700, Colors.orange.shade600],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Database Issue Detected',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'An integrity check found possible corruption.\n'
                  'This can happen after a power failure or crash.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                if (_availableBackups.isNotEmpty) ...[
                  Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Backups',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _availableBackups.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final backup = _availableBackups[index];
                              final stat = backup.statSync();
                              final age = DateTime.now().difference(
                                stat.modified,
                              );
                              final sizeKb = (stat.size / 1024).toStringAsFixed(
                                0,
                              );
                              String ageStr;
                              if (age.inDays > 0) {
                                ageStr = '${age.inDays}d ago';
                              } else if (age.inHours > 0) {
                                ageStr = '${age.inHours}h ago';
                              } else {
                                ageStr = '${age.inMinutes}m ago';
                              }
                              return InkWell(
                                onTap: () => _restoreBackup(backup),
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.restore,
                                        size: 18,
                                        color: AppColors.porchAmber,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          ageStr,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        '$sizeKb KB',
                                        style: TextStyle(
                                          color: Colors.white.withValues(
                                            alpha: 0.4,
                                          ),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.orange.shade300,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No backups available to restore from.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Continue anyway
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      if (mounted) _rebuild(() => _isDbCorrupt = false);
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: Colors.white.withValues(alpha: 0.6),
                    ),
                    child: const Text('Continue Without Restoring'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _restoreBackup(File backup) async {
    if (mounted) {
      _rebuild(() {
        _isDbCorrupt = false;
        _isMigrating = true;
        _migrationStep = 'Restoring backup...';
        _migrationCurrent = 1;
        _migrationTotal = 2;
      });
    }

    try {
      await BackupService.restoreBackup(backup.path);

      if (mounted) {
        _rebuild(() {
          _migrationStep = 'Reopening database...';
          _migrationCurrent = 2;
        });
      }

      // Re-open AND rebind: restoreBackup closed the old AppDatabase, but every
      // repository/service captured that instance at startup. Without the same
      // rebind+reload the import flow uses, the app dismisses this overlay and
      // then throws "database was closed" on every action until a restart.
      // No image cleanup here — this snapshot predates any character added
      // since it was taken, and their portraits are not junk.
      final rebound = await _rebindAfterDatabaseSwap();

      if (mounted) {
        if (rebound) {
          _rebuild(() => _isMigrating = false);
        } else {
          // The backup IS safely on disk — only the live rewiring failed.
          // Never dismiss as success: every DB action would fail confusingly.
          _rebuild(() {
            _migrationStep =
                'Backup restored. Please close and reopen Front Porch AI '
                'to finish.';
          });
        }
      }

      debugPrint('[DB] Backup restored successfully from: ${backup.path}');
    } catch (e) {
      debugPrint('[DB] Backup restore failed: $e');
      // The old DB may already be closed — dismissing the overlay would leave
      // a half-dead app that looks fine. Keep it up with an honest message.
      if (mounted) {
        _rebuild(() {
          _migrationStep =
              'Restore failed. Please close and reopen Front Porch AI, '
              'then try another backup.';
        });
      }
    }
  }

  /// Rebinds every DB-holding service to a fresh AppDatabase instance, reloads
  /// them, and re-checks the file's health. Returns false when the rebind could
  /// not run/complete — callers that just closed the old instance (import,
  /// restore) must treat false as "the app needs a restart", not as success.
  ///
  /// [cleanOrphanedImages] must stay false for restores: an older snapshot
  /// legitimately lacks characters created since it was taken, and the cleanup
  /// would delete their portraits for good. See [reopenAndRebindDatabase].
  Future<bool> _rebindAfterDatabaseSwap({
    bool cleanOrphanedImages = false,
  }) async {
    if (!mounted) return false;

    final newDb = await reopenAndRebindDatabase(
      context,
      cleanOrphanedImages: cleanOrphanedImages,
    );
    if (newDb == null) return false;

    try {
      _dbHealthy = await newDb.integrityCheck();
    } catch (e) {
      debugPrint('[DB] Integrity check after database swap failed: $e');
      return false;
    }
    return true;
  }

  /// Show the stable DB import dialog on first beta launch.
  ///
  /// Offered when a stable DB exists and this beta install's library is still
  /// EMPTY. It deliberately does NOT use `StableDbImportDialog.shouldShow()`,
  /// which asks whether the beta `.db` file is absent: `main()` opens — and so
  /// creates — the beta database before the first frame (`_openDatabaseGuarded`
  /// even runs a `SELECT 1` probe to force it open), so by the time this
  /// post-first-frame callback runs the file ALWAYS exists and the offer could
  /// never be made. Emptiness is the honest question, and it additionally
  /// refuses to overwrite a beta library the user has already built up.
  ///
  /// If the user chooses Import, the stable DB replaces the freshly-created
  /// beta DB and all repositories are reloaded with the new data.
  Future<void> _showStableDbImportIfNeeded() async {
    if (!isPreRelease) return;

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('beta_stable_import_shown') ?? false) return;

    final stablePath = await StableDbImportDialog.stableDbPath();
    if (stablePath == null) return;

    // The dialog's path helpers assume the default documents-dir layout, so
    // the source it hands us is only ever the default stable location. Refuse
    // to act if startup actually opened the beta DB somewhere else (a moved
    // beta storage root): copying onto the default path would leave a stray
    // file the rebind never opens, and the user would be told nothing.
    final betaDbPath = p.join(
      (await getApplicationDocumentsDirectory()).path,
      'FrontPorchAI-Beta',
      'KoboldManager',
      'front_porch_beta.db',
    );
    final db = AppDatabase.current;
    if (db == null || AppDatabase.dbFilePath != betaDbPath) return;
    if (!await db.hasNoUserContent()) return;
    if (!mounted) return;

    // Show the dialog — it's modal and blocks further initialization
    await StableDbImportDialog.show(context);

    // Import unless the user chose Skip (the dialog writes both prefs).
    if (prefs.getBool('beta_stable_import_skipped') ?? false) return;

    try {
      // Same order the backup restore uses: close the live handle first, then
      // replace the file, then clear the stale WAL/SHM sidecars that belong to
      // the database we just replaced.
      await AppDatabase.closeAndReset();
      await File(stablePath).copy(betaDbPath);
      for (final sidecar in ['$betaDbPath-wal', '$betaDbPath-shm']) {
        try {
          await File(sidecar).delete();
        } catch (_) {}
      }
      debugPrint('[DB] Pre-release build — imported stable DB to beta DB');
    } catch (e) {
      // The copy failed; the beta DB is still whatever was there. Fall through
      // to the rebind so the app reopens a database instead of running on the
      // closed handle.
      debugPrint('[DB] Stable DB import failed (non-fatal): $e');
    }

    // Reinitialize the database and reload all repositories. The imported DB
    // is the new source of truth, so unreferenced portraits really are junk.
    await _rebindAfterDatabaseSwap(cleanOrphanedImages: true);
  }
}
