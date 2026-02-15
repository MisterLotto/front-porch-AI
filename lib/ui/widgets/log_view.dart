import 'package:flutter/material.dart';

class LogView extends StatelessWidget {
  final List<String> logs;

  const LogView({super.key, required this.logs});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24),
      ),
      child: ListView.builder(
        itemCount: logs.length,
        itemBuilder: (context, index) {
          // Reverse order to show newest at bottom if list is reversed, 
          // or just show normally. Assuming simpler list here.
          return Text(
            logs[index],
            style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace', fontSize: 12),
          );
        },
      ),
    );
  }
}
