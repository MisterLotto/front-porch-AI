// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "spell_check_plugin.h"

#include <dlfcn.h>
#include <sys/types.h>

#include <cstring>

// Exposes the system spell checker to Flutter via the
// `front_porch_ai/spell_check` method channel — the same channel, the same
// arguments and the same reply shape as macOS (NSSpellChecker, see
// macos/Runner/SpellCheckPlugin.swift) and Windows (ISpellChecker, see
// windows/runner/spell_check_plugin.cpp).
//
//   Channel method: `spellCheck`
//   Arguments:      [String languageTag, String text]
//   Returns:        List<Map> of
//                   { "startIndex": int, "endIndex": int,
//                     "suggestions": List<String> }
//                   or null when spell check is unavailable.
//
// Indices are **UTF-16 code units**, because that is what Dart's TextRange
// counts. The macOS and Windows implementations get this for free (NSString
// and std::wstring are both UTF-16); here the text arrives as UTF-8, so the
// scanner tracks a UTF-16 offset alongside the byte pointer. Getting this
// wrong would put the red underline on the wrong word in any message
// containing an emoji — which, in this app, is most of them.

namespace {

// ── Enchant, loaded lazily through dlopen ──────────────────────────────────
//
// Deliberately NOT linked at build time. Enchant is not present on every
// desktop Linux install, and a DT_NEEDED entry would make the entire app fail
// to start with "libenchant-2.so.2: cannot open shared object file" on those
// machines — turning a missing optional feature into a dead application for
// anyone running the tar.gz or AppImage. Loading it on demand keeps the app
// launching and simply leaves spell check off, which is exactly the behaviour
// Linux had before this plugin existed.
//
// It also means `flutter build linux` needs no new -dev package, so neither CI
// nor a contributor's checkout has to change to build this.
//
// soname is pinned to the versioned file: libenchant-2.so (unversioned) only
// exists when the -dev package is installed, which end users will not have.
// The 2.x soname has been stable since Enchant 2.0 (2017).
constexpr const char* kEnchantSoname = "libenchant-2.so.2";

struct EnchantBroker;
struct EnchantDict;

using BrokerInitFn = EnchantBroker* (*)();
using BrokerFreeFn = void (*)(EnchantBroker*);
using BrokerRequestDictFn = EnchantDict* (*)(EnchantBroker*, const char*);
using BrokerFreeDictFn = void (*)(EnchantBroker*, EnchantDict*);
using BrokerDictExistsFn = int (*)(EnchantBroker*, const char*);
using DictCheckFn = int (*)(EnchantDict*, const char*, ssize_t);
using DictSuggestFn = char** (*)(EnchantDict*, const char*, ssize_t, size_t*);
using DictFreeStringListFn = void (*)(EnchantDict*, char**);

// Beyond a few hundred red squiggles the underlines stop conveying anything,
// and every one of them costs an edit-distance search inside hunspell. Capping
// bounds the worst case (someone pasting a wall of text in another language
// into a character description) so the platform thread cannot stall.
constexpr size_t kMaxSpans = 512;

// The context menu in app_text_field.dart shows at most 5 replacements, so
// marshalling more across the channel is pure waste. Observably identical to
// macOS/Windows, which return everything and get truncated Dart-side.
constexpr size_t kMaxSuggestions = 5;

// Words shorter than this are never worth flagging ("a", "I", stray initials)
// and are a common false-positive source.
constexpr int kMinWordChars = 2;

struct SpellState {
  bool load_attempted = false;
  void* handle = nullptr;
  EnchantBroker* broker = nullptr;

  // Requested language tag -> dict (or nullptr when the language has no
  // dictionary installed). Requesting a dict parses the .dic file — ~50k
  // entries for en_US — so it must happen once, not once per keystroke. The
  // Windows plugin caches its ISpellChecker for the same reason, and its
  // comment records the per-character typing lag that appeared without it.
  GHashTable* dicts = nullptr;

  BrokerFreeFn broker_free = nullptr;
  BrokerRequestDictFn broker_request_dict = nullptr;
  BrokerFreeDictFn broker_free_dict = nullptr;
  BrokerDictExistsFn broker_dict_exists = nullptr;
  DictCheckFn dict_check = nullptr;
  DictSuggestFn dict_suggest = nullptr;
  DictFreeStringListFn dict_free_string_list = nullptr;
};

template <typename T>
bool BindSymbol(void* handle, const char* name, T* out) {
  void* sym = dlsym(handle, name);
  if (sym == nullptr) {
    return false;
  }
  *out = reinterpret_cast<T>(sym);
  return true;
}

// Opens libenchant and binds every symbol we need. Runs at most once; on any
// failure the state stays broker-less and every check returns null from then
// on. Called on first use rather than at registration so that a machine
// without Enchant pays nothing at startup.
void EnsureLoaded(SpellState* state) {
  if (state->load_attempted) {
    return;
  }
  state->load_attempted = true;

  state->handle = dlopen(kEnchantSoname, RTLD_LAZY | RTLD_LOCAL);
  if (state->handle == nullptr) {
    g_message(
        "Spell check disabled: %s could not be loaded (%s). Install the "
        "enchant 2 runtime and a hunspell dictionary to enable it.",
        kEnchantSoname, dlerror());
    return;
  }

  BrokerInitFn broker_init = nullptr;
  const bool ok =
      BindSymbol(state->handle, "enchant_broker_init", &broker_init) &&
      BindSymbol(state->handle, "enchant_broker_free", &state->broker_free) &&
      BindSymbol(state->handle, "enchant_broker_request_dict",
                 &state->broker_request_dict) &&
      BindSymbol(state->handle, "enchant_broker_free_dict",
                 &state->broker_free_dict) &&
      BindSymbol(state->handle, "enchant_broker_dict_exists",
                 &state->broker_dict_exists) &&
      BindSymbol(state->handle, "enchant_dict_check", &state->dict_check) &&
      BindSymbol(state->handle, "enchant_dict_suggest", &state->dict_suggest) &&
      BindSymbol(state->handle, "enchant_dict_free_string_list",
                 &state->dict_free_string_list);

  if (!ok) {
    g_message("Spell check disabled: %s is missing expected symbols.",
              kEnchantSoname);
    dlclose(state->handle);
    state->handle = nullptr;
    return;
  }

  state->broker = broker_init();
  if (state->broker == nullptr) {
    g_message("Spell check disabled: enchant_broker_init() failed.");
    return;
  }
  state->dicts = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, nullptr);
}

// Resolves a Dart language tag ("en-US") to an Enchant dictionary, falling
// back to the bare language ("en") when the regional variant is not installed
// — a machine with only `hunspell-en-gb` should still check English. Returns
// nullptr, cached, when nothing matches.
EnchantDict* GetDict(SpellState* state, const char* tag) {
  gpointer cached = nullptr;
  if (g_hash_table_lookup_extended(state->dicts, tag, nullptr, &cached)) {
    return static_cast<EnchantDict*>(cached);
  }

  g_autofree char* normalized = g_strdup(tag);
  for (char* c = normalized; *c != '\0'; ++c) {
    if (*c == '-') {
      *c = '_';
    }
  }

  EnchantDict* dict = nullptr;
  if (state->broker_dict_exists(state->broker, normalized) != 0) {
    dict = state->broker_request_dict(state->broker, normalized);
  } else {
    char* region = strchr(normalized, '_');
    if (region != nullptr) {
      *region = '\0';
      if (state->broker_dict_exists(state->broker, normalized) != 0) {
        dict = state->broker_request_dict(state->broker, normalized);
      }
    }
  }

  g_hash_table_insert(state->dicts, g_strdup(tag), dict);
  return dict;
}

int Utf16Len(gunichar c) { return c < 0x10000 ? 1 : 2; }

bool IsApostrophe(gunichar c) {
  return c == 0x0027 || c == 0x2019;  // ' and '
}

// Checks one word and appends a span when it is misspelled.
void CheckWord(SpellState* state, EnchantDict* dict, const char* start,
               const char* end, int u16_start, int u16_end, FlValue* spans) {
  const size_t byte_len = static_cast<size_t>(end - start);

  // hunspell dictionaries spell contractions with U+0027, so a typographic
  // apostrophe has to be folded down or every "don't" typed by a word
  // processor (or by this app's own smart-quote handling) reads as a typo.
  g_autofree char* folded = nullptr;
  const char* word = start;
  if (g_strstr_len(start, static_cast<gssize>(byte_len), "\xE2\x80\x99") !=
      nullptr) {
    g_autofree char* copy = g_strndup(start, byte_len);
    g_auto(GStrv) parts = g_strsplit(copy, "\xE2\x80\x99", -1);
    folded = g_strjoinv("'", parts);
    word = folded;
  }
  const size_t check_len = folded != nullptr ? strlen(folded) : byte_len;

  if (state->dict_check(dict, word, static_cast<ssize_t>(check_len)) <= 0) {
    return;  // 0 == correctly spelled, negative == checker error
  }

  FlValue* suggestions = fl_value_new_list();
  size_t count = 0;
  char** raw = state->dict_suggest(dict, word, static_cast<ssize_t>(check_len),
                                   &count);
  if (raw != nullptr) {
    const size_t limit = count < kMaxSuggestions ? count : kMaxSuggestions;
    for (size_t i = 0; i < limit; ++i) {
      fl_value_append_take(suggestions, fl_value_new_string(raw[i]));
    }
    state->dict_free_string_list(dict, raw);
  }

  FlValue* span = fl_value_new_map();
  fl_value_set_string_take(span, "startIndex", fl_value_new_int(u16_start));
  fl_value_set_string_take(span, "endIndex", fl_value_new_int(u16_end));
  fl_value_set_string_take(span, "suggestions", suggestions);
  fl_value_append_take(spans, span);
}

// Walks a whitespace-delimited chunk, spell-checking each word in it.
// |u16| is the UTF-16 offset of |start| within the whole text.
void ScanChunk(SpellState* state, EnchantDict* dict, const char* start,
               const char* end, int u16, FlValue* spans) {
  const char* p = start;
  while (p < end && fl_value_get_length(spans) < kMaxSpans) {
    gunichar c = g_utf8_get_char(p);
    if (!g_unichar_isalpha(c)) {
      u16 += Utf16Len(c);
      p = g_utf8_next_char(p);
      continue;
    }

    const char* word_start = p;
    const int word_u16_start = u16;
    int word_chars = 0;
    bool has_digit = false;

    while (p < end) {
      c = g_utf8_get_char(p);
      if (g_unichar_isalpha(c)) {
        // keep going
      } else if (g_unichar_isdigit(c)) {
        has_digit = true;
      } else if (IsApostrophe(c)) {
        // Only word-internal: "don't" is one word, "dogs'" ends at the s.
        const char* next = g_utf8_next_char(p);
        if (next >= end || !g_unichar_isalpha(g_utf8_get_char(next))) {
          break;
        }
      } else {
        break;
      }
      u16 += Utf16Len(c);
      ++word_chars;
      p = g_utf8_next_char(p);
    }

    // Tokens carrying digits are identifiers, not prose — "x86", "3rd",
    // "v0.9.8". Both other platforms leave them alone.
    if (!has_digit && word_chars >= kMinWordChars) {
      CheckWord(state, dict, word_start, p, word_u16_start, u16, spans);
    }
  }
}

// Splits the text into whitespace-delimited chunks so URLs and email
// addresses can be skipped wholesale. Without this, "github.com" reads as the
// two misspellings "github" and "com"; macOS and Windows both suppress them.
FlValue* CheckText(SpellState* state, EnchantDict* dict, const char* text) {
  FlValue* spans = fl_value_new_list();
  const char* p = text;
  int u16 = 0;

  while (*p != '\0' && fl_value_get_length(spans) < kMaxSpans) {
    gunichar c = g_utf8_get_char(p);
    if (g_unichar_isspace(c)) {
      u16 += Utf16Len(c);
      p = g_utf8_next_char(p);
      continue;
    }

    const char* chunk_start = p;
    const int chunk_u16 = u16;
    while (*p != '\0') {
      c = g_utf8_get_char(p);
      if (g_unichar_isspace(c)) {
        break;
      }
      u16 += Utf16Len(c);
      p = g_utf8_next_char(p);
    }

    const gssize chunk_len = static_cast<gssize>(p - chunk_start);
    const bool looks_like_a_link =
        g_strstr_len(chunk_start, chunk_len, "://") != nullptr ||
        g_strstr_len(chunk_start, chunk_len, "@") != nullptr ||
        g_str_has_prefix(chunk_start, "www.");
    if (!looks_like_a_link) {
      ScanChunk(state, dict, chunk_start, p, chunk_u16, spans);
    }
  }

  return spans;
}

void HandleMethodCall(FlMethodChannel* channel, FlMethodCall* method_call,
                      gpointer user_data) {
  (void)channel;
  SpellState* state = static_cast<SpellState*>(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(fl_method_call_get_name(method_call), "spellCheck") != 0) {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    g_autoptr(GError) error = nullptr;
    if (!fl_method_call_respond(method_call, response, &error)) {
      g_warning("Failed to respond to spell check call: %s", error->message);
    }
    return;
  }

  // Element types are checked, not assumed: fl_value_get_string on a non-string
  // FlValue is undefined behaviour, and "the Dart side always sends strings" is
  // exactly the assumption that turns a typo into a crash rather than an error.
  FlValue* args = fl_method_call_get_args(method_call);
  const bool args_ok =
      args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_LIST &&
      fl_value_get_length(args) >= 2 &&
      fl_value_get_type(fl_value_get_list_value(args, 0)) ==
          FL_VALUE_TYPE_STRING &&
      fl_value_get_type(fl_value_get_list_value(args, 1)) ==
          FL_VALUE_TYPE_STRING;

  if (!args_ok) {
    response = FL_METHOD_RESPONSE(fl_method_error_response_new(
        "INVALID_ARGS", "Expected [languageTag, text]", nullptr));
  } else {
    const char* language_tag =
        fl_value_get_string(fl_value_get_list_value(args, 0));
    const char* text = fl_value_get_string(fl_value_get_list_value(args, 1));

    EnsureLoaded(state);
    EnchantDict* dict =
        state->broker != nullptr ? GetDict(state, language_tag) : nullptr;

    // No Enchant, or no dictionary for this language: reply null, exactly as
    // the Windows plugin does when IsSupported() says no. DesktopSpellCheck-
    // Service treats null as "no results" and clears the underlines.
    g_autoptr(FlValue) result =
        dict != nullptr ? CheckText(state, dict, text) : fl_value_new_null();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to respond to spell check call: %s", error->message);
  }
}

void FreeState(gpointer data) {
  SpellState* state = static_cast<SpellState*>(data);
  if (state->dicts != nullptr) {
    GHashTableIter iter;
    gpointer value = nullptr;
    g_hash_table_iter_init(&iter, state->dicts);
    while (g_hash_table_iter_next(&iter, nullptr, &value)) {
      if (value != nullptr) {
        state->broker_free_dict(state->broker,
                                static_cast<EnchantDict*>(value));
      }
    }
    g_hash_table_destroy(state->dicts);
  }
  if (state->broker != nullptr) {
    state->broker_free(state->broker);
  }
  if (state->handle != nullptr) {
    dlclose(state->handle);
  }
  delete state;
}

}  // namespace

void spell_check_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      "front_porch_ai/spell_check", FL_METHOD_CODEC(codec));

  fl_method_channel_set_method_call_handler(channel, HandleMethodCall,
                                            new SpellState(), FreeState);

  // The registrar outlives the view, so parenting the channel to it keeps the
  // handler alive for the life of the app without a static.
  g_object_set_data_full(G_OBJECT(registrar), "front_porch_ai/spell_check",
                         channel, g_object_unref);
}
