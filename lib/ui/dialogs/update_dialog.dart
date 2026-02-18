import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/services/update_service.dart';

/// Dialog shown when a new version is available.
/// Three stages: prompt → downloading → ready to install.
/// User can always dismiss — never forced.
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
        if (service.downloadComplete) {
          return _buildReadyToInstallDialog(context, service);
        }
        if (service.downloading) {
          return _buildDownloadingDialog(context, service);
        }
        return _buildPromptDialog(context, service);
      },
    );
  }

  /// Stage 1: "A new version is available, would you like to download?"
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
            'Would you like to download the update?',
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not Now', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton.icon(
          onPressed: () => service.downloadUpdate(),
          icon: const Icon(Icons.download, size: 18),
          label: const Text('Download'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  /// Stage 2: Download in progress
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

  /// Stage 3: Download complete — "Ready to install now?"
  Widget _buildReadyToInstallDialog(BuildContext context, UpdateService service) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28),
          const SizedBox(width: 12),
          const Text('Ready to Install', style: TextStyle(color: Colors.white)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'The update has been downloaded. Would you like to install it now?',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Text(
            'If you choose "Later", the update will install automatically when you close the app.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later', style: TextStyle(color: Colors.white54)),
        ),
        ElevatedButton.icon(
          onPressed: () => service.installNow(),
          icon: const Icon(Icons.install_desktop, size: 18),
          label: const Text('Install Now'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent.shade700,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
