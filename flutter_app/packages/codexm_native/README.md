# codexm_native

`codexm_native` 是 CodexM Flutter 主线的 Android 原生插件，负责承接已验证的 Runtime / Git Native Core。

## 职责

- 暴露 Runtime / Git 的 Dart API
- 通过 `MethodChannel` / `EventChannel` 桥接 Kotlin 与 C++
- 打包 `codex`、`codex-exec`、`rg` 与附属共享库到 `nativeLibraryDir`

## 构建前准备

首次构建前，需要在仓库根目录执行：

```bash
python3 scripts/fetch_android_codex_deps.py --abi arm64-v8a
```

脚本会把以下产物下载到：

`flutter_app/packages/codexm_native/android/runtime_inputs/codex/arm64-v8a/`

- `codex`
- `codex-exec`
- `rg`
- `libcodex_z.so`
- `libcodex_lzma.so`

## 当前范围

- 仅支持 Android
- 当前只面向 `arm64-v8a`
- iOS 不在本轮范围内
