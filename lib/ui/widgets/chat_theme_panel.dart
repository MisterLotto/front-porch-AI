import 'package:flutter/material.dart';
import 'package:front_porch_ai/models/chat_theme_overrides.dart';
import 'package:front_porch_ai/models/chat_theme_preset.dart';
import 'package:front_porch_ai/ui/theme/app_colors.dart';
import 'package:front_porch_ai/ui/settings/dialogs/color_picker_dialog.dart';

class ChatThemePanel extends StatefulWidget {
  final ChatThemeOverrides overrides;
  final ValueChanged<ChatThemeOverrides> onChanged;

  const ChatThemePanel({
    super.key,
    required this.overrides,
    required this.onChanged,
  });

  @override
  State<ChatThemePanel> createState() => _ChatThemePanelState();
}

class _ChatThemePanelState extends State<ChatThemePanel> {
  late ChatThemeOverrides _overrides;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _overrides = widget.overrides.copy();
  }

  @override
  void didUpdateWidget(ChatThemePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.overrides.themeId != oldWidget.overrides.themeId) {
      _overrides = widget.overrides.copy();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _notify() => widget.onChanged(_overrides);

  @override
  Widget build(BuildContext context) {
    final activePreset = ChatThemePreset.byId(_overrides.themeId);
    const bgAssets = {
      'noir': 'Noir',
      'fantasy': 'Fantasy',
      'grid': 'Grid',
      'roman_market': 'Roman Market',
      'enchanted_wood': 'Enchanted Wood',
      'ocean_depth': 'Ocean Depth',
      'steampunk_bg': 'Steampunk',
      'cyberpunk_bedroom': 'Cyberpunk Bedroom',
      'coffee_shop': 'Coffee Shop',
      'beach': 'Beach',
      'futuristic_city': 'Futuristic City',
      'edm_rave': 'EDM Rave',
      'cozy_library': 'Cozy Library',
      'rainy_japan': 'Rainy Japan',
      'space_station': 'Space Station',
      'enchanted_forest': 'Enchanted Forest',
      'anime_cherry_blossom': 'Anime Cherry Blossom',
      'anime_rooftop': 'Anime Rooftop',
      'anime_rooftop_sunset': 'Anime Rooftop Sunset',
      'cherry_blossom': 'Cherry Blossom',
      'beach_waves': 'Beach Waves',
      'waifu_gaming_room': 'Waifu Gaming Room',
      'waifu_beach_bar': 'Waifu Beach Bar',
      'waifu_garden': 'Waifu Garden',
      'waifu_neon': 'Waifu Neon',
      'waifu_beach': 'Waifu Beach',
    };
    const borderStyles = [
      'scalloped',
      'dualLine',
      'grid',
      'wavy',
      'shadow',
      'vine',
      'wave',
      'glitch',
      'floral',
      'gear',
      'greekKey',
    ];
    const fontOptions = [
      'serif',
      'sans-serif',
      'monospace',
      'Georgia',
      'Times New Roman',
      'Arial',
      'Helvetica',
      'Courier New',
      'Verdana',
      'Roboto',
      'Open Sans',
      'Lato',
      'Merriweather',
      'Playfair Display',
      'Source Code Pro',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Divider(color: AppColors.borderOf(context)),
        const SizedBox(height: 16),
        Row(
          children: [
            const Text(
              'Chat Theme',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.formMasterAccent,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_overrides.isCustomized)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${activePreset?.displayName ?? 'Theme'} (Customized)',
              style: TextStyle(
                color: AppColors.porchAmberOf(context),
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.chevron_left,
                color: AppColors.textTertiary(context),
              ),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 72),
              padding: EdgeInsets.zero,
              onPressed: () {
                final offset = _scrollController.offset;
                _scrollController.animateTo(
                  (offset - 144).clamp(
                    0,
                    _scrollController.position.maxScrollExtent,
                  ),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                );
              },
            ),
            Expanded(
              child: SizedBox(
                height: 72,
                child: ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  itemCount: ChatThemePreset.presets.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      final isSelected = !_overrides.hasTheme;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _overrides = ChatThemeOverrides();
                          });
                          _notify();
                        },
                        child: Container(
                          width: 64,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.15)
                                : const Color(0xFF374151),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.formMasterAccent
                                  : Colors.white12,
                            ),
                          ),
                          child: const Center(
                            child: Text(
                              'None',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final preset = ChatThemePreset.presets[index - 1];
                    final isSelected = _overrides.themeId == preset.id;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _overrides = ChatThemeOverrides(themeId: preset.id);
                        });
                        _notify();
                      },
                      child: Container(
                        width: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFF374151),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.formMasterAccent
                                : Colors.white12,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: preset.defaultUserBubbleColor,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: preset.defaultAiBubbleColor,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              preset.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              preset.defaultBorderStyle,
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary(context),
              ),
              constraints: const BoxConstraints(minWidth: 28, minHeight: 72),
              padding: EdgeInsets.zero,
              onPressed: () {
                final offset = _scrollController.offset;
                _scrollController.animateTo(
                  (offset + 144).clamp(
                    0,
                    _scrollController.position.maxScrollExtent,
                  ),
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ],
        ),

        if (activePreset != null) ...[
          const SizedBox(height: 16),

          // Font family
          Row(
            children: [
              const SizedBox(width: 8),
              const Text(
                'Font',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value:
                        _overrides.fontFamily ?? activePreset.defaultFontFamily,
                    dropdownColor: const Color(0xFF374151),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: fontOptions
                        .map(
                          (f) => DropdownMenuItem(
                            value: f,
                            child: Text(f, style: TextStyle(fontFamily: f)),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          if (val == activePreset.defaultFontFamily) {
                            _overrides.fontFamily = null;
                          } else {
                            _overrides.fontFamily = val;
                          }
                        });
                        _notify();
                      }
                    },
                  ),
                ),
              ),
              if (_overrides.fontFamily != null)
                IconButton(
                  icon: Icon(
                    Icons.restart_alt,
                    size: 14,
                    color: AppColors.porchAmberOf(context),
                  ),
                  onPressed: () {
                    setState(() => _overrides.fontFamily = null);
                    _notify();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 12),
            ],
          ),

          // User bubble color
          _buildColorRow(
            label: 'User Bubble',
            hexValue: _overrides.userBubbleColor,
            defaultColor: activePreset.defaultUserBubbleColor,
            onChanged: (hex) {
              setState(() => _overrides.userBubbleColor = hex);
              _notify();
            },
            onReset: () {
              setState(() => _overrides.userBubbleColor = null);
              _notify();
            },
          ),

          // User text color
          _buildColorRow(
            label: 'User Text',
            hexValue: _overrides.userTextColor,
            defaultColor: activePreset.defaultUserTextColor,
            onChanged: (hex) {
              setState(() => _overrides.userTextColor = hex);
              _notify();
            },
            onReset: () {
              setState(() => _overrides.userTextColor = null);
              _notify();
            },
          ),

          // AI bubble color
          _buildColorRow(
            label: 'AI Bubble',
            hexValue: _overrides.aiBubbleColor,
            defaultColor: activePreset.defaultAiBubbleColor,
            onChanged: (hex) {
              setState(() => _overrides.aiBubbleColor = hex);
              _notify();
            },
            onReset: () {
              setState(() => _overrides.aiBubbleColor = null);
              _notify();
            },
          ),

          // AI text color
          _buildColorRow(
            label: 'AI Text',
            hexValue: _overrides.aiTextColor,
            defaultColor: activePreset.defaultAiTextColor,
            onChanged: (hex) {
              setState(() => _overrides.aiTextColor = hex);
              _notify();
            },
            onReset: () {
              setState(() => _overrides.aiTextColor = null);
              _notify();
            },
          ),

          // Background
          Row(
            children: [
              const SizedBox(width: 8),
              const Text(
                'Background',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value:
                        _overrides.backgroundKey ??
                        activePreset.defaultBackgroundKey,
                    dropdownColor: const Color(0xFF374151),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: bgAssets.entries
                        .map(
                          (e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          if (val == activePreset.defaultBackgroundKey) {
                            _overrides.backgroundKey = null;
                          } else {
                            _overrides.backgroundKey = val;
                          }
                        });
                        _notify();
                      }
                    },
                  ),
                ),
              ),
              if (_overrides.backgroundKey != null)
                IconButton(
                  icon: Icon(
                    Icons.restart_alt,
                    size: 14,
                    color: AppColors.porchAmberOf(context),
                  ),
                  onPressed: () {
                    setState(() => _overrides.backgroundKey = null);
                    _notify();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 12),
            ],
          ),

          // Border style
          Row(
            children: [
              const SizedBox(width: 8),
              const Text(
                'Border',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF374151),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value:
                        _overrides.borderStyle ??
                        activePreset.defaultBorderStyle,
                    dropdownColor: const Color(0xFF374151),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    items: borderStyles
                        .map(
                          (b) => DropdownMenuItem(
                            value: b,
                            child: Text(
                              b,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          if (val == activePreset.defaultBorderStyle) {
                            _overrides.borderStyle = null;
                          } else {
                            _overrides.borderStyle = val;
                          }
                        });
                        _notify();
                      }
                    },
                  ),
                ),
              ),
              if (_overrides.borderStyle != null)
                IconButton(
                  icon: Icon(
                    Icons.restart_alt,
                    size: 14,
                    color: AppColors.porchAmberOf(context),
                  ),
                  onPressed: () {
                    setState(() => _overrides.borderStyle = null);
                    _notify();
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 12),
            ],
          ),

          // Border color
          _buildColorRow(
            label: 'Border',
            hexValue: _overrides.borderColor,
            defaultColor:
                activePreset.defaultBorderColor ??
                activePreset.defaultUserTextColor,
            onChanged: (hex) {
              setState(() => _overrides.borderColor = hex);
              _notify();
            },
            onReset: () {
              setState(() => _overrides.borderColor = null);
              _notify();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildColorRow({
    required String label,
    required String? hexValue,
    required Color defaultColor,
    required ValueChanged<String?> onChanged,
    required VoidCallback onReset,
  }) {
    final currentColor = hexValue != null ? _parseHex(hexValue) : defaultColor;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              showColorPicker(context, currentColor, (picked) {
                final hex = picked
                    .toARGB32()
                    .toRadixString(16)
                    .padLeft(8, '0')
                    .substring(2)
                    .toUpperCase();
                onChanged(hex);
              });
            },
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: currentColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(
                Icons.colorize,
                size: 14,
                color: AppColors.textTertiary(context),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: AppColors.textSecondary(context),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Text(
            _colorToHex(currentColor),
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              Icons.restart_alt,
              size: 14,
              color: AppColors.porchAmberOf(context),
            ),
            onPressed: onReset,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }

  String _colorToHex(Color c) =>
      c.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase();

  static Color _parseHex(String hex) {
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
