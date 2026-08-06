// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later
//
// This file is part of Front Porch AI.
//
// Front Porch AI is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Front Porch AI is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with Front Porch AI. If not, see <https://www.gnu.org/licenses/>.

part of 'tts_service.dart';

/// Buffered "speak the whole message" pipeline (extracted verbatim from
/// tts_service.dart, zero behaviour change).
extension TtsServiceSpeak on TtsService {
  /// Speak the given text using the active TTS engine.
  ///
  /// Generates audio for the entire message first (buffered), then plays
  /// it back seamlessly. Shows generation progress.
  Future<void> speak(String text, {String? voiceKey, String? messageId}) async {
    if (!_storageService.ttsEnabled) {
      print('TTS: disabled, skipping');
      return;
    }

    _lastError = null;
    await stop();

    // Resolve voice. A character's own voice deliberately wins over the
    // global one — say so in the log, because "I changed the voice in
    // Settings and it kept talking in the old one" is otherwise invisible.
    var voice = (voiceKey != null && voiceKey.isNotEmpty)
        ? voiceKey
        : _storageService.ttsVoiceModel;
    if (voice.isEmpty) {
      print('TTS: no voice configured');
      return;
    }
    if (voiceKey != null &&
        voiceKey.isNotEmpty &&
        voiceKey != _storageService.ttsVoiceModel) {
      print(
        'TTS: using this character\'s assigned voice "$voiceKey" instead of '
        'the global voice "${_storageService.ttsVoiceModel}".',
      );
    }

    // Defensive check: if the resolved voice key is clearly incompatible
    // with the current engine (e.g. Kokoro voice assigned to a character while
    // Piper is selected), fall back to the global voice for this engine.
    if (_isPiperEngine && !await _voiceManager.isVoiceInstalled(voice)) {
      print(
        'TTS WARNING: Character voice "$voice" not found for Piper engine. '
        'Falling back to global Piper voice. (This usually means a character '
        'was assigned a Kokoro voice while Piper was selected.)',
      );
      voice = _storageService.ttsVoiceModel;
      if (voice.isEmpty) return;
    }

    final sanitized = _sanitizeText(text);
    if (sanitized.trim().isEmpty) {
      print('TTS: text empty after sanitization');
      return;
    }

    final speed = _storageService.ttsSpeechRate;

    // Check cache — replay instantly if same message & same content
    final textHash = sanitized.hashCode;
    if (messageId != null &&
        messageId == _cachedMessageId &&
        textHash == _cachedTextHash &&
        voice == _cachedVoice &&
        _storageService.ttsEngine == _cachedEngine &&
        speed == _cachedSpeed &&
        _cachedWav != null &&
        _cachedWav!.existsSync()) {
      print('TTS: cache hit for message $messageId');
      _isSpeaking = true;
      _isGenerating = false;
      _currentMessageId = messageId;
      _notify();
      try {
        await _playWavFile(_cachedWav!);
      } catch (e) {
        print('TTS cache playback error: $e');
      } finally {
        _isSpeaking = false;
        _currentMessageId = null;
        _notify();
      }
      return;
    }

    // Different message — clear old cache
    if (messageId != _cachedMessageId) {
      _clearCache();
    }

    print(
      'TTS: engine=${_storageService.ttsEngine}, voice=$voice, text="${sanitized.substring(0, sanitized.length.clamp(0, 60))}..."',
    );
    _isSpeaking = true;
    _isGenerating = true;
    _generationProgress = 0.0;
    _currentMessageId = messageId;
    _notify();

    try {
      // For Kokoro, ensure model is downloaded
      if (_storageService.ttsEngine == 'kokoro') {
        final ready = await activeEngine.ensureModelReady(
          onProgress: (p) {
            _modelDownloadProgress = p;
            _isDownloadingModel = p < 1.0;
            _notify();
          },
        );
        _isDownloadingModel = false;
        if (!ready || !_isSpeaking) {
          print('TTS: Kokoro model not ready');
          return;
        }

        // Pre-start the worker pool so first audio doesn't have cold-start delay
        if (activeEngine is KokoroEngine) {
          unawaited((activeEngine as KokoroEngine).ensureWorkersWarm());
        }
      }

      final bool isKokoro = _storageService.ttsEngine == 'kokoro';
      final bool isPiper = _isPiperEngine;

      // Unified modern path for Kokoro (persistent) and Piper (one-shot).
      // Both now benefit from proper sanitization, smart chunking for long text,
      // real progress reporting, and correct ordering/collation.
      // Piper remains strictly one-shot under the hood (as the binary is designed).
      if (isKokoro || isPiper) {
        final engineName = isPiper ? 'Piper' : 'Kokoro';
        final modeLabel = _storageService.ttsNarrateQuotedOnly
            ? 'Only Quotes'
            : _storageService.ttsIgnoreAsterisks
            ? 'Ignore Asterisks'
            : 'Verbatim';
        kDebugPrint(
          '[TtsService] $engineName single full-text generation ($modeLabel mode)',
        );

        _generationProgress = 0.01;
        _isGenerating = true;
        _notify();

        List<File> generatedWavs = [];

        if (isPiper) {
          // Piper: per-chunk one-shot on the in-process sherpa engine
          // (sidecar retirement phase 4b — the legacy binary is gone).
          if (!await _ensurePiperVoice(voice)) {
            _isGenerating = false;
            _notify();
            return;
          }

          final bool readEverythingMode =
              !_storageService.ttsIgnoreAsterisks &&
              !_storageService.ttsNarrateQuotedOnly;

          final List<KokoroChunk> chunks;
          if (readEverythingMode) {
            chunks = KokoroChunker.splitFixedCharacterCount(
              text: sanitized,
              voice: voice,
              speed: speed,
              lang: 'en-us',
              modelPath: '',
              voicesPath: '',
              chunkSize: KokoroChunker.verbatimChunkSize,
            );
          } else {
            chunks = KokoroChunker.split(
              text: sanitized,
              voice: voice,
              speed: speed,
              lang: 'en-us',
              modelPath: '',
              voicesPath: '',
              maxChars: 450,
            );
          }

          final total = chunks.length;
          for (int i = 0; i < total; i++) {
            if (!_isSpeaking) break;

            final wav = await _piperGenerateWav(voice, chunks[i].text, i, speed);
            if (wav != null) {
              generatedWavs.add(wav);
            }

            _generationProgress = (i + 1) / total;
            _notify();
          }
        } else {
          // Kokoro: uses the persistent worker pool + internal chunking + collation
          final wav = await activeEngine.generateAudio(
            sanitized,
            voice,
            speed,
            onProgress: (progress) {
              _generationProgress = progress;
              _notify();
            },
          );

          if (wav != null) {
            generatedWavs = [wav];
          }
        }

        _isGenerating = false;
        _notify();

        if (generatedWavs.isNotEmpty && _isSpeaking) {
          File? finalAudio;

          if (generatedWavs.length == 1) {
            finalAudio = generatedWavs.first;
          } else {
            finalAudio = await WavUtils.concatenateWavFiles(generatedWavs);
            _cleanupFiles(generatedWavs);
          }

          if (finalAudio != null) {
            _cachedWav = finalAudio;
            _cachedMessageId = messageId;
            _cachedTextHash = sanitized.hashCode;
            _cachedVoice = voice;
            _cachedEngine = _storageService.ttsEngine;
            _cachedSpeed = speed;

            await _playWavFile(finalAudio);
          }
        } else {
          _generationProgress = 0.0;
          _notify();
        }

        return; // finally block will reset speaking state
      }

      final sentences = _splitSentences(sanitized);
      final wavFiles = <File?>[]; // Filled via OrderedAudioCollector for Kokoro

      // Phase 1: Generate audio
      // ElevenLabs is fast enough to process full text in one request —
      // skip sentence splitting for better intonation and fewer API calls.
      // (Kokoro and Piper returned above; only the cloud engines get here.)
      if (_storageService.ttsEngine == 'elevenlabs') {
        final engine = activeEngine;
        final speed = _storageService.ttsSpeechRate;
        _generationProgress = 0.5;
        _notify();
        final wav = await engine.generateAudio(sanitized, voice, speed);
        if (wav != null && _isSpeaking) {
          wavFiles.add(wav);
        }
        _generationProgress = 1.0;
        _notify();
      } else {
        // Parallel for Kokoro / OpenAI — all results go through the OrderedAudioCollector
        final engine = activeEngine;
        final speed = _storageService.ttsSpeechRate;
        final maxConcurrency = _storageService.ttsConcurrency;

        _audioCollector = OrderedAudioCollector(
          maxLookahead: _storageService.ttsAudioLookahead,
        );
        _audioCollector!.reset(); // Ensure clean state for new utterance

        kDebugPrint(
          '[TtsService] Starting parallel generation of ${sentences.length} sentences (concurrency=$maxConcurrency)',
        );

        for (
          int batchStart = 0;
          batchStart < sentences.length;
          batchStart += maxConcurrency
        ) {
          if (!_isSpeaking) break;

          final batchEnd = (batchStart + maxConcurrency).clamp(
            0,
            sentences.length,
          );
          final futures = <Future<File?>>[];

          for (int i = batchStart; i < batchEnd; i++) {
            futures.add(engine.generateAudio(sentences[i], voice, speed));
          }

          final results = await Future.wait(futures);

          bool failed = false;
          for (int j = 0; j < results.length; j++) {
            final sentenceIndex = batchStart + j;
            final file = results[j];

            if (file == null || !_isSpeaking) {
              failed = true;
              break;
            }

            // Submit to collector — it will only release files in the correct global order
            final readyFiles = _audioCollector!.submit(sentenceIndex, file);
            for (final readyFile in readyFiles) {
              wavFiles.add(readyFile); // We collect in correct order
            }
          }
          if (failed) break;

          _generationProgress = batchEnd / sentences.length;
          _notify();
        }
      }

      // wavFiles should be in correct order thanks to OrderedAudioCollector
      final validWavFiles = wavFiles.whereType<File>().toList();

      if (!_isSpeaking || validWavFiles.isEmpty) {
        _cleanupFiles(validWavFiles);
        return;
      }

      // Phase 2: Concatenate and play
      _isGenerating = false;
      _notify();

      File? audioFile;
      if (_storageService.ttsEngine == 'elevenlabs' &&
          validWavFiles.length == 1) {
        // ElevenLabs returns a single MP3 — play directly, no WAV concat needed.
        audioFile = validWavFiles.first;
      } else {
        audioFile = await WavUtils.concatenateWavFiles(validWavFiles);
        _cleanupFiles(validWavFiles);
      }

      if (audioFile != null && _isSpeaking) {
        // Cache the audio for instant replay
        _cachedWav = audioFile;
        _cachedMessageId = messageId;
        _cachedTextHash = sanitized.hashCode;
        _cachedVoice = voice;
        _cachedEngine = _storageService.ttsEngine;
        _cachedSpeed = speed;
        await _playWavFile(audioFile);
        // Don't delete — it's cached now
      }
    } on ElevenLabsApiException catch (e) {
      print('TTS ElevenLabs error: $e');
      _lastError = e.message;
      _isSpeaking = false;
      _isGenerating = false;
      _generationProgress = 0.0;
      _currentMessageId = null;
      _notify();
      return;
    } catch (e) {
      print('TTS error: $e');
    } finally {
      _isSpeaking = false;
      _isGenerating = false;
      _generationProgress = 0.0;
      _currentMessageId = null;
      _notify();
    }
  }
}
