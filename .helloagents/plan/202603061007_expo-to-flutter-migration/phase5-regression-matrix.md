# Phase 5.1｜RN → Flutter 功能等价回归矩阵

> 目标：以当前 React Native 主线为基线，对 Flutter Android-only 迁移线做功能等价核对，并明确“已等价 / 部分等价 / 缺口”边界。

## 1. 本轮证据

### 已执行自动回归

- `flutter analyze`
- `flutter test`
- `./gradlew :app:assembleDebug`
- 参考脚本：`scripts/flutter_phase5_regression.sh`

### 基线来源

- 工作区：`app/(tabs)/index.tsx`、`app/new-workspace.tsx`、`app/workspace/[id].tsx`
- 会话：`app/(tabs)/sessions.tsx`、`app/new-session.tsx`、`app/session/[id].tsx`
- MCP：`app/(tabs)/mcp.tsx`
- 设置：`app/(tabs)/settings.tsx`
- Markdown：`src/markdown/*`

## 2. 等价矩阵

| 领域 | RN 基线能力 | Flutter 当前状态 | 判定 | 证据 | 后续动作 |
|---|---|---|---|---|---|
| 应用壳层 | 底部导航、工作区/会话主入口 | 已实现共享上下文、底部导航与当前工作区提示 | 已等价 | `flutter_app/lib/app/app.dart` | 进入真机验证 |
| 工作区基础流 | 列表、新建、激活、删除 | 已实现列表、新建、激活、重命名、删除、详情摘要 | 已等价 | `flutter_app/lib/features/workspaces/presentation/` | 真机验证目录与交互稳定性 |
| 工作区高级配置 | Git 远端、提交身份、WebDAV、认证 | 已按 Flutter 迁移口径收敛为“调试信息”卡片，展示 workspace id、`.meta` / `codex-home` / log 路径与激活态 | 按新口径已等价 | `flutter_app/lib/features/workspaces/presentation/pages/workspaces_page*.dart` | 若后续恢复 Git / WebDAV 编辑，再单独立项 |
| 会话基础流 | 列表、新建、重命名、删除 | 已实现 | 已等价 | `flutter_app/lib/features/sessions/presentation/pages/sessions_page*.dart` | 真机验证 |
| Codex 流式对话 | 首轮消息、多轮上下文、线程恢复 | 已接入真实 `CodexSessionRunner` | 已等价 | `flutter_app/lib/features/codex/application/codex_session_runner.dart` | 执行真机首轮消息验证 |
| Review / Compact | `/review`、上下文整理 | Flutter 会话页已提供“审查工作区 / 整理上下文”按钮 | 已等价 | `sessions_page_actions.dart` | 真机验证 |
| Markdown 展示 | 普通文本、代码块、thinking 片段 | 已实现轻量版 paragraph / quote / code / thinking 渲染 | 已等价 | `simple_markdown_view.dart`、对应 widget test | 后续可再做视觉增强 |
| MCP 选择模型 | 工作区 / 会话级勾选 MCP server | Flutter 已收敛为全局 MCP 选择，运行时仅读取 `CodexSettings.enabledGlobalMcpServerIds` | 按新口径已等价 | `codex_settings_store.dart`、`codex_launch_context_service.dart` | 真机验证全局配置生效 |
| MCP 基础管理 | URL / stdio 新增、编辑、删除 | 已实现，但 Flutter 只保留 `Streamable HTTP/HTTP` 与 `Rust stdio（aarch64 build）` 两类受控入口，并支持全局启用/停用 | 按新口径已等价 | `flutter_app/lib/features/mcp/presentation/pages/mcp_page*.dart` | 真机验证 |
| MCP 托管安装 | 安装、卸载本地文件、路径状态 | Flutter 已补齐“安装地址 → 下载并安装 / 重新安装 / 卸载本地文件”交互，并在删除服务器时同步清理托管文件 | 已等价 | `flutter_app/lib/features/mcp/presentation/pages/mcp_page*.dart`、`managed_mcp_installer.dart` | 真机验证下载/卸载链路 |
| 设置基础流 | 模型、地址、密钥、偏好、配置落盘 | 已实现并可物化 `codex-home` | 已等价 | `flutter_app/lib/features/settings/presentation/pages/settings_page*.dart` | 真机验证配置生效 |
| Skills / 全局管理 | 技能安装状态、编辑与落盘 | Flutter 已明确 skills 为全局目录，并在设置页补齐全局列表、载入、编辑、保存、删除与运行摘要 | 已等价 | `flutter_app/lib/features/settings/presentation/pages/settings_page*.dart`、`codex_skills_store.dart` | 真机验证全局 skills 写入与会话启用链路 |
| WebDAV | 配置、认证与基础同步 | Flutter 已补齐工作区内的 WebDAV 配置 UI、认证保存、连接测试、拉取与推送功能 | 已等价 | `flutter_app/lib/features/workspaces/presentation/pages/workspaces_page*.dart`、`flutter_app/lib/features/webdav/application/` | 真机验证连通性与同步速度 |

## 3. 结论

### 当前已具备切换候选资格的能力

- 应用壳层与底部导航
- 工作区基础流
- 会话基础流
- Codex 流式对话 / review / compact
- MCP 基础 CRUD
- 设置基础配置与运行配置物化
- Markdown / CodeBlock / Thinking 基本展示

### 当前仍阻塞“完全等价切换”的差异

1. Android `arm64` 真机链路尚未执行

## 4. Phase 5.1 判定

- 结论：**Phase 5.1 已完成**
- 说明：已完成“矩阵建立 + 自动回归 + 差异分层”，但不等同于“可立即切主线”
- 下一步：进入 `5.2`，在 Android `arm64` 真机完成验证；随后才能对 `5.3 / 5.4` 做最终确认
