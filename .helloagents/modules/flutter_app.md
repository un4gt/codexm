# 模块：flutter_app

## 职责

- 提供 Android-only Flutter 应用入口
- 承接主线页面壳层、主题、导航与业务实现

## 当前行为

- `lib/app/app.dart` 提供底部导航应用壳层，并维护当前工作区 / 当前会话共享上下文
- `lib/app/theme/app_theme.dart` 已提供页面留白、section 间距、card / input radius、composer 高度与内容最大宽度等主题令牌
- `lib/shared/widgets/feature_scaffold.dart` 已统一工作区、会话等页面的移动端 header / content 骨架，并按 Google 官方 `window size classes` 应用 `compact / medium / expanded` 留白分级
- `lib/shared/widgets/adaptive_breakpoints.dart` 已沉淀官方 `600 / 840dp` 宽度断点与页面留白辅助方法，供手机 / 平板自适应布局复用
- `features/workspaces` 已提供工作区列表、新建、激活、重命名、删除、Git clone / pull 与进入会话主链路
- `features/workspaces/presentation/` 已收敛为等宽主按钮 + 工作区列表卡片，不再在主界面展示 WebDAV、仓库详情与当前选中工作区大卡
- `features/sessions` 已提供会话列表、新建、重命名、删除、流式消息、slash command、本地命令与 `@` 标记能力
- `features/sessions/presentation/` 已按 Happy 风格重构为 header + message list + fixed composer 的单主会话视图，并通过头部按钮 + bottom sheet 管理会话切换；当前会随官方 `600 / 840dp` 断点调整页面留白、头部按钮堆叠与 composer 布局
- `features/sessions/presentation/widgets/` 已提供轻量 Markdown / CodeBlock / Thinking 渲染
- `features/settings` 已收敛为用户偏好与全局 skills 管理，不再暴露连接 / 模型 / 审批策略 / 回复风格 / 多代理等开发者导向配置
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
- 当前主线口径为 Android-only + 移动端优先交互；尚未补齐的主要差异项为真机 `arm64` 验证与 clone 真机场景回归
