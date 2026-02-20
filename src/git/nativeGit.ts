import { NativeModules } from 'react-native';

import { loadAuth } from '@/src/auth/authStore';
import type { GitHttpsAuth } from '@/src/auth/types';

import type { GitCheckoutParams, GitCloneParams, GitPullParams, GitPushParams, GitStatus } from './types';

type NativeGitAuth = { username: string; token: string } | null;

type NativeGitModule = {
  clone(params: GitCloneParams & { auth?: NativeGitAuth; allowInsecure?: boolean }): Promise<void>;
  checkout(params: GitCheckoutParams): Promise<void>;
  pull(params: GitPullParams & { auth?: NativeGitAuth; allowInsecure?: boolean }): Promise<void>;
  push(params: GitPushParams & { auth?: NativeGitAuth; allowInsecure?: boolean }): Promise<void>;
  status(params: { localRepoDirUri: string }): Promise<GitStatus>;
  diff(params: { localRepoDirUri: string; maxBytes?: number }): Promise<string>;
};

function getNativeGit(): NativeGitModule {
  const mod = (NativeModules as any).CodexMGit as NativeGitModule | undefined;
  if (!mod) {
    throw new Error(
      'Native Git module (CodexMGit) 未安装。Phase A 需要通过 Expo Dev Client + prebuild 集成 libgit2 原生模块。'
    );
  }
  return mod;
}

async function resolveGitAuth(authRef?: string): Promise<{ username: string; token: string } | null> {
  if (!authRef) return null;
  const stored = await loadAuth<GitHttpsAuth>(authRef);
  if (!stored || stored.type !== 'git_https') return null;
  return { username: stored.username, token: stored.token };
}

export async function gitClone(params: GitCloneParams) {
  const auth = await resolveGitAuth(params.authRef);
  return await getNativeGit().clone({ ...params, auth });
}

export async function gitCheckout(params: GitCheckoutParams) {
  return await getNativeGit().checkout(params);
}

export async function gitPull(params: GitPullParams) {
  const auth = await resolveGitAuth(params.authRef);
  return await getNativeGit().pull({ ...params, auth });
}

export async function gitPush(params: GitPushParams) {
  const auth = await resolveGitAuth(params.authRef);
  return await getNativeGit().push({ ...params, auth });
}

export async function gitStatus(params: { localRepoDirUri: string }): Promise<GitStatus> {
  return await getNativeGit().status(params);
}

export async function gitDiff(params: { localRepoDirUri: string; maxBytes?: number }): Promise<string> {
  return await getNativeGit().diff(params);
}
