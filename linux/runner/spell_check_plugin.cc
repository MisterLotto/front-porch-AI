// Copyright (C) 2026 Front Porch AI
// SPDX-License-Identifier: AGPL-3.0-or-later

#include "spell_check_plugin.h"

#include <limits.h>
#include <unistd.h>

#include <algorithm>
#include <map>
#include <memory>
#include <string>
#include <vector>

#include "hunspell.hxx"

// Exposes a spell checker to Flutter via the `front_porch_ai/spell_check`
// method channel — the same channel, the same arguments and the same reply
// shape as macOS (NSSpellChecker, see macos/Runner/SpellCheckPlugin.swift) and
// Windows (ISpellChecker, see windows/runner/spell_check_plugin.cpp).
//
//   Channel method: `spellCheck`
//   Arguments:      [String languageTag, String text]
//   Returns:        List<Map> of
//                   { "startIndex": int, "endIndex": int,
//                     "suggestions": List<String> }
//                   or null when no dictionary matches the language.
//
// The engine is hunspell, compiled into this binary from third_party/hunspell
// (see its README.fpai.md). Nothing is dlopen'd, nothing is spawned, and there
// is no runtime package to install: an en_US dictionary ships in the app
// bundle, so spell check works out of the box on any distribution. The user's
// own system dictionaries are still preferred when present, which is what
// keeps other languages — and any words they have added themselves — working.
//
// Indices are **UTF-16 code units**, because that is what Dart's TextRange
// counts. The macOS and Windows implementations get this for free (NSString
// and std::wstring are both UTF-16); here the text arrives as UTF-8, so the
// scanner tracks a UTF-16 offset alongside the byte pointer. Getting this
// wrong would put the red underline on the wrong word in any message
// containing an emoji — which, in this app, is most of them.

namespace {

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

struct Dictionary {
  std::unique_ptr<Hunspell> engine;
  // Dictionaries are usually UTF-8, but plenty of older system ones are
  // ISO8859-x. hunspell wants words in the dictionary's own encoding, so when
  // it is not UTF-8 every word has to be converted on the way in and every
  // suggestion converted back.
  std::string encoding;
  bool utf8 = true;
};

struct SpellState {
  // Requested language tag -> dictionary, or a null entry when that language
  // has none. Loading one parses the whole .dic (~50k entries for en_US), so
  // it must happen once, not once per keystroke. The Windows plugin caches its
  // ISpellChecker for the same reason, and its comment records the
  // per-character typing lag that appeared without it.
  std::map<std::string, std::unique_ptr<Dictionary>> dicts;
};

// Directory the running executable lives in. The dictionary we ship sits at
// <exe dir>/data/dictionaries/, which is where linux/CMakeLists.txt installs
// it inside the bundle, next to data/flutter_assets.
std::string ExeDir() {
  char buf[PATH_MAX];
  const ssize_t len = readlink("/proc/self/exe", buf, sizeof(buf) - 1);
  if (len <= 0) {
    return std::string();
  }
  buf[len] = '\0';
  g_autofree char* dir = g_path_get_dirname(buf);
  return std::string(dir);
}

// Where distributions put hunspell/myspell dictionaries. Ordered most-specific
// first so a user's own dictionary in $HOME wins over the system's.
std::vector<std::string> SystemDictDirs() {
  std::vector<std::string> dirs;
  const char* home = g_get_home_dir();
  if (home != nullptr) {
    dirs.push_back(std::string(home) + "/.local/share/hunspell");
  }
  dirs.push_back("/usr/local/share/hunspell");
  dirs.push_back("/usr/share/hunspell");
  dirs.push_back("/usr/share/myspell/dicts");
  dirs.push_back("/usr/share/myspell");
  return dirs;
}

// A dictionary is an .aff/.dic pair sharing a basename. Returns the basename
// path (no extension) when both halves exist.
bool DictPairExists(const std::string& base) {
  return g_file_test((base + ".aff").c_str(), G_FILE_TEST_IS_REGULAR) &&
         g_file_test((base + ".dic").c_str(), G_FILE_TEST_IS_REGULAR);
}

// Finds any installed variant of a base language ("en" -> "en_GB"), so a
// machine carrying only hunspell-en-gb still gets English.
bool FindVariant(const std::string& dir, const std::string& base,
                 std::string* out) {
  g_autoptr(GDir) handle = g_dir_open(dir.c_str(), 0, nullptr);
  if (handle == nullptr) {
    return false;
  }
  const std::string prefix = base + "_";
  const char* name = nullptr;
  while ((name = g_dir_read_name(handle)) != nullptr) {
    const std::string entry(name);
    if (entry.size() > 4 && entry.compare(entry.size() - 4, 4, ".dic") == 0 &&
        entry.compare(0, prefix.size(), prefix) == 0) {
      const std::string candidate = dir + "/" + entry.substr(0, entry.size() - 4);
      if (DictPairExists(candidate)) {
        *out = candidate;
        return true;
      }
    }
  }
  return false;
}

// Resolution order, and the reasoning behind it:
//   1. the exact tag the user's locale asks for (en_GB, de_DE)
//   2. the bare language, for dictionaries named just "de"
//   3. any installed variant of that language
//   4. the dictionary we ship, for English only
// System dictionaries come first so that a user's own installed language — and
// any words they have added to it — keep working exactly as they did when this
// went through Enchant. The bundled copy is a floor, not a replacement: it is
// what guarantees the feature can never silently do nothing.
bool ResolveDictPath(const std::string& tag, std::string* out) {
  std::string normalized = tag;
  for (char& c : normalized) {
    if (c == '-') {
      c = '_';
    }
  }
  const size_t underscore = normalized.find('_');
  const std::string base =
      underscore == std::string::npos ? normalized : normalized.substr(0, underscore);

  for (const std::string& dir : SystemDictDirs()) {
    const std::string exact = dir + "/" + normalized;
    if (DictPairExists(exact)) {
      *out = exact;
      return true;
    }
  }
  for (const std::string& dir : SystemDictDirs()) {
    const std::string bare = dir + "/" + base;
    if (DictPairExists(bare)) {
      *out = bare;
      return true;
    }
  }
  for (const std::string& dir : SystemDictDirs()) {
    if (FindVariant(dir, base, out)) {
      return true;
    }
  }

  if (base == "en") {
    const std::string bundled = ExeDir() + "/data/dictionaries/en_US";
    if (DictPairExists(bundled)) {
      *out = bundled;
      return true;
    }
    g_message(
        "Spell check: the bundled en_US dictionary is missing from the app "
        "bundle (looked in %s). The install is incomplete.",
        bundled.c_str());
  }
  return false;
}

Dictionary* GetDict(SpellState* state, const char* tag) {
  auto cached = state->dicts.find(tag);
  if (cached != state->dicts.end()) {
    return cached->second.get();
  }

  std::string path;
  std::unique_ptr<Dictionary> dict;
  if (ResolveDictPath(tag, &path)) {
    dict.reset(new Dictionary());
    dict->engine.reset(new Hunspell((path + ".aff").c_str(),
                                    (path + ".dic").c_str()));
    const char* encoding = dict->engine->get_dic_encoding();
    dict->encoding = encoding != nullptr ? encoding : "UTF-8";
    dict->utf8 = g_ascii_strcasecmp(dict->encoding.c_str(), "UTF-8") == 0 ||
                 g_ascii_strcasecmp(dict->encoding.c_str(), "UTF8") == 0;
  }

  Dictionary* raw = dict.get();
  state->dicts.emplace(tag, std::move(dict));
  return raw;
}

// Every language tag with a usable dictionary on this machine, for the
// Settings picker. Includes the one we bundle, which is always present.
FlValue* AvailableLanguages() {
  std::vector<std::string> tags;
  auto add = [&tags](const std::string& tag) {
    for (const std::string& seen : tags) {
      if (seen == tag) {
        return;
      }
    }
    tags.push_back(tag);
  };

  for (const std::string& dir : SystemDictDirs()) {
    g_autoptr(GDir) handle = g_dir_open(dir.c_str(), 0, nullptr);
    if (handle == nullptr) {
      continue;
    }
    const char* name = nullptr;
    while ((name = g_dir_read_name(handle)) != nullptr) {
      const std::string entry(name);
      if (entry.size() > 4 && entry.compare(entry.size() - 4, 4, ".dic") == 0) {
        const std::string stem = entry.substr(0, entry.size() - 4);
        if (DictPairExists(dir + "/" + stem)) {
          add(stem);
        }
      }
    }
  }
  if (DictPairExists(ExeDir() + "/data/dictionaries/en_US")) {
    add("en_US");
  }

  std::sort(tags.begin(), tags.end());
  FlValue* out = fl_value_new_list();
  for (const std::string& tag : tags) {
    fl_value_append_take(out, fl_value_new_string(tag.c_str()));
  }
  return out;
}

int Utf16Len(gunichar c) { return c < 0x10000 ? 1 : 2; }

bool IsApostrophe(gunichar c) {
  return c == 0x0027 || c == 0x2019;  // ' and ’
}

// Checks one word and appends a span when it is misspelled.
void CheckWord(Dictionary* dict, const char* start, const char* end,
               int u16_start, int u16_end, FlValue* spans) {
  const size_t byte_len = static_cast<size_t>(end - start);
  std::string word(start, byte_len);

  // hunspell dictionaries spell contractions with U+0027, so a typographic
  // apostrophe has to be folded down or every "don't" typed by a word
  // processor (or by this app's own smart-quote handling) reads as a typo.
  for (size_t at = word.find("\xE2\x80\x99"); at != std::string::npos;
       at = word.find("\xE2\x80\x99", at + 1)) {
    word.replace(at, 3, "'");
  }

  if (!dict->utf8) {
    g_autofree gchar* converted =
        g_convert(word.c_str(), -1, dict->encoding.c_str(), "UTF-8", nullptr,
                  nullptr, nullptr);
    if (converted == nullptr) {
      return;  // not representable in this dictionary — cannot be judged
    }
    word.assign(converted);
  }

  if (dict->engine->spell(word)) {
    return;
  }

  FlValue* suggestions = fl_value_new_list();
  const std::vector<std::string> raw = dict->engine->suggest(word);
  for (size_t i = 0; i < raw.size() && i < kMaxSuggestions; ++i) {
    if (dict->utf8) {
      fl_value_append_take(suggestions, fl_value_new_string(raw[i].c_str()));
      continue;
    }
    g_autofree gchar* back = g_convert(raw[i].c_str(), -1, "UTF-8",
                                       dict->encoding.c_str(), nullptr, nullptr,
                                       nullptr);
    if (back != nullptr) {
      fl_value_append_take(suggestions, fl_value_new_string(back));
    }
  }

  FlValue* span = fl_value_new_map();
  fl_value_set_string_take(span, "startIndex", fl_value_new_int(u16_start));
  fl_value_set_string_take(span, "endIndex", fl_value_new_int(u16_end));
  fl_value_set_string_take(span, "suggestions", suggestions);
  fl_value_append_take(spans, span);
}

// Walks a whitespace-delimited chunk, spell-checking each word in it.
// |u16| is the UTF-16 offset of |start| within the whole text.
void ScanChunk(Dictionary* dict, const char* start, const char* end, int u16,
               FlValue* spans) {
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
      CheckWord(dict, word_start, p, word_u16_start, u16, spans);
    }
  }
}

// Splits the text into whitespace-delimited chunks so URLs and email
// addresses can be skipped wholesale. Without this, "github.com" reads as the
// two misspellings "github" and "com"; macOS and Windows both suppress them.
FlValue* CheckText(Dictionary* dict, const char* text) {
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
      ScanChunk(dict, chunk_start, p, chunk_u16, spans);
    }
  }

  return spans;
}

void HandleMethodCall(FlMethodChannel* channel, FlMethodCall* method_call,
                      gpointer user_data) {
  (void)channel;
  SpellState* state = static_cast<SpellState*>(user_data);
  g_autoptr(FlMethodResponse) response = nullptr;

  if (strcmp(fl_method_call_get_name(method_call), "availableLanguages") == 0) {
    g_autoptr(FlValue) languages = AvailableLanguages();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(languages));
    g_autoptr(GError) list_error = nullptr;
    if (!fl_method_call_respond(method_call, response, &list_error)) {
      g_warning("Failed to respond to spell check call: %s",
                list_error->message);
    }
    return;
  }

  if (strcmp(fl_method_call_get_name(method_call), "spellCheck") != 0) {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    g_autoptr(GError) not_impl_error = nullptr;
    if (!fl_method_call_respond(method_call, response, &not_impl_error)) {
      g_warning("Failed to respond to spell check call: %s",
                not_impl_error->message);
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

    Dictionary* dict = GetDict(state, language_tag);

    // No dictionary for this language: reply null, exactly as the Windows
    // plugin does when IsSupported() says no. DesktopSpellCheckService treats
    // null as "no results" and clears the underlines.
    g_autoptr(FlValue) result =
        dict != nullptr ? CheckText(dict, text) : fl_value_new_null();
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error)) {
    g_warning("Failed to respond to spell check call: %s", error->message);
  }
}

void FreeState(gpointer data) { delete static_cast<SpellState*>(data); }

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
