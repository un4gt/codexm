# CodexM Flutter Android 架构

## 目标

- 以 `flutter_app/` 作为唯一移动端主线
- 仅支持 Android，优先 `arm64-v8a`
- 复用已验证的 `Codex` Native Runtime 与 `libgit2` Git Native Core
- 通过 Flutter UI、持久化与业务服务层提供完整工作流

## 代码分层

### 1. Flutter App

- 路径：`flutter_app/`
- 负责：
  - 应用壳层、导航、主题
  - 工作区 / 会话 / MCP / 设置 / WebDAV 页面与交互
  - 本地 JSON store、配置生成、会话恢复

主要功能域：

- `lib/features/workspaces/`
- `lib/features/sessions/`
- `lib/features/settings/`
- `lib/features/mcp/`
- `lib/features/webdav/`
- `lib/features/codex/`

### 2. Native Plugin

- 路径：`flutter_app/packages/codexm_native/`
- 负责：
  - `MethodChannel` / `EventChannel`
  - Android Kotlin Runtime / Git 桥接
  - C++ `libgit2` JNI 实现
  - `codex` 运行时可执行文件与共享库的 `jniLibs` 生成

### 3. Release Tooling

- `scripts/fetch_android_codex_deps.py`
  - 下载 `codex`、`codex-exec`、`rg`
  - 下载 `libcodex_z.so`、`libcodex_lzma.so`
  - 输出到 `flutter_app/packages/codexm_native/android/src/main/assets/codex/<abi>/`
- `scripts/flutter_phase5_regression.sh`
  - 执行依赖下载、`flutter analyze`、`flutter test`、Android debug 构建
- `.github/workflows/flutter-android-release.yml`
  - 执行 GitHub Actions 上的 Flutter Android release 构建

## 运行时路径

1. Flutter 设置页生成运行配置与 `config.toml`
2. `CodexLaunchContextService` 汇总工作区、MCP、skills、会话与鉴权信息
3. `codexm_native` 从 `nativeLibraryDir` 解析 `libcodex.so` / `libcodex_exec.so` / `librg.so`
4. Android 侧补齐 `LD_LIBRARY_PATH`，并在运行前做共享库依赖预检
5. `CodexSessionRunner` 通过 JSON-RPC / SSE 驱动会话流式消息

## 当前产品约束

- 每个 workspace 只保留一个主 session
- MCP 与 skills 为全局作用域
- MCP 仅支持：
  - `Streamable HTTP/HTTP`
  - `Rust stdio (aarch64 build)`
- 多 session / worktree 冲突管理暂不进入当前主线
- 真机 `arm64` 验收仍待执行
