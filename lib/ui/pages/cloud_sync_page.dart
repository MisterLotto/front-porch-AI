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

import 'dart:io';
import 'package:front_porch_ai/app_version.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/cloud_sync_service.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/backup_service.dart';
import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/services/v2_card_service.dart';
import 'package:front_porch_ai/services/cloud_providers/webdav_provider.dart';
import 'package:front_porch_ai/services/cloud_providers/google_drive_provider.dart';
import 'package:path/path.dart' as path;

class CloudSyncPage extends StatefulWidget {
  const CloudSyncPage({super.key});

  @override
  State<CloudSyncPage> createState() => _CloudSyncPageState();
}

class _CloudSyncPageState extends State<CloudSyncPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final storageService = Provider.of<StorageService>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Page header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blueAccent.shade700, Colors.cyanAccent.shade400],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.cloud_sync, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Cloud Sync',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Manage cloud sync, backups, and data recovery',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _buildCloudSyncSection(context, storageService, theme),
                const SizedBox(height: 24),
                _buildBackupSection(context, theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildCloudSyncSection(BuildContext context, StorageService storageService, ThemeData theme) {
    // Pre-release builds cannot use cloud sync to prevent database
    // version conflicts with stable releases on other devices.
    if (isPreRelease) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('☁️ Cloud Sync'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.cloud_off, size: 48, color: Colors.amber.withValues(alpha: 0.6)),
                const SizedBox(height: 12),
                Text(
                  'Cloud Sync Disabled',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'This feature is disabled due to database incompatibility '
                  'with the stable release. Cloud Sync will be re-enabled '
                  'once $stableVersionBase goes stable.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.amber,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This pre-release uses a separate database '
                          '(front_porch_beta.db) to protect your stable data.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.blueAccent,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    final syncService = Provider.of<CloudSyncService>(context);
    final isEnabled = storageService.cloudSyncEnabled;
    final provider = storageService.cloudSyncProvider;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('☁️ Cloud Sync'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enable toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_sync, color: Colors.blueAccent, size: 20),
                      const SizedBox(width: 8),
                      Text('Enable Cloud Sync', style: theme.textTheme.titleSmall),
                    ],
                  ),
                  Switch(
                    value: isEnabled,
                    onChanged: (val) async {
                      if (val) {
                        // Show alpha warning before enabling
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            title: Row(
                              children: [
                                Icon(Icons.warning_amber_rounded, color: Colors.amber.shade400, size: 24),
                                const SizedBox(width: 10),
                                const Text('Alpha Feature', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            content: const Text(
                              'Cloud Sync is currently in alpha. While functional, you may encounter '
                              'occasional issues. Your local data will not be affected.\n\n'
                              'Supported providers: Google Drive, Nextcloud (WebDAV).',
                              style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueAccent,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Enable Anyway'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          storageService.setCloudSyncEnabled(true);
                        }
                      } else {
                        storageService.setCloudSyncEnabled(false);
                      }
                    },
                  ),
                ],
              ),
              if (isEnabled) ...[
                const SizedBox(height: 12),
                // Provider dropdown
                DropdownButtonFormField<String>(
                  initialValue: provider == 'none' ? null : provider,
                  isExpanded: true,
                  hint: const Text('Select provider...'),
                  decoration: InputDecoration(
                    labelText: 'Cloud Provider',
                    filled: true,
                    fillColor: theme.scaffoldBackgroundColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'webdav', child: Text('Nextcloud (WebDAV)')),
                    DropdownMenuItem(value: 'gdrive', child: Text('Google Drive')),
                  ],
                  onChanged: (val) {
                    if (val != null) storageService.setCloudSyncProvider(val);
                  },
                ),

                // WebDAV fields
                if (provider == 'webdav') ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    initialValue: storageService.cloudSyncUrl,
                    decoration: InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'https://your-nextcloud.com/remote.php/dav/files/username',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) => storageService.setCloudSyncUrl(val.trim()),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: storageService.cloudSyncUsername,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) => storageService.setCloudSyncUsername(val.trim()),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    initialValue: storageService.cloudSyncPassword,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password / App Token',
                      filled: true,
                      fillColor: theme.scaffoldBackgroundColor,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      suffixIcon: const Icon(Icons.key, size: 18),
                    ),
                    onChanged: (val) => storageService.setCloudSyncPassword(val),
                  ),
                ],

                // Google Drive sign-in / disconnect buttons
                if (provider == 'gdrive') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: syncService.isConnected ? null : () async {
                            try {
                              final gProvider = GoogleDriveProvider();
                              await gProvider.connect({});
                              syncService.setProvider(gProvider);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('✅ Signed in to Google Drive!')),
                                );
                                setState(() {});
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('❌ Google sign-in failed: $e')),
                                );
                              }
                            }
                          },
                          icon: Icon(syncService.isConnected ? Icons.check_circle : Icons.login, size: 18),
                          label: Text(syncService.isConnected ? 'Connected' : 'Sign in with Google'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: syncService.isConnected ? Colors.green.shade700 : Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      if (syncService.isConnected) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () async {
                            await syncService.provider?.disconnect();
                            syncService.clearProvider();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Disconnected from Google Drive')),
                              );
                              setState(() {});
                            }
                          },
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Disconnect'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                // Action buttons
                if (provider != 'none') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Test connection
                            CloudStorageProvider testProvider;
                            switch (provider) {
                              case 'webdav':
                                testProvider = WebDavProvider();
                                break;
                              case 'gdrive':
                                testProvider = GoogleDriveProvider();
                                break;
                              default:
                                return;
                            }
                            try {
                              await testProvider.connect({
                                'url': storageService.cloudSyncUrl,
                                'username': storageService.cloudSyncUsername,
                                'password': storageService.cloudSyncPassword,
                              });
                              syncService.setProvider(testProvider);
                              final ok = await syncService.testConnection();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(ok ? '✅ Connection successful!' : '❌ Connection failed: ${syncService.lastError}')),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('❌ Connection failed: $e')),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.wifi_tethering, size: 18),
                          label: const Text('Test'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent.withValues(alpha: 0.8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: syncService.status == SyncStatus.syncing ? null : () async {
                            // Full sync now
                            if (!syncService.isConnected) {
                              CloudStorageProvider p;
                              switch (provider) {
                                case 'webdav':
                                  p = WebDavProvider();
                                  break;
                                case 'gdrive':
                                  p = GoogleDriveProvider();
                                  break;
                                default:
                                  return;
                              }
                              await p.connect({
                                'url': storageService.cloudSyncUrl,
                                'username': storageService.cloudSyncUsername,
                                'password': storageService.cloudSyncPassword,
                              });
                              syncService.setProvider(p);
                            }

                            final chatsPath = storageService.chatsDir.path;
                            final rootPath = storageService.rootPath ?? chatsPath;
                            final charactersPath = '$rootPath${Platform.pathSeparator}KoboldManager${Platform.pathSeparator}Characters';

                            await syncService.fullSync(chatsPath, charactersPath);
                            if (syncService.status == SyncStatus.success) {
                              await storageService.setCloudSyncLastTime(DateTime.now().toIso8601String());

                              // Reload characters so newly downloaded PNGs appear in the UI
                              final charRepo = Provider.of<CharacterRepository>(context, listen: false);
                              await charRepo.loadCharacters();

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('✅ Synced ${syncService.syncedFiles} files!')),
                                );
                              }
                            } else if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('❌ Sync error: ${syncService.lastError}')),
                              );
                            }
                          },
                          icon: syncService.status == SyncStatus.syncing
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.sync, size: 18),
                          label: Text(syncService.status == SyncStatus.syncing
                              ? 'Syncing ${(syncService.progress * 100).toInt()}%'
                              : 'Sync Now'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade700,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Browse Cloud Characters button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: syncService.status == SyncStatus.syncing
                          ? null
                          : () async {
                              final storageService = Provider.of<StorageService>(context, listen: false);
                              final rootPath = storageService.rootPath ?? storageService.chatsDir.path;
                              final charactersPath = '$rootPath${Platform.pathSeparator}KoboldManager${Platform.pathSeparator}Characters';
                              final charRepo = Provider.of<CharacterRepository>(context, listen: false);

                              // Ensure provider is connected
                              if (!syncService.isConnected) {
                                CloudStorageProvider p;
                                switch (storageService.cloudSyncProvider) {
                                  case 'webdav':
                                    p = WebDavProvider();
                                    break;
                                  case 'gdrive':
                                    p = GoogleDriveProvider();
                                    break;
                                  default:
                                    return;
                                }
                                await p.connect({
                                  'url': storageService.cloudSyncUrl,
                                  'username': storageService.cloudSyncUsername,
                                  'password': storageService.cloudSyncPassword,
                                });
                                syncService.setProvider(p);
                              }

                              if (mounted) {
                                await _showCloudCharacterBrowser(
                                  context, syncService, charRepo, charactersPath,
                                );
                              }
                            },
                      icon: const Icon(Icons.cloud_outlined, size: 16),
                      label: const Text('Browse Cloud Characters'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blueAccent,
                        side: const BorderSide(color: Colors.blueAccent, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Force Upload button (disaster recovery)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: syncService.status == SyncStatus.syncing
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E293B),
                                  title: const Row(
                                    children: [
                                      Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 28),
                                      SizedBox(width: 12),
                                      Expanded(child: Text('Force Upload?', style: TextStyle(color: Colors.white))),
                                    ],
                                  ),
                                  content: const Text(
                                    'This will overwrite the cloud database with your local copy. '
                                    'Any data on the cloud that is not on this device will be lost.\n\n'
                                    'Use this after restoring a backup to push clean data to the cloud.',
                                    style: TextStyle(color: Colors.white70, height: 1.5),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.amberAccent,
                                        foregroundColor: Colors.black87,
                                      ),
                                      child: const Text('Upload'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                try {
                                  await syncService.forceUploadDatabase();
                                  final storageService = Provider.of<StorageService>(context, listen: false);
                                  await storageService.setCloudSyncLastTime(DateTime.now().toIso8601String());
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('✅ Database uploaded to cloud')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('❌ Upload failed: $e')),
                                    );
                                  }
                                }
                              }
                            },
                      icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                      label: const Text('Force Upload Database'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.amberAccent,
                        side: const BorderSide(color: Colors.amberAccent, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Purge Cloud Data button (nuclear option)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: syncService.status == SyncStatus.syncing
                          ? null
                          : () async {
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: const Color(0xFF1E293B),
                                  title: const Row(
                                    children: [
                                      Icon(Icons.delete_forever, color: Colors.redAccent, size: 28),
                                      SizedBox(width: 12),
                                      Expanded(child: Text('Purge All Cloud Data?', style: TextStyle(color: Colors.white))),
                                    ],
                                  ),
                                  content: const Text(
                                    'This will permanently delete ALL data from the cloud:\n\n'
                                    '• Database (characters, chats, folders, sessions)\n'
                                    '• Character PNG files\n\n'
                                    'Your local data will NOT be affected. '
                                    'You can re-upload with "Force Upload" or "Sync Now" afterwards.',
                                    style: TextStyle(color: Colors.white70, height: 1.5),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Delete Everything'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirmed == true) {
                                try {
                                  await syncService.purgeCloudData();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('☁️ All cloud data deleted')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('❌ Purge failed: $e')),
                                    );
                                  }
                                }
                              }
                            },
                      icon: const Icon(Icons.delete_forever, size: 16),
                      label: const Text('Purge Cloud Data'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent, width: 1),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],

                // Status display
                if (storageService.cloudSyncLastTime.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last synced: ${_formatSyncTime(storageService.cloudSyncLastTime)}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),
                ],
                if (syncService.status == SyncStatus.error && syncService.lastError != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Error: ${syncService.lastError}',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.redAccent),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBackupSection(BuildContext context, ThemeData theme) {
    if (isPreRelease) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Database Backups'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.backup, size: 48, color: Colors.amber.withValues(alpha: 0.6)),
                const SizedBox(height: 12),
                Text(
                  'Backups Disabled',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Database backups are disabled in pre-release builds to prevent '
                  'confusion between beta and stable databases. Backups will be '
                  're-enabled once $stableVersionBase goes stable.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.amber,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Database Backups'),
        const SizedBox(height: 8),
        Text(
          'Backups are created automatically before each cloud sync. '
          'Up to ${BackupService.maxBackups} recent backups are kept.',
          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Manual backup button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final path = await BackupService.createBackup();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(
                          path != null ? 'Backup created successfully' : 'No database to back up',
                        )),
                      );
                      setState(() {}); // refresh the backup list
                    }
                  },
                  icon: const Icon(Icons.backup, size: 18),
                  label: const Text('Create Backup Now'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blueAccent,
                    side: const BorderSide(color: Colors.blueAccent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Backup list
              FutureBuilder<List<File>>(
                future: BackupService.listBackups(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    );
                  }
                  final backups = snapshot.data ?? [];
                  if (backups.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'No backups yet. Backups will be created before cloud sync runs.',
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return Column(
                    children: backups.map((backup) {
                      final stat = backup.statSync();
                      final sizeMb = (stat.size / (1024 * 1024)).toStringAsFixed(1);
                      final modified = stat.modified.toLocal();
                      final timeStr = '${modified.month}/${modified.day}/${modified.year} '
                          '${modified.hour}:${modified.minute.toString().padLeft(2, '0')}';
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.storage, size: 20, color: Colors.blueAccent),
                        title: Text(timeStr, style: theme.textTheme.bodyMedium),
                        subtitle: Text('$sizeMb MB', style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => _confirmRestore(context, backup.path),
                              child: const Text('Restore', style: TextStyle(color: Colors.amberAccent)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                              tooltip: 'Delete backup',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: const Color(0xFF1E293B),
                                    title: const Text('Delete Backup?', style: TextStyle(color: Colors.white)),
                                    content: Text(
                                      'Delete backup from $timeStr ($sizeMb MB)?\n\nThis cannot be undone.',
                                      style: const TextStyle(color: Colors.white70, height: 1.5),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true) {
                                  try {
                                    await backup.delete();
                                    if (mounted) {
                                      setState(() {});
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Backup deleted')),
                                      );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Delete failed: $e')),
                                      );
                                    }
                                  }
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _confirmRestore(BuildContext context, String backupPath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 28),
            SizedBox(width: 12),
            Text('Restore Backup?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text(
          'This will replace your current database with the backup. '
          'All changes made after this backup was created will be lost.\n\n'
          'The app will need to restart after restoring.',
          style: TextStyle(color: Colors.white70, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await BackupService.restoreBackup(backupPath);
                // Reopen the database
                await AppDatabase.instance();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup restored. Please restart the app for full effect.')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Restore failed: $e')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amberAccent,
              foregroundColor: Colors.black87,
            ),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  String _formatSyncTime(String isoTime) {
    try {
      final dt = DateTime.parse(isoTime).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inHours < 1) return '${diff.inMinutes}m ago';
      if (diff.inDays < 1) return '${diff.inHours}h ago';
      return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return isoTime;
    }
  }

  /// Show a dialog browsing ALL characters on the cloud.
  Future<void> _showCloudCharacterBrowser(
    BuildContext context,
    CloudSyncService syncService,
    CharacterRepository charRepo,
    String charactersDir,
  ) async {
    // Show a loading indicator while we fetch
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    // Fetch the list of all remote characters
    final allRemote = await syncService.listAllRemoteCharacters(charactersDir);

    if (!context.mounted) return;
    Navigator.pop(context); // dismiss loading

    if (allRemote.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No characters found on cloud.')),
        );
      }
      return;
    }

    // For characters already on device, use local path; for others, download to temp
    final localExist = <String>{};
    final needDownload = <String>[];
    for (final r in allRemote) {
      if (r.existsLocally) {
        localExist.add(r.name);
      } else {
        needDownload.add(r.name);
      }
    }

    // Show loading for temp downloads if needed
    Map<String, String> tempPreviews = {};
    if (needDownload.isNotEmpty) {
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text('Fetching ${needDownload.length} preview(s)...',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, decoration: TextDecoration.none),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      tempPreviews = await syncService.downloadCharactersToTemp(needDownload);

      if (context.mounted) Navigator.pop(context); // dismiss loading
    }

    // Build a combined map of filename → image path
    final imagePaths = <String, String>{};
    for (final r in allRemote) {
      if (r.existsLocally) {
        imagePaths[r.name] = path.join(charactersDir, r.name);
      } else if (tempPreviews.containsKey(r.name)) {
        imagePaths[r.name] = tempPreviews[r.name]!;
      }
    }

    // Extract character names
    final v2 = V2CardService();
    final charNames = <String, String>{};
    for (final entry in imagePaths.entries) {
      try {
        final card = await v2.readCard(entry.value);
        charNames[entry.key] = card?.name ?? path.basenameWithoutExtension(entry.key);
      } catch (_) {
        charNames[entry.key] = path.basenameWithoutExtension(entry.key);
      }
    }

    if (!context.mounted) return;

    // Track which remote-only characters the user wants to download
    final selected = <String>{};

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final hasDownloadable = needDownload.isNotEmpty;
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.cloud, color: Colors.blueAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Cloud Characters',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${allRemote.length} character(s) • ${localExist.length} on device • ${needDownload.length} available',
                          style: const TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 520,
                height: 420,
                child: Column(
                  children: [
                    if (hasDownloadable) ...[
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => setDialogState(() => selected.addAll(needDownload)),
                            child: const Text('Select All New', style: TextStyle(color: Colors.blueAccent, fontSize: 12)),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () => setDialogState(() => selected.clear()),
                            child: const Text('Clear', style: TextStyle(color: Colors.white38, fontSize: 12)),
                          ),
                          const Spacer(),
                          if (selected.isNotEmpty)
                            Text(
                              '${selected.length} to download',
                              style: const TextStyle(color: Colors.amberAccent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.75,
                        ),
                        itemCount: allRemote.length,
                        itemBuilder: (ctx, index) {
                          final info = allRemote[index];
                          final imgPath = imagePaths[info.name];
                          final displayName = charNames[info.name] ?? info.name;
                          final isLocal = info.existsLocally;
                          final isSelected = selected.contains(info.name);

                          return GestureDetector(
                            onTap: isLocal
                                ? null // already on device, no action
                                : () {
                                    setDialogState(() {
                                      if (isSelected) {
                                        selected.remove(info.name);
                                      } else {
                                        selected.add(info.name);
                                      }
                                    });
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isLocal
                                      ? Colors.green.withValues(alpha: 0.5)
                                      : isSelected
                                          ? Colors.blueAccent
                                          : Colors.white12,
                                  width: isSelected ? 2.5 : 1,
                                ),
                                boxShadow: isSelected
                                    ? [BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.3), blurRadius: 8)]
                                    : null,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(11),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    // Character avatar
                                    if (imgPath != null)
                                      Image.file(
                                        File(imgPath),
                                        fit: BoxFit.cover,
                                        alignment: Alignment.topCenter,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.black26,
                                          child: const Icon(Icons.person, color: Colors.white24, size: 48),
                                        ),
                                      )
                                    else
                                      Container(
                                        color: Colors.black26,
                                        child: const Icon(Icons.person, color: Colors.white24, size: 48),
                                      ),
                                    // Gradient overlay for name
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.85)],
                                          ),
                                        ),
                                        child: Text(
                                          displayName,
                                          textAlign: TextAlign.center,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    // Status badge
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isLocal
                                              ? Colors.green
                                              : isSelected
                                                  ? Colors.blueAccent
                                                  : Colors.black54,
                                        ),
                                        padding: const EdgeInsets.all(2),
                                        child: Icon(
                                          isLocal
                                              ? Icons.check
                                              : isSelected
                                                  ? Icons.check
                                                  : Icons.cloud_download_outlined,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                    // "On device" label for local characters
                                    if (isLocal)
                                      Positioned(
                                        top: 4,
                                        left: 4,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.85),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'On device',
                                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, <String>{}),
                  child: const Text('Close', style: TextStyle(color: Colors.white38)),
                ),
                if (hasDownloadable)
                  ElevatedButton.icon(
                    onPressed: selected.isEmpty
                        ? null
                        : () => Navigator.pop(ctx, selected),
                    icon: const Icon(Icons.download, size: 16),
                    label: Text('Download ${selected.length}'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.white12,
                    ),
                  ),
              ],
            );
          },
        );
      },
    );

    // Download selected characters
    if (result != null && result.isNotEmpty) {
      final dir = Directory(charactersDir);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      int copied = 0;
      for (final filename in result) {
        final tempPath = tempPreviews[filename];
        if (tempPath != null && File(tempPath).existsSync()) {
          final destPath = path.join(charactersDir, filename);
          try {
            await File(tempPath).copy(destPath);
            copied++;
          } catch (e) {
            debugPrint('Error copying character $filename: $e');
          }
        }
      }

      await charRepo.loadCharacters();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Downloaded $copied character(s)!')),
        );
      }
    }

    // Clean up temp files
    for (final tempPath in tempPreviews.values) {
      try {
        final f = File(tempPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }
}
