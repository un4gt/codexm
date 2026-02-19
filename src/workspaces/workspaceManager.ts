import * as FileSystem from 'expo-file-system/legacy';

import { workspaceRoot } from './paths';
import { getActiveWorkspaceId, getWorkspace, initWorkspace, listWorkspaces, removeWorkspaceFromIndex, setActiveWorkspaceId, upsertWorkspace } from './store';
import type { Workspace, WorkspaceId } from './types';
import { uuidV4 } from '@/src/utils/uuid';

export async function createWorkspace(params: {
    name: string;
    git?: Workspace['git'];
    webdav?: Workspace['webdav'];
}): Promise<Workspace> {
    const id: WorkspaceId = uuidV4();
    const ws: Workspace = {
        id,
        name: params.name,
        createdAt: Date.now(),
        localPath: workspaceRoot(id),
        git: params.git,
        webdav: params.webdav,
    };
    await initWorkspace(ws);
    return ws;
}

export async function getAllWorkspaces() {
    return await listWorkspaces();
}

export async function getActiveWorkspace(): Promise<Workspace | null> {
    const activeId = await getActiveWorkspaceId();
    if (!activeId) return null;
    const all = await listWorkspaces();
    return all.find((w) => w.id === activeId) ?? null;
}

export async function setActiveWorkspace(id: WorkspaceId | null) {
    await setActiveWorkspaceId(id);
}

export async function deleteWorkspace(id: WorkspaceId) {
    const activeId = await getActiveWorkspaceId();
    if (activeId === id) await setActiveWorkspaceId(null);

    await removeWorkspaceFromIndex(id);
    await FileSystem.deleteAsync(workspaceRoot(id), { idempotent: true });
}

export async function updateWorkspace(id: WorkspaceId, patch: Partial<Omit<Workspace, 'id'>>) {
    const ws = await getWorkspace(id);
    if (!ws) throw new Error(`Workspace not found: ${id}`);
    const next: Workspace = { ...ws, ...patch, id: ws.id };
    await upsertWorkspace(next);
    return next;
}
