import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/services/setup_service.dart';
import 'package:kobold_character_card_manager/services/backend_manager.dart';

class SetupOverlay extends StatefulWidget {
  const SetupOverlay({super.key});

  @override
  State<SetupOverlay> createState() => _SetupOverlayState();
}

class _SetupOverlayState extends State<SetupOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SetupService>(context, listen: false).runAutoSetup();
    });
  }

  @override
  Widget build(BuildContext context) {
    final setupService = Provider.of<SetupService>(context);
    final backendManager = Provider.of<BackendManager>(context);

    if (setupService.currentStep == SetupStep.idle || setupService.currentStep == SetupStep.complete) {
      return const SizedBox.shrink();
    }

    return Material(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E26),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(0.1),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blueAccent, size: 48),
              const SizedBox(height: 24),
              Text(
                'Starting Front Porch AI',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              _buildStepContent(setupService, backendManager, context),
              if (setupService.currentStep == SetupStep.error) ...[
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => setupService.runAutoSetup(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Retry Setup'),
                ),
                TextButton(
                  onPressed: () => setupService.reset(),
                  child: const Text('Continue to App anyway', style: TextStyle(color: Colors.white54)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(SetupService setup, BackendManager backend, BuildContext context) {
    switch (setup.currentStep) {
      case SetupStep.checkingBackend:
        return _buildStatusRow('Checking installation...', true);
      case SetupStep.downloadingBackend:
        return Column(
          children: [
            _buildStatusRow('Downloading Backend...', true),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: backend.downloadProgress,
              backgroundColor: Colors.white10,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
            const SizedBox(height: 12),
            Text(
              backend.statusMessage,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        );
      case SetupStep.startingBackend:
        return _buildStatusRow('Booting Backend...', true);
      case SetupStep.error:
        return Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
            const SizedBox(height: 8),
            Text(
              setup.errorMessage ?? 'Unknown error occurred',
              style: const TextStyle(color: Colors.redAccent),
              textAlign: TextAlign.center,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStatusRow(String text, bool spinning) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (spinning)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blueAccent),
          ),
        if (spinning) const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
