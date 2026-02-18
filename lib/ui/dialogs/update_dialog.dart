import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/services/update_service.dart';

/// Dialog shown when a new version is available.
/// User can choose to update or dismiss — never forced.
class UpdateDialog extends StatelessWidget {
  const UpdateDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: Provider.of<UpdateService>(context, listen: false),
        child: const UpdateDialog(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UpdateService>(
      builder: (context, service, _) {
        if (service.downloading) {
          return _buildDownloadingDialog(context, service);
        }
        return _buildPromptDialog(context, service);
      },
    );
  }

  Widget _buildPromptDialog(BuildContext context, UpdateService service) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.system_update, color: Colors.greenAccent, size: 28),
          const SizedBox(width: 12),
          const Text('Update Available', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              children: [
                const TextSpan(text: 'A new version of Front Porch AI is available.\n\n'),
                const TextSpan(text: 'Current: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white54)),
                TextSpan(text: 'v${service.currentVersion}\n'),
                const TextSpan(text: 'Latest: ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.greenAccent)),
                TextSpan(text: 'v${service.latestVersion}\n'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Would you like to update now?',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            'The app will close briefly while the update installs.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not Now', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton.icon(
          onPressed: () => service.downloadAndInstall(),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Update'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadingDialog(BuildContext context, UpdateService service) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Downloading Update...', style: TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: service.downloadProgress > 0 ? service.downloadProgress : null,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
          ),
          const SizedBox(height: 16),
          Text(
            '${(service.downloadProgress * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
