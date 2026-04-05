// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

import AppKit
import FlutterMacOS

/// Exposes `NSSpellChecker` to Flutter via the `front_porch_ai/spell_check`
/// method channel.
///
/// Channel method: `spellCheck`
/// Arguments: `[String languageTag, String text]`
/// Returns:   `List<Map>` where each map is:
///   `{ "startIndex": Int, "endIndex": Int, "suggestions": [String] }`
class SpellCheckPlugin: NSObject, FlutterPlugin {

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "front_porch_ai/spell_check",
            binaryMessenger: registrar.messenger
        )
        let instance = SpellCheckPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "spellCheck" else {
            result(FlutterMethodNotImplemented)
            return
        }

        guard
            let args = call.arguments as? [String],
            args.count >= 2
        else {
            result(FlutterError(
                code: "INVALID_ARGS",
                message: "Expected [languageTag, text]",
                details: nil
            ))
            return
        }

        let languageTag = args[0]
        let text        = args[1]

        DispatchQueue.global(qos: .userInitiated).async {
            let spans = SpellCheckPlugin.check(text: text, language: languageTag)
            DispatchQueue.main.async { result(spans) }
        }
    }

    // ── Core spell-check logic ────────────────────────────────────────────

    private static func check(text: String, language: String) -> [[String: Any]] {
        let checker  = NSSpellChecker.shared
        let nsText   = text as NSString
        let fullLen  = nsText.length
        var spans: [[String: Any]] = []
        var offset   = 0

        // language tag may be "en-US" or "en_US"; NSSpellChecker wants "en_US"
        let lang = language.replacingOccurrences(of: "-", with: "_")

        while offset < fullLen {
            let range = checker.checkSpelling(
                of:   text,
                startingAt: offset,
                language:   lang,
                wrap:       false,
                inSpellDocumentWithTag: 0,
                wordCount:  nil
            )

            guard range.location != NSNotFound else { break }

            let suggestions: [String] = checker.guesses(
                forWordRange: range,
                in:           text,
                language:     lang,
                inSpellDocumentWithTag: 0
            ) ?? []

            spans.append([
                "startIndex":  range.location,
                "endIndex":    range.location + range.length,
                "suggestions": suggestions,
            ])

            offset = range.location + max(range.length, 1)
        }

        return spans
    }
}
