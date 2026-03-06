# 方案包：Expo 到 Flutter 迁移蓝图

- 包名：`202603061007_expo-to-flutter-migration`
- 创建时间：`2026-03-06 10:07 UTC`
- 类型：`overview`
- 场景：在尽量不改动已跑通的 `arm64 Codex` 运行逻辑前提下，将当前 `Expo + React Native` 项目重构迁移为 `Flutter` 技术栈

## 1. 需求

### 1.1 背景

当前项目是一个基于 `Expo + React Native` 的移动端应用，已经具备以下核心能力：

- 工作区管理、本地文件目录与会话持久化
- `Codex` 会话运行、JSON-RPC 通信、SSE 流式输出
- 本地 `MCP` 配置与安装
- `WebDAV` 同步
- 基于 Android 原生模块的 `arm64 Codex` 运行时与 `libgit2` Git 能力

其中最关键的事实约束是：`arm64 Codex` 相关逻辑已经在当前项目中实现并跑通，因此迁移方案必须优先复用已验证的 Android 原生实现，而不是重新设计该运行链路。

### 1.2 目标

- 将前端与应用框架从 `Expo + React Native` 迁移为 `Flutter`
- 保留当前产品的信息架构与核心能力，不改变产品定位
- 将 `Codex` 原生运行时与 Git 原生能力作为“冻结核心”优先复用
- 形成可执行的阶段路线图、模块映射、风险控制、回滚策略与验收标准

### 1.3 约束条件

- `arm64 Codex` 启动、打包、环境变量注入、`LD_LIBRARY_PATH`、资产装载逻辑尽量不修改
- 本轮仅考虑 Android，`iOS` 不在迁移范围内
- 先保证能力等价，再做体验优化或架构美化
- 迁移过程必须允许阶段性回归验证，避免一次性切换失败

### 1.4 非目标

- 本轮不追求同时重构业务模型与产品交互
- 本轮不优先支持 Web 端同等体验
- 本轮不把 `Codex` 原生运行时改写为 Dart/FFI 全新实现

## 2. 当前系统基线

### 2.1 当前项目结构

- 路由入口：`app/_layout.tsx`、`app/(tabs)/_layout.tsx`
- 页面层：工作区、会话、MCP、设置、新建工作区、新建会话、工作区详情、会话详情
- 状态与存储：
  - `src/workspaces/*`
  - `src/sessions/*`
  - `src/auth/*`
  - `src/mcp/*`
- 核心业务：
  - `src/codex/*`
  - `src/git/*`
  - `src/webdav/*`
  - `src/markdown/*`
- 原生 Android 关键实现：
  - `packages/codexm-native/android/src/main/java/com/codexm/nativemodules/*`
  - `packages/codexm-native/android/src/main/cpp/*`
  - `packages/codexm-native/android/src/main/assets/codex/arm64-v8a/*`
  - `plugins/withExtractNativeLibs.js`
  - `plugins/withIgnoreCodexAssets.js`
  - `plugins/withLegacyPackaging.js`
  - `plugins/withNdkPkgPrefabRepo.js`

### 2.2 当前架构特征

- UI 层依赖 `Expo Router + React Navigation + React Native Paper`
- 状态管理以 `Context + 本地 store` 为主
- 本地存储依赖 `expo-file-system` 与 `expo-secure-store`
- `Codex` 运行通过 TypeScript 层组织参数、配置和事件流，再调用 Android 原生模块执行
- Android 原生层已处理二进制打包、`jniLibs` 映射、进程启动、`LD_LIBRARY_PATH` 注入、Git JNI 桥接等高风险问题

## 3. 冻结区与兼容边界

以下内容定义为本次迁移的“冻结区”，迁移期间只能做接口适配，不做行为重写：

### 3.1 冻结区 A：Android 原生运行时

- `CodexRuntimeManagerModule.kt`
- `CodexMGitModule.kt`
- `cpp/` 下的 `libgit2` JNI 实现
- `assets/codex/arm64-v8a/` 下已验证可执行文件
- 当前 `build.gradle` 中对 `codex`/`codex-exec`/`rg` 到 `jniLibs` 的映射策略
- 当前 `LD_LIBRARY_PATH` 组装逻辑

### 3.2 冻结区 B：运行时协议契约

- `Codex` 进程启动参数与工作目录规则
- `CODEX_HOME`、`HOME`、`TMPDIR`、`SQLITE_TMPDIR`
- `OPENAI_API_KEY`、`CODEX_API_KEY`、`OPENAI_BASE_URL` 等环境变量约定
- `JSON-RPC` 消息模型、SSE 解析模型、stderr 错误收敛方式
- 工作区路径布局与 `codex-home` 落盘结构

### 3.3 冻结区 C：能力边界

- 工作区、本地 Git、会话、MCP、WebDAV、Markdown 渲染这六类能力必须在 Flutter 版本保持可用
- Android `arm64` 是第一优先目标平台

## 4. 方案对比

### 方案 A：一次性重写为独立 Flutter App

- 核心思路：直接新建 Flutter 应用，业务逻辑和原生桥接全部重新组织
- 优点：
  - 结构最干净
  - 后续维护成本最低
  - Expo 依赖可一次性移除
- 缺点：
  - 对 `arm64 Codex` 运行链路扰动最大
  - 初期回归面太大
  - 一旦 Flutter 原生桥接有偏差，定位成本高
- 结论：不推荐作为首选

### 方案 B：Hybrid Add-to-App 过渡

- 核心思路：保留现有 Android 宿主，逐步嵌入 Flutter 页面
- 优点：
  - 理论上最稳，支持渐进迁移
  - 可继续复用原有 Android 宿主能力
- 缺点：
  - 当前仓库以 Expo 工程为主，并没有持续维护的原生 Android App 宿主工程
  - 会引入双宿主维护成本
  - 对最终“完全 Flutter 化”帮助有限
- 结论：作为失败兜底方案保留，不作为主路径

### 方案 C：先抽离 Native Core，再重建 Flutter App

- 核心思路：先把当前 Android 原生能力抽为 Flutter Plugin，保持原生实现基本不动；再重建 Flutter UI、状态和页面层
- 优点：
  - 对 `arm64 Codex` 扰动最小
  - 迁移边界清晰：先保核心，再迁 UI
  - 与最终 Flutter 目标一致，不需要长期维持双宿主
  - 可按模块逐步验证
- 缺点：
  - 初期需要设计清晰的 Dart API 层
  - 仍需完整迁移 UI 与状态管理
- 结论：推荐

## 5. 推荐方案

### 5.1 结论

推荐采用 **方案 C：先抽离 Native Core，再重建 Flutter App**。

这一路径最符合你的核心约束：**尽量不改动已跑通的 `arm64 Codex` 逻辑**。迁移中应把“原生能力保真”视为第一目标，把“UI 框架替换”视为第二目标。

### 5.2 推荐实施原则

1. 先冻结 `Codex Native Core`，再开始 Flutter 迁移
2. 先迁基础设施层，再迁页面层
3. 先做 Android `arm64` 等价验证，再推进 Android 切换
4. 任何阶段都以“Flutter 版本行为是否等价于当前 RN 版本”为准绳

## 6. 目标 Flutter 架构

### 6.1 推荐目录结构

```text
flutter_app/
├── lib/
│   ├── app/                 # 路由、主题、应用入口
│   ├── core/                # 常量、错误、工具、平台抽象
│   ├── features/
│   │   ├── workspaces/
│   │   ├── sessions/
│   │   ├── codex/
│   │   ├── mcp/
│   │   ├── settings/
│   │   └── webdav/
│   ├── shared/
│   │   ├── widgets/
│   │   ├── markdown/
│   │   └── models/
│   └── main.dart
├── packages/
│   └── codexm_native/       # Flutter 插件，承接现有 Android Native Core
└── android/                 # Flutter Android 宿主
```

### 6.2 状态管理建议

- 建议在 Flutter 端使用“功能分域 + 单向数据流”组织状态
- 推荐组合：
  - 路由：`go_router`
  - 状态：`flutter_riverpod`
  - 本地数据层：Repository + Service 拆分
- 说明：这里的 `go_router` / `flutter_riverpod` 选择属于基于项目规模和迁移成本做出的工程推断，不是对官方唯一推荐的声称

### 6.3 原生桥接建议

- 第一阶段采用 `MethodChannel + EventChannel`
- 保持 Android Kotlin/C++ 逻辑主体不动，只替换 React Native bridge 为 Flutter plugin entry
- 后续若有性能瓶颈，再局部评估 `FFI`

## 7. 模块映射表

| 当前模块 | Flutter 目标 | 迁移策略 |
|---|---|---|
| `app/_layout.tsx` / `app/(tabs)/_layout.tsx` | `lib/app/router.dart` | 用 `go_router` + `ShellRoute` 重建顶层导航 |
| `app/(tabs)/*` | `features/*/presentation/` | 按功能拆页面，不再依赖文件式路由 |
| `components/*` | `shared/widgets/*` | 组件级重写，主题 token 保持一致 |
| `constants/theme.ts` | `app/theme.dart` | 映射到 Flutter Material 3 `ThemeData` |
| `src/workspaces/*` | `features/workspaces/*` | 优先原样迁移领域模型和路径规则 |
| `src/sessions/*` | `features/sessions/*` | 保持会话模型、消息落盘结构与线程 ID 语义 |
| `src/auth/*` | `features/settings` + `core/security` | 用 `flutter_secure_storage` 替代 Expo Secure Store |
| `src/mcp/*` | `features/mcp/*` | 保持数据结构和启停约定，UI 重新实现 |
| `src/codex/settings.ts` | `features/codex/data/codex_settings_repository.dart` | 保留配置生成语义与文件布局 |
| `src/codex/sessionRunner.ts` | `features/codex/domain/codex_session_runner.dart` | 先 1:1 迁移协议流程，再优化结构 |
| `src/codex/nativeRuntime.ts` | `packages/codexm_native` + Dart facade | 原生逻辑冻结，桥接层重写 |
| `src/git/nativeGit.ts` | `packages/codexm_native` + Dart facade | Kotlin/JNI 冻结，Dart API 重写 |
| `src/webdav/*` | `features/webdav/*` | 业务逻辑可基本平移到 Dart |
| `src/markdown/*` / `components/markdown/*` | `shared/markdown/*` | 先保输出语义，再决定使用库还是自研解析 |

## 8. 分阶段路线图

### 阶段 P0：基线冻结

- 输出 RN 基线清单
- 录制关键回归路径：
  - 打开工作区
  - 新建会话
  - 启动 `Codex`
  - 收到流式消息
  - Git 状态/差异
  - MCP 启用
- 为 `arm64 Codex` 建立最小烟雾验证脚本或人工验收清单

阶段出口：

- `Codex` 原生启动与会话链路有可重复验证基线

### 阶段 P1：抽离 Native Core

- 新建 Flutter plugin：`packages/codexm_native`
- 迁移 Android 层文件：
  - Kotlin runtime manager
  - Kotlin git module
  - C++ JNI
  - `codex` 资产与 Gradle 打包逻辑
- 把 RN bridge 改成 Flutter `MethodChannel` / `EventChannel`

阶段出口：

- Flutter 空壳应用可在 Android `arm64` 启动 `Codex`
- `Git` 基础调用成功

### 阶段 P2：迁移基础设施层

- 迁移工作区路径规则
- 迁移本地 JSON store
- 迁移 secure storage
- 迁移 `codex-home`、会话、调试日志、MCP 配置文件落盘逻辑

阶段出口：

- Flutter 端可以完整创建、读取、更新本地数据

### 阶段 P3：迁移 Codex 业务层

- 迁移设置生成与配置物料化逻辑
- 迁移 `JSON-RPC` 客户端
- 迁移 SSE 解析与增量事件流
- 迁移会话驱动器与错误收敛逻辑

阶段出口：

- Flutter 端可完整跑通一轮 `Codex` 对话

### 阶段 P4：迁移 UI 与页面

- 重建 Flutter Material 3 应用外壳
- 迁移工作区、会话、MCP、设置等页面
- 重建 Markdown、代码块、Thinking block 呈现

阶段出口：

- 主要页面都可用
- 核心操作路径具备 UI 等价性

### 阶段 P5：回归与切换

- 按基线矩阵做 RN ↔ Flutter 对照验证
- 开展 Android `arm64` 内测
- 解决剩余不一致项
- 确认 Expo 特定层可下线

阶段出口：

- Android `arm64` Flutter 版本可替代 RN 版本

## 9. 风险与回滚

### 9.1 主要风险

1. Flutter plugin 包装后，`jniLibs` 与资产打包路径发生变化，导致 `codex` 无法执行
2. Dart 层迁移 `sessionRunner` 时改动了环境变量、线程 ID、MCP 注入或错误处理语义
3. Markdown 与流式 UI 行为在 Flutter 中出现明显体验倒退
4. Flutter 与 RN 并行演进期间可能产生双轨差异，导致回归成本增加

### 9.2 风险缓解

- 任何时刻都保留 RN 基线版本可运行
- Native Core 抽离完成前，不启动大规模 UI 迁移
- 为 `Codex` 启动、首轮消息、Git diff、MCP 注入建立固定回归案例
- 所有迁移以“行为对齐”优先，不做无关优化

### 9.3 回滚策略

- 如果 P1 失败：退回方案 B，采用 Hybrid Add-to-App 过渡
- 如果 P3 失败：保留 Flutter UI 迁移成果，但继续复用 RN 作为主版本
- 如果 P5 失败：仅内部试用 Flutter 版本，不切主线

## 10. 里程碑

| 里程碑 | 目标 | 完成信号 |
|---|---|---|
| M1 | Native Core 抽离完成 | Flutter 空应用成功启动 `Codex` 与 Git |
| M2 | 数据与配置层迁移完成 | 工作区、会话、设置、MCP 可持久化 |
| M3 | Codex 对话链路迁移完成 | Flutter 端完成真实对话闭环 |
| M4 | 主页面迁移完成 | 工作区、会话、MCP、设置全部可用 |
| M5 | Android 切换就绪 | Android `arm64` 回归通过，可替代 RN |

## 11. 验收清单

- `arm64` 设备上可正常启动 `Codex`
- Flutter 端会话可完成至少一轮真实请求/响应
- Git clone/status/diff/pull/push 中核心路径可用
- 工作区、会话、设置、MCP 配置都能持久化
- Markdown、代码块、Thinking 内容可读性不低于现版本
- 关键路径回归结果与 RN 基线对齐
- Expo 特有依赖被完全隔离或移除

## 12. 建议执行顺序

推荐采用：

`P0 → P1 → P2 → P3 → P4 → P5`

不要采用：

- 先重写 UI，再补原生运行时
- 先追求全量页面重写，再验证 Android `arm64`
- 一次性迁移所有页面后才做首轮运行时验证

## 13. 官方参考资料

- Flutter 平台通道：`https://docs.flutter.dev/platform-integration/platform-channels`
- Flutter 开发插件：`https://docs.flutter.dev/packages-and-plugins/developing-packages`
- Flutter FFI：`https://docs.flutter.dev/platform-integration/android/c-interop`
- Flutter Add-to-App：`https://docs.flutter.dev/add-to-app`
- `go_router`：`https://pub.dev/packages/go_router`

## 14. 结论

这次迁移不应被当成“普通技术栈重写”，而应被定义为：

**以 Android Native Core 保真为前提的 Flutter 壳层重建项目。**

只要坚持“先冻结 `Codex Native Core`，再迁 Flutter UI/状态层”的顺序，就能把最大风险压缩在最小范围内，并保留当前已经验证通过的 `arm64` 运行成果。
