import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:front_porch_ai/services/kobold_binary_version.dart';
import 'package:front_porch_ai/services/llm_service.dart';
import 'package:front_porch_ai/services/openai_chat_stream.dart';
import 'package:path/path.dart' as path;

class PseudoRemoteService extends LLMService {
  Process? _process;
  bool _isRunning = false;
  bool _isStarting = false;
  String _baseUrl = 'http://127.0.0.1:5001';
  Timer? _readinessProbe;
  bool _modelReady = false;
  final List<String> _logs = [];
  String? _executablePath;
  http.Client? _activeClient;

  // LLMService interface
  @override
  bool get isReady => _isRunning && _modelReady;
  @override
  String get backendName => 'PseudoRemote';
  bool get isRunning => _isRunning;
  bool get isProcessRunning => _isRunning;
  bool get isStarting => _isStarting;
  List<String> get logs => List.unmodifiable(_logs);
  String get modelName => 'PseudoRemote (KoboldCPP)';

  PseudoRemoteService();

  /// Probe the KoboldCPP server — same as KoboldService.reconnectIfAlive().
  Future<void> reconnectIfAlive() async {
    if (_isRunning) return;
    if (_process == null) return;
    final client = http.Client();
    try {
      final uri = Uri.parse('$_baseUrl/api/extra/version');
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        debugPrint(
          '[PseudoRemote] Reconnected to existing KoboldCPP instance.',
        );
        _isRunning = true;
        _modelReady = true;
        notifyListeners();
        await _syncVersionFromResponse(response);
      }
    } catch (_) {
    } finally {
      client.close();
    }
  }

  Future<void> start({
    required String executablePath,
    required String kcppsPath,
    String? modelPath,
    String? mmprojPath,
    int port = 5001,
  }) async {
    if (_isStarting) return;
    if (_isRunning || _process != null) {
      debugPrint(
        '[PseudoRemote] start called while still running — stopping first.',
      );
      await stop();
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    _isStarting = true;
    _executablePath = executablePath;

    final args = [
      '--config',
      kcppsPath,
      '--port',
      port.toString(),
      if (modelPath != null && modelPath.isNotEmpty) ...['--model', modelPath],
      // Vision projector: only when configured AND the file exists, so a stale
      // mmproj path never aborts the launch. Mirrors KoboldService.startKobold.
      if (mmprojPath != null &&
          mmprojPath.isNotEmpty &&
          File(mmprojPath).existsSync())
        ...['--mmproj', mmprojPath],
    ];

    try {
      _process = await Process.start(
        executablePath,
        args,
        workingDirectory: path.dirname(executablePath),
      );
      _isRunning = true;
      _modelReady = false;
      _addLog('Starting Koboldcpp (PseudoRemote)...');
      _addLog('Command: $executablePath ${args.join(' ')}');
      notifyListeners();

      _startReadinessProbe();

      _process!.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen((data) {
            _addLog(data);
            _parseLoadingStatus(data);
          });

      _process!.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .listen((data) {
            var cleanData = data.trim();
            if (cleanData.isNotEmpty) {
              cleanData = cleanData
                  .replaceAll('ERR: ', '')
                  .replaceAll('ERR:', '');
              if (cleanData != '.' && cleanData != '..' && cleanData != '...') {
                _addLog(cleanData);
                _parseLoadingStatus(cleanData);
              }
            }
          });

      _process!.exitCode.then((code) {
        _isRunning = false;
        _process = null;
        _addLog('Process exited with code $code');
        notifyListeners();
      });
    } catch (e) {
      _addLog('Failed to start process: $e');
      _isRunning = false;
      notifyListeners();
      rethrow;
    } finally {
      _isStarting = false;
    }
  }

  // Same KoboldCpp server as the managed local backend — same tool door
  // (capable models like the Qwen3 family call tools; the rest yield no
  // calls and the Journal's negotiation falls back to its XML transport).
  @override
  Future<LlmToolResponse?> generateWithTools(
    GenerationParams params,
    List<Map<String, dynamic>> tools,
  ) async {
    if (!isReady) return null;
    return postOpenAiChatWithTools(
      _baseUrl,
      params,
      tools,
      registerClient: (client) => _activeClient = client,
      onDone: () => _activeClient = null,
    );
  }

  @override
  Stream<String> generateStream(GenerationParams params) async* {
    if (!isReady) {
      throw Exception('PseudoRemote backend not ready.');
    }
    // Shared OpenAI chat transport (same one the managed KoboldCpp backend now
    // uses). `_baseUrl` is the KoboldCpp root; the helper appends
    // `/v1/chat/completions`.
    yield* streamOpenAiChat(
      _baseUrl,
      params,
      registerClient: (client) => _activeClient = client,
      onDone: () => _activeClient = null,
    );
  }

  @override
  void abortGeneration() {
    _activeClient?.close();
    _activeClient = null;
  }

  // ── Readiness probe ──

  static final RegExp _readyPattern = RegExp(
    r'(please connect|server listen|starting server|ready to)',
    caseSensitive: false,
  );
  static final RegExp _loadModelPattern = RegExp(
    r'loading (the )?model',
    caseSensitive: false,
  );
  static final RegExp _loadFilePattern = RegExp(
    r'loading (hf|gguf|safetensors|model file)',
    caseSensitive: false,
  );
  static final RegExp _mappingPattern = RegExp(
    r'(mapping model|ggml_backend|allocat)',
    caseSensitive: false,
  );
  static final RegExp _warmupPattern = RegExp(
    r'warm(ing)? up',
    caseSensitive: false,
  );
  static final RegExp _progressLinePattern = RegExp(
    r'^(Generating \(|Processing Prompt(?: \[BATCH\])? \()',
    caseSensitive: false,
  );

  void _startReadinessProbe() {
    _stopReadinessProbe();
    _readinessProbe = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _probeVersion(),
    );
  }

  void _stopReadinessProbe() {
    _readinessProbe?.cancel();
    _readinessProbe = null;
  }

  Future<void> _probeVersion() async {
    if (_modelReady) {
      _stopReadinessProbe();
      return;
    }
    final client = http.Client();
    try {
      final uri = Uri.parse('$_baseUrl/api/extra/version');
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 3));
      if (response.statusCode == 200) {
        _modelReady = true;
        _stopReadinessProbe();
        notifyListeners();
        await _syncVersionFromResponse(response);
      }
    } catch (_) {
    } finally {
      client.close();
    }
  }

  Future<void> _syncVersionFromResponse(http.Response response) async {
    if (_executablePath == null) return;
    try {
      final v = jsonDecode(response.body)['version'] as String?;
      if (v != null && v.isNotEmpty) {
        await KoboldBinaryVersion.write(
          path.dirname(_executablePath!),
          version: v,
          size: File(_executablePath!).lengthSync(),
        );
      }
    } catch (_) {}
  }

  void _parseLoadingStatus(String data) {
    if (_readyPattern.hasMatch(data)) {
      _modelReady = true;
      _stopReadinessProbe();
      notifyListeners();
      return;
    }
    if (!_modelReady) {
      if (_loadModelPattern.hasMatch(data)) {
        notifyListeners();
      } else if (_loadFilePattern.hasMatch(data)) {
        notifyListeners();
      } else if (_mappingPattern.hasMatch(data)) {
        notifyListeners();
      } else if (_warmupPattern.hasMatch(data)) {
        notifyListeners();
      }
    }
  }

  void _addLog(String data) {
    if (data.trim().isEmpty) return;
    final rawLines = data.split(RegExp(r'\r\n|\r|\n'));
    bool changed = false;
    for (final rawLine in rawLines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final isProgress = _progressLinePattern.hasMatch(line);
      if (isProgress && _logs.isNotEmpty) {
        final lastEntry = _logs.last;
        if (_progressLinePattern.hasMatch(lastEntry)) {
          _logs.last = line;
          changed = true;
          continue;
        }
      }
      _logs.add(line);
      if (_logs.length > 1000) _logs.removeAt(0);
      changed = true;
    }
    if (changed) notifyListeners();
  }

  // ── Utilities ──

  Future<Map<String, dynamic>?> fetchPerf() async {
    final client = http.Client();
    try {
      final uri = Uri.parse('$_baseUrl/api/extra/perf');
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 2));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {
    } finally {
      client.close();
    }
    return null;
  }

  Future<int> countTokens(String text) async {
    if (text.isEmpty) return 0;
    try {
      final uri = Uri.parse('$_baseUrl/api/extra/tokencount');
      final client = http.Client();
      try {
        final response = await client
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'prompt': text}),
            )
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return (data['value'] as num?)?.toInt() ?? (text.length / 4).ceil();
        }
      } finally {
        client.close();
      }
    } catch (_) {}
    return (text.length / 4).ceil();
  }

  Future<void> stop() async {
    if (_process != null) {
      final pid = _process!.pid;
      _addLog('Stopping PseudoRemote Backend (PID: $pid)...');

      if (Platform.isWindows) {
        try {
          await Process.run('taskkill', ['/F', '/T', '/PID', pid.toString()]);
          _addLog('Force killed process tree.');
        } catch (e) {
          _addLog('Taskkill failed, trying standard kill: $e');
          _process!.kill();
        }
      } else {
        try {
          _addLog('Killing child processes of PID $pid...');
          await Process.run('pkill', ['-TERM', '-P', pid.toString()]);
          _process?.kill(ProcessSignal.sigterm);
          _addLog('Sent SIGTERM to parent and children.');
          bool exited = false;
          for (int i = 0; i < 6; i++) {
            await Future.delayed(const Duration(milliseconds: 500));
            try {
              final check = await Process.run('kill', ['-0', pid.toString()]);
              if (check.exitCode != 0) {
                exited = true;
                break;
              }
            } catch (_) {
              exited = true;
              break;
            }
          }
          if (!exited) {
            _addLog('Process did not exit gracefully, sending SIGKILL...');
            await Process.run('pkill', ['-KILL', '-P', pid.toString()]);
            _process?.kill(ProcessSignal.sigkill);
          }
          if (_executablePath != null) {
            final exeName = path.basename(_executablePath!);
            _addLog('Cleaning up any remaining $exeName processes...');
            await Process.run('pkill', ['-KILL', '-f', exeName]);
          }
        } catch (e) {
          _addLog('Process cleanup failed, using fallback: $e');
          _process?.kill(ProcessSignal.sigkill);
          if (_executablePath != null) {
            final exeName = path.basename(_executablePath!);
            try {
              await Process.run('pkill', ['-KILL', '-f', exeName]);
            } catch (_) {}
          }
        }
      }

      try {
        await _process?.exitCode.timeout(const Duration(seconds: 2));
      } catch (_) {}

      _process = null;
      _isRunning = false;
      _modelReady = false;
      _stopReadinessProbe();
      notifyListeners();
    }
  }
}
