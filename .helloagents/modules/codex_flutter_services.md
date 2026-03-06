# 模块：codex_flutter_services

## 路径

- `flutter_app/lib/features/codex/application/`

## 职责

- 为 Flutter Android 主线提供 Codex 业务层服务
- 生成运行时配置与环境变量注入契约
- 提供 JSON-RPC / SSE / 会话驱动等协议能力
- 提供 slash command、skills 与错误映射的 Flutter 侧实现

## 当前行为

- `CodexLaunchContextService` 会联动工作区、会话、设置、MCP store，生成运行时所需的 `CODEX_HOME`、`TMPDIR`、API Key 与 `config.toml`
- `JsonRpcClient` 已支持 request / notification / server request 三类 JSON-RPC 交互
- `CodexSessionRunner` 已支持：
  - `initialize` / `initialized`
  - `thread/start` / `thread/resume`
  - `turn/start`
  - `review/start`
  - `thread/compact/start`
  - 增量 delta 合并、`turn/completed` 结束判定与线程 ID 落盘
- `CodexServerClient` 与 SSE parser 已完成远端流式协议封装
- `CodexSkillsStore` 已支持技能名标准化、写入、列出和删除
- `codex_slash_commands.dart` 已维护移动端展示所需的 slash command 清单
- Flutter 会话页已接入本模块，真实使用 `run(turn/review/rpc)` 驱动流式消息、工作区审查与上下文整理

## 约束

- 当前只支持 Android Native Runtime，不考虑 iOS
- `arm64 Codex` Native Core 仍保持冻结，本模块只消费既有 `codexm_native` bridge
- 真机 `arm64` 行为一致性仍待最终确认

## 依赖

- `flutter_app/packages/codexm_native/`
- `flutter_app/lib/features/settings/application/`
- `flutter_app/lib/features/sessions/application/`
- `flutter_app/lib/features/workspaces/application/`
- `flutter_app/lib/features/mcp/application/`
