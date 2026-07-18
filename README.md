# CodexM（Flutter Android）

CodexM 是一个以移动端为主的 Codex 交互与 coding 工作台，当前仓库已经收敛为 **Flutter Android 主线**。目标是在 Android `arm64` 设备上复用已跑通的 `Codex` Native Runtime 与 Git Native Core，并提供 workspace / session / MCP / WebDAV 的一体化体验。

## 当前主线

- `flutter_app/`：Flutter Android 应用主工程
- `flutter_app/packages/codexm_native/`：Flutter 原生插件，承接 Runtime / Git Native Core
- `.github/workflows/flutter-android-release.yml`：Flutter Android 发布工作流
- `scripts/fetch_android_codex_deps.py`：下载 `codex` / `codex-exec` / `rg` 与附属共享库
- `.helloagents/`：迁移与切换知识库

## 已完成能力

- 设置：密钥 / 地址 / 模型列表拉取、配置预览与连接配置生成
- 工作区：空白工作区创建、Git clone / pull、WebDAV 配置与同步，以及主集成分支管理
- 会话：单工作区多会话、Codex thread 恢复、独立 Git 分支与 linked worktree、流式消息、review / compact
- 代码流转：代码检查点、基于会话新建、会话间合并、合并到主工作区、冲突继续或放弃、归档与受保护删除
- 输入增强：slash command、本地命令、`@` 文件与最近 commit mention
- MCP：全局作用域，仅支持 `Streamable HTTP/HTTP` 与 `Rust stdio (aarch64 build)`
- skills：全局作用域管理

## 仍待验证

- Android `arm64` 真机验收尚未执行
- 当前不支持 iOS
- 同一时间只运行一个 Codex turn
- 会话合并仅修改本地仓库，不会自动推送远端

## 开发与发布

开发环境、构建命令、Android runtime 依赖、release 签名配置与 GitHub Actions 发布要求，统一见 `_develop.md`。
