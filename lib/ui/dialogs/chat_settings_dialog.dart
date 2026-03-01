import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:front_porch_ai/services/storage_service.dart';
import 'package:front_porch_ai/services/llm_provider.dart';

class ChatSettingsDialog extends StatefulWidget {
  const ChatSettingsDialog({super.key});

  @override
  State<ChatSettingsDialog> createState() => _ChatSettingsDialogState();
}

class _ChatSettingsDialogState extends State<ChatSettingsDialog> {
  final TextEditingController _stopSequenceController = TextEditingController();

  @override
  void dispose() {
    _stopSequenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storageService = Provider.of<StorageService>(context);
    final llmProvider = Provider.of<LLMProvider>(context);
    final isRemote = !llmProvider.isLocal;
    
    return Dialog(
        backgroundColor: const Color(0xFF1F2937),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   const Text('Chat Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                   IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context)),
                 ],
               ),
               const SizedBox(height: 16),
               
               Expanded(
                 child: SingleChildScrollView(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       // Reasoning toggle (only for Remote API)
                       if (isRemote) ...[
                         const Text('Reasoning', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                         const SizedBox(height: 8),
                         Row(
                           children: [
                             const Text('Request Reasoning', style: TextStyle(color: Colors.white)),
                             const Spacer(),
                             Switch(
                               value: storageService.reasoningEnabled,
                               onChanged: (val) => storageService.setReasoningEnabled(val),
                               activeTrackColor: Colors.blueAccent,
                             ),
                           ],
                         ),
                         if (storageService.reasoningEnabled)
                           Padding(
                             padding: const EdgeInsets.only(bottom: 8),
                             child: Row(
                               children: [
                                 const Text('Effort Level', style: TextStyle(color: Colors.white70)),
                                 const Spacer(),
                                 Container(
                                   padding: const EdgeInsets.symmetric(horizontal: 12),
                                   decoration: BoxDecoration(
                                     color: const Color(0xFF374151),
                                     borderRadius: BorderRadius.circular(8),
                                   ),
                                   child: DropdownButtonHideUnderline(
                                     child: DropdownButton<String>(
                                       value: storageService.reasoningEffort,
                                       dropdownColor: const Color(0xFF374151),
                                       style: const TextStyle(color: Colors.white),
                                       items: const [
                                         DropdownMenuItem(value: 'low', child: Text('Low')),
                                         DropdownMenuItem(value: 'medium', child: Text('Medium')),
                                         DropdownMenuItem(value: 'high', child: Text('High')),
                                       ],
                                       onChanged: (val) {
                                         if (val != null) storageService.setReasoningEffort(val);
                                       },
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         if (!storageService.reasoningEnabled)
                           Padding(
                             padding: const EdgeInsets.only(bottom: 8),
                             child: Text(
                               'Enable to request thinking/reasoning from compatible models',
                               style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
                             ),
                           ),
                         const SizedBox(height: 8),
                         const Divider(color: Colors.white10),
                         const SizedBox(height: 8),
                       ],

                       // Appearance
                       const Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                       const SizedBox(height: 8),
                       _buildSlider('Bubble Opacity', storageService.bubbleOpacity, 0.1, 1.0, (val) => storageService.setBubbleOpacity(val), divisions: 18),
                       const SizedBox(height: 8),
                       const Divider(color: Colors.white10),
                       const SizedBox(height: 8),
                       // Generation
                       const Text('Generation', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                       const SizedBox(height: 8),
                       _buildSlider('Temperature', storageService.temperature, 0.0, 2.0, (val) => storageService.setTemperature(val), divisions: 20, tooltip: 'Controls randomness. Low = predictable and focused. High = creative and surprising. 0.7 is a good default.'),
                       _buildSlider('Min-P', storageService.minP, 0.0, 1.0, (val) => storageService.setMinP(val), divisions: 100, tooltip: 'Filters out unlikely words. Higher = only the most probable words are kept. Start around 0.05–0.1.'),
                       _buildSlider('Repeat Penalty', storageService.repeatPenalty, 1.0, 3.0, (val) => storageService.setRepeatPenalty(val), divisions: 200, tooltip: 'Discourages the AI from repeating the same words. Higher = less repetition. 1.1 is a safe default.'),
                       _buildSlider('Rep Pen Tokens', storageService.repeatPenaltyTokens.toDouble(), 0, 512, (val) => storageService.setRepeatPenaltyTokens(val.toInt()), divisions: 512, tooltip: 'How far back the AI checks for repetition (in tokens). Higher = checks more of the conversation history.'),
                       _buildSlider('XTC Threshold', storageService.xtcThreshold, 0.0, 0.5, (val) => storageService.setXtcThreshold(val), divisions: 50, tooltip: 'Exclude Top Choices — removes the most obvious/cliché word choices. Lower = stronger effect. Try 0.1 for more creative writing.'),
                       _buildSlider('XTC Probability', storageService.xtcProbability, 0.0, 1.0, (val) => storageService.setXtcProbability(val), divisions: 20, tooltip: 'How often XTC activates. 0 = never, 1 = always. Try 0.5 for a balance between creativity and coherence.'),
                       _buildSlider('Max Output Tokens', storageService.maxLength.toDouble(), 16, 16384, (val) => storageService.setMaxLength(val.toInt()), divisions: null, tooltip: 'Maximum number of tokens the AI can write in one response. Thinking models need higher values since reasoning tokens count toward this limit.'),
                       _buildSlider('Min Output Tokens', storageService.minLength.toDouble(), 0, 512, (val) => storageService.setMinLength(val.toInt()), divisions: 512, tooltip: 'Minimum tokens the AI must write before it can stop. Increase for longer responses.'),
                       _buildIntSlider('Context Size', storageService.contextSize.toDouble().clamp(512, isRemote ? 500000 : 15000), 512, isRemote ? 500000.0 : 15000.0, (val) => storageService.setContextSize(val.toInt()), step: 512),

                       const SizedBox(height: 16),
                       Row(
                         children: [
                           const Text('Dynamic Temperature', style: TextStyle(color: Colors.white)),
                           Tooltip(
                             message: 'Varies temperature randomly within a range each generation for more varied outputs.',
                             child: const Padding(
                               padding: EdgeInsets.only(left: 4),
                               child: Icon(Icons.info_outline, size: 16, color: Colors.white38),
                             ),
                           ),
                           const Spacer(),
                           Switch(
                             value: storageService.dynamicTempEnabled,
                             onChanged: (val) => storageService.setDynamicTempEnabled(val),
                             activeTrackColor: Colors.blueAccent,
                           ),
                         ],
                       ),
                       if (storageService.dynamicTempEnabled)
                         _buildSlider('Dynatemp Range', storageService.dynamicTempRange, 0.0, 2.0, (val) => storageService.setDynamicTempRange(val), divisions: 20, tooltip: 'How much the temperature can vary around the base temperature.'),

                        const SizedBox(height: 24),
                        const Text('Display Output', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        const SizedBox(height: 8),
                        _buildSlider('Chat Text Size', storageService.textScale, 0.5, 2.0, (val) => storageService.setTextScale(val), divisions: 30, tooltip: 'Scale the chat text size up or down.'),
                        const SizedBox(height: 16),
                        const Text('Chat Background', style: TextStyle(color: Colors.white70, fontSize: 13)),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 280,
                          child: GridView.count(
                            crossAxisCount: 5,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 1.4,
                            children: [
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
                            ],
                          ),
                        ),
                       const SizedBox(height: 8),
                       Row(
                         children: [
                           const Text('Smooth Output Buffer', style: TextStyle(color: Colors.white)),
                           const Spacer(),
                           Switch(
                             value: storageService.displayBufferEnabled,
                             onChanged: (val) => storageService.setDisplayBufferEnabled(val),
                             activeTrackColor: Colors.blueAccent,
                           ),
                         ],
                       ),
                       if (!storageService.displayBufferEnabled)
                         Padding(
                           padding: const EdgeInsets.only(bottom: 8),
                           child: Text(
                             'Tokens display as they arrive (no buffering)',
                             style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12),
                           ),
                         ),
                       if (storageService.displayBufferEnabled)
                         _buildSlider(
                           'Target Display Speed (t/s)',
                           storageService.targetDisplayTps,
                           5.0,
                           60.0,
                           (val) => storageService.setTargetDisplayTps(val),
                           divisions: 55,
                         ),
                       if (storageService.displayBufferEnabled)
                         _buildSlider(
                           'Buffer Duration (seconds)',
                           storageService.bufferDurationSeconds,
                           1.0,
                           10.0,
                           (val) => storageService.setBufferDurationSeconds(val),
                           divisions: 9,
                           tooltip: 'How many seconds of tokens to accumulate before the display starts. Higher = smoother output but longer delay before text appears.',
                         ),
                        const SizedBox(height: 24),
                        const Text('Stop Sequences', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                        const SizedBox(height: 8),
                         Container(
                           decoration: BoxDecoration(
                             color: const Color(0xFF374151),
                             borderRadius: BorderRadius.circular(8),
                           ),
                           child: Column(
                             children: [
                               Padding(
                                 padding: const EdgeInsets.symmetric(horizontal: 12),
                                 child: Row(
                                   children: [
                                     Expanded(
                                       child: TextField(
                                         controller: _stopSequenceController,
                                         style: const TextStyle(color: Colors.white),
                                         decoration: const InputDecoration(
                                           hintText: 'Add stop sequence...',
                                           hintStyle: TextStyle(color: Colors.white38),
                                           border: InputBorder.none,
                                         ),
                                         onSubmitted: (val) {
                                            if (val.isNotEmpty) {
                                              storageService.addStopSequence(val);
                                              _stopSequenceController.clear();
                                            }
                                         },
                                       ),
                                     ),
                                     IconButton(
                                       icon: const Icon(Icons.add_circle, color: Colors.blueAccent),
                                       onPressed: () {
                                         if (_stopSequenceController.text.isNotEmpty) {
                                           storageService.addStopSequence(_stopSequenceController.text);
                                           _stopSequenceController.clear();
                                         }
                                       },
                                     ),
                                   ],
                                 ),
                               ),
                               const Divider(height: 1, color: Colors.white10),
                               ...storageService.stopSequences.map((seq) => ListTile(
                                 title: Text(seq.replaceAll('\n', '\\n'), style: const TextStyle(color: Colors.white)),
                                 trailing: IconButton(
                                   icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent, size: 20),
                                   onPressed: () => storageService.removeStopSequence(seq),
                                 ),
                                 dense: true,
                               )),
                             ],
                           ),
                         ),
                     ],
                   ),
                 ),
               ),
            ],
          ),
        ),
    );
  }

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged, {int? divisions, String? tooltip}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(color: Colors.white70)),
                if (tooltip != null)
                  Tooltip(
                    message: tooltip,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 4),
                      child: Icon(Icons.info_outline, size: 16, color: Colors.white38),
                    ),
                  ),
              ],
            ),
            Text(value.toStringAsFixed(2), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
          activeColor: Colors.blueAccent,
          inactiveColor: Colors.white24,
        ),
      ],
    );
  }

  Widget _buildIntSlider(String label, double value, double min, double max, Function(double) onChanged, {int step = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
            Text(value.toInt().toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) / step).round(),
          onChanged: onChanged,
          activeColor: Colors.blueAccent,
          inactiveColor: Colors.white24,
        ),
      ],
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
            width: isSelected ? 2 : 1,
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
                child: const Center(child: Icon(Icons.block, color: Colors.white38, size: 20)),
              ),
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 2),
                color: Colors.black54,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: isSelected ? Colors.blueAccent : Colors.white70,
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
