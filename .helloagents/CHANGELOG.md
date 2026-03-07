# CHANGELOG

## [0.0.10] - 2026-03-07

### 变更
- **[flutter_app]**: 参考 `happy-app` 移动端会话设计，彻底重构会话 tab 为 `header + message list + fixed composer` 单主会话结构，并移除会话概览、模式切换、审查工作区、整理上下文等干扰区块 — by Codex
  - 方案: [202603071140_happy-style-tab-rework](plan/202603071140_happy-style-tab-rework/)
  - 文件: `flutter_app/lib/features/sessions/presentation/pages/sessions_page.dart`、`flutter_app/lib/features/sessions/presentation/pages/sessions_page_actions.dart`、`flutter_app/lib/features/sessions/presentation/pages/sessions_page_panels.dart`、`flutter_app/test/features/sessions/presentation/sessions_page_smoke_test.dart`

- **[flutter_app]**: 将工作区 tab 收敛为等宽主操作行 + 工作区列表卡片，移除 WebDAV/仓库详情/当前选中工作区等大块信息 UI，并统一按钮尺寸和对齐 — by Codex
  - 方案: [202603071140_happy-style-tab-rework](plan/202603071140_happy-style-tab-rework/)
  - 文件: `flutter_app/lib/features/workspaces/presentation/pages/workspaces_page.dart`、`flutter_app/lib/features/workspaces/presentation/pages/workspaces_page_sections.dart`、`flutter_app/test/features/workspaces/presentation/workspaces_page_smoke_test.dart`

- **[flutter_app]**: 精简设置 tab，仅保留交互偏好与全局 skills 管理，删除连接与模型、审批策略、回复风格、多代理及运行摘要等开发者导向 UI，并将偏好改为即时保存 — by Codex
  - 方案: [202603071140_happy-style-tab-rework](plan/202603071140_happy-style-tab-rework/)
  - 文件: `flutter_app/lib/features/settings/presentation/pages/settings_page.dart`、`flutter_app/lib/features/settings/presentation/pages/settings_page_sections.dart`、`flutter_app/test/widget_test.dart`

- **[flutter_app]**: 统一接入 Google 官方 `window size classes`（`600 / 840dp`）断点，并将 `FeatureScaffold`、会话页和消息气泡的留白/宽度分级收敛到手机 / 平板自适应规则 — by Codex
  - 方案: [202603071140_happy-style-tab-rework](plan/202603071140_happy-style-tab-rework/)
  - 文件: `flutter_app/lib/shared/widgets/adaptive_breakpoints.dart`、`flutter_app/lib/shared/widgets/feature_scaffold.dart`、`flutter_app/lib/features/sessions/presentation/pages/sessions_page.dart`、`flutter_app/lib/features/sessions/presentation/pages/sessions_page_panels.dart`、`flutter_app/lib/features/sessions/presentation/widgets/message_bubble.dart`、`flutter_app/test/shared/adaptive_breakpoints_test.dart`

## [0.0.9] - 2026-03-07

### 变更
- **[flutter_app]**: 重建移动端主题令牌、FeatureScaffold 页面骨架与底部导航承载关系，系统性缓解页面贴边、组件堆叠与底栏挤压问题 — by un4gt
  - 方案: [202603070922_mobile-ui-session-clone-rework](archive/2026-03/202603070922_mobile-ui-session-clone-rework/)
  - 决策: mobile-ui-session-clone-rework#D001(优先重构信息架构而非样式补丁) / mobile-ui-session-clone-rework#D002(会话页采用手机单主视图+宽屏双栏)

- **[flutter_app]**: 重构会话页移动端布局、固定底部 composer 工作区，并补齐工作区页分层首页、全屏 clone 表单与进入会话主链路 — by un4gt
  - 方案: [202603070922_mobile-ui-session-clone-rework](archive/2026-03/202603070922_mobile-ui-session-clone-rework/)
  - 文件: `flutter_app/lib/app/app.dart`、`flutter_app/lib/app/theme/app_theme.dart`、`flutter_app/lib/shared/widgets/feature_scaffold.dart`、`flutter_app/lib/features/sessions/presentation/pages/`、`flutter_app/lib/features/sessions/presentation/widgets/message_bubble.dart`、`flutter_app/lib/features/workspaces/presentation/pages/`

- **[codexm_native_plugin]**: 增强 Android Git clone 凭证与错误链路，支持 token-only 认证回退、非空目录保护，并将 clone 错误统一映射为用户可理解提示 — by un4gt
  - 方案: [202603070922_mobile-ui-session-clone-rework](archive/2026-03/202603070922_mobile-ui-session-clone-rework/)
  - 决策: mobile-ui-session-clone-rework#D003(clone 错误优先分类透明化)

## [0.0.8] - 2026-03-06

### 变更
- **[flutter_release_tooling]**: 修复 GitHub Actions 上插件 example 分析失败的问题，在 `flutter analyze` 前显式为 `packages/codexm_native/example/` 执行 `flutter pub get`，并同步本地回归脚本 — by un4gt
  - 方案: [202603061832_flutter-mainline-cutover](archive/2026-03/202603061832_flutter-mainline-cutover/)
  - 文件: `.github/workflows/flutter-android-release.yml`、`scripts/flutter_phase5_regression.sh`

- **[flutter_app]**: 对比 RN 与 Flutter 已完成功能后，正式将仓库切换为 Flutter Android 主线，并移除 Expo / React Native 页面层、宿主工程、旧插件与旧发布链路 — by un4gt
  - 方案: [202603061832_flutter-mainline-cutover](archive/2026-03/202603061832_flutter-mainline-cutover/)
  - 决策: flutter-mainline-cutover#D001(Flutter 成为唯一移动端主线)

- **[codexm_native_plugin]**: 对齐 RN 旧实现的 Android Runtime 打包策略，补齐 `libcodex_z.so` / `libcodex_lzma.so` 映射，并统一改用 Flutter 插件资产下载目录 — by un4gt
  - 方案: [202603061832_flutter-mainline-cutover](archive/2026-03/202603061832_flutter-mainline-cutover/)
  - 决策: flutter-mainline-cutover#D002(运行时二进制继续按需下载) / flutter-mainline-cutover#D003(附属共享库映射对齐)

- **[flutter_release_tooling]**: 更新 Flutter Android release workflow、本地回归脚本与仓库文档，确保干净环境下可下载依赖并完成 Android 编译 — by un4gt
  - 方案: [202603061832_flutter-mainline-cutover](archive/2026-03/202603061832_flutter-mainline-cutover/)
  - 决策: flutter-mainline-cutover#D004(统一走 Flutter Android release workflow)

## [0.0.7] - 2026-03-06

### 新增
- **[flutter_app]**: 新增 Android-only Flutter 应用骨架、主题与底部导航壳层 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 决策: expo-to-flutter-migration#D001(Android-only 迁移路径)

- **[codexm_native_plugin]**: 新增 Flutter 原生插件骨架，并接入 Git Native Core 与 `codex` 资产打包脚手架 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 决策: expo-to-flutter-migration#D002(先保留 Native Core，再迁桥接层)

### 变更
- **[codexm_native_plugin]**: 完成 `CodexRuntimeManager` Flutter 化改造，打通 `MethodChannel` / `EventChannel` 运行时桥接，并补齐 Android `assembleDebug` 验证 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/packages/codexm_native/android/src/main/kotlin/com/codexm/nativemodules/`、`flutter_app/packages/codexm_native/android/src/main/kotlin/com/codexm/nativeplugin/`

- **[flutter_migration_plan]**: 新增 Android `arm64` 烟雾验证清单，作为 `1.5` 阶段验收前置 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `.helloagents/plan/202603061007_expo-to-flutter-migration/android-arm64-smoke-checklist.md`

- **[flutter_app]**: 在设置页新增 Android smoke 验证页面，接入目录准备、Runtime 启动、握手、首轮消息与 Git 基础验证入口 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/lib/features/settings/presentation/pages/android_smoke_page.dart`、`flutter_app/lib/features/settings/application/`

- **[flutter_app]**: 完成 Flutter 工作区目录契约与本地初始化逻辑迁移，并接入工作区页最小验证入口 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/lib/features/workspaces/application/workspace_paths.dart`、`flutter_app/lib/features/workspaces/presentation/pages/workspaces_page.dart`

- **[flutter_app]**: 完成会话 / 消息 / 调试日志 JSON store 迁移，并在会话页接入最小验证入口 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/lib/features/sessions/application/`、`flutter_app/lib/features/sessions/presentation/pages/sessions_page.dart`

- **[flutter_app]**: 完成设置、密钥存储与运行配置物化迁移，并在设置页接入最小验证入口 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/lib/features/settings/application/`、`flutter_app/lib/features/settings/presentation/pages/settings_page.dart`

- **[flutter_app]**: 完成 MCP store / 可运行性检查 与 WebDAV 基础客户端 / 同步逻辑迁移，并补齐回归测试 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/lib/features/mcp/application/`、`flutter_app/lib/features/webdav/application/`、`flutter_app/test/features/`

- **[flutter_app]**: 完成 Codex 业务层服务迁移，新增配置/环境注入、JSON-RPC/SSE、会话驱动与 skills/slash command 支撑 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/lib/features/codex/application/`、`flutter_app/test/features/codex/application/`

- **[flutter_app]**: 完成 Flutter Phase 4 UI 迁移，重建应用壳层、正式工作区 / 会话 / MCP / 设置页面，并接通真实流式消息体验 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/lib/app/`、`flutter_app/lib/features/workspaces/presentation/`、`flutter_app/lib/features/sessions/presentation/`、`flutter_app/lib/features/mcp/presentation/`、`flutter_app/lib/features/settings/presentation/`

- **[flutter_phase5]**: 完成 `5.1` 功能等价回归矩阵，并补齐 Android 真机验证模板、Expo 下线顺序草案、Flutter release workflow 与发布 runbook — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `.helloagents/plan/202603061007_expo-to-flutter-migration/phase5-regression-matrix.md`、`.helloagents/plan/202603061007_expo-to-flutter-migration/android-arm64-smoke-checklist.md`、`.helloagents/plan/202603061007_expo-to-flutter-migration/expo-decommission-cutover-plan.md`、`.helloagents/plan/202603061007_expo-to-flutter-migration/flutter-android-release-runbook.md`、`.github/workflows/flutter-android-release.yml`、`scripts/flutter_phase5_regression.sh`

- **[flutter_app]**: 按 Android-only 新口径收敛 MCP / skills / 工作区高级配置：MCP 改为全局启用、skills 改为全局摘要，工作区页补齐调试信息卡片 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/lib/features/mcp/presentation/pages/mcp_page.dart`、`flutter_app/lib/features/mcp/presentation/pages/mcp_page_sections.dart`、`flutter_app/lib/features/settings/application/codex_settings_store.dart`、`flutter_app/lib/features/settings/presentation/pages/settings_page.dart`、`flutter_app/lib/features/workspaces/presentation/pages/workspaces_page_sections.dart`

- **[flutter_app]**: 补齐 MCP 托管安装 UI，支持 Rust stdio 服务的“下载并安装 / 重新安装 / 卸载本地文件”，并在删除服务器时同步清理托管安装目录 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/lib/features/mcp/presentation/pages/mcp_page.dart`、`flutter_app/lib/features/mcp/presentation/pages/mcp_page_actions.dart`、`flutter_app/lib/features/mcp/presentation/pages/mcp_page_sections.dart`

- **[flutter_app]**: 补齐工作区 WebDAV UI 与功能，支持配置保存、认证持久化、连接测试以及仓库目录的 pull/push 同步 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/lib/features/workspaces/presentation/pages/workspaces_page.dart`、`flutter_app/lib/features/workspaces/presentation/pages/workspaces_page_webdav.dart`

- **[flutter_app]**: 补齐全局 skills UI 与功能，支持列表刷新、载入编辑、保存与删除，并保持 skills 仅按全局作用域管理 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/lib/features/settings/presentation/pages/settings_page.dart`、`flutter_app/lib/features/settings/presentation/pages/settings_page_sections.dart`、`flutter_app/lib/features/codex/application/codex_skills_store.dart`、`flutter_app/test/features/codex/application/codex_skills_store_test.dart`、`flutter_app/test/widget_test.dart`

- **[flutter_app]**: 补齐设置模型拉取/选择、运行配置预览与保存前校验，并将工作区正式接入“空白工作区 + Git 克隆/拉取”流程 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/lib/features/settings/presentation/pages/settings_page.dart`、`flutter_app/lib/features/settings/presentation/pages/settings_page_sections.dart`、`flutter_app/lib/features/workspaces/presentation/pages/workspaces_page.dart`、`flutter_app/lib/features/workspaces/presentation/pages/workspaces_page_sections.dart`、`flutter_app/test/features/settings/application/codex_settings_store_test.dart`

- **[flutter_app]**: 将会话收敛为单工作区单 session，补齐历史恢复、slash command、本地命令、`@` 文件/提交标记与输入联想逻辑，并新增对应纯逻辑/存储测试 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/lib/features/sessions/application/session_store.dart`、`flutter_app/lib/features/sessions/application/session_composer_logic.dart`、`flutter_app/lib/features/sessions/presentation/pages/sessions_page.dart`、`flutter_app/lib/features/sessions/presentation/pages/sessions_page_actions.dart`、`flutter_app/lib/features/sessions/presentation/pages/sessions_page_panels.dart`、`flutter_app/test/features/sessions/application/`

- **[codexm_native_plugin]**: 扩展 Android Git Native bridge，新增最近提交列表与单提交详情查询接口，供 Flutter 会话页做 commit mention 联想与上下文展开 — by un4gt
  - 方案: [202603061007_expo-to-flutter-migration](plan/202603061007_expo-to-flutter-migration/)
  - 文件: `flutter_app/packages/codexm_native/lib/`、`flutter_app/packages/codexm_native/android/src/main/kotlin/com/codexm/nativeplugin/GitMethodHandler.kt`、`flutter_app/packages/codexm_native/android/src/main/kotlin/com/codexm/nativemodules/CodexMGitModule.kt`、`flutter_app/packages/codexm_native/android/src/main/cpp/git_ops.h`、`flutter_app/packages/codexm_native/android/src/main/cpp/git_ops.cpp`、`flutter_app/packages/codexm_native/android/src/main/cpp/codexmgit_jni.cpp`
