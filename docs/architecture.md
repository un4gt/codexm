# CodexM Architecture (Expo + Codex app-server + libgit2 + WebDAV zip)

## Scope & Phasing

### Target (Phase A)
- Mobile app (Expo Dev Client) is **the primary UX**.
- Codex runs as an external **Codex app-server** (backend).
- Workspace lives on-device; Codex access to workspace is enabled via **snapshot/patch sync**.
- Git operations are local on-device via **libgit2 native module**.
- WebDAV is used for **zip import/export** (not file-level mirroring).

### Phase B/C (later)
- Phase B: offline queueing and reduced Codex features when backend unreachable.
- Phase C: full offline Codex execution (high cost; not required for initial delivery).

## High-level Components

### On-device (React Native)
- `WorkspaceManager`: create/list/open/delete workspaces; manages metadata and directory layout.
- `GitService` (native): clone/checkout/fetch/pull/push/status/diff/commit with progress + cancel.
- `WebDavZipService`: download/upload archives + checksum/etag validation.
- `CodexClient`: talks to backend app-server (streaming) + workspace sync (snapshot/patch).
- UI: workspace list, repo browser/editor integration, logs, progress, codex chat.

### Backend
- Codex [`app-server`](https://github.com/openai/codex).
- Workspace adapter:
  - Receives snapshot uploads from device.
  - Runs codex tools on server-side workspace folder.
  - Produces patch/diff back to device.

## Workspace Model

### Metadata (device)
- `id: string` (uuid)
- `name: string`
- `createdAt: number`
- `localPath: string` (root)
- `git?: { remoteUrl: string; defaultBranch?: string; authRef?: string }`
- `webdav?: { endpoint: string; basePath?: string; authRef?: string }`
- `codex?: { serverUrl: string }`

### Directory layout (device)
- `DocumentDirectory/workspaces/<id>/repo/` — git working tree
- `DocumentDirectory/workspaces/<id>/.meta/` — metadata, state, indexes
- `CacheDirectory/workspaces/<id>/tmp/` — unzip, temporary downloads

## Security
- Secrets (token/password) are stored in OS keystore; workspace stores `authRef` only.
- TLS is strict by default; enterprise CA/self-signed requires explicit allowlist/pinning.

## Git (libgit2)
- Exposed as async task-based APIs with progress events and cancel tokens.
- Credentials via callback for GitHub/GHE PAT.

## WebDAV (zip)
- Download/import into `repo/` (requires clean tree or new workspace).
- Export: zip current repo (optionally excluding `.git/`) and upload.

## Codex Workspace Sync Strategy (Phase A)

### Snapshot upload
- App zips workspace (excluding heavy caches) and uploads to backend.
- Backend unzips into an ephemeral working directory.

### Patch return
- Backend returns a patch (unified diff) or a changed-files bundle.
- App applies changes to local `repo/` and optionally commits.
