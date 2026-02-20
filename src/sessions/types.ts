import type { WorkspaceId } from '@/src/workspaces/types';

export type SessionId = string;

export type Session = {
  id: SessionId;
  workspaceId: WorkspaceId;
  title: string;
  createdAt: number;
  updatedAt: number;
  codexThreadId?: string;
  /** 可选：协作模式（用于 /plan 等客户端命令）。 */
  codexCollaborationMode?: 'code' | 'plan';
  /** 可选：本会话启用的 MCP server（按 id）。 */
  mcpEnabledServerIds?: string[];
};

export type ChatMessage = {
  id: string;
  sessionId: SessionId;
  workspaceId: WorkspaceId;
  role: 'user' | 'assistant' | 'system';
  createdAt: number;
  content: string;
};
