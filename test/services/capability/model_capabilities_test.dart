// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:front_porch_ai/services/capability/model_capabilities.dart';
import 'package:front_porch_ai/utils/gguf_vision.dart';

void main() {
  group('ModelApiCapabilities.fromOpenRouterEntry', () {
    test('reads vision from architecture.input_modalities', () {
      final caps = ModelApiCapabilities.fromOpenRouterEntry({
        'id': 'anthropic/claude-3.5-sonnet',
        'architecture': {
          'input_modalities': ['text', 'image'],
          'output_modalities': ['text'],
        },
        'supported_parameters': ['tools', 'temperature'],
      });
      expect(caps.vision, isTrue);
      expect(caps.toolCalling, isTrue);
    });

    test('text-only model has neither vision nor tools', () {
      final caps = ModelApiCapabilities.fromOpenRouterEntry({
        'id': 'some/text-model',
        'architecture': {
          'input_modalities': ['text'],
        },
        'supported_parameters': ['temperature', 'top_p'],
      });
      expect(caps.vision, isFalse);
      expect(caps.toolCalling, isFalse);
    });

    test('tolerates missing/malformed fields', () {
      final caps = ModelApiCapabilities.fromOpenRouterEntry({'id': 'x'});
      expect(caps.vision, isFalse);
      expect(caps.toolCalling, isFalse);
    });
  });

  group('ModelApiCapabilities.fromNanoGptEntry', () {
    test('reads capabilities.vision and tool_calling', () {
      final caps = ModelApiCapabilities.fromNanoGptEntry({
        'id': 'gpt-4o',
        'capabilities': {'vision': true, 'tool_calling': true},
      });
      expect(caps.vision, isTrue);
      expect(caps.toolCalling, isTrue);
    });

    test('false capabilities parse to false', () {
      final caps = ModelApiCapabilities.fromNanoGptEntry({
        'id': 'text-only',
        'capabilities': {'vision': false, 'tool_calling': false},
      });
      expect(caps.vision, isFalse);
      expect(caps.toolCalling, isFalse);
    });

    test('missing capabilities object defaults to false', () {
      final caps = ModelApiCapabilities.fromNanoGptEntry({'id': 'basic'});
      expect(caps.vision, isFalse);
      expect(caps.toolCalling, isFalse);
    });
  });

  group('VisionSupport.fromApi', () {
    test('vision-capable caps → supported via apiMetadata', () {
      final s =
          VisionSupport.fromApi(const ModelApiCapabilities(vision: true));
      expect(s.supported, isTrue);
      expect(s.source, VisionSource.apiMetadata);
    });

    test('null or non-vision caps → none', () {
      expect(VisionSupport.fromApi(null).supported, isFalse);
      expect(
        VisionSupport.fromApi(const ModelApiCapabilities()).source,
        VisionSource.none,
      );
    });
  });

  group('VisionSupport.fromGguf', () {
    GgufVisionInfo info({
      bool embedded = false,
      bool multimodal = false,
      String arch = 'llama',
    }) =>
        GgufVisionInfo(
          architecture: arch,
          hasEmbeddedProjector: embedded,
          isMultimodal: multimodal,
        );

    test('embedded projector → supported (ggufEmbedded)', () {
      final s = VisionSupport.fromGguf(
        info(embedded: true, multimodal: true),
        mmprojConfigured: false,
      );
      expect(s.supported, isTrue);
      expect(s.source, VisionSource.ggufEmbedded);
    });

    test('multimodal + mmproj configured → supported (ggufWithMmproj)', () {
      final s = VisionSupport.fromGguf(
        info(multimodal: true),
        mmprojConfigured: true,
      );
      expect(s.supported, isTrue);
      expect(s.source, VisionSource.ggufWithMmproj);
    });

    test('multimodal without mmproj → not supported', () {
      final s = VisionSupport.fromGguf(
        info(multimodal: true),
        mmprojConfigured: false,
      );
      expect(s.supported, isFalse);
      expect(s.source, VisionSource.none);
    });

    test('text-only → not supported', () {
      final s =
          VisionSupport.fromGguf(info(), mmprojConfigured: true);
      expect(s.supported, isFalse);
    });

    test('null info → none', () {
      expect(
        VisionSupport.fromGguf(null, mmprojConfigured: true).supported,
        isFalse,
      );
    });
  });

  group('capability metadata host detection (shared helper)', () {
    test('OpenRouter and Nano-GPT hosts are metadata providers', () {
      expect(
        isCapabilityMetadataProviderUrl('https://openrouter.ai/api/v1'),
        isTrue,
      );
      expect(
        isCapabilityMetadataProviderUrl('https://nano-gpt.com/api/v1'),
        isTrue,
      );
      expect(isCapabilityMetadataProviderUrl('HTTPS://NANO-GPT.com/API/v1'),
          isTrue);
    });

    test('generic remotes, oMLX, and localhost are not', () {
      expect(
        isCapabilityMetadataProviderUrl('http://localhost:8000/v1'),
        isFalse,
      );
      expect(
        isCapabilityMetadataProviderUrl('http://192.168.1.20:1234/v1'),
        isFalse,
      );
      expect(isCapabilityMetadataProviderUrl('https://api.openai.com/v1'),
          isFalse);
      expect(isCapabilityMetadataProviderUrl(''), isFalse);
    });

    test('only Nano-GPT needs the detailed models request', () {
      expect(isNanoGptUrl('https://nano-gpt.com/api/v1'), isTrue);
      expect(isNanoGptUrl('https://openrouter.ai/api/v1'), isFalse);
    });
  });
}
