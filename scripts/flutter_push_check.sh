#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="${ROOT_DIR}/flutter_app"

echo "[Push check] flutter pub get"
(
  cd "${FLUTTER_DIR}"
  flutter pub get
)

echo "[Push check] flutter analyze"
(
  cd "${FLUTTER_DIR}"
  flutter analyze
)

cat <<'EOF'

[Push check] 快速检查已完成。
完整回归请按需手动运行：
  ./scripts/flutter_phase5_regression.sh
EOF
