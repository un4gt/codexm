import * as FileSystem from 'expo-file-system/legacy';
import { Platform } from 'react-native';

import { chmodPath, extractTarGz } from '@/src/codex/nativeRuntime';

const DOC = FileSystem.documentDirectory ?? 'file:///';

export type McpInstallResult = {
  execUri: string;
  execPath: string;
};

export function mcpInstallsDirUri() {
  return `${DOC}mcp/installs/`;
}

export function managedExecUri(serverId: string) {
  return `${mcpInstallsDirUri()}${serverId}/server`;
}

function fileUriToPath(uriOrPath: string) {
  if (uriOrPath.startsWith('file://')) return uriOrPath.slice('file://'.length);
  return uriOrPath;
}

async function ensureDir(dirUri: string) {
  await FileSystem.makeDirectoryAsync(dirUri, { intermediates: true });
}

async function safeDelete(uri: string) {
  try {
    await FileSystem.deleteAsync(uri, { idempotent: true });
  } catch {
    // ignore
  }
}

function shouldIgnoreAsExecutableCandidate(name: string) {
  const lower = name.toLowerCase();
  if (!lower) return true;
  if (lower === 'readme' || lower.startsWith('readme.')) return true;
  if (lower === 'license' || lower.startsWith('license.')) return true;
  if (lower === 'changelog' || lower.startsWith('changelog.')) return true;
  if (lower === 'notice' || lower.startsWith('notice.')) return true;
  if (lower === 'copying' || lower.startsWith('copying.')) return true;
  if (lower.endsWith('.md')) return true;
  if (lower.endsWith('.txt')) return true;
  if (lower.endsWith('.json')) return true;
  if (lower.endsWith('.toml')) return true;
  if (lower.endsWith('.yaml') || lower.endsWith('.yml')) return true;
  if (lower.endsWith('.html')) return true;
  return false;
}

async function listFilesRecursive(dirUri: string): Promise<string[]> {
  const out: string[] = [];
  const names = await FileSystem.readDirectoryAsync(dirUri);
  for (const name of names) {
    const child = `${dirUri}${name}`;
    const info = await FileSystem.getInfoAsync(child);
    if (!info.exists) continue;
    if (info.isDirectory) {
      const nested = await listFilesRecursive(`${child}/`);
      out.push(...nested);
    } else {
      out.push(child);
    }
  }
  return out;
}

async function pickBestExecutableCandidate(extractDirUri: string) {
  const files = await listFilesRecursive(extractDirUri);
  if (!files.length) throw new Error('安装包为空，未找到可执行文件。');

  type Candidate = { uri: string; size: number; ignored: boolean };
  const candidates: Candidate[] = [];

  for (const uri of files) {
    const name = uri.split('/').pop() ?? '';
    const info = await FileSystem.getInfoAsync(uri);
    if (!info.exists) continue;
    if (info.isDirectory) continue;
    const size = typeof info.size === 'number' ? info.size : 0;
    candidates.push({ uri, size, ignored: shouldIgnoreAsExecutableCandidate(name) });
  }

  const preferred = candidates.filter((c) => !c.ignored);
  const pool = preferred.length ? preferred : candidates;
  pool.sort((a, b) => b.size - a.size);
  return pool[0].uri;
}

export async function isManagedInstalled(serverId: string) {
  const uri = managedExecUri(serverId);
  const info = await FileSystem.getInfoAsync(uri);
  if (!info.exists) return false;
  return !info.isDirectory;
}

export async function uninstallManagedMcp(serverId: string) {
  await safeDelete(`${mcpInstallsDirUri()}${serverId}/`);
}

export async function installManagedMcpFromUrl(serverId: string, url: string): Promise<McpInstallResult> {
  if (Platform.OS !== 'android') {
    throw new Error('仅 Android 支持运行时安装本地 Rust MCP 可执行文件。');
  }
  const trimmed = url.trim();
  if (!trimmed) throw new Error('URL 不能为空。');

  const installsDir = mcpInstallsDirUri();
  const rootUri = `${installsDir}${serverId}/`;
  const extractUri = `${rootUri}extract/`;
  const execUri = managedExecUri(serverId);
  const downloadUri = `${rootUri}download`;

  await ensureDir(installsDir);
  await safeDelete(rootUri);
  await ensureDir(extractUri);

  await FileSystem.downloadAsync(trimmed, downloadUri);

  const lower = trimmed.toLowerCase();
  if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
    await extractTarGz(downloadUri, extractUri);
    const candidate = await pickBestExecutableCandidate(extractUri);
    await FileSystem.copyAsync({ from: candidate, to: execUri });
  } else {
    await FileSystem.copyAsync({ from: downloadUri, to: execUri });
  }

  await chmodPath(execUri);

  await safeDelete(extractUri);
  await safeDelete(downloadUri);

  return { execUri, execPath: fileUriToPath(execUri) };
}
