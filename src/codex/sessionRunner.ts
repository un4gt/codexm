import type { Workspace } from '@/src/workspaces/types';
import { Platform } from 'react-native';

import { getSession, setSessionCodexThreadId } from '@/src/sessions/store';
import { ensureWorkspaceDirs, workspaceRepoPath } from '@/src/workspaces/paths';

import { JsonRpcClient, JsonRpcError } from './jsonRpc';
import type { JsonRpcNotification } from './jsonRpc';
import type { CodexRuntimeLineEvent } from './nativeRuntime';
import { onCodexRuntimeLine, sendCodexLine, startCodexRuntime, stopCodexRuntime } from './nativeRuntime';
import { getCodexApiKey, getCodexSettings, materializeCodexConfigFiles } from './settings';

export type CodexTurnEvent =
  | { type: 'text'; text: string }
  | { type: 'error'; message: string }
  | { type: 'done' };

/**
 * 内嵌 `codex app-server`（stdio JSON-RPC / JSONL）驱动一轮对话，并把事件流映射为 UI 友好的增量文本。
 *
 * 注意：在 Expo 里使用该能力需要 **Dev Client + prebuild**，并在 Android 侧集成 `CodexRuntimeManager` 原生模块。
 */
export async function* runCodexTurn(_params: {
  workspace: Workspace;
  sessionId: string;
  input: string;
}): AsyncGenerator<CodexTurnEvent> {
  if (Platform.OS !== 'android') {
    yield { type: 'error', message: '当前仅实现 Android 端内嵌 codex app-server（stdio JSON-RPC）。' };
    yield { type: 'done' };
    return;
  }

  const { workspace, sessionId, input } = _params;

  class AsyncQueue<T> {
    private items: T[] = [];
    private waiters: ((v: T | null) => void)[] = [];
    private closed = false;

    push(v: T) {
      if (this.closed) return;
      const w = this.waiters.shift();
      if (w) w(v);
      else this.items.push(v);
    }

    close() {
      this.closed = true;
      while (this.waiters.length) this.waiters.shift()?.(null);
    }

    async shift(): Promise<T | null> {
      if (this.items.length) return this.items.shift() ?? null;
      if (this.closed) return null;
      return await new Promise<T | null>((resolve) => this.waiters.push(resolve));
    }
  }

  function fileUriToPath(uri: string) {
    return uri.startsWith('file://') ? uri.replace('file://', '') : uri;
  }

  function isMissingThreadState(err: unknown) {
    const msg = err instanceof Error ? err.message : String(err);
    const details =
      err instanceof JsonRpcError &&
      err.data &&
      typeof err.data === 'object' &&
      typeof (err.data as any).details === 'string'
        ? String((err.data as any).details)
        : '';
    const hay = `${msg}\n${details}`.toLowerCase();
    return hay.includes('no rollout found for thread id') || hay.includes('no thread found with id');
  }

  function formatRpcError(e: unknown): string {
    if (!(e instanceof JsonRpcError)) {
      return e instanceof Error ? e.stack || e.message : String(e);
    }
    const base = e.message || 'JSON-RPC error';
    const details =
      e.data &&
      typeof e.data === 'object' &&
      typeof (e.data as any).details === 'string' &&
      String((e.data as any).details).trim()
        ? String((e.data as any).details).trim()
        : '';
    const raw = details && !base.toLowerCase().includes(details.toLowerCase()) ? `${base}\n${details}` : base;
    return raw;
  }

  await ensureWorkspaceDirs(workspace.id);

  const cwdUri = workspaceRepoPath(workspace.id);

  const settings = await getCodexSettings();
  if (!settings.enabled) {
    yield { type: 'error', message: 'Codex 未开启：请到「设置」中开启。' };
    yield { type: 'done' };
    return;
  }

  const apiKey = await getCodexApiKey();
  if (!apiKey) {
    yield { type: 'error', message: '未设置密钥：请到「设置」中设置。' };
    yield { type: 'done' };
    return;
  }

  const { codexHomeUri } = await materializeCodexConfigFiles();

  const env: Record<string, string> = {
    CODEX_HOME: fileUriToPath(codexHomeUri),
    HOME: fileUriToPath(codexHomeUri),
  };

  env.OPENAI_API_KEY = apiKey;
  // Codex 在部分版本/模式下会读取 CODEX_API_KEY（而非 OPENAI_API_KEY）作为 OpenAI API Key。
  // 为了兼容不同版本，这里同时注入两者。
  env.CODEX_API_KEY = apiKey;
  if (settings.openaiBaseUrl?.trim()) {
    env.OPENAI_BASE_URL = settings.openaiBaseUrl.trim();
  }

  // One process per turn (simple + avoids cross-session event mixing).
  const runtimeId = `${workspace.id}:${sessionId}:${Date.now()}`;
  const lineQueue = new AsyncQueue<CodexRuntimeLineEvent>();
  const notifQueue = new AsyncQueue<JsonRpcNotification>();

  let unsubscribe = () => {};

  let pumpRunning = true;
  let started = false;

  const rpc = new JsonRpcClient((line) => sendCodexLine(runtimeId, line));
  rpc.onNotification((n) => notifQueue.push(n));
  rpc.setServerRequestHandler(async ({ method }) => {
    // Phase A: do not block on approvals; accept by default.
    if (method.endsWith('/requestApproval')) return { decision: 'accept' };
    return { decision: 'decline' };
  });

  let pump: Promise<void> | null = null;

  try {
    unsubscribe = onCodexRuntimeLine((ev) => {
      if (ev.runtimeId !== runtimeId) return;
      lineQueue.push(ev);
    });

    await startCodexRuntime({
      runtimeId,
      cwdUri,
      // 默认从 Android assets 里复制可执行文件；你需要在原生侧打包该 asset。
      assetPath: 'codex/{abi}/codex',
      args: ['app-server', '--listen', 'stdio://'],
      env,
    });
    started = true;

    pump = (async () => {
      while (pumpRunning) {
        const ev = await lineQueue.shift();
        if (!ev) break;
        if (ev.stream !== 'stdout') continue;
        await rpc.handleLine(ev.line);
      }
    })();

    // Handshake
    await rpc.request('initialize', {
      clientInfo: { name: 'codexm_android', title: 'CodexM Android', version: '0.0.1' },
    });
    await rpc.notify('initialized', {});

    // Thread
    const s = await getSession(workspace.id, sessionId);
    let threadId = s?.codexThreadId ?? null;

    if (threadId) {
      try {
        await rpc.request('thread/resume', {
          threadId,
          cwd: fileUriToPath(cwdUri),
          approvalPolicy: settings.approvalPolicy,
          personality: settings.personality,
        });
      } catch (e) {
        // Workaround for Codex thread resume failures where persisted rollout is missing/expired.
        if (isMissingThreadState(e)) {
          await setSessionCodexThreadId(workspace.id, sessionId, null);
          threadId = null;
        } else {
          throw e;
        }
      }
    }

    if (!threadId) {
      const res = await rpc.request<any>('thread/start', {
        cwd: fileUriToPath(cwdUri),
        approvalPolicy: settings.approvalPolicy,
        personality: settings.personality,
      });
      threadId = res?.thread?.id ?? null;
      if (threadId) await setSessionCodexThreadId(workspace.id, sessionId, threadId);
    }

    if (!threadId) throw new Error('Codex threadId 缺失：thread/start 或 thread/resume 返回异常。');

    // Start turn
    const turnRes = await rpc.request<any>('turn/start', {
      threadId,
      cwd: fileUriToPath(cwdUri),
      approvalPolicy: settings.approvalPolicy,
      input: [{ type: 'text', text: input }],
    });
    const turnId: string | null = turnRes?.turn?.id ?? null;

    // Stream events until this turn completes
    let completed = false;
    while (!completed) {
      const n = await notifQueue.shift();
      if (!n) break;

      if (n.method === 'item/agentMessage/delta') {
        const delta = n.params?.delta;
        if (typeof delta === 'string' && delta) {
          yield { type: 'text', text: delta };
        }
        continue;
      }

      if (typeof n.method === 'string' && n.method.endsWith('/outputDelta')) {
        const delta = n.params?.delta;
        if (typeof delta === 'string' && delta) {
          yield { type: 'text', text: delta };
        }
        continue;
      }

      if (n.method === 'error') {
        const err = n.params?.error;
        const msg = err?.message ?? n.params?.message ?? 'Codex 运行出错。';
        const parts: string[] = [String(msg)];
        const extra = err?.additionalDetails ?? err?.details;
        if (extra != null) {
          try {
            parts.push(typeof extra === 'string' ? extra : JSON.stringify(extra, null, 2));
          } catch {
            parts.push(String(extra));
          }
        }
        const http = err?.codexErrorInfo?.httpStatusCode;
        if (typeof http === 'number') parts.push(`HTTP ${http}`);
        const url = err?.codexErrorInfo?.url;
        if (typeof url === 'string' && url) parts.push(`url: ${url}`);
        yield { type: 'error', message: parts.filter(Boolean).join('\n') };
        continue;
      }

      if (n.method === 'turn/completed') {
        const t = n.params?.turn;
        const id = t?.id ?? n.params?.turnId;
        if (!turnId || id === turnId) {
          if (t?.status === 'failed') {
            const msg = t?.error?.message ?? 'Codex turn failed';
            yield { type: 'error', message: String(msg) };
          }
          completed = true;
        }
        continue;
      }
    }
  } catch (e) {
    rpc.rejectAllPending(e);
    const message = formatRpcError(e);
    yield { type: 'error', message };
  } finally {
    pumpRunning = false;
    lineQueue.close();
    notifQueue.close();
    unsubscribe();
    try {
      if (started) await stopCodexRuntime(runtimeId);
    } catch {
      // ignore
    }
    try {
      if (pump) await pump;
    } catch {
      // ignore
    }
    yield { type: 'done' };
  }
}
