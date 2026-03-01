import { File } from 'expo-file-system';
import * as FileSystem from 'expo-file-system/legacy';

import { workspaceCodexHomePath } from '@/src/workspaces/paths';
import type { WorkspaceId } from '@/src/workspaces/types';

type DebugLogRecord = {
  ts: string;
  workspaceId: string;
  sessionId: string;
  event: string;
  message?: string;
  details?: string;
};

const encoder = new TextEncoder();

const writeQueues = new Map<string, Promise<void>>();

function enqueue(fileUri: string, task: () => Promise<void>) {
  const prev = writeQueues.get(fileUri) ?? Promise.resolve();
  const next = prev
    .catch(() => {})
    .then(task)
    .catch(() => {});
  writeQueues.set(fileUri, next);
  next.finally(() => {
    if (writeQueues.get(fileUri) === next) writeQueues.delete(fileUri);
  });
  return next;
}

function sanitizeFileStem(stem: string) {
  const t = stem.trim();
  const base = t ? t : 'session';
  const cleaned = base.replace(/[^a-zA-Z0-9._-]+/g, '_').replace(/^_+|_+$/g, '');
  return (cleaned || 'session').slice(0, 64);
}

function logDirUri(workspaceId: WorkspaceId) {
  return `${workspaceCodexHomePath(workspaceId)}logs/`;
}

function sessionLogFileUri(workspaceId: WorkspaceId, sessionId: string) {
  const safe = sanitizeFileStem(sessionId);
  return `${logDirUri(workspaceId)}${safe}.log`;
}

function redactSecrets(text: string): string {
  let out = text;
  // Redact OpenAI-style keys.
  out = out.replace(/sk-[a-zA-Z0-9_-]{10,}/g, 'sk-***');
  // Redact bearer tokens.
  out = out.replace(/Bearer\s+[a-zA-Z0-9._-]{10,}/g, 'Bearer ***');
  return out;
}

function safeDetails(details?: unknown): string | undefined {
  if (details == null) return undefined;
  try {
    if (details instanceof Error) return redactSecrets(details.stack || details.message);
    if (typeof details === 'string') return redactSecrets(details);
    return redactSecrets(JSON.stringify(details));
  } catch {
    return redactSecrets(String(details));
  }
}

async function ensureDirAndFile(fileUri: string) {
  const dir = fileUri.slice(0, fileUri.lastIndexOf('/') + 1);
  try {
    await FileSystem.makeDirectoryAsync(dir, { intermediates: true });
  } catch {
    // ignore
  }

  try {
    const info = await FileSystem.getInfoAsync(fileUri);
    if (!info.exists) await FileSystem.writeAsStringAsync(fileUri, '');
  } catch {
    // ignore
  }
}

function appendWithHandle(fileUri: string, text: string) {
  const file = new File(fileUri);
  const handle = file.open();
  try {
    const size = handle.size ?? 0;
    // Setting offset beyond size appends at end.
    handle.offset = size + 1;
    handle.writeBytes(encoder.encode(text));
  } finally {
    try {
      handle.close();
    } catch {
      // ignore
    }
  }
}

export async function pruneDebugLogs(workspaceId: WorkspaceId, retentionDays: number) {
  const days = Math.floor(retentionDays);
  if (!Number.isFinite(days) || days <= 0) return;

  const dirUri = logDirUri(workspaceId);

  let names: string[] = [];
  try {
    names = await FileSystem.readDirectoryAsync(dirUri);
  } catch {
    return;
  }

  const cutoffSec = Date.now() / 1000 - days * 24 * 60 * 60;

  for (const name of names) {
    const fileUri = `${dirUri}${name}`;
    try {
      const info = await FileSystem.getInfoAsync(fileUri);
      if (!info.exists) continue;
      if (info.isDirectory) continue;
      if (typeof info.modificationTime !== 'number') continue;
      if (info.modificationTime < cutoffSec) {
        await FileSystem.deleteAsync(fileUri, { idempotent: true });
      }
    } catch {
      // ignore
    }
  }
}

export async function appendDebugLog(params: {
  workspaceId: WorkspaceId;
  sessionId: string;
  event: string;
  message?: string;
  details?: unknown;
}) {
  const fileUri = sessionLogFileUri(params.workspaceId, params.sessionId);

  return await enqueue(fileUri, async () => {
    await ensureDirAndFile(fileUri);

    const record: DebugLogRecord = {
      ts: new Date().toISOString(),
      workspaceId: params.workspaceId,
      sessionId: params.sessionId,
      event: params.event,
      message: params.message ? redactSecrets(params.message) : undefined,
      details: safeDetails(params.details),
    };

    const line = `${JSON.stringify(record)}\n`;

    try {
      appendWithHandle(fileUri, line);
    } catch {
      // Fallback: overwrite-based append (should be rare; used only if FileHandle fails).
      try {
        const prev = await FileSystem.readAsStringAsync(fileUri);
        await FileSystem.writeAsStringAsync(fileUri, prev + line);
      } catch {
        // ignore
      }
    }
  });
}

