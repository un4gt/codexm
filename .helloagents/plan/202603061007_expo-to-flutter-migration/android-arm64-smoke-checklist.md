# Android `arm64` 真机验证清单

> 目标：在不改写既有 `arm64 Codex` Native Core 语义的前提下，验证 Flutter Android 宿主已具备接管运行时、Git、MCP 与核心会话链路的条件。

## 当前使用方式

- 本文件是 `1.5` 与 `5.2` 共用的真机验证模板
- 当前会话约束为“暂不执行真机测试”，因此本文件先作为待执行清单保留
- 真机验证前，先执行 `scripts/flutter_phase5_regression.sh`

## 前置条件

- 构建产物：`flutter_app/android` 已通过 `./gradlew :app:assembleDebug`
- 设备：Android `arm64-v8a` 真机
- 安装包：`flutter_app/build/app/outputs/flutter-apk/app-debug.apk`
- 插件状态：`codexm_native` 已接通 `MethodChannel` / `EventChannel`
- Flutter UI 已接入真实工作区 / 会话 / MCP / 设置页面

## 验证项

> 记录方式：每一项请补充“结果 / 备注”，便于 `5.2` 后直接回填差异项。

### 1. 启动链路

| 项目 | 预期 | 结果 | 备注 |
|---|---|---|---|
| 安装并启动 Flutter `debug` 包 | App 正常启动，无闪退 | [ ] |  |
| 进入设置页或 smoke 页读取平台信息 | `codexm_native.getPlatformVersion()` 返回正常 | [ ] |  |
| 进入工作区页创建工作区 | 目录准备成功 | [ ] |  |
| 进入会话页创建会话 | 会话与消息列表可加载 | [ ] |  |
| 调用 `runtime.start` | 返回合法 `runtimeId` | [ ] |  |
| 监听 `runtime_lines` | 能收到 stdout / stderr 行事件 | [ ] |  |

### 2. 首轮消息

| 项目 | 预期 | 结果 | 备注 |
|---|---|---|---|
| 会话页发送首轮消息 | UI 出现流式回复 | [ ] |  |
| 多轮继续发送 | 线程上下文保持连续 | [ ] |  |
| 执行“审查工作区” | 能返回 review 结果 | [ ] |  |
| 执行“整理上下文” | 能完成 compact 并返回结果 | [ ] |  |
| 非法工作目录 / 非法参数启动 | Flutter 侧收到结构化错误信息 | [ ] |  |

### 3. Git 基础能力

| 项目 | 预期 | 结果 | 备注 |
|---|---|---|---|
| `git.status` | 返回 `staged / unstaged / untracked` | [ ] |  |
| `git.diff` | 返回文本 diff，且受 `maxBytes` 限制 | [ ] |  |
| `git.checkout` | 可切换目标分支或提交 | [ ] |  |

### 4. MCP / 目录契约前置

| 项目 | 预期 | 结果 | 备注 |
|---|---|---|---|
| 工作区目录与 RN 基线一致 | `workspaceRoot / repo / .meta / tmp` 对齐 | [ ] |  |
| MCP URL / stdio 配置可正常保存 | 新增、编辑、删除生效 | [ ] |  |
| 运行时 `PATH / LD_LIBRARY_PATH` 注入正确 | 可解析 `codex-exec` 与 `rg` | [ ] |  |

## 通过标准

- 启动、首轮消息、Git 状态/差异三项全部通过
- 未出现 `Permission denied`、缺失动态库、EventChannel 无事件三类阻断问题
- 对 `arm64 Codex` 冻结区仅发生桥接层改动，无需回退 Native Core 逻辑

## 执行后输出

完成真机验证后，请将结果同步回：

- `.helloagents/plan/202603061007_expo-to-flutter-migration/tasks.md`
- `.helloagents/plan/202603061007_expo-to-flutter-migration/phase5-regression-matrix.md`
- `.helloagents/context.md`
