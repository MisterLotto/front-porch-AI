
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:provider/provider.dart';
import 'package:desktop_webview_window/desktop_webview_window.dart'; // New import
import 'package:window_manager/window_manager.dart';
import 'package:kobold_character_card_manager/providers/app_state.dart';
import 'package:kobold_character_card_manager/ui/layout/main_layout.dart'; // Keep original import for MainLayout
import 'package:kobold_character_card_manager/services/kobold_service.dart';
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
import 'package:kobold_character_card_manager/ui/widgets/setup_overlay.dart';

void main(List<String> args) async {
  if (runWebViewTitleBarWidget(args)) {
    return;
  }
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
        ChangeNotifierProxyProvider4<KoboldService, UserPersonaService, StorageService, WorldRepository, ChatService>(
          create: (context) => ChatService(
            Provider.of<KoboldService>(context, listen: false),
            Provider.of<UserPersonaService>(context, listen: false),
            Provider.of<StorageService>(context, listen: false),
            Provider.of<WorldRepository>(context, listen: false),
          ),
          update: (context, kobold, persona, storage, worldRepo, previous) => 
              previous ?? ChatService(kobold, persona, storage, worldRepo),
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
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
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
}
