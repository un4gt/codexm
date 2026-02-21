# CodexM（Expo / React Native）

CodexM 是一个以移动端为主的 Codex 交互与 coding 工作台（当前聚焦 **Android arm64**），目标是在 React Native/Expo 应用内嵌 `openai/codex`，提供 workspace / sessions / git / webdav 的一体化体验。

## 需求与方案（精简版）

- **Git 集成**：Android 原生 `libgit2`（`CodexMGit`）提供 `clone/checkout/pull/push/status`；私有库通过 HTTPS token 认证（token 写入 `expo-secure-store`，workspace 只保存 `authRef`）。
- **WebDAV 集成**：通过 WebDAV 上传/下载代码（用于对接自定义平台；实现侧优先做 workspace 级别的打包/同步策略）。
- **Workspace 概念**：每个项目一个 workspace，本地路径 `DocumentDirectory/workspaces/<id>/repo/`；并为 Codex 创建独立 `CODEX_HOME/HOME`，确保在该 workspace 内正确访问项目文件。
- **Codex 交互**：Android 原生 `CodexRuntimeManager` 拉起 `codex app-server`（stdio JSON-RPC/JSONL），桥接 stdout/stderr 事件流；`src/codex/sessionRunner.ts` 已接入真实流式事件（`item/agentMessage/delta`）。
- **MCP**：通过 `codex app-server` 的 `config.toml` 对接 MCP（`mcp_servers`）；支持远程 URL 与本地 Rust 可执行（stdio）。本地 MCP 支持运行时下载安装（`.tar.gz`/`.tgz` 或直接二进制），默认全局登记但不启用，可在新建 workspace/session 时勾选启用。
- **UI**：底部 Tab：`工作区 / 会话 / MCP / 设置`（Codex 的鉴权与配置在「设置」里全局管理；工作区只负责项目目录与元数据）。

参考实现思路：`codex-termux`（在 Android 上运行 codex 并以 app-server 模式启动）。注意：Android 10+ 且 `targetSdkVersion >= 29` 时，SELinux 会阻止第三方应用从 app 私有可写目录（`/data/data/<pkg>/...`）直接 `execve()` 二进制（常见 `avc: denied { execute_no_trans }`），因此本项目采用“assets 作为输入 → 构建时拷贝为 jniLibs（`.so`）→ 运行时从 `nativeLibraryDir` 执行（filesDir 里只放 symlink）”的方式来兼容。

## MCP（Model Context Protocol）

本项目通过 `codex app-server` 的 `config.toml` 对接 MCP（写入 `[mcp_servers.<name>]`）。

- **远程 MCP（URL）**：在 App 的 `MCP` Tab 新增 `URL` 类型 Server；在新建 workspace / 新建 session 时勾选启用即可。
- **本地 MCP（Rust 可执行，stdio）**：在 `MCP` Tab 新增 `stdio` 类型 Server。Android 下可填写安装包 URL（`.tar.gz`/`.tgz` 或直接二进制）进行**运行时安装**，安装后会自动把 `command` 指向已安装的可执行文件路径。

限制与注意事项：

- 仅面向 **Rust/可执行式 MCP**（rmcp 生态）；不提供 Node.js / Python runtime 以运行对应 MCP server。
- `stdio` 会执行本机命令，请只安装/登记你信任来源的可执行文件。
- 部分 Android 设备/系统策略可能限制从应用可写目录执行下载的 ELF（常见 `Permission denied` / `execute_no_trans`）。如遇该问题，请优先使用远程 MCP，或在你的运行环境中放开限制。

更多细节见：`docs/mcp.md`。

## Android（Dev Client）运行

> 当前只考虑 **arm64-v8a**。请使用 arm64 真机或 arm64 模拟器镜像；常见 `x86_64` 模拟器不支持只打包 arm64 的可执行文件。

### 1) 安装依赖

```bash
npm install
```

### 2) 准备 Codex 二进制（assets）

推荐直接运行脚本自动下载（assets 目录已加入 `.gitignore`，不会入库）：

```bash
python scripts/fetch_android_codex_deps.py --abi arm64-v8a
```

或手动把可执行文件放到以下目录（文件名需一致）：

- `packages/codexm-native/android/src/main/assets/codex/arm64-v8a/codex`
- `packages/codexm-native/android/src/main/assets/codex/arm64-v8a/codex-exec`

可选：提供更快的搜索（ripgrep）：

- `packages/codexm-native/android/src/main/assets/codex/arm64-v8a/rg`

推荐下载（仅 arm64）：从 `ripgrep-prebuilt v15.0.0` 选择 `ripgrep-v15.0.0-aarch64-unknown-linux-musl.tar.gz`，解压得到 `rg` 放入上面的目录（`*-linux-gnu*` 通常无法在 Android 上运行）。

说明：
- `packages/codexm-native/android/build.gradle` 会在构建时把这些 assets 复制到 jniLibs 并重命名为：`libcodex.so` / `libcodex_exec.so` / `librg.so`，从而进入 APK native library 目录（`ApplicationInfo.nativeLibraryDir`）。
- 为避免 APK 体积重复打包，打包阶段会忽略 `assets/codex/`（由 `plugins/withIgnoreCodexAssets.js` 保证）。这些文件仅作为构建输入用于生成 jniLibs；运行时只从 `nativeLibraryDir` 解析并执行。
- `CodexRuntimeManager` 启动时会在 `filesDir/codexm/bin/<abi>/` 创建 `codex/codex-exec/rg` 的 symlink 指向上述 native libs，并把该目录 prepend 到 `PATH`，让 Codex 在运行时能找到 helper。

### 3) 生成原生工程（prebuild）

```bash
npx expo prebuild --platform android --clean
```

### 4) 构建并安装 Dev Client

```bash
npx expo run:android
```

### 5) 启动 Metro（Dev Client 模式）

```bash
npx expo start --dev-client
```

### 6) 验收流程

1. App 内创建 workspace（仅创建/选择项目目录 `.../workspaces/<id>/repo/`）。
2. 进入 `Settings`：开启 Codex，设置 `OPENAI_API_KEY`（写入 SecureStore）并保存；App 会在 `DocumentDirectory/codex-home/` 生成 `config.toml` 与 `auth.json`（不使用 HTTP 模式，app-server 走 stdio）。
3. 进入 `Sessions` 新建会话并发送消息：应看到 Codex 输出的 **流式**文本（`item/agentMessage/delta`）。

## Troubleshooting

- Gradle 报 `Namespace ... 'native' is a Java keyword`：避免使用 `com.*.native` 作为 `namespace/package`；本项目原生模块使用 `com.codexm.nativemodules`，改完后请 `npx expo prebuild --platform android --clean` 再构建。
- 运行时 `error=13 Permission denied`（无法执行 `codex`）且 logcat 出现 `avc: denied { execute_no_trans } ... tcontext=app_data_file`：这是 Android 10+（且 `targetSdkVersion >= 29`）的预期限制，**仅 chmod +x 不会生效**。确认是否已走 “nativeLibraryDir 执行” 路径：
  - `android/gradle.properties` 需设置 `expo.useLegacyPackaging=true`（否则 native libs 可能不落盘，`nativeLibraryDir` 下找不到 `libcodex.so`，启动会直接失败）
  - `adb shell run-as com.unsafe.codexm ls -l files/codexm/bin/arm64-v8a/`（应看到 `codex -> .../libcodex.so` 这类 symlink）
  - 如仍是普通文件而非 symlink：检查 `plugins/withExtractNativeLibs.js` 是否生效（重新 `npx expo prebuild --platform android --clean`），并确认 assets 下的 `codex/codex-exec/rg` 存在。
- 运行时出现 `401 Unauthorized / 缺少 API Key`：Codex 内置 OpenAI provider 依赖 `CODEX_HOME/auth.json`（或 keyring）进行鉴权；本项目会在保存设置时把 SecureStore 中的 Key 同步到 `DocumentDirectory/codex-home/auth.json`。请确保已更新到最新代码并在 App「设置」里点一次“保存”以重写配置与鉴权文件。

## References

- Codex（app-server）：https://github.com/openai/codex
- Android 端运行 Codex 的参考项目（Termux）：https://github.com/DioNanos/codex-termux
- ripgrep 预编译：https://github.com/microsoft/ripgrep-prebuilt/releases/tag/v15.0.0
