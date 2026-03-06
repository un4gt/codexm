# Expo 下线顺序与主线切换方案

> 2026-03-06 更新：该草案已被 `202603061832_flutter-mainline-cutover` 的实际执行结果覆盖；当前仓库已切换为 Flutter-only Android 主线。以下内容保留为历史决策轨迹。

> 适用阶段：`5.3`  
> 当前状态：已形成候选切换方案，**最终确认仍依赖 `5.2` 真机验证通过**。

## 1. 切换目标

- 将 `flutter_app/` 提升为 Android 主线交付物
- 将 `Expo + React Native` 保留为短期回滚基线
- 在不破坏已跑通的 `arm64 Codex` Native Core 语义前提下，逐步下线 Expo 依赖

## 2. 切换闸门

只有同时满足以下条件，才允许进入“正式主线切换”：

1. `5.1` 自动回归完成
2. `5.2` Android `arm64` 真机验证通过
3. Flutter release 构建链路可重复执行
4. Flutter 侧遗留差异项已接受（补齐或明确延期）

## 3. 推荐下线顺序

### Stage A｜冻结 RN 基线

- 打 Tag 记录 RN 稳定基线
- 冻结 `app/`、`src/`、`components/` 上的新功能开发
- 在知识库记录“RN 仅接受阻断性修复”

### Stage B｜双线并行

- 保留现有 Expo Android 发布链路
- 同时启用 Flutter Android release workflow
- 所有 Android 候选改动优先在 Flutter 线落地

### Stage C｜切换 Android 主产物

- 发布物从 Expo APK 切到 Flutter APK
- 将 QA / 内测安装包默认指向 Flutter 构建产物
- Expo Android 发布工作流改为“回滚备用”状态

### Stage D｜下线 Expo 页面层

先归档、后删除，顺序建议：

1. `app/` 路由页
2. `components/`、`hooks/`、`constants/`
3. `src/markdown/`
4. `src/workspaces/`、`src/sessions/`、`src/mcp/`、`src/webdav/`、`src/codex/`

### Stage E｜下线 Expo 依赖与插件

当 Stage D 完成且回滚窗口关闭后，再移除：

1. `expo-router`、`@react-navigation/*`、`react-native-paper`
2. `expo-*` 运行时依赖
3. `plugins/with*.js`
4. `packages/codexm-native/`（RN 插件版本）
5. 根目录 RN Android 宿主构建链路

## 4. 回滚策略

若 Flutter 主线在 `5.2` 或发布后首轮内测中出现阻断问题：

- 立即恢复 Expo Android 发布链路为主产物
- Flutter 分支仅继续修复，不进行依赖删除
- `packages/codexm-native/`、`plugins/`、RN 页面层保持原样

## 5. 当前建议

- **现在不要执行 Expo 依赖删除**
- 先完成 `5.2` 真机验证
- 以本文件作为 `5.3` 的候选切换脚本，在真机通过后再转为最终决策
