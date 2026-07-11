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

import 'package:front_porch_ai/services/capability/image_reference_role.dart';
import 'package:front_porch_ai/services/image_gen_service.dart'
    show ImageGenBackend;

/// Adapter that maps the active [ImageGenBackend] to the pure backend bits
/// [resolveCapability] needs — the ONE place the service enum meets the pure
/// seam, so `image_reference_role.dart` stays dependency-free and unit-testable.
///
/// Stateless and cheap (pure sync, no network/file I/O), so there is no cache —
/// the intent of `VisionSupportResolver` without its cost.
class ImageReferenceResolver {
  const ImageReferenceResolver._();

  /// The reference capability for the active backend + model.
  ///
  /// Edit GENERATION is wired per backend as phases land; a backend whose edit
  /// path isn't built yet passes `backendEditMaxImages: 0`, so its Edit tab
  /// honestly degrades instead of appearing-and-failing. Today only Draw Things
  /// edit is wired (Phase 2); ComfyUI + remote turn on in Phase 5, and Draw
  /// Things reaches [kQwenEditMaxImages] once its multi-image plumbing lands
  /// (Phase 6).
  static ImageReferenceCapability resolveForBackend({
    required ImageGenBackend backend,
    required String modelName,
  }) {
    switch (backend) {
      case ImageGenBackend.a1111:
        // Stock A1111 / Forge is classic denoise only — never edit-conditioning.
        return resolveCapability(
          modelName: modelName,
          backendSupportsImg2img: true,
          backendEditMaxImages: 0,
        );
      case ImageGenBackend.drawThings:
        return resolveCapability(
          modelName: modelName,
          backendSupportsImg2img: true,
          backendEditMaxImages: kDrawThingsEditMaxImages,
        );
      case ImageGenBackend.comfyUi:
        // Phase 5 wires edit here (uncapped ceiling + a live /object_info node
        // check). Until then edit is off, with honest "coming" copy so an edit
        // model on ComfyUI is never told to "try ComfyUI".
        return resolveCapability(
          modelName: modelName,
          backendSupportsImg2img: true,
          backendEditMaxImages: 0,
          backendEditUnavailableReason:
              'Editing on ComfyUI is coming in an update. For now, use Draw '
              'Things for edits, or Create.',
        );
      case ImageGenBackend.remote:
        // Phase 5 wires edit here (useRemoteAllowlist + a per-model ceiling).
        return resolveCapability(
          modelName: modelName,
          backendSupportsImg2img: false,
          backendEditMaxImages: 0,
          backendEditUnavailableReason:
              'Editing with remote models is coming in an update. For now, use '
              'Draw Things for edits, or Create.',
        );
    }
  }
}
