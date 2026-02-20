import * as FileSystem from 'expo-file-system/legacy';

import { workspaceMetaPath } from '@/src/workspaces/paths';
import type { WorkspaceId } from '@/src/workspaces/types';
import { uuidV4 } from '@/src/utils/uuid';

import type { ChatMessage, Session, SessionId } from './types';

type SessionsIndex = {
  version: 2;
  sessions: Session[];
};

function sessionsDir(workspaceId: WorkspaceId) {
  return `${workspaceMetaPath(workspaceId)}sessions/`;
}

function indexPath(workspaceId: WorkspaceId) {
  return `${sessionsDir(workspaceId)}index.json`;
}

function messagesPath(workspaceId: WorkspaceId, sessionId: SessionId) {
  return `${sessionsDir(workspaceId)}${sessionId}.json`;
}

async function ensureSessionsDir(workspaceId: WorkspaceId) {
  await FileSystem.makeDirectoryAsync(sessionsDir(workspaceId), { intermediates: true });
}

async function readIndex(workspaceId: WorkspaceId): Promise<SessionsIndex> {
  await ensureSessionsDir(workspaceId);
  const path = indexPath(workspaceId);
  const info = await FileSystem.getInfoAsync(path);
  if (!info.exists) return { version: 2, sessions: [] };
  const raw = await FileSystem.readAsStringAsync(path);
  const parsed = JSON.parse(raw) as any;
  const version = parsed?.version ?? 1;
  if (version === 2) {
    return { version: 2, sessions: (parsed.sessions ?? []) as Session[] };
  }
  // v1 -> v2 migration
  const sessions = ((parsed.sessions ?? []) as any[]).map((s) => ({
    id: s.id,
    workspaceId: s.workspaceId,
    title: s.title,
    createdAt: s.createdAt,
    updatedAt: s.updatedAt,
    codexThreadId: s.codexThreadId,
    codexCollaborationMode: s.codexCollaborationMode,
  })) as Session[];
  return { version: 2, sessions };
}

async function writeIndex(workspaceId: WorkspaceId, idx: SessionsIndex) {
  await ensureSessionsDir(workspaceId);
  const path = indexPath(workspaceId);
  await FileSystem.writeAsStringAsync(path, JSON.stringify(idx, null, 2));
}

export async function listSessions(workspaceId: WorkspaceId): Promise<Session[]> {
  const idx = await readIndex(workspaceId);
  return idx.sessions ?? [];
}

export async function getSession(workspaceId: WorkspaceId, sessionId: SessionId): Promise<Session | null> {
  const idx = await readIndex(workspaceId);
  return (idx.sessions ?? []).find((s) => s.id === sessionId) ?? null;
}

export async function createSession(
  workspaceId: WorkspaceId,
  title?: string,
  opts?: { mcpEnabledServerIds?: string[] }
): Promise<Session> {
  const now = Date.now();
  const session: Session = {
    id: uuidV4(),
    workspaceId,
    title: title?.trim() || '新会话',
    createdAt: now,
    updatedAt: now,
    mcpEnabledServerIds: opts?.mcpEnabledServerIds,
  };

  const idx = await readIndex(workspaceId);
  idx.sessions = [session, ...(idx.sessions ?? [])];
  await writeIndex(workspaceId, idx);

  await FileSystem.writeAsStringAsync(messagesPath(workspaceId, session.id), JSON.stringify({ version: 1, messages: [] }, null, 2));

  return session;
}

export async function cloneSessionMessages(workspaceId: WorkspaceId, fromSessionId: SessionId, toSessionId: SessionId) {
  await ensureSessionsDir(workspaceId);
  const from = await FileSystem.readAsStringAsync(messagesPath(workspaceId, fromSessionId));
  await FileSystem.writeAsStringAsync(messagesPath(workspaceId, toSessionId), from);
}

export async function renameSession(workspaceId: WorkspaceId, sessionId: SessionId, title: string) {
  const idx = await readIndex(workspaceId);
  const next = (idx.sessions ?? []).map((s) =>
    s.id === sessionId ? { ...s, title: title.trim() || s.title, updatedAt: Date.now() } : s
  );
  idx.sessions = next;
  await writeIndex(workspaceId, idx);
}

export async function setSessionCodexThreadId(workspaceId: WorkspaceId, sessionId: SessionId, threadId: string | null) {
  const idx = await readIndex(workspaceId);
  idx.sessions = (idx.sessions ?? []).map((s) =>
    s.id === sessionId
      ? threadId
        ? { ...s, codexThreadId: threadId, updatedAt: Date.now() }
        : { ...s, codexThreadId: undefined, updatedAt: Date.now() }
      : s
  );
  await writeIndex(workspaceId, idx);
}

export async function setSessionCodexCollaborationMode(
  workspaceId: WorkspaceId,
  sessionId: SessionId,
  mode: Session['codexCollaborationMode'] | null
) {
  const idx = await readIndex(workspaceId);
  idx.sessions = (idx.sessions ?? []).map((s) =>
    s.id === sessionId
      ? mode
        ? { ...s, codexCollaborationMode: mode, updatedAt: Date.now() }
        : { ...s, codexCollaborationMode: undefined, updatedAt: Date.now() }
      : s
  );
  await writeIndex(workspaceId, idx);
}

export async function deleteSession(workspaceId: WorkspaceId, sessionId: SessionId) {
  const idx = await readIndex(workspaceId);
  idx.sessions = (idx.sessions ?? []).filter((s) => s.id !== sessionId);
  await writeIndex(workspaceId, idx);
  await FileSystem.deleteAsync(messagesPath(workspaceId, sessionId), { idempotent: true });
}

type MessagesFile = { version: 1; messages: ChatMessage[] };

export async function listMessages(workspaceId: WorkspaceId, sessionId: SessionId): Promise<ChatMessage[]> {
  await ensureSessionsDir(workspaceId);
  const path = messagesPath(workspaceId, sessionId);
  const info = await FileSystem.getInfoAsync(path);
  if (!info.exists) return [];
  const raw = await FileSystem.readAsStringAsync(path);
  const parsed = JSON.parse(raw) as MessagesFile;
  return parsed.messages ?? [];
}

export async function appendMessage(workspaceId: WorkspaceId, sessionId: SessionId, msg: Omit<ChatMessage, 'id'>) {
  const all = await listMessages(workspaceId, sessionId);
  const next: ChatMessage = { id: uuidV4(), ...msg };
  const file: MessagesFile = { version: 1, messages: [...all, next] };
  await FileSystem.writeAsStringAsync(messagesPath(workspaceId, sessionId), JSON.stringify(file, null, 2));

  // bump updatedAt in index
  const idx = await readIndex(workspaceId);
  idx.sessions = (idx.sessions ?? []).map((s) => (s.id === sessionId ? { ...s, updatedAt: Date.now() } : s));
  await writeIndex(workspaceId, idx);
}
