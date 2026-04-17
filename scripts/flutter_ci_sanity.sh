#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="${ROOT_DIR}/flutter_app"
PLUGIN_EXAMPLE_DIR="${FLUTTER_DIR}/packages/codexm_native/example"

echo "[CI sanity] flutter pub get"
(
  cd "${FLUTTER_DIR}"
  flutter pub get
)

echo "[CI sanity] flutter pub get (plugin example)"
(
  cd "${PLUGIN_EXAMPLE_DIR}"
  flutter pub get
)

echo "[CI sanity] flutter analyze"
(
  cd "${FLUTTER_DIR}"
  flutter analyze
)

echo "[CI sanity] flutter test"
(
  cd "${FLUTTER_DIR}"
  flutter test
)
