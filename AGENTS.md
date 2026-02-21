# Repository Guidelines

## Project Structure & Module Organization
- `app/`: Expo Router file-based routes and layouts (e.g. `app/_layout.tsx`, `app/(tabs)/_layout.tsx`).
- `components/`: UI building blocks (`ThemedText`, parallax, collapsible, icons).
- `hooks/`: Shared hooks (color scheme, theme colors).
- `constants/`: Design tokens (see `constants/theme.ts`).
- `src/`: Non-UI modules:
  - `src/codex/`: Codex client + SSE streaming + local server manager stubs.
  - `src/workspaces/`: On-device workspace metadata + filesystem layout (`expo-file-system`).
  - `src/webdav/`: Simple WebDAV client (HEAD/GET/PUT).
- `assets/`: Icons and images.
- `docs/`: Architecture and runtime plans (`docs/architecture.md`, `docs/codex-mobile-runtime.md`).

## Build, Test, and Development Commands
- `npm install`: Install dependencies.
- `npm start` (or `npx expo start`): Start the Expo dev server.
- `npm run android` / `npm run ios` / `npm run web`: Launch on a specific platform.
- `npm run lint`: Run ESLint via Expo (`eslint-config-expo` flat config).
- `npx tsc --noEmit`: Typecheck (TypeScript `strict` mode).
- `npm run reset-project`: Reset starter template (moves/removes template dirs and recreates `app/`).

## Coding Style & Naming Conventions
- TypeScript + React Native; prefer `import type { ... }` for type-only imports.
- Use the `@/` path alias for internal imports (configured in `tsconfig.json`).
- Keep formatting consistent with existing files: single quotes; UI code typically uses 2-space indentation.
- Recommended editor setup: enable ESLint fixes and import organization on save (see `.vscode/settings.json`).

## 用户界面文案规范
- 面向用户的 UI（标题、说明、placeholder、按钮、错误提示等）严格禁止出现开发者教学/调试内容，例如：命令行参数（如 `--foo`）、内部文件名/扩展名（如 `config.toml`、`.tar.gz`）、内部命令（如 `/debug-config`）等。
- 技术细节、示例与排错指引请放在 `docs/` 或代码注释中，不得出现在用户可见文案里。

## Testing Guidelines
- No test framework is configured yet. Keep business logic in `src/` as pure helpers to make future unit tests easy.
- If adding tests, use `*.test.ts(x)` or `__tests__/` and add an `npm test` script in the same PR.

## Commit & Pull Request Guidelines
- Git history does not establish conventions yet (only “Initial commit”).
- Recommended commit style: Conventional Commits (e.g. `feat(workspaces): add create flow`, `fix(codex): handle stream errors`).
- PRs should include: clear description, linked issue (if any), manual test steps (platform + steps), and screenshots for UI changes.

## Security & Configuration Tips
- Never commit secrets (API keys/tokens). Use secure storage on device and store references only.
- PowerShell tip: quote paths with parentheses, e.g. `Get-Content -Raw 'app/(tabs)/index.tsx'`.
