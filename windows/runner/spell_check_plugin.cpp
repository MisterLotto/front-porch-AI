// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "spell_check_plugin.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <windows.h>
#include <spellcheck.h>
#include <wrl/client.h>

#include <map>
#include <memory>
#include <string>
#include <vector>

using namespace Microsoft::WRL;

namespace {

// Helper to convert std::string (UTF-8) to std::wstring (UTF-16)
std::wstring Utf8ToUtf16(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  int size_needed = MultiByteToWideChar(CP_UTF8, 0, &utf8[0], (int)utf8.size(), NULL, 0);
  std::wstring utf16(size_needed, 0);
  MultiByteToWideChar(CP_UTF8, 0, &utf8[0], (int)utf8.size(), &utf16[0], size_needed);
  return utf16;
}

// Helper to convert std::wstring (UTF-16) to std::string (UTF-8)
std::string Utf16ToUtf8(const std::wstring& utf16) {
  if (utf16.empty()) {
    return std::string();
  }
  int size_needed = WideCharToMultiByte(CP_UTF8, 0, &utf16[0], (int)utf16.size(), NULL, 0, NULL, NULL);
  std::string utf8(size_needed, 0);
  WideCharToMultiByte(CP_UTF8, 0, &utf16[0], (int)utf16.size(), &utf8[0], size_needed, NULL, NULL);
  return utf8;
}

class SpellCheckPluginImpl {
 public:
  static void RegisterWithMessenger(flutter::BinaryMessenger* messenger) {
    auto channel =
        std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            messenger, "front_porch_ai/spell_check",
            &flutter::StandardMethodCodec::GetInstance());

    auto plugin = std::make_shared<SpellCheckPluginImpl>();

    channel->SetMethodCallHandler(
        [plugin](const auto& call, auto result) {
          plugin->HandleMethodCall(call, std::move(result));
        });
  }

  SpellCheckPluginImpl() {
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
    CoCreateInstance(__uuidof(SpellCheckerFactory), nullptr,
                     CLSCTX_INPROC_SERVER, __uuidof(ISpellCheckerFactory),
                     (void**)&factory_);
  }

  virtual ~SpellCheckPluginImpl() {
    factory_ = nullptr;
    CoUninitialize();
  }

 private:
  ComPtr<ISpellCheckerFactory> factory_;

  // Cache one ISpellChecker per language tag.
  // CreateSpellChecker() involves a cross-process RPC to the Windows
  // spell-check broker (MSSPCheck.exe) and is expensive — calling it on
  // every keystroke caused the per-character typing lag reported by users.
  std::map<std::wstring, ComPtr<ISpellChecker>> checker_cache_;

  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    if (method_call.method_name().compare("spellCheck") == 0) {
      if (!factory_) {
        result->Success(flutter::EncodableValue());
        return;
      }

      const auto* args_list = std::get_if<flutter::EncodableList>(method_call.arguments());
      if (!args_list || args_list->size() < 2) {
        result->Error("INVALID_ARGS", "Expected [languageTag, text]");
        return;
      }

      std::string language_tag = std::get<std::string>((*args_list)[0]);
      std::string text = std::get<std::string>((*args_list)[1]);

      std::wstring w_language = Utf8ToUtf16(language_tag);
      std::wstring w_text = Utf8ToUtf16(text);

      BOOL supported = FALSE;
      factory_->IsSupported(w_language.c_str(), &supported);
      if (!supported) {
        result->Success(flutter::EncodableValue());
        return;
      }

      // Look up the cached checker for this language, creating it only once.
      auto it = checker_cache_.find(w_language);
      if (it == checker_cache_.end()) {
        ComPtr<ISpellChecker> new_checker;
        HRESULT hr = factory_->CreateSpellChecker(w_language.c_str(), &new_checker);
        if (FAILED(hr) || !new_checker) {
          result->Success(flutter::EncodableValue());
          return;
        }
        it = checker_cache_.emplace(w_language, std::move(new_checker)).first;
      }
      const ComPtr<ISpellChecker>& checker = it->second;

      ComPtr<IEnumSpellingError> errors;
      hr = checker->Check(w_text.c_str(), &errors);
      if (FAILED(hr) || !errors) {
        result->Success(flutter::EncodableValue());
        return;
      }

      flutter::EncodableList spans;

      ComPtr<ISpellingError> error;
      while (errors->Next(&error) == S_OK) {
        CORRECTIVE_ACTION action;
        error->get_CorrectiveAction(&action);

        if (action == CORRECTIVE_ACTION_GET_SUGGESTIONS ||
            action == CORRECTIVE_ACTION_REPLACE) {

          ULONG start_index;
          ULONG length;
          error->get_StartIndex(&start_index);
          error->get_Length(&length);

          flutter::EncodableList suggestions;

          ComPtr<IEnumString> suggestions_enum;
          if (checker->Suggest(w_text.substr(start_index, length).c_str(), &suggestions_enum) == S_OK) {
            LPOLESTR suggestion;
            while (suggestions_enum->Next(1, &suggestion, nullptr) == S_OK) {
              suggestions.push_back(flutter::EncodableValue(Utf16ToUtf8(suggestion)));
              CoTaskMemFree(suggestion);
            }
          } else if (action == CORRECTIVE_ACTION_REPLACE) {
            LPOLESTR replacement;
            if (error->get_Replacement(&replacement) == S_OK) {
               suggestions.push_back(flutter::EncodableValue(Utf16ToUtf8(replacement)));
               CoTaskMemFree(replacement);
            }
          }

          // We must return indices in terms of UTF-16 code units because Dart's
          // TextRange works with UTF-16 code units.
          flutter::EncodableMap span;
          span[flutter::EncodableValue("startIndex")] = flutter::EncodableValue((int)start_index);
          span[flutter::EncodableValue("endIndex")] = flutter::EncodableValue((int)(start_index + length));
          span[flutter::EncodableValue("suggestions")] = flutter::EncodableValue(suggestions);
          spans.push_back(flutter::EncodableValue(span));
        }
      }

      result->Success(flutter::EncodableValue(spans));
    } else {
      result->NotImplemented();
    }
  }
};

}  // namespace

void SpellCheckPlugin::RegisterWithMessenger(
    flutter::BinaryMessenger* messenger) {
  SpellCheckPluginImpl::RegisterWithMessenger(messenger);
}
