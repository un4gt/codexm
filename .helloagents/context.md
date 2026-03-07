# 项目上下文

## 基本信息

- 项目名：`codexm`
- 当前主线：`Flutter Android`
- 平台范围：`Android-only`
- 当前阶段：`Flutter-only 主线已切换完成；已完成 Happy 风格三大 tab 重构并通过本地验证`

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
  - 基于 Google 官方 `window size classes` 的 `600 / 840dp` 手机 / 平板宽度断点
  - 工作区列表 / 创建 / Git clone / pull 与轻量进入会话链路
  - Happy 风格单主会话、历史恢复、流式消息、固定底部输入区
  - `@` 文件 / 最近 commit mention
  - slash command、本地命令与 Markdown 渲染
  - 精简后的用户偏好设置与全局 skills 管理
  - 全局 MCP 管理（`Streamable HTTP/HTTP`、`Rust stdio (aarch64 build)`）
  - Android Runtime / Git Native Core Flutter 桥接
  - `codex` 资产下载脚本与 `jniLibs` 打包脚手架
  - Flutter Android release workflow 与签名接入点

## 当前约束

- 不考虑 `iOS`
- `arm64 Codex` 运行链路属于冻结区，尽量不改行为语义
- 真机 `arm64` 验证仍未执行
- 会话 / 工作区 / 设置三大 tab 已收敛为移动端优先的信息架构，避免开发者配置直出主界面
- MCP 选择已改为全局配置：仅支持 `Streamable HTTP/HTTP` 与 `Rust stdio (aarch64 build)` 两类接入
- skills 目录已明确为全局作用域，设置页已补齐全局列表、载入、编辑、保存与删除能力
- 当前仍待补齐的主要差异包括：Android `arm64` 真机体验验收，以及 public/private/self-signed 仓库的真机 clone 烟雾覆盖

## 下一步

- 已完成方案包 `202603071140_happy-style-tab-rework`
- 下一步执行 Android `arm64` 真机体验验收
- 基于真机结果做 release / 回滚演练
