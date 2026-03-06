# Flutter 目录骨架与 Native Plugin 拆分方案

- 关联方案包：`202603061007_expo-to-flutter-migration`
- 创建时间：`2026-03-06 10:07 UTC`
- 目标：为 `Expo + React Native → Flutter` 迁移提供可直接落地的目录结构、模块边界和 Native Plugin 拆分方案
- 核心约束：`arm64 Codex` 已跑通的 Android Native Core 尽量不改，只做桥接层与工程包装层迁移

## 1. 设计原则

### 1.1 核心原则

1. `Native Core` 冻结，`Flutter Shell` 重建
2. 业务域与平台域解耦，避免 Dart 直接感知 Android 实现细节
3. 页面层只依赖 `Application Facade / Controller`，不直接调用平台通道
4. Plugin 第一阶段优先 Android 单实现，第二阶段再考虑联邦化（federated plugin）

### 1.2 不做的事

- 不把现有 Kotlin/C++ 运行时整体改写为 Dart FFI
- 不在本轮引入 `iOS` 平台实现或双端 Native Core 设计
- 不让 Flutter UI 直接拼装 `LD_LIBRARY_PATH`、路径映射和二进制执行参数

## 2. 推荐 Flutter 仓库骨架

> 当前已落地实现使用 `flutter_app/` 目录。以下骨架以“当前已落地 + 后续可扩展”形式描述，优先保证与现有代码一致。

```text
flutter_app/
├── android/
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   └── theme/
│   │       └── app_theme.dart
│   ├── shared/
│   │   └── widgets/
│   │       └── feature_scaffold.dart
│   ├── features/
│   │   ├── workspaces/
│   │   │   └── presentation/pages/workspaces_page.dart
│   │   ├── sessions/
│   │   │   └── presentation/pages/sessions_page.dart
│   │   ├── mcp/
│   │   │   └── presentation/pages/mcp_page.dart
│   │   ├── settings/
│   │   │   └── presentation/pages/settings_page.dart
│   │   ├── codex/
│   │   ├── git/
│   │   └── webdav/
├── packages/
│   └── codexm_native/
│       ├── lib/
│       │   ├── codexm_native.dart
│       │   ├── codexm_native_method_channel.dart
│       │   ├── codexm_native_platform_interface.dart
│       │   └── src/models/
│       ├── android/
│       │   ├── src/main/assets/codex/
│       │   ├── src/main/cpp/
│       │   └── src/main/kotlin/
│       └── pubspec.yaml
├── test/
└── pubspec.yaml
```

## 3. 目录分层职责

## 3.1 `app/`

职责：

- 应用启动顺序
- 路由注册
- 全局主题
- Provider/Scope 根挂载

不要放：

- 平台通道
- 文件系统路径算法
- `Codex` 业务协议解析

## 3.2 `core/`

职责：

- 通用错误模型
- 文件/时间/路径等基础工具
- 本地存储抽象
- 平台能力门面接口

关键建议：

- 只放跨 feature 复用的能力
- 如果逻辑只服务单一业务域，不要上提到 `core/`

## 3.3 `shared/`

职责：

- 纯 UI 组件
- Markdown 渲染组件
- 通用展示模型

对应当前 RN：

- `components/*`
- `components/markdown/*`
- `src/markdown/*` 中偏展示的部分

## 3.4 `features/`

职责：

- 以业务域拆分，而不是按技术类型拆分
- 每个 feature 内部自含 `data / domain / presentation`

推荐映射：

- `workspaces`：工作区目录、元数据、激活态
- `sessions`：会话列表、消息、线程 ID、协作模式
- `codex`：配置生成、会话驱动、流式事件、命令能力
- `git`：Git façade 与结果模型
- `mcp`：MCP 服务登记、安装、可运行性检查
- `settings`：用户设置、API Key、实验特性
- `webdav`：同步与远程目录协议

## 4. 推荐业务模块落位

### 4.1 工作区

```text
features/workspaces/
├── data/
│   ├── workspace_store.dart
│   ├── workspace_paths.dart
│   └── workspace_repository_impl.dart
├── domain/
│   ├── workspace.dart
│   ├── workspace_id.dart
│   └── workspace_repository.dart
└── presentation/
    ├── pages/
    ├── controllers/
    └── widgets/
```

说明：

- 当前 `src/workspaces/paths.ts` 的路径语义应优先原样迁移
- `workspaceRoot / repo / .meta / tmp` 规则属于协议契约，不要改名

### 4.2 会话

```text
features/sessions/
├── data/
│   ├── session_store.dart
│   ├── message_store.dart
│   └── session_repository_impl.dart
├── domain/
│   ├── session.dart
│   ├── chat_message.dart
│   └── session_repository.dart
└── presentation/
    ├── pages/
    ├── controllers/
    └── widgets/
```

说明：

- 会话 JSON 结构建议保持兼容，便于迁移历史数据
- `codexThreadId` 与 `codexCollaborationMode` 继续作为会话元字段

### 4.3 Codex

```text
features/codex/
├── data/
│   ├── codex_settings_store.dart
│   ├── codex_config_materializer.dart
│   ├── json_rpc_client.dart
│   ├── sse_reader.dart
│   └── native_runtime_gateway.dart
├── domain/
│   ├── codex_settings.dart
│   ├── codex_turn_event.dart
│   ├── codex_stream_event.dart
│   └── codex_runtime_contract.dart
├── application/
│   ├── run_codex_turn.dart
│   ├── prepare_codex_env.dart
│   └── codex_session_service.dart
└── presentation/
    ├── pages/
    ├── controllers/
    └── widgets/
```

说明：

- `runCodexTurn` 是迁移关键文件，建议保持接近当前 `sessionRunner.ts` 的职责边界
- `native_runtime_gateway.dart` 负责与 Flutter plugin 交互，不允许 UI 直连平台通道

### 4.4 Git / MCP / WebDAV / Settings

这几类能力都建议采用同样模式：

- `domain`：放模型与仓储接口
- `data`：放本地存储、网络请求、平台调用实现
- `application`：放编排流程
- `presentation`：仅在需要页面时存在

## 5. Flutter Plugin 拆分方案

## 5.1 目标

把当前 React Native 原生能力迁移为 Flutter 可调用插件，但尽量让 Kotlin/C++ 主体逻辑保持稳定。

## 5.2 V1 推荐方案：单插件、单 Android 实现

```text
packages/codexm_native/
├── lib/
│   ├── codexm_native.dart
│   ├── src/
│   │   ├── channels.dart
│   │   ├── codex_runtime_api.dart
│   │   ├── git_api.dart
│   │   ├── models/
│   │   └── events/
├── android/
│   ├── src/main/kotlin/com/codexm/nativeplugin/
│   │   ├── CodexmNativePlugin.kt
│   │   ├── CodexRuntimeBridge.kt
│   │   ├── GitBridge.kt
│   │   └── EventEmitterBridge.kt
│   ├── src/main/java/...             # 可保留现有包路径，按迁移实际情况调整
│   ├── src/main/cpp/
│   ├── src/main/assets/codex/
│   ├── build.gradle
│   └── AndroidManifest.xml
└── pubspec.yaml
```

适用阶段：

- Android-only
- 目标是尽快跑通 Flutter 首个可执行版本

优点：

- 改动最小
- 迁移速度最快
- 最符合“冻结 Native Core”的约束

缺点：

- 平台抽象还不够彻底
- 后续若扩平台，仍需再次拆分

## 5.3 Android-only 后续扩展预留

> 当前不做联邦化插件拆分；只有当 Android 版本稳定且确有跨平台需求时，才再评估是否升级为多 package 架构。

```text
packages/
├── codexm_native/
│   └── lib/
├── codexm_native_platform_interface/
│   └── lib/
└── codexm_native_android/
    ├── lib/
    └── android/
```

推荐触发条件：

- Android 版本已稳定
- 需要让 Android 实现与 Dart 接口完全解耦
- 当前单插件结构已成为维护瓶颈

当前不建议立即采用的原因：

- 会增加 package 数量与维护复杂度
- 与“先保住 Android `arm64`”的当前目标不一致

## 6. Plugin 内部职责拆分

即使先用单插件，也建议在插件内部做“逻辑分层”。以下结构同时反映当前已落地实现。

### 6.1 Dart 侧

```text
lib/
├── codexm_native.dart
├── codexm_native_method_channel.dart
├── codexm_native_platform_interface.dart
└── src/models/
    ├── runtime_line_event.dart
    └── git_status.dart
```

职责：

- 暴露 typed API
- 序列化 / 反序列化参数
- 屏蔽通道名称和原生 map 细节

### 6.2 Android Kotlin 侧

```text
android/src/main/kotlin/
├── com/codexm/nativeplugin/
│   ├── CodexmNativePlugin.kt
│   ├── RuntimeMethodHandler.kt
│   └── GitMethodHandler.kt
└── com/codexm/nativemodules/
    └── CodexMGitModule.kt
```

职责：

- `CodexmNativePlugin.kt`：注册 MethodChannel / EventChannel
- `RuntimeMethodHandler.kt`：当前运行时占位实现，后续承接 `CodexRuntimeManager` 迁移
- `GitMethodHandler.kt`：Flutter ↔ Git Native Core 参数分发
- `CodexMGitModule.kt`：复用原生 Git JNI 能力

说明：

- 当前已采用“最薄 Flutter handler + 原生 Git 模块复用”的方式推进迁移

### 6.3 C++ 侧

保持现有结构优先：

```text
android/src/main/cpp/
├── CMakeLists.txt
├── codexmgit_jni.cpp
├── git_ops.cpp
├── git_ops.h
└── cmake/
```

建议：

- 第一阶段不要动 JNI 函数语义
- 只在包名、加载入口、构建路径确有必要时做最小变更

## 7. 平台通道边界设计

## 7.1 MethodChannel 建议接口

### Runtime

- `runtime.start`
- `runtime.stop`
- `runtime.sendLine`
- `runtime.chmodPath`
- `runtime.extractTarGz`

### Git

- `git.clone`
- `git.checkout`
- `git.pull`
- `git.push`
- `git.status`
- `git.diff`

## 7.2 EventChannel 建议接口

- `runtime.lineEvents`

事件模型：

```json
{
  "runtimeId": "workspace:session:timestamp",
  "stream": "stdout",
  "line": "..."
}
```

说明：

- 事件结构尽量与当前 `CodexRuntimeLineEvent` 对齐，减小 Dart 迁移成本

## 7.3 是否引入 Pigeon

建议：

- 第一阶段：不引入 `Pigeon`
- 第二阶段：当通道数量增长、类型模型稳定后再评估

原因：

- 当前迁移重点是低风险复用 Native Core
- 手写少量 `MethodChannel` / `EventChannel` 更便于对照现有实现

## 8. 推荐的页面骨架

```text
features/workspaces/presentation/pages/
├── workspaces_page.dart
├── new_workspace_page.dart
└── workspace_detail_page.dart

features/sessions/presentation/pages/
├── sessions_page.dart
├── new_session_page.dart
└── session_detail_page.dart

features/mcp/presentation/pages/
└── mcp_page.dart

features/settings/presentation/pages/
└── settings_page.dart
```

路由骨架建议：

- `/workspaces`
- `/workspace/:id`
- `/sessions`
- `/session/new`
- `/session/:id`
- `/mcp`
- `/settings`

## 9. 迁移顺序建议

### 第一步：先搭骨架，不迁 UI

- 建 Flutter 工程
- 建 plugin
- 跑通 Android `arm64 Codex`

### 第二步：迁数据和平台能力

- 迁工作区/会话/store
- 迁 `Codex` 配置与运行时编排
- 迁 Git / MCP / WebDAV

### 第三步：再迁页面

- 先迁工作区与设置
- 再迁会话详情这种高复杂界面

### 第四步：最后做样式与体验补齐

- Markdown 渲染
- Thinking block
- 动画、手感、主题细节

## 10. 应保留不动的关键清单

- `codex` / `codex-exec` / `rg` 的打包输入物
- `jniLibs` 包装策略
- `nativeLibraryDir` 解析逻辑
- `LD_LIBRARY_PATH` 拼装规则
- `CODEX_HOME` / `HOME` / `TMPDIR` / `SQLITE_TMPDIR`
- `OPENAI_API_KEY` / `CODEX_API_KEY` / `OPENAI_BASE_URL`
- `Git` JNI 主流程

## 11. 最终推荐结论

对当前项目，最稳妥的拆分方式是：

### 应用层

- 一个独立 `Flutter app`
- 按 `features` 做业务域拆分

### 原生层

- 一个 `codexm_native` Flutter plugin
- 插件内部再分 `runtime / git / bridge / channels`
- Android Native Core 整体平移、最薄包装

### 未来扩展

- 等 Android 版本稳定后，再评估是否升级为联邦化插件

这套方案最大的价值是：**把“技术栈替换”与“高风险原生能力重写”分离开来**，从而最大化保住你已经跑通的 `arm64 Codex` 成果。

## 12. 参考资料

- Flutter 官方平台通道：`https://docs.flutter.dev/platform-integration/platform-channels`
- Flutter 官方插件开发：`https://docs.flutter.dev/packages-and-plugins/developing-packages`
- `go_router`：`https://pub.dev/packages/go_router`
