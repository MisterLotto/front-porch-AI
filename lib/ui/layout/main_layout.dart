import 'package:flutter/material.dart';
import 'package:kobold_character_card_manager/ui/widgets/sidebar.dart';
import 'package:kobold_character_card_manager/ui/pages/home_page.dart';
import 'package:kobold_character_card_manager/ui/pages/create_character_page.dart';
import 'package:kobold_character_card_manager/ui/pages/model_manager_page.dart';
import 'package:kobold_character_card_manager/ui/pages/settings_page.dart';
import 'package:kobold_character_card_manager/ui/pages/user_persona_page.dart';
import 'package:kobold_character_card_manager/ui/pages/world_management_page.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/providers/app_state.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  final List<Widget> _pages = [
    const HomePage(),
    const CreateCharacterPage(),
    const ModelManagerPage(), 
    const SettingsPage(),
    const UserPersonaPage(),
    const WorldManagementPage(),
  ];

  @override
  Widget build(BuildContext context) {
    // Watch AppState to rebuild on index change
    final appState = Provider.of<AppState>(context);
    
    return Scaffold(
      body: Row(
        children: [
          const Sidebar(), 
          Expanded(
            child: _pages[appState.selectedIndex < _pages.length ? appState.selectedIndex : 0],
          ),
        ],
      ),
    );
  }
}
