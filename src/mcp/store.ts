import * as FileSystem from 'expo-file-system/legacy';

import { uuidV4 } from '@/src/utils/uuid';

import type { McpIndex, McpServer, McpServerCreateParams, McpServerId } from './types';

const DOC = FileSystem.documentDirectory ?? 'file:///';

type StoredMcpIndex = Partial<McpIndex> & { version?: number };

function mcpDir() {
  return `${DOC}mcp/`;
}

function indexPath() {
  return `${mcpDir()}index.json`;
}

async function ensureMcpDir() {
  await FileSystem.makeDirectoryAsync(mcpDir(), { intermediates: true });
}

function sanitizeConfigKey(input: string) {
  const raw = input.trim().toLowerCase();
  const replaced = raw
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-+/, '')
    .replace(/-+$/, '');
  return replaced || 'mcp';
}

function ensureUniqueConfigKey(base: string, existing: Set<string>) {
  if (!existing.has(base)) return base;
  for (let i = 2; i < 10_000; i++) {
    const next = `${base}-${i}`;
    if (!existing.has(next)) return next;
  }
  return `${base}-${Date.now()}`;
}

async function readIndex(): Promise<McpIndex> {
  await ensureMcpDir();
  const path = indexPath();
  const info = await FileSystem.getInfoAsync(path);
  if (!info.exists) return { version: 1, servers: [] };

  const raw = await FileSystem.readAsStringAsync(path);
  const parsed = JSON.parse(raw) as StoredMcpIndex;
  const servers = Array.isArray(parsed?.servers) ? (parsed.servers as McpServer[]) : [];
  return { version: 1, servers };
}

async function writeIndex(idx: McpIndex) {
  await ensureMcpDir();
  await FileSystem.writeAsStringAsync(indexPath(), JSON.stringify(idx, null, 2));
}

function validateServer(server: Omit<McpServer, 'id' | 'createdAt' | 'updatedAt'>) {
  if (!server.name?.trim()) throw new Error('MCP 名称不能为空。');
  if (!server.configKey?.trim()) throw new Error('MCP configKey 不能为空。');

  if (server.transport === 'url') {
    const url = server.url?.trim() ?? '';
    if (!url) throw new Error('URL 不能为空。');
    const lower = url.toLowerCase();
    if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
      throw new Error('URL 必须以 http:// 或 https:// 开头。');
    }
  }

  if (server.transport === 'stdio') {
    const cmd = server.command?.trim() ?? '';
    if (!cmd) throw new Error('command 不能为空。');
  }
}

export async function listMcpServers(): Promise<McpServer[]> {
  const idx = await readIndex();
  return idx.servers ?? [];
}

export async function addMcpServer(params: McpServerCreateParams): Promise<McpServer> {
  const idx = await readIndex();
  const now = Date.now();

  const requestedId = params.id?.trim();
  if (requestedId) {
    const exists = (idx.servers ?? []).some((s) => s.id === requestedId);
    if (exists) throw new Error('MCP id 已存在，请重试。');
  }

  const existingKeys = new Set((idx.servers ?? []).map((s) => String(s.configKey ?? '').toLowerCase()).filter(Boolean));
  const baseKey = sanitizeConfigKey(params.configKey?.trim() ? params.configKey : params.name);
  const configKey = ensureUniqueConfigKey(baseKey, existingKeys);

  const server: McpServer = {
    id: requestedId ?? uuidV4(),
    kind: 'rmcp',
    name: params.name.trim(),
    configKey,
    transport: params.transport,
    url: params.transport === 'url' ? params.url?.trim() : undefined,
    command: params.transport === 'stdio' ? params.command?.trim() : undefined,
    args: params.transport === 'stdio' ? (params.args ?? []) : undefined,
    createdAt: now,
    updatedAt: now,
  };

  validateServer(server);

  const next: McpIndex = { version: 1, servers: [server, ...(idx.servers ?? [])] };
  await writeIndex(next);
  return server;
}

export async function updateMcpServer(id: McpServerId, patch: Partial<McpServerCreateParams>): Promise<McpServer> {
  const idx = await readIndex();
  const current = (idx.servers ?? []).find((s) => s.id === id);
  if (!current) throw new Error(`MCP server not found: ${id}`);

  const existingKeys = new Set(
    (idx.servers ?? [])
      .filter((s) => s.id !== id)
      .map((s) => String(s.configKey ?? '').toLowerCase())
      .filter(Boolean)
  );

  const nextConfigKeyRaw =
    typeof patch.configKey === 'string' && patch.configKey.trim() ? patch.configKey.trim() : current.configKey;
  const nextConfigKey = ensureUniqueConfigKey(sanitizeConfigKey(nextConfigKeyRaw), existingKeys);

  const next: McpServer = {
    ...current,
    ...patch,
    name: typeof patch.name === 'string' ? patch.name : current.name,
    configKey: nextConfigKey,
    updatedAt: Date.now(),
  };

  // 归一化字段：避免 transport 变更后遗留无效字段
  if (next.transport === 'url') {
    next.url = (patch.url ?? current.url)?.trim();
    next.command = undefined;
    next.args = undefined;
  } else {
    next.command = (patch.command ?? current.command)?.trim();
    next.args = patch.args ?? current.args ?? [];
    next.url = undefined;
  }

  validateServer(next);

  const servers = (idx.servers ?? []).map((s) => (s.id === id ? next : s));
  await writeIndex({ version: 1, servers });
  return next;
}

export async function deleteMcpServer(id: McpServerId) {
  const idx = await readIndex();
  const servers = (idx.servers ?? []).filter((s) => s.id !== id);
  await writeIndex({ version: 1, servers });
}

