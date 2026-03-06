@feature: expo-to-flutter-migration
@created: 2026-03-06 10:07 UTC
@status: in_progress
@mode: overview

## 进度概览

- 完成：21
- 失败：0
- 跳过：0
- 总数：25

<!-- LIVE_STATUS_BEGIN -->
状态: in_progress | 进度: 21/25 (84%) | 更新: 2026-03-06 17:48:00
当前: 已补齐 WebDAV、全局 MCP 与全局 skills 的 UI + 功能；下一步仍待解除真机限制后执行 `1.5 / 5.2`
<!-- LIVE_STATUS_END -->

## 任务列表

### Phase 0｜基线冻结

[√] 0.1 记录 `arm64 Codex` 冻结区与协议契约 | depends_on: []
[√] 0.2 建立 Android `arm64` 运行时烟雾验证清单（启动、首轮消息、Git、MCP） | depends_on: [0.1]

### Phase 1｜抽离 Native Core

[√] 1.1 初始化 Flutter 工程，并对齐 Android 构建参数与签名策略 | depends_on: [0.1]
[√] 1.2 创建 `packages/codexm_native` Flutter 插件骨架 | depends_on: [1.1]
[√] 1.3 迁移 `codex` 二进制资产、`jniLibs` 映射与 Gradle 打包逻辑 | depends_on: [1.2]
[√] 1.4 迁移 Kotlin Runtime / Git 模块桥接到 `MethodChannel` / `EventChannel` | depends_on: [1.2]
[ ] 1.5 在 Flutter 空壳应用中跑通 `arm64 Codex` 与 Git 基础调用 | depends_on: [1.3, 1.4, 0.2]

### Phase 2｜迁移基础设施层

[√] 2.1 迁移工作区路径规则与本地目录初始化逻辑 | depends_on: [1.5]
[√] 2.2 迁移会话、消息、调试日志的本地 JSON store | depends_on: [2.1]
[√] 2.3 迁移设置、密钥存储与 `codex-home` 配置落盘逻辑 | depends_on: [1.5]
[√] 2.4 迁移 MCP store、安装记录与可运行性检查逻辑 | depends_on: [2.2, 2.3]
[√] 2.5 迁移 WebDAV 基础客户端与同步逻辑 | depends_on: [2.1, 2.3]

### Phase 3｜迁移 Codex 业务层

[√] 3.1 迁移 `Codex` 配置生成与环境变量注入契约 | depends_on: [2.3, 2.4]
[√] 3.2 迁移 `JSON-RPC`、SSE 与增量事件流解析 | depends_on: [3.1]
[√] 3.3 迁移会话驱动器与线程 ID / 协作模式语义 | depends_on: [3.2, 2.2]
[√] 3.4 迁移 slash command、skills 与错误映射逻辑 | depends_on: [3.3]

### Phase 4｜迁移 UI 与交互层

[√] 4.1 重建 Flutter Material 3 应用外壳、主题与底部导航 | depends_on: [2.1, 2.3]
[√] 4.2 迁移工作区列表、新建工作区、工作区详情页面 | depends_on: [4.1, 2.1]
[√] 4.3 迁移会话列表、新建会话、会话详情与流式消息界面 | depends_on: [4.1, 3.3, 2.2]
[√] 4.4 迁移 MCP、设置页面与配置编辑交互 | depends_on: [4.1, 2.4, 2.3]
[√] 4.5 迁移 Markdown / CodeBlock / Thinking 渲染与展示细节 | depends_on: [4.3]

### Phase 5｜回归、切换与平台决策

[√] 5.1 按 RN 基线执行功能等价回归矩阵 | depends_on: [4.2, 4.3, 4.4, 4.5, 2.5]
[ ] 5.2 在 Android `arm64` 真机进行内测并清理差异项 | depends_on: [5.1]
[ ] 5.3 确认 Expo 依赖下线顺序并完成主线切换决策 | depends_on: [5.2]
[ ] 5.4 完成 Android 发布与主线切换预案 | depends_on: [5.2]

## 执行日志

- 2026-03-06 10:07 UTC｜创建方案包 `202603061007_expo-to-flutter-migration`
- 2026-03-06 10:07 UTC｜已完成现状扫描与迁移路径设计
- 2026-03-06 10:07 UTC｜多方案对比由主代理降级执行，未使用子代理编排
- 2026-03-06 10:07 UTC｜已补充 Flutter 目录骨架与 Native Plugin 拆分方案文档
- 2026-03-06 10:07 UTC｜已将迁移目标收敛为 Android-only，并开始 Phase 1 实施
- 2026-03-06 10:07 UTC｜已创建 `flutter_app/` 与 `flutter_app/packages/codexm_native/` 基础骨架
- 2026-03-06 10:07 UTC｜`flutter analyze` 已通过，Flutter app 与插件 Dart 测试已通过
- 2026-03-06 10:07 UTC｜已尝试 Android 原生编译校验，构建进入 NDK 安装阶段，尚未拿到最终产物结论
- 2026-03-06 12:16 UTC｜已补齐 `arm64` 冻结区文档与 Android 烟雾验证清单
- 2026-03-06 12:16 UTC｜已完成 `CodexRuntimeManager` Flutter 化改造，并接通 `MethodChannel` / `EventChannel`
- 2026-03-06 12:16 UTC｜`flutter analyze`、`flutter test`（app/plugin）与 `./gradlew :app:assembleDebug` 已通过
- 2026-03-06 12:31 UTC｜已在 Flutter 设置页新增 Android smoke 验证页面，串起目录准备、Runtime 启动、握手、首轮消息与 Git 基础验证入口
- 2026-03-06 12:31 UTC｜已补充 Smoke 路径契约 / JSON-RPC helper 测试，并完成 app/plugin 再次构建回归
- 2026-03-06 12:31 UTC｜已抽取正式 `WorkspaceDirectoryService`，完成 Flutter 工作区目录契约与本地初始化逻辑迁移
- 2026-03-06 12:31 UTC｜工作区页已接入最小目录验证入口，为 2.2/2.3 的持久化迁移提供落脚点
- 2026-03-06 13:12 UTC｜已迁移 `WorkspaceStore`、`SessionStore`、`DebugLogStore`，并在 Flutter 会话页接入最小验证入口
- 2026-03-06 13:12 UTC｜已迁移 `CodexSettingsStore`、安全密钥存储与 `codex-home` 配置物化，并在设置页接入最小验证入口
- 2026-03-06 13:12 UTC｜已迁移 `McpStore`、托管安装路径 / 可运行性检查与 `WebDavClient` / `WebDavSyncService`
- 2026-03-06 13:12 UTC｜已补充 Phase 2 底层单元测试与 Widget 测试，并重新通过 `flutter analyze`、分组 `flutter test` 与 `./gradlew :app:assembleDebug`
- 2026-03-06 13:41 UTC｜已新增 `features/codex/application/`，完成 `CodexLaunchContextService`、`JsonRpcClient`、SSE parser、`CodexSessionRunner` 与 `CodexSkillsStore`
- 2026-03-06 13:41 UTC｜已迁移 `thread/start|resume`、`turn/start`、review/rpc 调用与增量 delta 合并逻辑，保持 Android Native Core 冻结区不变
- 2026-03-06 13:41 UTC｜已补充 Phase 3 单元测试，并重新通过 `flutter analyze`、全量分组 `flutter test` 与 `./gradlew :app:assembleDebug`
- 2026-03-06 14:31 UTC｜已重建 Flutter 应用壳层共享上下文状态，完成工作区列表 / 详情 / 激活交互与 Material 3 视觉收口
- 2026-03-06 14:31 UTC｜已将会话页接入真实 `CodexSessionRunner`，支持新建会话、流式回复、工作区审查、上下文整理与 Markdown / CodeBlock / Thinking 展示
- 2026-03-06 14:31 UTC｜已完成 MCP / 设置正式编辑页，补充 installed skills / 快捷能力摘要，并重新通过 `flutter analyze`、`flutter test` 与 `./gradlew :app:assembleDebug`
- 2026-03-06 14:31 UTC｜已建立 `5.1` 功能等价回归矩阵，确认 Flutter 线已覆盖工作区 / 会话 / Codex / MCP / 设置基础流，并识别遗留缺口
- 2026-03-06 14:31 UTC｜已补齐 `5.2` Android `arm64` 真机验证模板、Expo 下线顺序草案、Flutter Android 发布 runbook 与 release workflow
- 2026-03-06 14:31 UTC｜已通过 `flutter build apk --release --target-platform android-arm64 --split-per-abi` 验证 Flutter Android release 构建链路
- 2026-03-06 16:10 UTC｜已将 MCP 选择收敛为全局配置，限制为 `Streamable HTTP/HTTP` 与 `Rust stdio (aarch64 build)` 两类入口，并完成设置页/工作区页对应文案与调试信息补齐
- 2026-03-06 16:45 UTC｜已补齐 MCP 托管安装 UI，支持安装地址驱动的下载并新增/重新安装/卸载本地文件，并重新通过 `flutter analyze`、`flutter test` 与 `./gradlew :app:assembleDebug`
- 2026-03-06 17:20 UTC｜已补齐工作区 WebDAV UI 与功能，支持配置保存、认证持久化、连接测试、拉取与推送，并重新通过 `flutter analyze`、`flutter test` 与 `./gradlew :app:assembleDebug`
- 2026-03-06 17:48 UTC｜已补齐全局 skills UI 与功能，支持列表刷新、载入编辑、保存与删除，并重新通过 `flutter analyze`、`flutter test` 与 `./gradlew :app:assembleDebug`
- 2026-03-06 18:11 UTC｜已补齐设置模型列表拉取/选择、运行配置预览与保存前校验，并将工作区正式接入空白工作区 + Git 克隆/拉取流程
- 2026-03-06 18:11 UTC｜已将 Flutter 会话页收敛为单工作区单 session，补齐 slash command、本地命令、`@` 文件/提交标记、commit context 展开与对应纯逻辑/存储测试
- 2026-03-06 18:11 UTC｜已扩展 Android Git Native bridge，新增 recent commits / show commit 能力，并重新通过 `flutter analyze`、`flutter test` 与 `./gradlew :app:assembleDebug`
- 2026-03-06 18:32 UTC｜主线切换与 RN 清理由后续方案包 `202603061832_flutter-mainline-cutover` 接手执行，当前计划保留为迁移历史记录

## 执行备注

- 本方案包已进入实施阶段，优先执行 Android-only 路径
- `arm64 Codex` 相关 Android Native Core 为最高优先级冻结区
- 若 Phase 1 遇到 Flutter 插件打包阻塞，切换到 Hybrid Add-to-App 兜底路径
- `5.2` 尚未执行的原因是当前明确约束为“暂不执行真机测试”
