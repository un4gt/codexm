# Repository Guidelines

## Project Structure & Module Organization
- `flutter_app/`: Flutter Android 主应用（页面、状态、业务服务层）。
- `flutter_app/lib/features/`: 按业务域组织的 Flutter 代码（`workspaces` / `sessions` / `settings` / `mcp` / `webdav` / `codex`）。
- `flutter_app/packages/codexm_native/`: Flutter Android 原生插件，承接 Runtime / Git Native Core。
- `scripts/`: Flutter 构建辅助脚本（如 Android `codex` 依赖下载、回归脚本）。
- `.github/workflows/`: Flutter Android CI/CD 工作流。
- `docs/`: Flutter 主线架构与 MCP 说明。
- `.helloagents/`: 迁移知识库、方案包与变更记录。

## Build, Test, and Development Commands
- `python3 scripts/fetch_android_codex_deps.py --abi arm64-v8a`: 下载 Flutter 插件需要的 Android `codex` 运行时文件。
- `cd flutter_app && flutter pub get`: 安装 Flutter 依赖。
- `cd flutter_app && flutter analyze`: 运行 Dart/Flutter 静态检查。
- `cd flutter_app && flutter test`: 运行 Flutter 测试。
- `cd flutter_app/android && ./gradlew :app:assembleDebug`: 验证 Android Debug 宿主构建。
- `./scripts/flutter_phase5_regression.sh`: 执行当前推荐的本地回归命令集。

## Coding Style & Naming Conventions
- Dart / Flutter 为主，原生桥接使用 Kotlin / C++。
- 保持与现有文件风格一致；Dart 代码优先沿用现有 feature 分层与命名。
- Android Native Core 属于冻结区，除非任务明确要求，否则避免改动运行时语义。
- Recommended editor setup: enable ESLint fixes and import organization on save (see `.vscode/settings.json`).

## 用户界面文案规范
- 面向用户的 UI（标题、说明、placeholder、按钮、错误提示等）严格禁止出现开发者教学/调试内容，例如：命令行参数（如 `--foo`）、内部文件名/扩展名（如 `config.toml`、`.tar.gz`）、内部命令（如 `/debug-config`）等。
- 技术细节、示例与排错指引请放在 `docs/` 或代码注释中，不得出现在用户可见文案里。

## Testing Guidelines
- 使用 `flutter test` 作为默认测试入口。
- 新增 Dart 逻辑优先放在 `lib/features/**/application/`，并在 `flutter_app/test/` 下补纯逻辑测试。
- 原生插件相关验证优先使用现有 `flutter analyze`、`flutter test` 与 Android 构建校验组合。

## Commit & Pull Request Guidelines
- Git history does not establish conventions yet (only “Initial commit”).
- Recommended commit style: Conventional Commits (e.g. `feat(workspaces): add create flow`, `fix(codex): handle stream errors`).
- PRs should include: clear description, linked issue (if any), manual test steps (platform + steps), and screenshots for UI changes.

## Security & Configuration Tips
- Never commit secrets (API keys/tokens). Use secure storage on device and store references only.
- Android `codex` 二进制与附属共享库默认通过脚本下载，不直接提交入库。

## Known Gotchas (2026-03-06)
- GitHub Actions Flutter release 构建前必须先下载 Android `codex` 依赖，并安装 Android SDK `36`、NDK `28.2.13676358` 与 CMake。
- Android: spawning packaged native executables (Codex runtime) can exit immediately with missing `libc++_shared.so`. When using `ProcessBuilder`, make sure `LD_LIBRARY_PATH` includes `applicationInfo.nativeLibraryDir` so the dynamic linker can find the app-bundled shared libraries.
- Flutter 插件打包时需要同时映射 `libcodex_z.so` 与 `libcodex_lzma.so`，否则运行时可能出现动态链接失败。
