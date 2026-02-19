import type { WorkspaceId } from '@/src/workspaces/types';

export type SessionId = string;

export type Session = {
  id: SessionId;
  workspaceId: WorkspaceId;
  title: string;
  createdAt: number;
  updatedAt: number;
  codexThreadId?: string;
};

export type ChatMessage = {
  id: string;
  sessionId: SessionId;
  workspaceId: WorkspaceId;
  role: 'user' | 'assistant' | 'system';
  createdAt: number;
  content: string;
};
