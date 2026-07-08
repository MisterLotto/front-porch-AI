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

import 'settings_base.dart';

/// Image generation (A1111/Draw Things/remote) + Draw Things gRPC settings.
///
/// Lifted Stage 7.
class ImageGenSettings with SettingsBase {
  bool _imageGenEnabled = false;
  String _imageGenBackend =
      'remote'; // 'remote', 'a1111', 'drawthings', 'comfyui'
  String _localImageGenUrl = 'http://127.0.0.1:7860';
  String _comfyUiUrl = 'http://127.0.0.1:8188';
  String _imageGenModel = '';
  String _imageGenSize = '1024x1024';
  String _imageGenNegativePrompt = 'blurry, low quality, watermark, text';
  String _imageGenStyle = 'photorealistic';
  String _imageGenPromptParadigm = 'natural'; // 'natural', 'tags'
  String _imageGenLora = '';
  double _imageGenLoraWeight = 0.8;
  int _imageGenSteps = 20;
  double _imageGenCfgScale = 7.0;
  String _imageGenSampler = 'Euler a';
  int _imageGenSeed = -1;

  // Draw Things gRPC-specific
  String _drawThingsGrpcHost = '127.0.0.1';
  int _drawThingsGrpcPort = 7859;
  int _drawThingsSampler = 16;
  double _drawThingsShift = 3.0;
  double _drawThingsStrength = 1.0;
  int _drawThingsSeedMode = 2;
  bool _drawThingsTeaCache = false;
  bool _drawThingsCfgZeroStar = false;

  bool get imageGenEnabled => _imageGenEnabled;
  String get imageGenBackend => _imageGenBackend;
  String get localImageGenUrl => _localImageGenUrl;
  String get comfyUiUrl => _comfyUiUrl;
  String get imageGenModel => _imageGenModel;
  String get imageGenSize => _imageGenSize;
  String get imageGenNegativePrompt => _imageGenNegativePrompt;
  String get imageGenStyle => _imageGenStyle;
  String get imageGenPromptParadigm => _imageGenPromptParadigm;
  String get imageGenLora => _imageGenLora;
  double get imageGenLoraWeight => _imageGenLoraWeight;
  int get imageGenSteps => _imageGenSteps;
  double get imageGenCfgScale => _imageGenCfgScale;
  String get imageGenSampler => _imageGenSampler;
  int get imageGenSeed => _imageGenSeed;

  String get drawThingsGrpcHost => _drawThingsGrpcHost;
  int get drawThingsGrpcPort => _drawThingsGrpcPort;
  int get drawThingsSampler => _drawThingsSampler;
  double get drawThingsShift => _drawThingsShift;
  double get drawThingsStrength => _drawThingsStrength;
  int get drawThingsSeedMode => _drawThingsSeedMode;
  bool get drawThingsTeaCache => _drawThingsTeaCache;
  bool get drawThingsCfgZeroStar => _drawThingsCfgZeroStar;

  void load() {
    _imageGenEnabled = prefs?.getBool(k('image_gen_enabled')) ?? false;
    _imageGenBackend = prefs?.getString(k('image_gen_backend')) ?? 'remote';
    _localImageGenUrl =
        prefs?.getString(k('local_image_gen_url')) ?? 'http://127.0.0.1:7860';
    _comfyUiUrl =
        prefs?.getString(k('comfy_ui_url')) ?? 'http://127.0.0.1:8188';
    _imageGenModel = prefs?.getString(k('image_gen_model')) ?? '';
    _imageGenSize = prefs?.getString(k('image_gen_size')) ?? '1024x1024';
    _imageGenNegativePrompt =
        prefs?.getString(k('image_gen_negative_prompt')) ??
        'blurry, low quality, watermark, text';
    _imageGenStyle = prefs?.getString(k('image_gen_style')) ?? 'photorealistic';
    _imageGenPromptParadigm =
        prefs?.getString(k('image_gen_prompt_paradigm')) ?? 'natural';
    _imageGenLora = prefs?.getString(k('image_gen_lora')) ?? '';
    _imageGenLoraWeight = prefs?.getDouble(k('image_gen_lora_weight')) ?? 0.8;
    _imageGenSteps = prefs?.getInt(k('image_gen_steps')) ?? 20;
    _imageGenCfgScale = prefs?.getDouble(k('image_gen_cfg_scale')) ?? 7.0;
    _imageGenSampler = prefs?.getString(k('image_gen_sampler')) ?? 'Euler a';
    _imageGenSeed = prefs?.getInt(k('image_gen_seed')) ?? -1;

    _drawThingsGrpcHost =
        prefs?.getString(k('draw_things_grpc_host')) ?? '127.0.0.1';
    _drawThingsGrpcPort = prefs?.getInt(k('draw_things_grpc_port')) ?? 7859;
    _drawThingsSampler = prefs?.getInt(k('draw_things_sampler')) ?? 16;
    _drawThingsShift = prefs?.getDouble(k('draw_things_shift')) ?? 3.0;
    _drawThingsStrength = prefs?.getDouble(k('draw_things_strength')) ?? 1.0;
    _drawThingsSeedMode = prefs?.getInt(k('draw_things_seed_mode')) ?? 2;
    _drawThingsTeaCache = prefs?.getBool(k('draw_things_tea_cache')) ?? false;
    _drawThingsCfgZeroStar =
        prefs?.getBool(k('draw_things_cfg_zero_star')) ?? false;
  }

  Future<void> setImageGenEnabled(bool value) async {
    _imageGenEnabled = value;
    await prefs?.setBool(k('image_gen_enabled'), value);
    notify();
  }

  Future<void> setImageGenBackend(String value) async {
    _imageGenBackend = value;
    await prefs?.setString(k('image_gen_backend'), value);
    notify();
  }

  Future<void> setLocalImageGenUrl(String value) async {
    _localImageGenUrl = value;
    await prefs?.setString(k('local_image_gen_url'), value);
    notify();
  }

  Future<void> setComfyUiUrl(String value) async {
    _comfyUiUrl = value;
    await prefs?.setString(k('comfy_ui_url'), value);
    notify();
  }

  Future<void> setImageGenModel(String value) async {
    _imageGenModel = value;
    await prefs?.setString(k('image_gen_model'), value);
    notify();
  }

  Future<void> setImageGenSize(String value) async {
    _imageGenSize = value;
    await prefs?.setString(k('image_gen_size'), value);
    notify();
  }

  Future<void> setImageGenNegativePrompt(String value) async {
    _imageGenNegativePrompt = value;
    await prefs?.setString(k('image_gen_negative_prompt'), value);
    notify();
  }

  Future<void> setImageGenStyle(String value) async {
    _imageGenStyle = value;
    await prefs?.setString(k('image_gen_style'), value);
    notify();
  }

  Future<void> setImageGenPromptParadigm(String value) async {
    _imageGenPromptParadigm = value;
    await prefs?.setString(k('image_gen_prompt_paradigm'), value);
    notify();
  }

  Future<void> setImageGenLora(String value) async {
    _imageGenLora = value;
    await prefs?.setString(k('image_gen_lora'), value);
    notify();
  }

  Future<void> setImageGenLoraWeight(double value) async {
    _imageGenLoraWeight = value.clamp(0.0, 1.0);
    await prefs?.setDouble(k('image_gen_lora_weight'), _imageGenLoraWeight);
    notify();
  }

  Future<void> setImageGenSteps(int value) async {
    _imageGenSteps = value.clamp(5, 50);
    await prefs?.setInt(k('image_gen_steps'), _imageGenSteps);
    notify();
  }

  Future<void> setImageGenCfgScale(double value) async {
    _imageGenCfgScale = value.clamp(1.0, 20.0);
    await prefs?.setDouble(k('image_gen_cfg_scale'), _imageGenCfgScale);
    notify();
  }

  Future<void> setImageGenSampler(String value) async {
    _imageGenSampler = value;
    await prefs?.setString(k('image_gen_sampler'), value);
    notify();
  }

  Future<void> setImageGenSeed(int value) async {
    _imageGenSeed = value;
    await prefs?.setInt(k('image_gen_seed'), value);
    notify();
  }

  // Draw Things gRPC setters
  Future<void> setDrawThingsGrpcHost(String value) async {
    _drawThingsGrpcHost = value.trim();
    await prefs?.setString(k('draw_things_grpc_host'), _drawThingsGrpcHost);
    notify();
  }

  Future<void> setDrawThingsGrpcPort(int value) async {
    _drawThingsGrpcPort = value;
    await prefs?.setInt(k('draw_things_grpc_port'), value);
    notify();
  }

  Future<void> setDrawThingsSampler(int value) async {
    _drawThingsSampler = value;
    await prefs?.setInt(k('draw_things_sampler'), value);
    notify();
  }

  Future<void> setDrawThingsShift(double value) async {
    _drawThingsShift = value;
    await prefs?.setDouble(k('draw_things_shift'), value);
    notify();
  }

  Future<void> setDrawThingsStrength(double value) async {
    _drawThingsStrength = value.clamp(0.0, 1.0);
    await prefs?.setDouble(k('draw_things_strength'), _drawThingsStrength);
    notify();
  }

  Future<void> setDrawThingsSeedMode(int value) async {
    _drawThingsSeedMode = value;
    await prefs?.setInt(k('draw_things_seed_mode'), value);
    notify();
  }

  Future<void> setDrawThingsTeaCache(bool value) async {
    _drawThingsTeaCache = value;
    await prefs?.setBool(k('draw_things_tea_cache'), value);
    notify();
  }

  Future<void> setDrawThingsCfgZeroStar(bool value) async {
    _drawThingsCfgZeroStar = value;
    await prefs?.setBool(k('draw_things_cfg_zero_star'), value);
    notify();
  }
}
