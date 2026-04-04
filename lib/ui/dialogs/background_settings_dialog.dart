import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:front_porch_ai/services/storage_service.dart';

class BackgroundSettingsDialog extends StatelessWidget {
  const BackgroundSettingsDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final storageService = Provider.of<StorageService>(context);

    // List of background thumbnails
    final backgrounds = [
      _buildBgThumbnail(storageService, 'none', 'None', null),
      _buildBgThumbnail(storageService, 'cyberpunk_bedroom', 'Cyberpunk', 'assets/backgrounds/cyberpunk_bedroom.png'),
      _buildBgThumbnail(storageService, 'coffee_shop', 'Coffee Shop', 'assets/backgrounds/coffee_shop.png'),
      _buildBgThumbnail(storageService, 'beach', 'Beach', 'assets/backgrounds/beach.png'),
      _buildBgThumbnail(storageService, 'futuristic_city', 'Neon City', 'assets/backgrounds/futuristic_city.png'),
      _buildBgThumbnail(storageService, 'edm_rave', 'EDM Rave', 'assets/backgrounds/edm_rave.png'),
      _buildBgThumbnail(storageService, 'cozy_library', 'Library', 'assets/backgrounds/cozy_library.png'),
      _buildBgThumbnail(storageService, 'rainy_japan', 'Rainy Japan', 'assets/backgrounds/rainy_japan.png'),
      _buildBgThumbnail(storageService, 'space_station', 'Space', 'assets/backgrounds/space_station.png'),
      _buildBgThumbnail(storageService, 'enchanted_forest', 'Forest', 'assets/backgrounds/enchanted_forest.png'),
      _buildBgThumbnail(storageService, 'anime_cherry_blossom', 'Sakura', 'assets/backgrounds/anime_cherry_blossom.png'),
      _buildBgThumbnail(storageService, 'anime_rooftop', 'Rooftop', 'assets/backgrounds/anime_rooftop.png'),
      _buildBgThumbnail(storageService, 'anime_rooftop_sunset', 'Sunset', 'assets/backgrounds/anime_rooftop_sunset.png'),
      _buildBgThumbnail(storageService, 'cherry_blossom', 'Blossom', 'assets/backgrounds/cherry_blossom.png'),
      _buildBgThumbnail(storageService, 'beach_waves', 'Waves', 'assets/backgrounds/beach_waves.png'),
      _buildBgThumbnail(storageService, 'waifu_gaming_room', 'Waifu Game', 'assets/backgrounds/waifu_gaming_room.png'),
      _buildBgThumbnail(storageService, 'waifu_beach_bar', 'Waifu Bar', 'assets/backgrounds/waifu_beach_bar.png'),
      _buildBgThumbnail(storageService, 'waifu_garden', 'Waifu Garden', 'assets/backgrounds/waifu_garden.png'),
      _buildBgThumbnail(storageService, 'waifu_neon', 'Waifu Neon', 'assets/backgrounds/waifu_neon.png'),
      _buildBgThumbnail(storageService, 'waifu_beach', 'Waifu Beach', 'assets/backgrounds/waifu_beach.png'),
    ];

    return Dialog(
      backgroundColor: const Color(0xFF1F2937),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 600, // Reasonable height for grid
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Chat Background', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.4,
                children: backgrounds,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBgThumbnail(StorageService storageService, String key, String label, String? assetPath) {
    final isSelected = storageService.chatBackground == key;
    return GestureDetector(
      onTap: () => storageService.setChatBackground(key),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white24,
            width: isSelected ? 3 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (assetPath != null)
              Image.asset(assetPath, fit: BoxFit.cover)
            else
              Container(
                color: const Color(0xFF111827),
                child: const Center(child: Icon(Icons.block, color: Colors.white38, size: 28)),
              ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.black54,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: isSelected ? Colors.white : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
