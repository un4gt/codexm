# 模块：codexm_native_plugin

## 职责

- 为 Flutter 提供 Android Native Core 的统一 Dart API
- 负责 MethodChannel / EventChannel 与原生 Kotlin/C++ 之间的桥接
- 承接 `codex` 运行时与 Git 能力的迁移

## 当前行为

- Dart 侧已定义 Runtime / Git API 契约
- Android 侧已接入 Runtime / Git Method handler
- Runtime stdout/stderr 已通过 `EventChannel` 映射为 Flutter 事件流
- C++ Git JNI 已从 RN 主线复制并改造为返回标准 Java 集合
- `codex` 资产通过脚本下载到插件目录，并接入 `jniLibs` 打包脚手架
- `jniLibs` 生成已对齐 RN 旧实现，包含 `libcodex_z.so` / `libcodex_lzma.so`
- Android `assembleDebug` 已通过，插件可随 Flutter 宿主完成原生编译

## 未完成项

- 尚未完成 Android `arm64` 真机烟雾验证

## 依赖

- `android/src/main/cpp/`
- `android/src/main/assets/codex/`
- `com.fpliu.ndk.pkg.prefab.android.21:openssl`
