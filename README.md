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
- 工作区：空白工作区创建、Git clone / pull、WebDAV 配置与同步
- 会话：单工作区单 session、历史恢复、流式消息、review / compact
- 输入增强：slash command、本地命令、`@` 文件与最近 commit mention
- MCP：全局作用域，仅支持 `Streamable HTTP/HTTP` 与 `Rust stdio (aarch64 build)`
- skills：全局作用域管理

## 仍待验证

- Android `arm64` 真机验收尚未执行
- 当前不支持 iOS
- 多 session / worktree 冲突管理暂不在范围内

## 环境要求

- Flutter `3.41.4`
- Dart `3.11.1`
- Android SDK `36`
- Android NDK `28.2.13676358`
- Python 3（用于下载 Android `codex` 依赖）

## 开发命令

```bash
cd flutter_app
flutter pub get
flutter analyze
flutter test
```

## 下载 Android Runtime 依赖

`codexm_native` 不直接提交 `codex` 二进制；首次构建前请执行：

```bash
python3 scripts/fetch_android_codex_deps.py --abi arm64-v8a
```

脚本会把以下产物放到 Flutter 插件运行时输入目录，随后由插件构建任务转换成 `jniLibs`：

- `codex`
- `codex-exec`
- `rg`
- `libcodex_z.so`
- `libcodex_lzma.so`

## 本地验证

```bash
./scripts/flutter_phase5_regression.sh
```

该脚本会自动执行：

1. 下载 Android Runtime 依赖
2. `flutter analyze`
3. `flutter test`
4. `./gradlew :app:assembleDebug`

## Android Release 构建

```bash
cd flutter_app
flutter build apk --release --target-platform android-arm64 --split-per-abi
```

## GitHub Actions

`/.github/workflows/flutter-android-release.yml` 会：

1. 安装 Java / Flutter / Android SDK / NDK / CMake
2. 下载 Flutter 插件所需的 `codex` Android 依赖
3. 执行 `flutter analyze` 与 `flutter test`
4. 构建 `arm64-v8a` release APK
5. 上传 Artifact，并在 tag 发布时附加到 GitHub Release
