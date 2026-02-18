
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';

import 'package:window_manager/window_manager.dart';
import 'package:kobold_character_card_manager/providers/app_state.dart';
import 'package:kobold_character_card_manager/ui/layout/main_layout.dart'; // Keep original import for MainLayout
import 'package:kobold_character_card_manager/services/kobold_service.dart';
import 'package:kobold_character_card_manager/services/open_router_service.dart';
import 'package:kobold_character_card_manager/services/llm_provider.dart';
import 'package:kobold_character_card_manager/services/character_repository.dart';
import 'package:kobold_character_card_manager/services/backend_manager.dart';
import 'package:kobold_character_card_manager/services/model_manager.dart';
import 'package:kobold_character_card_manager/services/storage_service.dart';
import 'package:kobold_character_card_manager/services/hardware_service.dart';
import 'package:kobold_character_card_manager/services/chat_service.dart';
import 'package:kobold_character_card_manager/services/user_persona_service.dart';
import 'package:kobold_character_card_manager/services/world_repository.dart';
import 'package:kobold_character_card_manager/services/setup_service.dart';
import 'package:kobold_character_card_manager/services/folder_service.dart';
import 'package:kobold_character_card_manager/services/update_service.dart';
import 'package:kobold_character_card_manager/ui/widgets/setup_overlay.dart';
import 'package:kobold_character_card_manager/ui/dialogs/update_dialog.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  
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
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => StorageService()),
        ChangeNotifierProxyProvider<StorageService, KoboldService>(
          create: (context) => KoboldService(Provider.of<StorageService>(context, listen: false)),
          update: (context, storage, previous) => previous ?? KoboldService(storage),
        ),
        ChangeNotifierProvider(create: (_) => HardwareService()),
        ChangeNotifierProvider(create: (_) => CharacterRepository()),
        ChangeNotifierProvider(create: (_) => UserPersonaService()),
        ChangeNotifierProvider(create: (_) => FolderService()),
        ChangeNotifierProxyProvider<StorageService, WorldRepository>(
          create: (context) => WorldRepository(Provider.of<StorageService>(context, listen: false)),
          update: (context, storage, previous) => previous ?? WorldRepository(storage),
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
            // Wire LLMProvider immediately at creation time
            chatService.setLLMProvider(Provider.of<LLMProvider>(context, listen: false));
            return chatService;
          },
          update: (context, kobold, persona, storage, worldRepo, previous) {
            if (previous != null) {
              // Re-wire LLMProvider on every update to stay in sync
              previous.setLLMProvider(Provider.of<LLMProvider>(context, listen: false));
              return previous;
            }
            final chatService = ChatService(kobold, persona, storage, worldRepo);
            chatService.setLLMProvider(Provider.of<LLMProvider>(context, listen: false));
            return chatService;
          },
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

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
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
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    if (!UpdateService.isSupported) return;

    final updateService = Provider.of<UpdateService>(context, listen: false);
    await updateService.initialize();

    if (!updateService.autoCheckEnabled) return;

    final hasUpdate = await updateService.checkForUpdate();
    if (hasUpdate && context.mounted) {
      UpdateDialog.show(context);
    }
  }
}
