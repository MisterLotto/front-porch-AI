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

import 'dart:io';
import 'dart:ui' show BoxHeightStyle, BoxWidthStyle;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:front_porch_ai/services/desktop_spell_check_service.dart';

// Re-export so callers can reference SpellCheckConfiguration without an extra
// import when they need to explicitly opt out on a technical input field.
export 'package:flutter/material.dart' show SpellCheckConfiguration;

/// The standard text input widget for all user-facing **prose** fields across
/// Front Porch AI (chat input, character descriptions, system prompts, lore
/// entries, story prose, etc.).
///
/// ## Why this wrapper exists
///
/// Flutter's [TextField] has platform-native spell check support via
/// [spellCheckConfiguration], but it is **disabled by default** on every
/// platform. There is no `ThemeData` hook for it, so the only maintainable
/// approach is a shared wrapper that enables it centrally.
///
/// ## Platform behaviour
///
/// | Platform | Spell check service            |
/// |----------|-------------------------------|
/// | macOS    | `NSSpellChecker`              |
/// | Windows  | Windows Spell Checking API    |
/// | iOS/Android | OS keyboard handles it (no override needed) |
/// | Linux    | Not yet supported by Flutter  |
///
/// This widget only injects [SpellCheckConfiguration] on macOS and Windows.
/// All other platforms fall through to Flutter's native defaults.
///
/// ## Opting out (technical inputs)
///
/// API keys, URLs, host/port fields, model names, search bars, and other
/// non-prose inputs should remain as a plain [TextField] **or** pass
/// `spellCheckConfiguration: SpellCheckConfiguration.disabled()` explicitly.
/// Keeping that intent visible at the call site makes it clear in code review
/// that the omission is deliberate, not an oversight.
///
/// ## Drop-in replacement
///
/// [AppTextField] is a true structural alias for [TextField] — it proxies every
/// constructor parameter. Swapping `TextField(` for `AppTextField(` requires no
/// other changes.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.undoController,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textDirection,
    this.readOnly = false,
    this.showCursor,
    this.autofocus = false,
    this.statesController,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    this.smartDashesType,
    this.smartQuotesType,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onAppPrivateCommand,
    this.inputFormatters,
    this.enabled,
    this.ignorePointers,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius,
    this.cursorOpacityAnimates,
    this.cursorColor,
    this.cursorErrorColor,
    this.selectionHeightStyle = BoxHeightStyle.tight,
    this.selectionWidthStyle = BoxWidthStyle.tight,
    this.keyboardAppearance,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.dragStartBehavior = DragStartBehavior.start,
    this.enableInteractiveSelection,
    this.selectionControls,
    this.onTap,
    this.onTapAlwaysCalled = false,
    this.onTapOutside,
    this.mouseCursor,
    this.buildCounter,
    this.scrollController,
    this.scrollPhysics,
    this.autofillHints = const <String>[],
    this.contentInsertionConfiguration,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.stylusHandwritingEnabled = true,
    this.enableIMEPersonalizedLearning = true,
    this.contextMenuBuilder,
    // Spell check: callers may override explicitly. Passing
    // SpellCheckConfiguration.disabled() at the call site documents
    // intent clearly for technical inputs (API keys, URLs, etc.).
    this.spellCheckConfiguration,
    this.magnifierConfiguration,
    this.onTapUpOutside,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final UndoHistoryController? undoController;
  final InputDecoration? decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final StrutStyle? strutStyle;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final TextDirection? textDirection;
  final bool readOnly;
  final bool? showCursor;
  final bool autofocus;
  final WidgetStatesController? statesController;
  final String obscuringCharacter;
  final bool obscureText;
  final bool autocorrect;
  final SmartDashesType? smartDashesType;
  final SmartQuotesType? smartQuotesType;
  final bool enableSuggestions;
  final int? maxLines;
  final int? minLines;
  final bool expands;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onEditingComplete;
  final ValueChanged<String>? onSubmitted;
  final AppPrivateCommandCallback? onAppPrivateCommand;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;
  final bool? ignorePointers;
  final double cursorWidth;
  final double? cursorHeight;
  final Radius? cursorRadius;
  final bool? cursorOpacityAnimates;
  final Color? cursorColor;
  final Color? cursorErrorColor;
  final BoxHeightStyle selectionHeightStyle;
  final BoxWidthStyle selectionWidthStyle;
  final Brightness? keyboardAppearance;
  final EdgeInsets scrollPadding;
  final DragStartBehavior dragStartBehavior;
  final bool? enableInteractiveSelection;
  final TextSelectionControls? selectionControls;
  final GestureTapCallback? onTap;
  final bool onTapAlwaysCalled;
  final TapRegionCallback? onTapOutside;
  final MouseCursor? mouseCursor;
  final InputCounterWidgetBuilder? buildCounter;
  final ScrollController? scrollController;
  final ScrollPhysics? scrollPhysics;
  final Iterable<String>? autofillHints;
  final ContentInsertionConfiguration? contentInsertionConfiguration;
  final Clip clipBehavior;
  final String? restorationId;
  final bool stylusHandwritingEnabled;
  final bool enableIMEPersonalizedLearning;
  final EditableTextContextMenuBuilder? contextMenuBuilder;
  final SpellCheckConfiguration? spellCheckConfiguration;
  final TextMagnifierConfiguration? magnifierConfiguration;
  final TapRegionUpCallback? onTapUpOutside;

  /// Returns the correct [SpellCheckConfiguration] for the current platform,
  /// or `null` on unsupported platforms (Linux, web, etc.).
  ///
  /// Exposed as a static so other widgets that cannot use [AppTextField]
  /// (e.g. [TextFormField] with a `validator`) can reuse the same logic.
  ///
  /// ## macOS / Windows
  ///
  /// No explicit [SpellCheckService] is provided. On macOS, Flutter's material
  /// [TextField.build] routes the config through
  /// [CupertinoTextField.inferIOSSpellCheckConfiguration], which adds the
  /// misspelled text style and hands off to the native [FlutterTextInputPlugin]
  /// (NSSpellChecker). [DefaultSpellCheckService] must NOT be used here —
  /// its own documentation states it is "currently only supported by Android
  /// and iOS" and it returns empty results on macOS desktop.
  ///
  /// A debug-mode warning about `nativeSpellCheckServiceDefined` may appear
  /// on the first build before the text input plugin activates; this is a
  /// known Flutter timing quirk and does not prevent native spell check from
  /// working once a field is focused.
  ///
  /// | Platform | Behaviour                                        |
  /// |----------|--------------------------------------------------|
  /// | macOS    | Native NSSpellChecker via FlutterTextInputPlugin |
  /// | Windows  | Native Windows Spell Checking API                |
  /// | Others   | `null` — spell check disabled                   |
  static SpellCheckConfiguration? platformSpellCheck() {
    if (Platform.isMacOS || Platform.isWindows) {
      // Route spell check through the native platform spell checkers
      // (NSSpellChecker on macOS, ISpellChecker on Windows) via our custom plugin.
      // Both [DefaultSpellCheckService] and the nativeSpellCheckServiceDefined path
      // fail on desktop — the only reliable approach is direct platform API calls
      // through method channels.
      return SpellCheckConfiguration(
        spellCheckService: DesktopSpellCheckService(),
        misspelledTextStyle: TextStyle(
          decoration: TextDecoration.underline,
          decorationColor: Colors.redAccent.withOpacity(0.6), // Softer underline
          decorationStyle: TextDecorationStyle.wavy,
        ),
      );
    }
    return null;
  }

  /// Context menu builder that injects spell-check correction suggestions when
  /// the cursor is positioned on a misspelled word.
  ///
  /// Adds up to 5 replacement suggestions at the **top** of the right-click
  /// menu — above the standard Cut / Copy / Paste / Select All items.
  /// If the cursor is not on a misspelled word the standard menu is shown
  /// unchanged.
  ///
  /// Pass this as [contextMenuBuilder] on any [TextField] or [TextFormField]
  /// that also uses [platformSpellCheck] as its [spellCheckConfiguration].
  static Widget spellCheckContextMenuBuilder(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final SpellCheckResults? results = editableTextState.spellCheckResults;
    final TextEditingValue value = editableTextState.textEditingValue;

    // Find a misspelled span that contains the current cursor position.
    SuggestionSpan? hitSpan;
    if (results != null && value.selection.isValid) {
      final int cursor = value.selection.baseOffset;
      for (final SuggestionSpan span in results.suggestionSpans) {
        if (cursor >= span.range.start && cursor <= span.range.end) {
          hitSpan = span;
          break;
        }
      }
    }

    final List<ContextMenuButtonItem> baseItems =
        editableTextState.contextMenuButtonItems;

    if (hitSpan == null || hitSpan.suggestions.isEmpty) {
      // No misspelled word at cursor — return the standard context menu.
      return AdaptiveTextSelectionToolbar.buttonItems(
        anchors: editableTextState.contextMenuAnchors,
        buttonItems: baseItems,
      );
    }

    final SuggestionSpan span = hitSpan;
    final List<ContextMenuButtonItem> suggestionItems = span.suggestions
        .take(5)
        .map(
          (String suggestion) => ContextMenuButtonItem(
            label: suggestion,
            onPressed: () {
              editableTextState.userUpdateTextEditingValue(
                value.replaced(span.range, suggestion),
                SelectionChangedCause.tap,
              );
              editableTextState.hideToolbar(false);
            },
          ),
        )
        .toList();

    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: <ContextMenuButtonItem>[
        ...suggestionItems,
        ...baseItems,
      ],
    );
  }

  /// The resolved spell check configuration for this widget instance.
  ///
  /// Priority:
  ///   1. Explicit caller override (allows opt-out on technical fields)
  ///   2. Platform-resolved default via [platformSpellCheck]
  ///   3. `null` — no spell check (unsupported platforms)
  SpellCheckConfiguration? get _resolvedSpellCheck {
    // Explicit caller override always wins — allows both opt-in and opt-out.
    if (spellCheckConfiguration != null) return spellCheckConfiguration;
    // Never enable on obscured fields (passwords etc.)
    if (obscureText) return null;
    return platformSpellCheck();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      undoController: undoController,
      decoration: decoration,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      style: style,
      strutStyle: strutStyle,
      textAlign: textAlign,
      textAlignVertical: textAlignVertical,
      textDirection: textDirection,
      readOnly: readOnly,
      showCursor: showCursor,
      autofocus: autofocus,
      statesController: statesController,
      obscuringCharacter: obscuringCharacter,
      obscureText: obscureText,
      autocorrect: autocorrect,
      smartDashesType: smartDashesType,
      smartQuotesType: smartQuotesType,
      enableSuggestions: enableSuggestions,
      maxLines: maxLines,
      minLines: minLines,
      expands: expands,
      maxLength: maxLength,
      maxLengthEnforcement: maxLengthEnforcement,
      onChanged: onChanged,
      onEditingComplete: onEditingComplete,
      onSubmitted: onSubmitted,
      onAppPrivateCommand: onAppPrivateCommand,
      inputFormatters: inputFormatters,
      enabled: enabled,
      ignorePointers: ignorePointers,
      cursorWidth: cursorWidth,
      cursorHeight: cursorHeight,
      cursorRadius: cursorRadius,
      cursorOpacityAnimates: cursorOpacityAnimates,
      cursorColor: cursorColor,
      cursorErrorColor: cursorErrorColor,
      selectionHeightStyle: selectionHeightStyle,
      selectionWidthStyle: selectionWidthStyle,
      keyboardAppearance: keyboardAppearance,
      scrollPadding: scrollPadding,
      dragStartBehavior: dragStartBehavior,
      enableInteractiveSelection: enableInteractiveSelection,
      selectionControls: selectionControls,
      onTap: onTap,
      onTapAlwaysCalled: onTapAlwaysCalled,
      onTapOutside: onTapOutside,
      mouseCursor: mouseCursor,
      buildCounter: buildCounter,
      scrollController: scrollController,
      scrollPhysics: scrollPhysics,
      autofillHints: autofillHints,
      contentInsertionConfiguration: contentInsertionConfiguration,
      clipBehavior: clipBehavior,
      restorationId: restorationId,
      stylusHandwritingEnabled: stylusHandwritingEnabled,
      enableIMEPersonalizedLearning: enableIMEPersonalizedLearning,
      contextMenuBuilder: contextMenuBuilder ?? AppTextField.spellCheckContextMenuBuilder,
      spellCheckConfiguration: _resolvedSpellCheck,
      magnifierConfiguration: magnifierConfiguration,
      onTapUpOutside: onTapUpOutside,
    );
  }
}
