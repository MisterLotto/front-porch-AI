import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/services/storage_service.dart';

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
                       _buildSlider('Temperature', storageService.temperature, 0.0, 2.0, (val) => storageService.setTemperature(val), divisions: 20),
                       _buildSlider('Min-P', storageService.minP, 0.0, 1.0, (val) => storageService.setMinP(val), divisions: 100),
                       _buildSlider('Repeat Penalty', storageService.repeatPenalty, 1.0, 3.0, (val) => storageService.setRepeatPenalty(val), divisions: 200),
                       _buildSlider('Rep Pen Tokens', storageService.repeatPenaltyTokens.toDouble(), 0, 512, (val) => storageService.setRepeatPenaltyTokens(val.toInt()), divisions: 512),
                       _buildSlider('Max Output Tokens', storageService.maxLength.toDouble(), 16, 2048, (val) => storageService.setMaxLength(val.toInt()), divisions: 2048 - 16),
                       _buildSlider('Min Output Tokens', storageService.minLength.toDouble(), 0, 512, (val) => storageService.setMinLength(val.toInt()), divisions: 512),

                       const SizedBox(height: 16),
                       Row(
                         children: [
                           const Text('Dynamic Temperature', style: TextStyle(color: Colors.white)),
                           const Spacer(),
                           Switch(
                             value: storageService.dynamicTempEnabled,
                             onChanged: (val) => storageService.setDynamicTempEnabled(val),
                             activeTrackColor: Colors.blueAccent,
                           ),
                         ],
                       ),
                       if (storageService.dynamicTempEnabled)
                         _buildSlider('Dynatemp Range', storageService.dynamicTempRange, 0.0, 2.0, (val) => storageService.setDynamicTempRange(val), divisions: 20),

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

  Widget _buildSlider(String label, double value, double min, double max, Function(double) onChanged, {int? divisions}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70)),
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
}
