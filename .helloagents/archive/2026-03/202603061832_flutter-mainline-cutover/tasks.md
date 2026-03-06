@feature: flutter-mainline-cutover
@created: 2026-03-06 18:32 UTC
@status: completed
@mode: implementation

## 进度概览

- 完成：6
- 失败：0
- 跳过：0
- 总数：6

<!-- LIVE_STATUS_BEGIN -->
状态: completed | 进度: 6/6 (100%) | 更新: 2026-03-06 18:32:00
当前: 已完成 Flutter 主线切换、RN 清理、CI 修复与本地回归
<!-- LIVE_STATUS_END -->

## 任务列表

### Phase 0｜分析与定界

[√] 0.1 对比 RN 与 Flutter 已完成功能，确认主线切换范围 | depends_on: []
[√] 0.2 确认需保留的 Flutter 构建脚本、Native 插件与发布链路 | depends_on: [0.1]

### Phase 1｜仓库切换

[√] 1.1 清理 Expo / React Native 页面层、宿主工程、旧插件与旧依赖入口 | depends_on: [0.2]
[√] 1.2 将 Android `codex` 依赖下载脚本切换到 Flutter 插件资产目录 | depends_on: [0.2]
[√] 1.3 对齐 Flutter 插件 `jniLibs` 生成逻辑，补齐附属共享库映射 | depends_on: [1.2]
[√] 1.4 更新 Flutter Android release workflow、本地回归脚本与知识库 | depends_on: [1.1, 1.2, 1.3]

## 执行日志

- 2026-03-06 18:32 UTC｜创建方案包 `202603061832_flutter-mainline-cutover`
- 2026-03-06 18:32 UTC｜已完成 RN / Flutter 功能对比，确认 Flutter 已覆盖本轮主线能力
- 2026-03-06 18:32 UTC｜已清理 Expo / React Native 页面层、宿主工程、旧插件、旧脚本与旧工作流
- 2026-03-06 18:32 UTC｜已将 `codex` Android 依赖下载脚本切到 Flutter 插件目录
- 2026-03-06 18:32 UTC｜已对齐 Flutter 插件的 `jniLibs` 生成逻辑，补齐 `libcodex_z.so` / `libcodex_lzma.so`
- 2026-03-06 18:32 UTC｜已更新 Flutter Android release workflow、本地回归脚本、README 与知识库
- 2026-03-06 18:32 UTC｜子代理编排不可用，方案设计与实施由主代理降级执行
