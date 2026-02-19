# Codex Mobile Runtime Plan (Android/iOS)

## Why the previous assumption was wrong
The earlier draft in [`docs/architecture.md`](docs/architecture.md:1) assumed Codex [`app-server`](https://github.com/openai/codex) would run on an external backend.

Your clarified requirement is: **Codex is bundled into the mobile app and executed locally**.

That changes the architecture: mobile must provide a *runtime* capable of launching and running the Codex CLI / server.

## Reality check: Codex execution requirements
Codex can be delivered in different forms:

1) **Node-based CLI/app-server** (needs a Node.js runtime).
2) **Native binary (Rust/Go/etc)** that can be executed on-device.
3) **Python-based service** (needs a Python runtime).

The link you provided points to **Termux builds** (Android) and the “Quick Install (Termux)” section explicitly installs `nodejs-lts` before installing the Codex CLI package. That implies that at least that distribution path relies on Node on Android.

## Feasible on-device execution options

### Option A — Android-first via embedded Node runtime (recommended for quickest PoC)
- Embed a Node runtime inside the Android app (e.g. nodejs-mobile or a custom JSI-based runtime).
- Bundle the Codex package (or ship it as assets) and launch:
  - `codex app-server --host 127.0.0.1 --port <port>`
- React Native talks to it via `http://127.0.0.1:<port>` (SSE/WebSocket depending on implementation).

Pros:
- Closest to “run `codex app-server`” literally.

Cons:
- iOS embedding is significantly harder (App Store review + sandbox + JIT restrictions).

### Option B — Native binary approach (cross-platform ideal, but depends on upstream)
- Build Codex as a native binary for Android/iOS.
- Ship binary in app and spawn it.

Pros:
- Best long-term; avoids Node.

Cons:
- Depends on upstream providing/allowing a stable native build of app-server.

### Option C — No local HTTP server: integrate Codex as a library
- Requires refactoring Codex so your app calls it as a library API.

Pros:
- Best UX and control.

Cons:
- Highest engineering cost; diverges from upstream.

## What we should implement next in this repo (client-side scaffolding)
Given Expo Dev Client constraints, the next incremental steps are:

1) Add a **`CodexLocalServerManager`** interface that assumes there is a local server at `127.0.0.1` and can:
   - start/stop
   - health check
   - provide baseUrl

2) Add a **`CodexClient`** that talks to `baseUrl` with:
   - create session
   - stream responses
   - send user messages

3) Keep the runtime pluggable:
   - Android: Node-embedded implementation
   - iOS: placeholder until runtime decision

## Open decisions (must be answered before iOS work)
- Do we support iOS in Phase A, or Android-only PoC first?
- Is the chosen Codex distribution strictly Node-based, or can we obtain a native app-server binary?
