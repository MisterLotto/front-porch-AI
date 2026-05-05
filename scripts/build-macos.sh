#!/bin/bash
# Build Front Porch AI for macOS, including the RAG embedding server.
# Usage: ./scripts/build-macos.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE="$ROOT/build/macos/Build/Products/Release/FrontPorchAI.app"
EMBED_SRC="$ROOT/tools/embed_server"

echo "==> Installing Flutter dependencies..."
cd "$ROOT"
flutter pub get

echo "==> Building embedding server..."
if ! command -v cargo &>/dev/null; then
  echo "Error: Rust toolchain not found. Install it from https://rustup.rs/"
  exit 1
fi
cargo build --release --manifest-path "$EMBED_SRC/Cargo.toml"

echo "==> Building macOS app..."
flutter build macos

echo "==> Bundling embedding server into app..."
DEST="$APP_BUNDLE/Contents/Resources/embed_server"
mkdir -p "$DEST"
cp "$EMBED_SRC/target/release/embed_server" "$DEST/"

echo "==> Done: $APP_BUNDLE"
