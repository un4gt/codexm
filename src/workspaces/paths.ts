import * as FileSystem from 'expo-file-system/legacy';
import type { WorkspaceId } from './types';

// expo-file-system exports these at runtime, but some TS setups fail to pick them up.
// Cast to keep build unblocked; runtime guard remains.
const DOC = (FileSystem as any).documentDirectory as string | null | undefined;
const CACHE = (FileSystem as any).cacheDirectory as string | null | undefined;

if (!DOC || !CACHE) {
    throw new Error('expo-file-system documentDirectory/cacheDirectory not available');
}

export function workspaceRoot(id: WorkspaceId) {
    return `${DOC}workspaces/${id}/`;
}

export function workspaceRepoPath(id: WorkspaceId) {
    return `${workspaceRoot(id)}repo/`;
}

export function workspaceMetaPath(id: WorkspaceId) {
    return `${workspaceRoot(id)}.meta/`;
}

export function workspaceCodexHomePath(id: WorkspaceId) {
    return `${workspaceMetaPath(id)}codex/`;
}

export function workspaceTmpPath(id: WorkspaceId) {
    return `${CACHE}workspaces/${id}/tmp/`;
}

export async function ensureWorkspaceDirs(id: WorkspaceId) {
    await FileSystem.makeDirectoryAsync(workspaceRepoPath(id), { intermediates: true });
    await FileSystem.makeDirectoryAsync(workspaceMetaPath(id), { intermediates: true });
    await FileSystem.makeDirectoryAsync(workspaceCodexHomePath(id), { intermediates: true });
    await FileSystem.makeDirectoryAsync(workspaceTmpPath(id), { intermediates: true });
}
