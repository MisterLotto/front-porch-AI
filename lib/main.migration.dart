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

/// The v0.9.0-era legacy-JSON → Drift data migration and its progress
/// overlay, extracted verbatim from `_MyAppState` (god-file elimination,
/// Tranche C).
extension _MainMigration on _MyAppState {
  // ── Data Migration ──────────────────────────────────────────────────

  Future<void> _runMigrationIfNeeded() async {
    final needsMigration = Provider.of<bool>(context, listen: false);
    if (!needsMigration) return;

    _rebuild(() => _isMigrating = true);

    final db = liveDatabase(context);
    final migration = DataMigrationService(db);
    try {
      await migration.migrate(
        onProgress: (step, current, total) {
          if (mounted) {
            _rebuild(() {
              _migrationStep = step;
              _migrationCurrent = current;
              _migrationTotal = total;
            });
          }
          debugPrint('DB Migration [$current/$total]: $step');
        },
      );
    } catch (e) {
      // A migration throw must NOT leave _isMigrating true forever (a
      // full-screen overlay = unusable app) and must NOT re-run every launch
      // (each retry re-imports characters, worsening the very duplicate-path
      // condition that can cause the throw). Log, drop the overlay, and let
      // the app open on whatever migrated so far — the legacy JSON is left in
      // place, so a fixed future build can retry.
      debugPrint('[DB Migration] Failed — continuing without it: $e');
    }

    if (mounted) {
      _rebuild(() => _isMigrating = false);
    }
  }

  Widget _buildMigrationOverlay() {
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
                      colors: [AppColors.porchAmberLight, AppColors.porchAmber],
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
                    Icons.storage_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'Migrating Your Data',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This only happens once — your data is being\nupgraded to a faster database format.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                // Step name
                Text(
                  _migrationStep,
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
                    value: _migrationTotal > 0
                        ? _migrationCurrent / _migrationTotal
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
                  'Step $_migrationCurrent of $_migrationTotal',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
