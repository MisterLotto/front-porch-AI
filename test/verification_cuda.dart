
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kobold_character_card_manager/services/hardware_service.dart';
import 'package:kobold_character_card_manager/ui/pages/settings_page.dart';
import 'package:kobold_character_card_manager/services/storage_service.dart';
import 'package:kobold_character_card_manager/services/kobold_service.dart';
import 'package:kobold_character_card_manager/services/backend_manager.dart';
import 'package:kobold_character_card_manager/services/model_manager.dart';
import 'package:kobold_character_card_manager/providers/app_state.dart';

// Mock Services
class MockHardwareService extends ChangeNotifier implements HardwareService {
  HardwareInfo? _hardwareInfo;
  HardwareInfo? _pendingResult;
  bool _isDetecting = false;

  @override
  HardwareInfo? get hardwareInfo => _hardwareInfo;
  @override
  bool get isDetecting => _isDetecting;

  void setHardwareInfo(HardwareInfo? info) {
    _hardwareInfo = info;
    notifyListeners();
  }

  void setPendingDetectionResult(HardwareInfo? info) {
    _pendingResult = info;
  }
  
  @override
  Future<void> detectHardware() async {
     if (_pendingResult != null) {
       _hardwareInfo = _pendingResult;
       notifyListeners();
     }
  }
}

class MockStorageService extends ChangeNotifier implements StorageService {
  bool? _useCublas;
  bool? _useVulkan;
 
  @override
  bool? get useCublas => _useCublas;
  @override
  bool? get useVulkan => _useVulkan;

  @override
  String? get rootPath => '/tmp';
  
  @override
  Future<void> setUseCublas(bool value) async {
    _useCublas = value;
    notifyListeners();
  }

  @override
  Future<void> setUseVulkan(bool value) async {
    _useVulkan = value;
    notifyListeners();
  }

  // Include other required getters with dummy values
  @override
  String get systemPrompt => '';
  @override
  double get minP => 0.0;
  @override
  double get temperature => 0.7;
  @override
  double get repeatPenalty => 1.1;
  @override
  int get repeatPenaltyTokens => 64;
  @override
  bool get dynamicTempEnabled => false;
  @override
  double get dynamicTempRange => 0.0;
  @override
  Directory get binDir => Directory('/tmp');
  @override
  Directory get modelsDir => Directory('/tmp');
  
  // Dummy implementations for other setters
  @override
  Future<void> setRootPath(String path) async {}
  @override
  Future<void> setSystemPrompt(String value) async {}
  @override
  Future<void> setMinP(double value) async {}
  @override
  Future<void> setTemperature(double value) async {}
  @override
  Future<void> setRepeatPenalty(double value) async {}
  @override
  Future<void> setRepeatPenaltyTokens(int value) async {}
  @override
  Future<void> setDynamicTempEnabled(bool value) async {}
  @override
  Future<void> setDynamicTempRange(double value) async {}
}

// Minimal mocks for other services just to satisfy Provider
class MockKoboldService extends ChangeNotifier implements KoboldService {
  @override
  bool get isRunning => false;
  @override
  String get baseUrl => '';
  @override
  List<String> get logs => [];
  @override
  Future<void> startKobold(String executablePath, String modelPath, {int port = 5001, int gpuLayers = 0, int contextSize = 4096, bool useVulkan = false, bool useCLBlast = false, bool useCublas = false}) async {}
  @override
  Future<void> stopKobold() async {}
  @override
  Future<String> generate(String prompt, {int maxLength = 80, double temp = 0.7, double repPenalty = 1.1, double topP = 0.9, double minP = 0.0, int repPenTokens = 64, double? dynatempRange}) async => '';
  @override
  bool get isProcessAlive => false;
  @override
  void setBaseUrl(String url) {}
}

class MockBackendManager extends ChangeNotifier implements BackendManager {
  @override
  String? get backendPath => '/tmp/koboldcpp';
  @override 
  String? get error => null;
  @override
  bool get isDownloading => false;
  @override
  double get downloadProgress => 0.0;
   @override
  Future<void> checkBackendAvailability() async {}
    @override
  Future<void> downloadBackend() async {}
  @override
  String get statusMessage => '';
  @override
  bool get useRocm => false;
}

class MockModelManager extends ChangeNotifier implements ModelManager {
   @override
   List<File> get models => [];
    @override
   Future<void> refreshModels() async {}
   @override
   String? get currentDownload => null;
   @override
   double get downloadProgress => 0.0;
   @override
   bool get isDownloading => false;
   @override
   String get statusMessage => '';
   @override
   Future<void> downloadModel(String url, String filename) async {}
   @override
   Future<void> deleteModel(String path) async {}
   @override
   Future<List<Map<String, String>>> getModelFiles(String repoId) async => [];
   @override
   List<String> getRecommendedSearchQueries(int vramMb) => [];
   @override
   Future<List<Map<String, dynamic>>> searchHFModels(String query) async => [];
}


void main() {
  testWidgets('Use CuBLAS option should be disabled for non-NVIDIA GPUs', (WidgetTester tester) async {
    final mockHardware = MockHardwareService();
    mockHardware.setHardwareInfo(HardwareInfo(
      gpuName: 'AMD Radeon RX 6600', 
      vramMb: 8000, 
      ramMb: 16000, 
      vendor: 'AMD'
    ));

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<HardwareService>.value(value: mockHardware),
          ChangeNotifierProvider<StorageService>(create: (_) => MockStorageService()),
          ChangeNotifierProvider<KoboldService>(create: (_) => MockKoboldService()),
          ChangeNotifierProvider<BackendManager>(create: (_) => MockBackendManager()),
          ChangeNotifierProvider<ModelManager>(create: (_) => MockModelManager()),
           ChangeNotifierProvider<AppState>(create: (_) => AppState()),
        ],
        child: MaterialApp(home: const SettingsPage()),
      ),
    );

    // Navigate to Advanced Tab (Tab index 1)
    await tester.tap(find.text('Advanced / GPU'));
    await tester.pumpAndSettle();

    // Find the FilterChip
    final chipFinder = find.widgetWithText(FilterChip, 'Use CuBLAS (Nvidia)');
    expect(chipFinder, findsOneWidget);

    final chip = tester.widget<FilterChip>(chipFinder);
    expect(chip.onSelected, isNull, reason: 'Chip should be disabled for AMD');
  });

  testWidgets('Use CuBLAS option should be enabled for NVIDIA GPUs', (WidgetTester tester) async {
    final mockHardware = MockHardwareService();
    mockHardware.setHardwareInfo(HardwareInfo(
      gpuName: 'NVIDIA GeForce RTX 3060', 
      vramMb: 12000, 
      ramMb: 16000, 
      vendor: 'Nvidia'
    ));

    await tester.pumpWidget(
      MultiProvider(
      providers: [
          ChangeNotifierProvider<HardwareService>.value(value: mockHardware),
          ChangeNotifierProvider<StorageService>(create: (_) => MockStorageService()),
          ChangeNotifierProvider<KoboldService>(create: (_) => MockKoboldService()),
          ChangeNotifierProvider<BackendManager>(create: (_) => MockBackendManager()),
          ChangeNotifierProvider<ModelManager>(create: (_) => MockModelManager()),
           ChangeNotifierProvider<AppState>(create: (_) => AppState()),
        ],
        child: MaterialApp(home: const SettingsPage()),
      ),
    );

    // Navigate to Advanced Tab
    await tester.tap(find.text('Advanced / GPU'));
    await tester.pumpAndSettle();

    final chipFinder = find.widgetWithText(FilterChip, 'Use CuBLAS (Nvidia)');
    expect(chipFinder, findsOneWidget);

    final chip = tester.widget<FilterChip>(chipFinder);
    expect(chip.onSelected, isNotNull, reason: 'Chip should be enabled for Nvidia');
  });

  testWidgets('Use CuBLAS should default to TRUE for NVIDIA if not set', (WidgetTester tester) async {
    final mockHardware = MockHardwareService();
    // Simulate hardware detection completing finding Nvidia
    mockHardware.setPendingDetectionResult(HardwareInfo(
      gpuName: 'NVIDIA GeForce RTX 4090', 
      vramMb: 24000, 
      ramMb: 32000, 
      vendor: 'Nvidia'
    ));
    
    final mockStorage = MockStorageService(); 

    await tester.pumpWidget(
      MultiProvider(
      providers: [
          ChangeNotifierProvider<HardwareService>.value(value: mockHardware),
          ChangeNotifierProvider<StorageService>.value(value: mockStorage), // Use .value to keep state
          ChangeNotifierProvider<KoboldService>(create: (_) => MockKoboldService()),
          ChangeNotifierProvider<BackendManager>(create: (_) => MockBackendManager()),
          ChangeNotifierProvider<ModelManager>(create: (_) => MockModelManager()),
           ChangeNotifierProvider<AppState>(create: (_) => AppState()),
        ],
        child: MaterialApp(home: const SettingsPage()),
      ),
    );

    // Initial pump triggers detectHardware, which will use pending result
    await tester.pumpAndSettle();

    // Navigate to Advanced Tab
    await tester.tap(find.text('Advanced / GPU'));
    await tester.pumpAndSettle();

    final chipFinder = find.widgetWithText(FilterChip, 'Use CuBLAS (Nvidia)');
    expect(chipFinder, findsOneWidget);
    
    final chip = tester.widget<FilterChip>(chipFinder);
    expect(chip.selected, isTrue, reason: 'Should be selected by default for Nvidia');
    expect(chip.selected, isTrue, reason: 'Should be selected by default for Nvidia');
    expect(mockStorage.useCublas, isTrue, reason: 'Should persist true to storage');
  });

  testWidgets('Use Vulkan should default to TRUE for AMD if not set', (WidgetTester tester) async {
    final mockHardware = MockHardwareService();
    mockHardware.setPendingDetectionResult(HardwareInfo(
      gpuName: 'AMD Radeon RX 6600', 
      vramMb: 8000, 
      ramMb: 16000, 
      vendor: 'AMD'
    ));
    
    final mockStorage = MockStorageService(); 

    await tester.pumpWidget(
      MultiProvider(
      providers: [
          ChangeNotifierProvider<HardwareService>.value(value: mockHardware),
          ChangeNotifierProvider<StorageService>.value(value: mockStorage),
          ChangeNotifierProvider<KoboldService>(create: (_) => MockKoboldService()),
          ChangeNotifierProvider<BackendManager>(create: (_) => MockBackendManager()),
          ChangeNotifierProvider<ModelManager>(create: (_) => MockModelManager()),
           ChangeNotifierProvider<AppState>(create: (_) => AppState()),
        ],
        child: MaterialApp(home: const SettingsPage()),
      ),
    );

    await tester.pumpAndSettle();

    // Navigate to Advanced Tab
    await tester.tap(find.text('Advanced / GPU'));
    await tester.pumpAndSettle();

    final chipFinder = find.widgetWithText(FilterChip, 'Use Vulkan');
    expect(chipFinder, findsOneWidget);
    
    final chip = tester.widget<FilterChip>(chipFinder);
    expect(chip.selected, isTrue, reason: 'Should be selected by default for AMD');
    expect(mockStorage.useVulkan, isTrue, reason: 'Should persist true to storage');
    expect(mockStorage.useCublas, isFalse, reason: 'Cublas should be disabled');
  });
}
