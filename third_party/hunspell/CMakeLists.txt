# Vendored hunspell 1.7.3 — see README.fpai.md for provenance and licence.
#
# Built as its own static library rather than dropped into the runner's source
# list on purpose: the runner compiles with -Wall -Werror (see
# APPLY_STANDARD_SETTINGS in linux/CMakeLists.txt) and third-party code is not
# warning-clean under it. Isolating the target keeps our own strictness intact
# instead of weakening it repo-wide to accommodate code we do not maintain.

cmake_minimum_required(VERSION 3.13)
project(hunspell LANGUAGES CXX)

add_library(hunspell STATIC
  "src/affentry.cxx"
  "src/affixmgr.cxx"
  "src/csutil.cxx"
  "src/filemgr.cxx"
  "src/hashmgr.cxx"
  "src/hunspell.cxx"
  "src/hunzip.cxx"
  "src/phonet.cxx"
  "src/replist.cxx"
  "src/suggestmgr.cxx"
)

# 1.7.3 uses <bit> and <chrono>, so it needs C++20 — the runner itself stays on
# C++14. Only machines that BUILD the app need a C++20 compiler (GCC 10+,
# 2020); users receive a compiled binary and need nothing.
target_compile_features(hunspell PRIVATE cxx_std_20)

# HUNSPELL_STATIC collapses the visibility macros in hunvisapi.h to nothing,
# which is what we want when linking into the executable.
target_compile_definitions(hunspell PUBLIC HUNSPELL_STATIC)

# -fPIC: the runner is a position-independent executable.
set_target_properties(hunspell PROPERTIES POSITION_INDEPENDENT_CODE ON)

# Upstream is warning-heavy and we do not patch it; silence the noise rather
# than let it drown out warnings in code we actually own.
target_compile_options(hunspell PRIVATE -w)

target_include_directories(hunspell PUBLIC "${CMAKE_CURRENT_SOURCE_DIR}/src")
