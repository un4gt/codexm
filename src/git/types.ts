import type { WorkspaceId } from '@/src/workspaces/types';

export type GitAuthRef = string;

export type GitProgressEvent = {
  op: 'clone' | 'fetch' | 'pull' | 'push' | 'checkout';
  phase?: string;
  current?: number;
  total?: number;
  message?: string;
};

export type GitCloneParams = {
  workspaceId: WorkspaceId;
  remoteUrl: string;
  localRepoDirUri: string;
  branch?: string;
  authRef?: GitAuthRef;
  allowInsecure?: boolean;
  userName?: string;
  userEmail?: string;
};

export type GitPullParams = {
  workspaceId: WorkspaceId;
  localRepoDirUri: string;
  remote?: string;
  branch?: string;
  authRef?: GitAuthRef;
  allowInsecure?: boolean;
};

export type GitPushParams = {
  workspaceId: WorkspaceId;
  localRepoDirUri: string;
  remote?: string;
  branch?: string;
  authRef?: GitAuthRef;
  allowInsecure?: boolean;
};

export type GitCheckoutParams = {
  workspaceId: WorkspaceId;
  localRepoDirUri: string;
  ref: string;
};

export type GitStatus = {
  staged: string[];
  unstaged: string[];
  untracked: string[];
};
