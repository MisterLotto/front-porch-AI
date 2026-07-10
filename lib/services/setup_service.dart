import 'package:flutter/foundation.dart';
import 'package:front_porch_ai/services/backend_manager.dart';
import 'package:front_porch_ai/services/kobold_service.dart';
import 'package:front_porch_ai/services/pseudo_remote_service.dart';
import 'package:front_porch_ai/services/storage_service.dart';

enum SetupStep {
  idle,
  checkingBackend,
  downloadingBackend,
  startingBackend,
  complete,
  error,
}

class SetupService extends ChangeNotifier {
  final StorageService _storageService;
  final BackendManager _backendManager;
  final KoboldService _koboldService;
  final PseudoRemoteService _pseudoRemoteService;

  SetupStep _currentStep = SetupStep.idle;
  String? _errorMessage;

  SetupStep get currentStep => _currentStep;
  String? get errorMessage => _errorMessage;

  SetupService(
    this._storageService,
    this._backendManager,
    this._koboldService,
    this._pseudoRemoteService,
  );

  Future<void> runAutoSetup() async {
    if (_currentStep != SetupStep.idle && _currentStep != SetupStep.error) {
      return;
    }

    // Intel Macs cannot run KoboldCpp — skip download and autostart entirely
    if (_backendManager.isIntelMac) {
      _currentStep = SetupStep.complete;
      notifyListeners();
      return;
    }

    _errorMessage = null;
    _currentStep = SetupStep.checkingBackend;
    notifyListeners();

    try {
      // 1. Wait for StorageService to fully initialize (SharedPreferences loaded)
      await _storageService.initialized;

      // 2. Check and Download Backend if missing
      await _backendManager.checkBackendAvailability();
      if (_backendManager.backendPath == null) {
        _currentStep = SetupStep.downloadingBackend;
        notifyListeners();

        await _backendManager.downloadBackend();

        if (_backendManager.backendPath == null) {
          throw Exception(_backendManager.error ?? 'Failed to install backend');
        }
      }

      // 3. Dismiss overlay so the user can interact with the app
      _currentStep = SetupStep.complete;
      notifyListeners();

      // 4. Wait 5 seconds before attempting autostart (gives the app UI time to settle)
      await Future.delayed(const Duration(seconds: 5));

      // 5. Autostart only for the backend that was last used
      if (_storageService.backendType == 'pseudoRemote') {
        if (_storageService.autostartPseudoRemote &&
            _storageService.activeKcppsPath != null &&
            _storageService.activeKcppsPath!.isNotEmpty) {
          _currentStep = SetupStep.startingBackend;
          notifyListeners();

          await _pseudoRemoteService.start(
            executablePath: _backendManager.backendPath!,
            kcppsPath: _storageService.activeKcppsPath!,
          );

          _currentStep = SetupStep.complete;
          notifyListeners();
        }
      } else if (_storageService.backendType != 'openRouter') {
        // kobold local backend
        if (_storageService.autostartBackend &&
            _storageService.lastUsedModelPath != null) {
          _currentStep = SetupStep.startingBackend;
          notifyListeners();

          await _koboldService.startKobold(
            _backendManager.backendPath!,
            _storageService.lastUsedModelPath!,
            kcppsPath: _storageService.activeKcppsPath,
            mmprojPath: _storageService.mmprojForModel(
              _storageService.lastUsedModelPath!,
            ),
            gpuLayers: _storageService.gpuLayers,
            contextSize: _storageService.contextSize,
            useVulkan: _storageService.useVulkan ?? false,
            useCublas: _storageService.useCublas ?? false,
            useMetal: _storageService.useMetal ?? false,
            useRocm: _storageService.useRocm ?? false,
          );

          _currentStep = SetupStep.complete;
          notifyListeners();
        }
      }
    } catch (e) {
      _errorMessage = e.toString();
      _currentStep = SetupStep.error;
      notifyListeners();
    }
  }

  void reset() {
    _currentStep = SetupStep.idle;
    _errorMessage = null;
    notifyListeners();
  }
}
