
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';

import 'package:window_manager/window_manager.dart';
import 'package:front_porch_ai/providers/app_state.dart';
import 'package:front_porch_ai/ui/layout/main_layout.dart'; // Keep original import for MainLayout
import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/services/open_router_service.dart';
import 'package:front_porch_ai/services/llm_provider.dart';
import 'package:front_porch_ai/services/character_repository.dart';
import 'package:front_porch_ai/services/backend_manager.dart';
import 'package:front_porch_ai/services/model_manager.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/hardware_service.dart';
import 'package:front_porch_ai/services/chat_service.dart';
import 'package:front_porch_ai/services/user_persona_service.dart';
import 'package:front_porch_ai/services/world_repository.dart';
import 'package:front_porch_ai/services/setup_service.dart';
import 'package:front_porch_ai/services/folder_service.dart';
import 'package:front_porch_ai/services/update_service.dart';
import 'package:front_porch_ai/services/group_chat_repository.dart';
import 'package:front_porch_ai/services/voice_manager.dart';
import 'package:front_porch_ai/services/tts_service.dart';
import 'package:front_porch_ai/services/cloud_sync_service.dart';
import 'package:front_porch_ai/services/cloud_providers/webdav_provider.dart';
import 'package:front_porch_ai/services/cloud_providers/google_drive_provider.dart';
import 'package:front_porch_ai/database/database.dart';
import 'package:front_porch_ai/database/data_migration_service.dart';

import 'package:front_porch_ai/ui/widgets/setup_overlay.dart';
import 'package:front_porch_ai/ui/dialogs/update_dialog.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  
  // Initialize database
  final db = await AppDatabase.instance();
  final needsMigration = !await DataMigrationService.isMigrated();
  
  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setPreventClose(true);
  });
  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: db),
        Provider<bool>.value(value: needsMigration), // migration flag
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => StorageService()),
        ChangeNotifierProxyProvider<StorageService, KoboldService>(
          create: (context) => KoboldService(Provider.of<StorageService>(context, listen: false)),
          update: (context, storage, previous) => previous ?? KoboldService(storage),
        ),
        ChangeNotifierProvider(create: (_) => HardwareService()),
        ChangeNotifierProvider(create: (context) => CharacterRepository(db)),
        ChangeNotifierProvider(create: (context) => UserPersonaService(db)),
        ChangeNotifierProvider(create: (context) => FolderService(db)),
        ChangeNotifierProxyProvider<StorageService, WorldRepository>(
          create: (context) => WorldRepository(Provider.of<StorageService>(context, listen: false), db),
          update: (context, storage, previous) => previous ?? WorldRepository(storage, db),
        ),
        ChangeNotifierProxyProvider<StorageService, BackendManager>(
          create: (context) => BackendManager(Provider.of<StorageService>(context, listen: false)),
          update: (context, storage, previous) => previous ?? BackendManager(storage),
        ),
        ChangeNotifierProxyProvider<StorageService, ModelManager>(
          create: (context) => ModelManager(Provider.of<StorageService>(context, listen: false)),
          update: (context, storage, previous) => previous ?? ModelManager(storage),
        ),
        ChangeNotifierProvider(create: (_) => OpenRouterService()),
        ChangeNotifierProxyProvider3<KoboldService, OpenRouterService, StorageService, LLMProvider>(
          create: (context) => LLMProvider(
            Provider.of<KoboldService>(context, listen: false),
            Provider.of<OpenRouterService>(context, listen: false),
            Provider.of<StorageService>(context, listen: false),
          ),
          update: (context, kobold, openRouter, storage, previous) =>
              previous ?? LLMProvider(kobold, openRouter, storage),
        ),
        ChangeNotifierProxyProvider4<KoboldService, UserPersonaService, StorageService, WorldRepository, ChatService>(
          create: (context) {
            final chatService = ChatService(
              Provider.of<KoboldService>(context, listen: false),
              Provider.of<UserPersonaService>(context, listen: false),
              Provider.of<StorageService>(context, listen: false),
              Provider.of<WorldRepository>(context, listen: false),
            );
            // Wire LLMProvider and CharacterRepository immediately at creation time
            chatService.setDatabase(db);
            chatService.setLLMProvider(Provider.of<LLMProvider>(context, listen: false));
            chatService.setCharacterRepository(Provider.of<CharacterRepository>(context, listen: false));
            return chatService;
          },
          update: (context, kobold, persona, storage, worldRepo, previous) {
            if (previous != null) {
              // Re-wire dependencies on every update to stay in sync
              previous.setLLMProvider(Provider.of<LLMProvider>(context, listen: false));
              previous.setCharacterRepository(Provider.of<CharacterRepository>(context, listen: false));
              // Wire TtsService if available (it's registered later in the tree)
              try { previous.setTtsService(Provider.of<TtsService>(context, listen: false)); } catch (_) {}
              return previous;
            }
            final chatService = ChatService(kobold, persona, storage, worldRepo);
            chatService.setDatabase(db);
            chatService.setLLMProvider(Provider.of<LLMProvider>(context, listen: false));
            chatService.setCharacterRepository(Provider.of<CharacterRepository>(context, listen: false));
            return chatService;
          },
        ),
        ChangeNotifierProxyProvider<StorageService, GroupChatRepository>(
          create: (context) => GroupChatRepository(Provider.of<StorageService>(context, listen: false), db),
          update: (context, storage, previous) => previous ?? GroupChatRepository(storage, db),
        ),
        ChangeNotifierProxyProvider3<StorageService, BackendManager, KoboldService, SetupService>(
          create: (context) => SetupService(
            Provider.of<StorageService>(context, listen: false),
            Provider.of<BackendManager>(context, listen: false),
            Provider.of<KoboldService>(context, listen: false),
          ),
          update: (context, storage, backend, kobold, previous) => 
              previous ?? SetupService(storage, backend, kobold),
        ),
        ChangeNotifierProvider(create: (_) => UpdateService()),
        ChangeNotifierProvider(create: (_) => VoiceManager()),
        ChangeNotifierProxyProvider2<StorageService, VoiceManager, TtsService>(
          create: (context) => TtsService(
            Provider.of<StorageService>(context, listen: false),
            Provider.of<VoiceManager>(context, listen: false),
          ),
          update: (context, storage, voiceManager, previous) =>
              previous ?? TtsService(storage, voiceManager),
        ),
        ChangeNotifierProvider(create: (_) => CloudSyncService()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WindowListener {
  bool _updateChecked = false;
  bool _isMigrating = false;
  String _migrationStep = '';
  int _migrationCurrent = 0;
  int _migrationTotal = 1;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    // Run migration after first frame if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runMigrationIfNeeded();
    });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowClose() async {
    // Run pending installer if user deferred the update
    if (UpdateService.isSupported) {
      final updateService = Provider.of<UpdateService>(context, listen: false);
      if (updateService.hasPendingInstaller) {
        await updateService.installOnClose();
      }
    }
    await windowManager.destroy();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return MaterialApp(
          title: 'Front Porch AI',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: appState.darkMode ? Brightness.dark : Brightness.light,
            primarySwatch: Colors.blue,
            scaffoldBackgroundColor: appState.darkMode ? const Color(0xFF0F172A) : const Color(0xFFF3F4F6),
            cardColor: appState.darkMode ? const Color(0xFF1E293B) : Colors.white,
            textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme).apply(
              bodyColor: appState.darkMode ? Colors.white : Colors.black87,
              displayColor: appState.darkMode ? Colors.white : Colors.black87,
            ),
            useMaterial3: true,
          ),
          home: Builder(
            builder: (context) {
              // Trigger update check once after first build
              if (!_updateChecked) {
                _updateChecked = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _checkForUpdates(context);
                  _runCloudSync(context);
                });
              }

              final storage = Provider.of<StorageService>(context);
              final width = MediaQuery.of(context).size.width;
              
              // Scale text relative to base design width of 1280px
              // Clamp responsive base between 0.85 and 1.5
              final responsiveScale = (width / 1280).clamp(0.85, 1.5);
              
              // Combine with user preference
              final effectiveScale = responsiveScale * storage.textScale;
              
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(effectiveScale),
                ),
                child: Stack(
                  children: [
                    const MainLayout(),
                    const SetupOverlay(),
                    if (_isMigrating)
                      _buildMigrationOverlay(),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _runMigrationIfNeeded() async {
    final needsMigration = Provider.of<bool>(context, listen: false);
    if (!needsMigration) return;

    setState(() => _isMigrating = true);

    final db = Provider.of<AppDatabase>(context, listen: false);
    final migration = DataMigrationService(db);
    await migration.migrate(
      onProgress: (step, current, total) {
        if (mounted) {
          setState(() {
            _migrationStep = step;
            _migrationCurrent = current;
            _migrationTotal = total;
          });
        }
        debugPrint('DB Migration [$current/$total]: $step');
      },
    );

    if (mounted) {
      setState(() => _isMigrating = false);
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
                      colors: [Colors.blueAccent.shade700, Colors.purpleAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.withValues(alpha: 0.3),
                        blurRadius: 24,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.storage_rounded, size: 40, color: Colors.white),
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
                    color: Colors.blueAccent.shade100,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _migrationTotal > 0 ? _migrationCurrent / _migrationTotal : null,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent.shade200),
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

  Future<void> _checkForUpdates(BuildContext context) async {
    final updateService = Provider.of<UpdateService>(context, listen: false);
    await updateService.initialize();

    // Only check for updates on platforms that support self-update
    if (!UpdateService.isSupported) return;
    if (!updateService.autoCheckEnabled) return;

    final hasUpdate = await updateService.checkForUpdate();
    if (hasUpdate && context.mounted) {
      UpdateDialog.show(context);
    }
  }

  Future<void> _runCloudSync(BuildContext context) async {
    final storage = Provider.of<StorageService>(context, listen: false);
    await storage.initialized;
    if (!storage.cloudSyncEnabled || storage.cloudSyncProvider == 'none') return;

    final syncService = Provider.of<CloudSyncService>(context, listen: false);

    // Wire cloud sync service into ChatService
    final chatService = Provider.of<ChatService>(context, listen: false);
    chatService.setCloudSyncService(syncService);

    // Create and connect the appropriate provider
    CloudStorageProvider provider;
    switch (storage.cloudSyncProvider) {
      case 'webdav':
        provider = WebDavProvider();
        break;
      case 'gdrive':
        provider = GoogleDriveProvider();
        break;
      default:
        return;
    }

    try {
      await provider.connect({
        'url': storage.cloudSyncUrl,
        'username': storage.cloudSyncUsername,
        'password': storage.cloudSyncPassword,
      });
      syncService.setProvider(provider);

      // Get paths
      final chatsPath = storage.chatsDir.path;
      final rootPath = storage.rootPath ?? chatsPath;
      final charactersPath = '$rootPath${Platform.pathSeparator}KoboldManager${Platform.pathSeparator}Characters';

      await syncService.fullSync(chatsPath, charactersPath);
      if (syncService.status == SyncStatus.success) {
        await storage.setCloudSyncLastTime(DateTime.now().toIso8601String());
        // Reload characters so newly downloaded PNGs appear in the UI
        final charRepo = Provider.of<CharacterRepository>(context, listen: false);
        await charRepo.loadCharacters();

        // If a new database was downloaded, update all repo DB references and reload
        if (syncService.dbWasDownloaded) {
          debugPrint('[CloudSync] DB was downloaded — updating all repositories');
          final newDb = await AppDatabase.instance();

          // Push the new DB connection to every repo
          charRepo.updateDatabase(newDb);
          final folderService = Provider.of<FolderService>(context, listen: false);
          final personaService = Provider.of<UserPersonaService>(context, listen: false);
          final groupRepo = Provider.of<GroupChatRepository>(context, listen: false);
          final worldRepo = Provider.of<WorldRepository>(context, listen: false);
          folderService.updateDatabase(newDb);
          personaService.updateDatabase(newDb);
          groupRepo.updateDatabase(newDb);
          worldRepo.updateDatabase(newDb);
          chatService.updateDatabase(newDb);

          // Now reload all data from the new DB
          await charRepo.loadCharacters();
          await folderService.reload();
          await personaService.reload();
          await groupRepo.reload();
          await worldRepo.loadWorlds();
          chatService.clearChat();
        }
      }
    } catch (e) {
      debugPrint('Cloud sync startup error: \$e');
    }
  }
}
