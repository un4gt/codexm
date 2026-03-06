# 方案包：Flutter 主线切换与 RN 清理

- 包名：`202603061832_flutter-mainline-cutover`
- 创建时间：`2026-03-06 18:32 UTC`
- 类型：`implementation`
- 场景：对比现有 RN 与 Flutter 已完成功能后，将仓库切换为 Flutter Android 主线，清理 RN / Expo 代码与旧发布链路，同时补齐 Flutter CI 构建前置

## 1. 目标

- 以 `flutter_app/` 作为唯一移动端主线
- 移除 Expo / React Native 页面层、宿主工程、旧插件与旧依赖入口
- 保留并稳定 `arm64 Codex` Native Core 的 Flutter 承载方式
- 让 GitHub Actions 可以在干净环境下完成 Flutter Android 编译

## 2. 功能对比结论

### 2.1 RN 既有核心能力

- 工作区：创建、本地目录管理、Git 元数据
- 会话：Codex 流式对话、历史消息、slash command
- 设置：鉴权、地址、模型、配置落盘
- MCP：远程 / 本地 server 配置
- WebDAV：基础同步
- Native：Android Runtime / Git Native Core

### 2.2 Flutter 当前已完成覆盖

- 工作区：空白创建、Git clone / pull、调试信息、WebDAV 配置与同步
- 会话：单工作区单 session、自动恢复、流式消息、review / compact
- 输入：slash command、本地命令、`@` 文件 / commit mention
- 设置：密钥 / base URL / 模型列表、配置预览、`config.toml` 生成
- MCP：全局管理，支持 `Streamable HTTP/HTTP` 与 `Rust stdio (aarch64 build)`
- skills：全局管理
- Native：Flutter `codexm_native` 已承接 Runtime / Git Native Core

### 2.3 本轮明确不追求

- iOS
- 多 session / worktree 冲突管理
- 保留 RN 回滚基线

## 3. 关键决策

- `flutter-mainline-cutover#D001`：仓库收敛为 Flutter Android 主线，不再保留 RN 页面层与旧宿主
- `flutter-mainline-cutover#D002`：`codex` Android 二进制继续采用“构建前下载”策略，不直接提交入库
- `flutter-mainline-cutover#D003`：Flutter 插件的 `jniLibs` 生成逻辑与旧 RN 打包策略对齐，保留附属共享库映射
- `flutter-mainline-cutover#D004`：GitHub Actions 统一走 Flutter release workflow，并显式安装 Android SDK / NDK / CMake

## 4. 实施范围

### 删除

- `app/`
- `components/`
- `constants/`
- `hooks/`
- `src/`
- 根目录 `android/`
- `packages/codexm-native/`
- `plugins/`
- 旧 RN / Expo 配置与工作流

### 保留 / 更新

- `flutter_app/`
- `flutter_app/packages/codexm_native/`
- `scripts/fetch_android_codex_deps.py`
- `scripts/flutter_phase5_regression.sh`
- `.github/workflows/flutter-android-release.yml`
- `README.md`
- `.helloagents/`

## 5. 风险

- 干净环境构建若未下载 `codex` 二进制会直接失败
- 若 Flutter 插件未携带附属共享库，运行时可能出现动态链接失败
- 删除 RN 基线后，仓库内不再保留快速回滚路径

## 6. 验收

- RN / Expo 代码与旧工作流已从仓库移除
- Flutter 相关文档、脚本、知识库口径一致
- `flutter analyze` 通过
- `flutter test` 通过
- `cd flutter_app/android && ./gradlew :app:assembleDebug` 通过
- Flutter release workflow 在逻辑上可于干净 GitHub Actions 环境完成构建
