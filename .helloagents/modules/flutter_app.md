# 模块：flutter_app

## 职责

- 提供 Android-only Flutter 应用入口
- 承接主线页面壳层、主题、导航与业务实现

## 当前行为

- `lib/app/app.dart` 提供底部导航应用壳层，并维护当前工作区 / 当前会话共享上下文
- `features/workspaces` 已提供工作区列表、新建、激活、重命名、详情摘要、WebDAV 配置/同步入口与工作区调试信息卡片
- `features/sessions` 已提供会话列表、新建、重命名、删除、流式消息、review / compact 操作与日志查看
- `features/sessions/presentation/widgets/` 已提供轻量 Markdown / CodeBlock / Thinking 渲染
- `features/settings` 已提供模型 / 地址 / 密钥 / 偏好 / 高级配置编辑、全局 MCP / skills 管理与运行配置生成
- `features/settings` 页会读取 `codexm_native` 的基础平台信息，并保留 Android smoke 验证入口
- `features/mcp` 已提供扩展服务列表、添加、编辑、删除、全局启用切换、托管安装/卸载交互与可运行性摘要
- `features/webdav/application/` 已提供基础客户端与同步服务，并通过单元测试验证
- `features/codex/application/` 已提供 Codex 配置/环境注入、JSON-RPC、SSE、会话驱动与 skills/slash command 服务层
- Android 工程已可通过 `./gradlew :app:assembleDebug` 完成宿主编译
- 已补齐 release signing 注入点与 Flutter Android release workflow，可产出 `arm64-v8a` release APK

## 依赖

- `flutter_app/packages/codexm_native/`
- Flutter Material 3
- `flutter_secure_storage`
- `uuid`
- `xml`
- Flutter `Stream` / `HttpClient` 能力（用于 Codex JSON-RPC 与 SSE）

## 约束

- 当前只支持 Android
- 真机 `arm64` 烟雾验证仍未执行
- `arm64 Codex` Native Core 仍保持冻结，Flutter 侧只在宿主/UI/持久化层扩展
- 当前主线口径为 Android-only + 全局能力管理；尚未补齐的主要差异项为真机 `arm64` 验证
