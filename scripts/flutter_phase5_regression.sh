#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER_DIR="${ROOT_DIR}/flutter_app"

echo "[Phase 5.1] fetch Android codex deps"
python3 "${ROOT_DIR}/scripts/fetch_android_codex_deps.py" --abi arm64-v8a

echo "[Phase 5.1] flutter pub get (plugin example)"
(
  cd "${FLUTTER_DIR}/packages/codexm_native/example"
  flutter pub get
)

echo "[Phase 5.1] flutter analyze"
(
  cd "${FLUTTER_DIR}"
  flutter analyze
)

echo "[Phase 5.1] flutter test"
(
  cd "${FLUTTER_DIR}"
  flutter test
)

echo "[Phase 5.1] Android debug build"
(
  cd "${FLUTTER_DIR}/android"
  ./gradlew :app:assembleDebug
)

cat <<'EOF'

[Phase 5.1] 自动回归已完成。
后续仍需人工执行：
1. Android arm64 真机安装与启动验证
2. 首轮消息 / Git / MCP 真机冒烟
3. 切换主线前的发布与回滚演练
EOF
