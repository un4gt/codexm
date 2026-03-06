# 模块索引

| 模块 | 路径 | 职责 |
|---|---|---|
| `flutter_app` | `flutter_app/` | Android-only Flutter 主应用 |
| `codexm_native_plugin` | `flutter_app/packages/codexm_native/` | Flutter 原生插件，承接 Android Native Core |
| `codex_flutter_services` | `flutter_app/lib/features/codex/application/` | Flutter 侧 Codex 配置、协议与会话驱动服务层 |
| `flutter_release_tooling` | `.github/workflows/flutter-android-release.yml`、`scripts/` | Flutter Android 构建、依赖下载与回归脚本 |
