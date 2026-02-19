import * as FileSystem from 'expo-file-system/legacy';

import type { WebDavEntry } from './types';
import { WebDavClient } from './webdavClient';

export type WebDavSyncProgress = {
  phase: 'list-remote' | 'list-local' | 'mkdir-local' | 'mkdir-remote' | 'download' | 'upload' | 'done';
  current?: number;
  total?: number;
  path?: string;
};

const DEFAULT_EXCLUDE_DIRS = new Set(['.git', 'node_modules', '.expo', 'dist', 'build']);

function ensureDirUri(uri: string) {
  return uri.endsWith('/') ? uri : `${uri}/`;
}

function joinUri(baseDirUri: string, name: string) {
  const base = ensureDirUri(baseDirUri);
  return `${base}${name}`;
}

function normalizeRemoteDir(path: string) {
  let p = path.trim();
  while (p.startsWith('/')) p = p.slice(1);
  if (p && !p.endsWith('/')) p += '/';
  return p;
}

function shouldExclude(relPath: string) {
  const parts = relPath.split('/').filter(Boolean);
  return parts.some((p) => DEFAULT_EXCLUDE_DIRS.has(p));
}

type LocalEntry = {
  uri: string;
  isDirectory: boolean;
  size?: number;
};

async function listLocalTree(rootDirUri: string, onProgress?: (p: WebDavSyncProgress) => void) {
  const root = ensureDirUri(rootDirUri);
  const files = new Map<string, LocalEntry>();
  const dirs = new Set<string>();

  onProgress?.({ phase: 'list-local' });

  async function walk(dirUri: string, relPrefix: string) {
    const items = await FileSystem.readDirectoryAsync(dirUri);
    for (const name of items) {
      const rel = relPrefix ? `${relPrefix}/${name}` : name;
      if (shouldExclude(rel)) continue;
      const uri = joinUri(dirUri, name);
      const info = await FileSystem.getInfoAsync(uri);
      if (!info.exists) continue;
      if (info.isDirectory) {
        dirs.add(rel);
        await walk(ensureDirUri(uri), rel);
      } else {
        files.set(rel, { uri, isDirectory: false, size: info.size ?? undefined });
      }
    }
  }

  await walk(root, '');

  return { files, dirs };
}

async function listRemoteTree(
  client: WebDavClient,
  remoteRootDir: string,
  onProgress?: (p: WebDavSyncProgress) => void
) {
  const root = normalizeRemoteDir(remoteRootDir);
  const rootNoSlash = root.replace(/\/$/, '');

  onProgress?.({ phase: 'list-remote' });

  const files = new Map<string, WebDavEntry>();
  const dirs = new Set<string>();

  async function walk(dir: string) {
    const entries = await client.propfind(dir, '1');
    for (const e of entries) {
      const full = e.path.replace(/\/$/, ''); // normalize no trailing slash
      const isDir = e.isCollection;

      // Skip the directory itself.
      if (rootNoSlash && full === rootNoSlash) continue;
      if (!rootNoSlash && full === '') continue;

      let rel = full;
      if (rootNoSlash) {
        if (full === rootNoSlash) rel = '';
        else if (full.startsWith(`${rootNoSlash}/`)) rel = full.slice(rootNoSlash.length + 1);
      }
      if (!rel) continue;
      if (shouldExclude(rel)) continue;

      if (isDir) {
        dirs.add(rel);
        await walk(`${full}/`);
      } else {
        files.set(rel, e);
      }
    }
  }

  await walk(root);
  return { files, dirs, root };
}

export async function pullWebDav(params: {
  client: WebDavClient;
  remoteRootDir: string;
  localRootDirUri: string;
  onProgress?: (p: WebDavSyncProgress) => void;
}) {
  const { client, localRootDirUri, onProgress } = params;
  const { files: remoteFiles, dirs: remoteDirs, root } = await listRemoteTree(
    client,
    params.remoteRootDir,
    onProgress
  );

  // Create local directories first.
  const dirs = Array.from(remoteDirs).sort((a, b) => a.localeCompare(b));
  for (let i = 0; i < dirs.length; i++) {
    const relDir = dirs[i];
    onProgress?.({ phase: 'mkdir-local', current: i + 1, total: dirs.length, path: relDir });
    await FileSystem.makeDirectoryAsync(joinUri(localRootDirUri, relDir), { intermediates: true });
  }

  const remoteEntries = Array.from(remoteFiles.entries());
  for (let i = 0; i < remoteEntries.length; i++) {
    const [rel, entry] = remoteEntries[i];
    onProgress?.({ phase: 'download', current: i + 1, total: remoteEntries.length, path: rel });

    const localUri = joinUri(localRootDirUri, rel);
    const localInfo = await FileSystem.getInfoAsync(localUri);
    const remoteSize = entry.contentLength;
    const shouldSkip = localInfo.exists && !localInfo.isDirectory && remoteSize != null && localInfo.size === remoteSize;
    if (shouldSkip) continue;

    // Ensure parent dir.
    const parent = rel.includes('/') ? rel.slice(0, rel.lastIndexOf('/')) : '';
    if (parent) await FileSystem.makeDirectoryAsync(joinUri(localRootDirUri, parent), { intermediates: true });

    await client.downloadToFile(`${root}${rel}`, localUri);
  }

  onProgress?.({ phase: 'done' });
}

export async function pushWebDav(params: {
  client: WebDavClient;
  remoteRootDir: string;
  localRootDirUri: string;
  onProgress?: (p: WebDavSyncProgress) => void;
}) {
  const { client, localRootDirUri, onProgress } = params;

  const { files: localFiles, dirs: localDirs } = await listLocalTree(localRootDirUri, onProgress);
  const { files: remoteFiles, root } = await listRemoteTree(client, params.remoteRootDir, onProgress);

  // Ensure remote root + directories.
  const allDirs = Array.from(localDirs).sort((a, b) => a.localeCompare(b));
  for (let i = 0; i < allDirs.length; i++) {
    const relDir = allDirs[i];
    onProgress?.({ phase: 'mkdir-remote', current: i + 1, total: allDirs.length, path: relDir });
    await client.mkcol(`${root}${relDir}/`);
  }

  const localEntries = Array.from(localFiles.entries());
  for (let i = 0; i < localEntries.length; i++) {
    const [rel, local] = localEntries[i];
    onProgress?.({ phase: 'upload', current: i + 1, total: localEntries.length, path: rel });

    const remote = remoteFiles.get(rel);
    const shouldSkip = remote?.contentLength != null && local.size != null && remote.contentLength === local.size;
    if (shouldSkip) continue;

    await client.uploadFile(`${root}${rel}`, local.uri);
  }

  onProgress?.({ phase: 'done' });
}
