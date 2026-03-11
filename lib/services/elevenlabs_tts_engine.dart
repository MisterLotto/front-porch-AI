import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:front_porch_ai/services/tts_engine.dart';
import 'package:front_porch_ai/services/tts_voice_info.dart';

/// ElevenLabs TTS engine — premium cloud-based TTS with expressive voices.
///
/// Uses the ElevenLabs Text-to-Speech API.
/// Requires an API key from https://elevenlabs.io
class ElevenLabsTtsEngine implements TtsEngine {
  String apiKey;
  String model;
  double stability;
  double similarityBoost;
  double style;

  /// Runtime-fetched voices (populated after calling [fetchVoices]).
  List<TtsVoiceInfo> _fetchedVoices = [];

  ElevenLabsTtsEngine({
    this.apiKey = '',
    this.model = 'eleven_flash_v2_5',
    this.stability = 0.5,
    this.similarityBoost = 0.75,
    this.style = 0.0,
  });

  static int _fileCounter = 0;

  @override
  String get engineName => 'ElevenLabs';

  @override
  String get engineId => 'elevenlabs';

  @override
  Future<bool> get isAvailable async => apiKey.isNotEmpty;

  @override
  Future<bool> ensureModelReady({void Function(double)? onProgress}) async => true;

  @override
  Future<File?> generateAudio(String text, String voice, double speed) async {
    if (apiKey.isEmpty) {
      print('ElevenLabs TTS: no API key configured');
      return null;
    }

    try {
      final response = await http.post(
        Uri.parse(
          'https://api.elevenlabs.io/v1/text-to-speech/$voice?output_format=pcm_22050',
        ),
        headers: {
          'xi-api-key': apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'model_id': model,
          'voice_settings': {
            'stability': stability,
            'similarity_boost': similarityBoost,
            'style': style,
            'use_speaker_boost': true,
          },
        }),
      );

      if (response.statusCode != 200) {
        print('ElevenLabs TTS error: ${response.statusCode} ${response.body}');
        return null;
      }

      // ElevenLabs returns raw PCM (16-bit signed, mono, 22050 Hz).
      // Wrap in a WAV header for compatibility with the TTS pipeline.
      final pcmBytes = response.bodyBytes;
      final wavBytes = _wrapPcmInWav(pcmBytes, sampleRate: 22050, channels: 1, bitsPerSample: 16);

      final tempDir = Directory.systemTemp;
      _fileCounter++;
      final outputFile = File(p.join(tempDir.path,
          'elevenlabs_tts_${DateTime.now().millisecondsSinceEpoch}_$_fileCounter.wav'));
      await outputFile.writeAsBytes(wavBytes);

      return outputFile;
    } catch (e) {
      print('ElevenLabs TTS error: $e');
      return null;
    }
  }

  /// Wrap raw PCM data in a standard WAV header.
  Uint8List _wrapPcmInWav(Uint8List pcmData, {
    required int sampleRate,
    required int channels,
    required int bitsPerSample,
  }) {
    final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
    final blockAlign = channels * (bitsPerSample ~/ 8);
    final dataSize = pcmData.length;
    final fileSize = 36 + dataSize;

    final header = ByteData(44);
    // RIFF
    header.setUint8(0, 0x52); header.setUint8(1, 0x49);
    header.setUint8(2, 0x46); header.setUint8(3, 0x46);
    header.setUint32(4, fileSize, Endian.little);
    // WAVE
    header.setUint8(8, 0x57); header.setUint8(9, 0x41);
    header.setUint8(10, 0x56); header.setUint8(11, 0x45);
    // fmt
    header.setUint8(12, 0x66); header.setUint8(13, 0x6D);
    header.setUint8(14, 0x74); header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little); // chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    // data
    header.setUint8(36, 0x64); header.setUint8(37, 0x61);
    header.setUint8(38, 0x74); header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);

    final result = Uint8List(44 + dataSize);
    result.setAll(0, header.buffer.asUint8List());
    result.setAll(44, pcmData);
    return result;
  }

  /// Fetch available voices from ElevenLabs API.
  /// Returns the list and caches it in [_fetchedVoices].
  Future<List<TtsVoiceInfo>> fetchVoices() async {
    if (apiKey.isEmpty) return _defaultVoices;

    try {
      final response = await http.get(
        Uri.parse('https://api.elevenlabs.io/v1/voices'),
        headers: {'xi-api-key': apiKey},
      );

      if (response.statusCode != 200) {
        print('ElevenLabs voices error: ${response.statusCode}');
        return _defaultVoices;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final voices = (data['voices'] as List?) ?? [];

      _fetchedVoices = voices.map((v) {
        final labels = v['labels'] as Map<String, dynamic>? ?? {};
        final gender = labels['gender']?.toString() ?? '';
        final accent = labels['accent']?.toString() ?? '';
        final description = labels['description']?.toString() ?? '';
        final name = v['name']?.toString() ?? 'Unknown';
        final subtitle = [
          if (gender.isNotEmpty) gender,
          if (accent.isNotEmpty) accent,
          if (description.isNotEmpty) description,
        ].join(', ');

        return TtsVoiceInfo(
          id: v['voice_id']?.toString() ?? '',
          name: '$name${subtitle.isNotEmpty ? ' ($subtitle)' : ''}',
          gender: gender.toLowerCase().contains('female') ? 'Female'
              : gender.toLowerCase().contains('male') ? 'Male'
              : 'Neutral',
          language: 'Multilingual',
          engine: 'elevenlabs',
        );
      }).where((v) => v.id.isNotEmpty).toList();

      return _fetchedVoices;
    } catch (e) {
      print('ElevenLabs fetchVoices error: $e');
      return _defaultVoices;
    }
  }

  @override
  List<TtsVoiceInfo> get availableVoices =>
      _fetchedVoices.isNotEmpty ? _fetchedVoices : _defaultVoices;

  /// Default premade voices available on all ElevenLabs accounts.
  static const _defaultVoices = [
    TtsVoiceInfo(id: 'EXAVITQu4vr4xnSDxMaL', name: 'Sarah', gender: 'Female', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'FGY2WhTYpPnrIDTdsKH5', name: 'Laura', gender: 'Female', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'IKne3meq5aSn9XLyUdCD', name: 'Charlie', gender: 'Male', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'JBFqnCBsd6RMkjVDRZzb', name: 'George', gender: 'Male', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'N2lVS1w4EtoT3dr4eOWO', name: 'Callum', gender: 'Male', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'TX3LPaxmHKxFdv7VOQHJ', name: 'Liam', gender: 'Male', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'XB0fDUnXU5powFXDhCwa', name: 'Charlotte', gender: 'Female', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'Xb7hH8MSUJpSbSDYk0k2', name: 'Alice', gender: 'Female', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'bIHbv24MWmeRgasZH58o', name: 'Will', gender: 'Male', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'cgSgspJ2msm6clMCkdW9', name: 'Jessica', gender: 'Female', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'cjVigY5qzO86Huf0OWal', name: 'Eric', gender: 'Male', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'iP95p4xoKVk53GoZ742B', name: 'Chris', gender: 'Male', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'nPczCjzI2devNBz1zQrb', name: 'Brian', gender: 'Male', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'onwK4e9ZLuTAKqWW03F9', name: 'Daniel', gender: 'Male', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'pFZP5JQG7iQjIQuC4Bku', name: 'Lily', gender: 'Female', language: 'Multilingual', engine: 'elevenlabs'),
    TtsVoiceInfo(id: 'pqHfZKP75CvOlQylNhV4', name: 'Bill', gender: 'Male', language: 'Multilingual', engine: 'elevenlabs'),
  ];
}
