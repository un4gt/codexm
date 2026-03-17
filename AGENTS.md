# Repository Guidelines

## Project Structure & Module Organization
- `flutter_app/`: Flutter Android app (entry: `lib/main.dart`).
- `flutter_app/lib/features/`: feature modules (`workspaces/`, `sessions/`, `settings/`, `mcp/`, `webdav/`, `codex/`).
- `flutter_app/packages/codexm_native/`: Flutter plugin that bridges the Android runtime + Git native core (Kotlin/C++).
- `flutter_app/test/`: Dart unit/widget tests (`*_test.dart`).
- `scripts/`: local tooling (Android runtime fetch + regression scripts).
- `docs/`: architecture + MCP notes.
- `.github/workflows/`: Android release pipeline.

## Build, Test, and Development Commands
Prereqs: Flutter `3.41.4` / Dart `3.11.1`, Android SDK `36` + NDK `28.2.13676358` (see `README.md`); Python 3 is required to fetch Android runtime deps. VS Code: install `Dart-Code.flutter` (see `.vscode/extensions.json`).

From repo root:
- `python3 scripts/fetch_android_codex_deps.py --abi arm64-v8a`: downloads Android `codex` runtime inputs for `codexm_native`.
- `./scripts/flutter_phase5_regression.sh`: recommended local regression (fetch deps → `flutter analyze` → `flutter test` → `:app:assembleDebug`).

From `flutter_app/`:
- `flutter pub get`: install Dart dependencies.
- `flutter analyze`: static analysis (uses `flutter_lints` via `analysis_options.yaml`).
- `flutter test`: run all Flutter tests.
- `flutter build apk --release --target-platform android-arm64 --split-per-abi`: build release APK(s).

## Coding Style & Naming Conventions
- Stick to Dart/Flutter conventions: 2-space indent, `lowerCamelCase` members, `UpperCamelCase` types, `snake_case.dart` files.
- Format Dart code with `dart format` (for example: `cd flutter_app && dart format lib test`).
- Keep user-facing UI copy free of internal/debug details (CLI flags, internal filenames like `config.toml`, or slash commands); put troubleshooting in `docs/` or logs.
- When touching native/plugin code, keep changes small and validate on Android `arm64-v8a`.

## Runtime Error Handling Guardrails
- Never map all runtime failures to one generic message (for example, do not always show “install release build and retry”).
- Classify Codex runtime failures into actionable buckets:
  - Missing packaged runtime binaries (`libcodex.so`, `libcodex_exec.so`, `librg.so`) → ask user to install a package that includes runtime components.
  - Permission/exec failures (`Permission denied`) → ask user to reinstall app/build.
  - Runtime starts then exits early (`runtime not running` / startup exit) → guide user to check `设置 > 连接设置` (`API Key` / `Base URL`) first.
  - Timeout/network/auth → guide user to check connectivity and credentials.
- Keep detailed diagnostics (raw stderr, linker/preflight details, native paths) in logs, not in user-facing copy.
- Before release builds, verify runtime packaging prerequisites:
  - Run `python3 scripts/fetch_android_codex_deps.py --abi arm64-v8a`.
  - Confirm APK/AAB includes runtime libs for target ABI.
  - Validate on real Android `arm64-v8a` device.

## Session UI/UX Guardrails
- Session page should stay simple and task-first, aligned with `happy-app` style principles: clear hierarchy, minimal chrome, obvious message entry.
- Input area must remain easy to find and use:
  - Keep composer in bottom area with a clear “发送” action.
  - Use direct copy such as “在这里输入消息...”; avoid developer-oriented hints in primary UI.
- Avoid repeated status/info blocks across header/sidebar/body; show one concise status at most when actionable.
- Prevent layout crowding/overlap on narrower devices:
  - Use conservative breakpoints for expanded/two-column layout.
  - Keep sidebar width bounded so chat area remains readable.
- Keep user-facing text product-oriented and concise:
  - No desktop-only guidance in core mobile flows.
  - No internal implementation terms unless user explicitly enters a debug flow.

## Testing Guidelines
- Add tests under `flutter_app/test/**` and name files `*_test.dart`.
- Prefer pure logic tests for `application/` code; use `testWidgets(...)` for UI flows.

## Commit & Pull Request Guidelines
- Follow the repo’s Conventional Commits pattern: `feat(scope): ...`, `fix(scope): ...`, `ci(release): ...`, `refactor(repo)!: ...`.
- PRs should include: what changed, how it was tested (commands + device/emulator), and screenshots/recordings for UI changes.

## Security & Configuration Tips
- Never commit secrets (API keys/tokens). Use platform secure storage and keep sample values out of screenshots.
- Do not commit downloaded runtime binaries; they are fetched via `scripts/fetch_android_codex_deps.py`.
