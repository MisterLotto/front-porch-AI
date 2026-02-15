import 'package:flutter/foundation.dart';
import 'package:kobold_character_card_manager/services/backend_manager.dart';
import 'package:kobold_character_card_manager/services/kobold_service.dart';
import 'package:kobold_character_card_manager/services/storage_service.dart';

enum SetupStep {
  idle,
  checkingBackend,
  downloadingBackend,
  startingBackend,
  complete,
  error
}

class SetupService extends ChangeNotifier {
  final StorageService _storageService;
  final BackendManager _backendManager;
  final KoboldService _koboldService;

  SetupStep _currentStep = SetupStep.idle;
  String? _errorMessage;

  SetupStep get currentStep => _currentStep;
  String? get errorMessage => _errorMessage;

  SetupService(this._storageService, this._backendManager, this._koboldService);

  Future<void> runAutoSetup() async {
    if (_currentStep != SetupStep.idle && _currentStep != SetupStep.error) return;

    _errorMessage = null;
    _currentStep = SetupStep.checkingBackend;
    notifyListeners();

    try {
      // 1. Wait for StorageService to init (rootPath must be available)
      if (_storageService.rootPath == null) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_storageService.rootPath == null) {
          throw Exception('Storage not initialized');
        }
      }

      // 2. Check and Download Backend if missing
      await _backendManager.checkBackendAvailability();
      if (_backendManager.backendPath == null) {
        _currentStep = SetupStep.downloadingBackend;
        notifyListeners();
        
        // Use the existing listener in BackendManager or just wait for it?
        // Let's call download and wait.
        // We'll add a listener to BackendManager to know when it's done.
        void listener() {
           if (!_backendManager.isDownloading && _backendManager.backendPath != null) {
             // Success
           }
        }
        _backendManager.addListener(listener);
        
        await _backendManager.downloadBackend();
        _backendManager.removeListener(listener);

        if (_backendManager.backendPath == null) {
          throw Exception(_backendManager.error ?? 'Failed to install backend');
        }
      }

      // 3. Autostart Backend if enabled
      if (_storageService.autostartBackend && _storageService.lastUsedModelPath != null) {
        _currentStep = SetupStep.startingBackend;
        notifyListeners();

        await _koboldService.startKobold(
          _backendManager.backendPath!,
          _storageService.lastUsedModelPath!,
          useVulkan: _storageService.useVulkan ?? false,
          useCublas: _storageService.useCublas ?? false,
        );
      }

      _currentStep = SetupStep.complete;
      notifyListeners();
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
