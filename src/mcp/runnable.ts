import * as FileSystem from 'expo-file-system/legacy';

import type { McpServer } from './types';

function pathToFileUri(pathOrUri: string) {
  const v = pathOrUri.trim();
  if (v.startsWith('file://')) return v;
  if (v.startsWith('/')) return `file://${v}`;
  return null;
}

export async function isMcpServerProbablyRunnable(server: McpServer) {
  if (server.transport === 'url') return Boolean(server.url?.trim());

  const cmd = server.command?.trim() ?? '';
  if (!cmd) return false;

  const uri = pathToFileUri(cmd);
  if (!uri) return true; // PATH/相对命令无法在 JS 侧可靠校验，保守认为可用。

  try {
    const info = await FileSystem.getInfoAsync(uri);
    return Boolean(info.exists && !info.isDirectory);
  } catch {
    return true;
  }
}
