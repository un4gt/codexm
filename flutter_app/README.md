# codexm

`flutter_app/` 是 CodexM 的 Flutter Android 主应用。

## 主要模块

- `lib/app/`：应用壳层与主题
- `lib/features/workspaces/`：工作区列表、创建、Git / WebDAV 相关能力
- `lib/features/sessions/`：会话恢复、流式消息、mention、slash command
- `lib/features/settings/`：鉴权、模型拉取、运行配置物化
- `lib/features/mcp/`：全局 MCP 管理
- `lib/features/codex/`：运行配置、JSON-RPC、SSE 与会话驱动

## 开发前准备

在仓库根目录执行：

```bash
python3 scripts/fetch_android_codex_deps.py --abi arm64-v8a
```

然后执行：

```bash
flutter pub get
flutter analyze
flutter test
```

## Android 构建

```bash
cd android
./gradlew :app:assembleDebug
```

当前仅支持 Android。
