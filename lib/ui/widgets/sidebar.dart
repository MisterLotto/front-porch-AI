import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/providers/app_state.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);
    final theme = Theme.of(context);

    return Container(
      width: 250,
      color: const Color(0xFF0F172A), // Dark slate
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.menu, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'FRONT PORCH AI',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          _SidebarItem(
            icon: Icons.home_outlined,
            label: 'Home',
            isSelected: appState.selectedIndex == 0,
            onTap: () => appState.setIndex(0),
          ),
          _SidebarItem(
            icon: Icons.add_circle_outline,
            label: 'Create Character',
            isSelected: appState.selectedIndex == 1,
            onTap: () => appState.setIndex(1),
          ),
          _SidebarItem(
            icon: Icons.dns_outlined,
            label: 'Manage Models',
            isSelected: appState.selectedIndex == 2,
            onTap: () => appState.setIndex(2),
          ),
           _SidebarItem(
            icon: Icons.settings_outlined,
            label: 'Settings',
            isSelected: appState.selectedIndex == 3,
            onTap: () => appState.setIndex(3),
          ),
          _SidebarItem(
            icon: Icons.person_outline,
            label: 'User Persona',
            isSelected: appState.selectedIndex == 4,
            onTap: () => appState.setIndex(4),
          ),
          _SidebarItem(
            icon: Icons.public_outlined,
            label: 'Worlds',
            isSelected: appState.selectedIndex == 5,
            onTap: () => appState.setIndex(5),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Tooltip(
                  message: 'Join our Discord Server',
                  child: GestureDetector(
                    onTap: () => launchUrl(Uri.parse('https://discord.gg/EqJrJPjdT')),
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(Icons.discord, size: 20, color: Colors.white54),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Join our Matrix Server',
                  child: GestureDetector(
                    onTap: () => launchUrl(Uri.parse('https://matrix.dreamersai.art')),
                    child: const MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Icon(Icons.grid_view_rounded, size: 20, color: Colors.white54),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'v0.0.3.2', // Updated version
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white38),
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 12.0),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.white70,
                size: 22,
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
