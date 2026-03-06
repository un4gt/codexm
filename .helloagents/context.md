# 项目上下文

## 基本信息

- 项目名：`codexm`
- 当前主线：`Flutter Android`
- 平台范围：`Android-only`
- 当前阶段：`Flutter-only 主线已切换完成，待执行 Android arm64 真机验收`

## 现状概述

当前仓库已移除 Expo / React Native 页面层、宿主工程与旧发布链路，只保留 Flutter Android 所需的代码、脚本与知识库。

当前产品结构为：

- `flutter_app/`：Flutter Android 应用
- `flutter_app/packages/codexm_native/`：Android Native Plugin
- `scripts/fetch_android_codex_deps.py`：运行时二进制下载脚本
- `.github/workflows/flutter-android-release.yml`：Android release 工作流

## 技术上下文

### 当前 Flutter 主线

- `flutter_app/`：Android-only Flutter App
- `flutter_app/packages/codexm_native/`：Flutter Plugin
- Flutter 端当前已具备：
  - Material 3 应用壳层
  - 工作区列表 / 创建 / Git clone / pull / WebDAV 配置与同步
  - 单工作区单 session、历史恢复、流式消息、review / compact
  - `@` 文件 / 最近 commit mention
  - slash command、本地命令与 Markdown 渲染
  - 设置页模型拉取、配置预览与 `config.toml` 物化
  - 全局 MCP 管理（`Streamable HTTP/HTTP`、`Rust stdio (aarch64 build)`）
  - 全局 skills 管理
  - Android Runtime / Git Native Core Flutter 桥接
  - `codex` 资产下载脚本与 `jniLibs` 打包脚手架
  - Flutter Android release workflow 与签名接入点

## 当前约束

- 不考虑 `iOS`
- `arm64 Codex` 运行链路属于冻结区，尽量不改行为语义
- 真机 `arm64` 验证仍未执行
- Flutter 侧工作区高级配置收敛为“调试信息”卡片
- MCP 选择已改为全局配置：仅支持 `Streamable HTTP/HTTP` 与 `Rust stdio (aarch64 build)` 两类接入
- skills 目录已明确为全局作用域，设置页已补齐全局列表、载入、编辑、保存与删除能力
- 当前仍待补齐的主要差异包括：Android `arm64` 真机验证

## 下一步

- 执行 Android `arm64` 真机验收
- 基于真机结果做 release / 回滚演练
- 沿 Flutter 主线继续收敛体验问题
