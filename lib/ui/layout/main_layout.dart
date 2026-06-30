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

import 'package:flutter/material.dart';
import 'package:front_porch_ai/ui/widgets/sidebar.dart';
import 'package:front_porch_ai/ui/pages/home_page.dart';
import 'package:front_porch_ai/ui/pages/create_character_page.dart';
import 'package:front_porch_ai/ui/pages/model_manager_page.dart';
import 'package:front_porch_ai/ui/pages/settings_page.dart';
import 'package:front_porch_ai/ui/pages/user_persona_page.dart';
import 'package:front_porch_ai/ui/pages/world_management_page.dart';
import 'package:provider/provider.dart';
import 'package:front_porch_ai/providers/app_state.dart';

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
            child:
                _pages[appState.selectedIndex < _pages.length
                    ? appState.selectedIndex
                    : 0],
          ),
        ],
      ),
    );
  }
}
