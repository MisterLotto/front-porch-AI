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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:front_porch_ai/models/models.dart';
import 'package:front_porch_ai/services/services.dart';

import 'package:front_porch_ai/ui/widgets/widgets.dart';
import 'external_image_widget.dart';

/// Applies a font family to a base TextStyle dynamically.
/// Uses Google Fonts for web-hosted fonts, otherwise applies system fonts directly.
TextStyle _applyGoogleFont(String? fontFamily, TextStyle baseStyle) {
  if (fontFamily == null || fontFamily.isEmpty) return baseStyle;

  switch (fontFamily) {
    case 'Roboto':
      return GoogleFonts.roboto(textStyle: baseStyle);
    case 'Open Sans':
      return GoogleFonts.openSans(textStyle: baseStyle);
    case 'Lato':
      return GoogleFonts.lato(textStyle: baseStyle);
    case 'Source Sans 3':
      return GoogleFonts.sourceSans3(textStyle: baseStyle);
    case 'Nunito':
      return GoogleFonts.nunito(textStyle: baseStyle);
    case 'Poppins':
      return GoogleFonts.poppins(textStyle: baseStyle);
    case 'Montserrat':
      return GoogleFonts.montserrat(textStyle: baseStyle);
    case 'Raleway':
      return GoogleFonts.raleway(textStyle: baseStyle);
    case 'Work Sans':
      return GoogleFonts.workSans(textStyle: baseStyle);
    case 'DM Sans':
      return GoogleFonts.dmSans(textStyle: baseStyle);
    case 'Quicksand':
      return GoogleFonts.quicksand(textStyle: baseStyle);
    case 'Rubik':
      return GoogleFonts.rubik(textStyle: baseStyle);
    case 'Karla':
      return GoogleFonts.karla(textStyle: baseStyle);
    case 'Merriweather':
      return GoogleFonts.merriweather(textStyle: baseStyle);
    case 'Playfair Display':
      return GoogleFonts.playfairDisplay(textStyle: baseStyle);
    case 'Roboto Mono':
      return GoogleFonts.robotoMono(textStyle: baseStyle);
    case 'Fira Code':
      return GoogleFonts.firaCode(textStyle: baseStyle);
    case 'Source Code Pro':
      return GoogleFonts.sourceCodePro(textStyle: baseStyle);
    // System fonts — apply as named fontFamily directly
    case 'serif':
      return baseStyle.copyWith(fontFamily: 'Times New Roman');
    case 'sans-serif':
      return baseStyle.copyWith(fontFamily: 'Arial');
    case 'monospace':
      return baseStyle.copyWith(fontFamily: 'Courier New');
    default:
      return baseStyle.copyWith(fontFamily: fontFamily);
  }
}

final _markdownImageRegex = RegExp(r'!\[([^\]]*)\]\((https?://[^)]+)\)');

/// Styled chat message with quote/action coloring and external image support.
///
/// Stateful purely for PARSE CACHING: during streaming the whole visible
/// message list rebuilds many times a second, and re-running the markdown
/// scan + dialogue/action tokenizer + Google-Fonts style resolution for
/// every unchanged message was the dominant UI-thread cost. Parse results
/// are cached keyed on the source text (identical() fast path — unchanged
/// messages keep the same string object; only the streaming bubble re-parses)
/// and the three resolved styles are cached on their inputs. Widgets are
/// still constructed fresh each build (cheap), so callbacks never go stale.
class StyledChatMessage extends StatefulWidget {
  final String text;
  final bool isUser;
  final bool? externalImagesAllowed;
  final Future<bool> Function()? onRequestImagePermission;
  final CharacterCard? character;
  final ChatThemePreset? themePreset;
  final ChatThemeOverrides? themeOverrides;

  const StyledChatMessage({
    super.key,
    required this.text,
    required this.isUser,
    this.externalImagesAllowed,
    this.onRequestImagePermission,
    this.character,
    this.themePreset,
    this.themeOverrides,
  });

  @override
  State<StyledChatMessage> createState() => _StyledChatMessageState();
}

class _StyledChatMessageState extends State<StyledChatMessage> {
  // Text-derived caches (invalidated when the source string changes).
  String? _parseSource;
  List<RegExpMatch>? _imageMatches;
  final Map<
    String,
    List<({int start, int end, String matchText, StyledTokenType type})>
  >
  _tokenCache = {};

  // Style caches (invalidated when any styling input changes).
  (String?, Color, Color, Color, double)? _styleKey;
  TextStyle? _plainStyle;
  TextStyle? _dialogueStyle;
  TextStyle? _actionStyle;
  TextStyle? _rootStyle;

  List<({int start, int end, String matchText, StyledTokenType type})>
  _tokensFor(String segment) =>
      _tokenCache.putIfAbsent(segment, () => tokenizeChat(segment).toList());

  void _refreshStyles(StorageService storageService, double scaledSize) {
    final character = widget.character;
    final fontFamily = storageService.getChatFontFamily(
      character,
      widget.themePreset,
      widget.themeOverrides,
    );
    final textColor = widget.isUser
        ? storageService.getUserTextColor(
            character,
            widget.themePreset,
            widget.themeOverrides,
          )
        : storageService.getAiTextColor(
            character,
            widget.themePreset,
            widget.themeOverrides,
          );
    final dialogueColor = storageService.getDialogueColor(
      character,
      widget.themePreset,
      widget.themeOverrides,
    );
    final actionColor = storageService.getActionColor(
      character,
      widget.themePreset,
      widget.themeOverrides,
    );
    final key = (fontFamily, textColor, dialogueColor, actionColor, scaledSize);
    if (key == _styleKey) return;
    _styleKey = key;
    _plainStyle = _applyGoogleFont(
      fontFamily,
      TextStyle(color: textColor, fontSize: scaledSize),
    );
    _dialogueStyle = _applyGoogleFont(
      fontFamily,
      TextStyle(
        color: dialogueColor,
        fontWeight: FontWeight.w500,
        fontSize: scaledSize,
      ),
    );
    _actionStyle = _applyGoogleFont(
      fontFamily,
      TextStyle(color: actionColor, fontSize: scaledSize),
    );
    _rootStyle = _applyGoogleFont(
      fontFamily,
      TextStyle(color: textColor, fontSize: scaledSize, height: 1.4),
    );
  }

  @override
  Widget build(BuildContext context) {
    final storageService = Provider.of<StorageService>(context);
    final scaledSize = 14.0 * storageService.textScale;
    final text = widget.text;
    _refreshStyles(storageService, scaledSize);

    // Check for markdown images (cached per source text).
    if (!identical(text, _parseSource)) {
      _parseSource = text;
      _tokenCache.clear();
      _imageMatches = _markdownImageRegex.allMatches(text).toList();
    }
    final imageMatches = _imageMatches!;
    if (imageMatches.isEmpty) {
      // No images — use existing fast path
      return _buildStyledText(text);
    }

    // Split text into segments: [text, image, text, image, text]
    final widgets = <Widget>[];
    int lastEnd = 0;

    for (final match in imageMatches) {
      // Text before this image
      if (match.start > lastEnd) {
        final textBefore = text.substring(lastEnd, match.start).trim();
        if (textBefore.isNotEmpty) {
          widgets.add(_buildStyledText(textBefore));
        }
      }

      final altText = match.group(1) ?? '';
      final imageUrl = match.group(2)!;

      // Image placeholder or loaded image
      widgets.add(
        ExternalImageWidget(
          url: imageUrl,
          altText: altText,
          allowed: widget.externalImagesAllowed,
          onRequestPermission: widget.onRequestImagePermission,
        ),
      );

      lastEnd = match.end;
    }

    // Remaining text after last image
    if (lastEnd < text.length) {
      final textAfter = text.substring(lastEnd).trim();
      if (textAfter.isNotEmpty) {
        widgets.add(_buildStyledText(textAfter));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildStyledText(String segment) {
    final tokens = _tokensFor(segment);

    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final t in tokens) {
      if (t.start > lastEnd) {
        spans.add(TextSpan(
          text: segment.substring(lastEnd, t.start),
          style: _plainStyle,
        ));
      }
      spans.add(TextSpan(
        text: t.matchText,
        style: t.type == StyledTokenType.dialogue
            ? _dialogueStyle
            : _actionStyle,
      ));
      lastEnd = t.end;
    }
    if (lastEnd < segment.length) {
      spans.add(TextSpan(
        text: segment.substring(lastEnd),
        style: _plainStyle,
      ));
    }

    if (spans.isEmpty) {
      return SelectionArea(child: Text(segment, style: _rootStyle));
    }

    return SelectionArea(
      child: RichText(
        text: TextSpan(style: _rootStyle, children: spans),
      ),
    );
  }
}
