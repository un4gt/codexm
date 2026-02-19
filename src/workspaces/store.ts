import * as FileSystem from 'expo-file-system/legacy';
import { ensureWorkspaceDirs, workspaceMetaPath } from './paths';
import type { Workspace, WorkspaceId } from './types';

const INDEX_FILE = 'workspaces.json';
const ACTIVE_FILE = 'active.json';

type WorkspaceIndex = {
    version: 1;
    workspaces: Workspace[];
};

const DOC = (FileSystem as any).documentDirectory as string | null | undefined;
if (!DOC) throw new Error('expo-file-system documentDirectory not available');

function indexPath() {
    // store global index under a shared meta dir
    const base = `${DOC}workspaces/.index/`;
    return `${base}${INDEX_FILE}`;
}

function activePath() {
    const base = `${DOC}workspaces/.index/`;
    return `${base}${ACTIVE_FILE}`;
}

async function ensureIndexDir() {
    const base = `${DOC}workspaces/.index/`;
    await FileSystem.makeDirectoryAsync(base, { intermediates: true });
}

export async function listWorkspaces(): Promise<Workspace[]> {
    await ensureIndexDir();
    const path = indexPath();
    const info = await FileSystem.getInfoAsync(path);
    if (!info.exists) return [];
    const raw = await FileSystem.readAsStringAsync(path);
    const parsed = JSON.parse(raw) as WorkspaceIndex;
    return parsed.workspaces ?? [];
}

export async function saveWorkspaceIndex(workspaces: Workspace[]) {
    await ensureIndexDir();
    const path = indexPath();
    const data: WorkspaceIndex = { version: 1, workspaces };
    await FileSystem.writeAsStringAsync(path, JSON.stringify(data, null, 2));
}

export async function getWorkspace(id: WorkspaceId): Promise<Workspace | null> {
    const all = await listWorkspaces();
    return all.find((w) => w.id === id) ?? null;
}

export async function upsertWorkspace(ws: Workspace) {
    const all = await listWorkspaces();
    const idx = all.findIndex((w) => w.id === ws.id);
    if (idx >= 0) all[idx] = ws;
    else all.unshift(ws);
    await saveWorkspaceIndex(all);
}

export async function removeWorkspaceFromIndex(id: WorkspaceId) {
    const all = await listWorkspaces();
    const next = all.filter((w) => w.id !== id);
    await saveWorkspaceIndex(next);
}

export async function initWorkspace(ws: Workspace) {
    await ensureWorkspaceDirs(ws.id);
    // also persist workspace.json under its .meta for integrity/debug
    const meta = workspaceMetaPath(ws.id);
    await FileSystem.writeAsStringAsync(`${meta}workspace.json`, JSON.stringify(ws, null, 2));
    await upsertWorkspace(ws);
}

export async function getActiveWorkspaceId(): Promise<WorkspaceId | null> {
    await ensureIndexDir();
    const path = activePath();
    const info = await FileSystem.getInfoAsync(path);
    if (!info.exists) return null;
    const raw = await FileSystem.readAsStringAsync(path);
    const parsed = JSON.parse(raw) as { id?: WorkspaceId };
    return parsed?.id ?? null;
}

export async function setActiveWorkspaceId(id: WorkspaceId | null) {
    await ensureIndexDir();
    const path = activePath();
    if (!id) {
        const info = await FileSystem.getInfoAsync(path);
        if (info.exists) await FileSystem.deleteAsync(path, { idempotent: true });
        return;
    }
    await FileSystem.writeAsStringAsync(path, JSON.stringify({ id }, null, 2));
}
