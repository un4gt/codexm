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

## Testing Guidelines
- Add tests under `flutter_app/test/**` and name files `*_test.dart`.
- Prefer pure logic tests for `application/` code; use `testWidgets(...)` for UI flows.

## Commit & Pull Request Guidelines
- Follow the repo’s Conventional Commits pattern: `feat(scope): ...`, `fix(scope): ...`, `ci(release): ...`, `refactor(repo)!: ...`.
- PRs should include: what changed, how it was tested (commands + device/emulator), and screenshots/recordings for UI changes.

## Security & Configuration Tips
- Never commit secrets (API keys/tokens). Use platform secure storage and keep sample values out of screenshots.
- Do not commit downloaded runtime binaries; they are fetched via `scripts/fetch_android_codex_deps.py`.
