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
- `lib/features/lan_access/`

`lib/app/app_services.dart` 是应用级服务容器。手机页面和局域网 HTTP 服务共享同一组 `WorkspaceStore`、`SessionStore`、`CodexSettingsStore`、`CodexSessionRunner` 与 `SessionTurnCoordinator`，避免为网页端创建第二份 runtime 或状态副本。

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
  - 输出到 `flutter_app/packages/codexm_native/android/runtime_inputs/codex/<abi>/`
- `scripts/flutter_phase5_regression.sh`
  - 执行依赖下载、`flutter analyze`、`flutter test`、Android debug 构建
- `.github/workflows/flutter-android-release.yml`
  - 执行 GitHub Actions 上的 Flutter Android release 构建

## 运行时路径

1. Flutter 设置页生成连接配置
2. `CodexLaunchContextService` 汇总工作区、MCP、skills、会话、会话 worktree 与鉴权信息
3. `codexm_native` 从 `nativeLibraryDir` 解析 `libcodex.so` / `libcodex_exec.so` / `librg.so`
4. Android 侧补齐 `LD_LIBRARY_PATH`，并在运行前做共享库依赖预检
5. `CodexSessionRunner` 以当前会话 worktree 作为 `cwd`，通过 JSON-RPC / SSE 启动或恢复 thread 并驱动流式消息

`SessionTurnCoordinator` 位于所有手机端和网页端入口之前，负责：

- 全局只允许一个 Codex turn
- 统一持久化 user / assistant / system 消息
- 聚合流式文本和结构化 message parts
- 广播 active turn 快照
- 协调停止请求，并保留停止前已经产生的输出
- 在 turn 运行期间排斥创建、重命名和模式切换等冲突操作

## 局域网 Web 工作台

局域网访问由三层组成：

1. Android `LanNetworkMonitor` 只枚举 Wi-Fi / 以太网的私有 IPv4 地址，并通过 EventChannel 推送地址变化。
2. `LanAccessController` 持久化开关与端口，根据网络状态启动、重绑或停止 `LanHttpServer`，同时维护 `connectedDevice` 前台服务通知。
3. `LanHttpServer` 提供打包在 APK 内的原生 HTML/CSS/ES Modules、JSON API 和 WebSocket 事件，并把会话操作交给共享 store 与 `SessionTurnCoordinator`。

Android `Application` 持有缓存的单个 `FlutterEngine`。`MainActivity` 销毁时不销毁 engine，因此页面退到后台或锁屏后，HTTP 监听和 Codex turn 不依赖 Activity 生命周期。持久化开关开启时，进程重新创建或 LAN 地址恢复会重新监听；不注册开机广播。

安全边界包括一次性 6 位配对码、内存 Cookie token、独立 CSRF token、精确 Origin 校验、来源 IP 限流、请求大小限制和脱敏 DTO。服务只绑定选定的 LAN 地址，不监听 `0.0.0.0`、蜂窝或 VPN。HTTP 本身不加密，完整约束见 [`lan-web.md`](lan-web.md)。

## 工作区与会话代码模型

一个工作区对应一个本地目录和一个主集成仓库，可以包含多个 CodexM 会话。会话不是 Codex runtime 的 resume ID：每个会话分别持有 CodexM 本地 session ID，以及用于 `thread/resume` 的 runtime `threadId`。

每个会话同时拥有独立 Git 分支和 linked worktree：

- 会话分支：`codexm/session/<sessionId>`
- worktree 名称：`session-<去掉连字符的 UUID>`
- 会话中的 runtime、文件引用、仓库扫描、diff 和 commit 查询都在该会话 worktree 中执行
- worktree 绝对路径由 workspace ID 与 session ID 推导，不写入持久化模型

工作区目录固定为：

```text
<workspaceRoot>/
├── repo/                   # 主集成分支所在仓库
├── worktrees/<sessionId>/  # 各会话的 linked worktree
└── .meta/sessions/         # 会话与消息元数据
```

`SessionCodeWorkspaceService` 负责仓库初始化、旧工作区迁移、worktree 恢复，以及会话的创建、检查点、派生、合并、冲突继续/放弃、归档和删除。底层 Git 操作经 Dart → MethodChannel → Kotlin → JNI → C++ 调用现有 `libgit2`，不依赖 Git CLI。

合并规则：

- 源会话合并前必须没有未保存改动
- 目标可以是主工作区，也可以是另一个会话
- 冲突状态保留在目标仓库，由用户选择完成合并或放弃合并
- 合并只修改本地仓库，不自动执行 push
- 删除会话会移除 worktree 与专属分支；存在未保存或未合并代码时需要二次确认

## 导航模型

应用根导航固定为三个入口：`工作区`、`MCP 与技能`、`设置`。会话不占用根导航位置，而是工作区内的二级流程：

```text
工作区列表 → 会话列表 → 会话详情
```

手机进入会话详情后隐藏底部导航，返回时依次回到会话列表和工作区列表；平板保留三项导航 rail，并使用会话列表与详情的主从布局。

## 当前产品约束

- MCP 与 skills 为全局作用域
- MCP 仅支持：
  - `Streamable HTTP/HTTP`
  - `Rust stdio (aarch64 build)`
- 同一时间只允许一个 Codex turn 运行；手机端和网页端都显示同一个 active turn，并可停止当前轮次
- 主工作区发生冲突时，当前没有专用 Codex 冲突处理会话，需要在后续版本补充对应流程
- 真机 `arm64` 验收仍待执行
