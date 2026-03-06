# 模块：flutter_release_tooling

## 路径

- `.github/workflows/flutter-android-release.yml`
- `scripts/fetch_android_codex_deps.py`
- `scripts/flutter_phase5_regression.sh`

## 职责

- 为 Flutter Android 主线提供可重复的本地与 CI 构建链路
- 在构建前下载 `codex` Runtime 二进制与附属共享库
- 统一执行 analyze / test / Android debug/release 构建

## 当前行为

- GitHub Actions 会显式安装 Android SDK `36`、NDK `28.2.13676358` 与 CMake
- release workflow 会在 `flutter build apk` 前下载 `codex` Android 依赖
- 回归脚本会先下载 Android 依赖，再执行 `flutter analyze`、`flutter test` 与 `./gradlew :app:assembleDebug`
- 构建产物聚焦 `arm64-v8a`

## 约束

- 当前只支持 Android
- `codex` 二进制资产不直接提交入库，由脚本按需下载
- 真机安装与启动验证仍需人工执行
