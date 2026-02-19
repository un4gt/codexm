export type { AuthRef } from '@/src/workspaces/types';

export type GitHttpsAuth = {
  type: 'git_https';
  /** e.g. "oauth2" for GitHub token auth */
  username: string;
  token: string;
};

export type WebDavStoredAuth =
  | { type: 'webdav_basic'; username: string; password: string }
  | { type: 'webdav_bearer'; token: string };

export type CodexProviderAuth = {
  type: 'codex_bearer';
  token: string;
};

export type StoredAuth = GitHttpsAuth | WebDavStoredAuth | CodexProviderAuth;
