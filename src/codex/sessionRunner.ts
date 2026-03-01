import type { Workspace } from '@/src/workspaces/types';
import { Platform } from 'react-native';

import { listMcpServers } from '@/src/mcp/store';
import { getSession, setSessionCodexThreadId } from '@/src/sessions/store';
import { ensureWorkspaceDirs, workspaceRepoPath } from '@/src/workspaces/paths';

import { JsonRpcClient, JsonRpcError } from './jsonRpc';
import type { JsonRpcNotification } from './jsonRpc';
import type { CodexRuntimeLineEvent } from './nativeRuntime';
import { onCodexRuntimeLine, sendCodexLine, startCodexRuntime, stopCodexRuntime } from './nativeRuntime';
import { getCodexApiKey, getCodexSettings, materializeCodexConfigFiles } from './settings';
import { appendDebugLog, pruneDebugLogs } from './debugLog';

export type CodexTurnEvent =
  | { type: 'text'; text: string }
  | { type: 'error'; message: string }
  | { type: 'rpc_result'; method: string; result: any }
  | { type: 'done' };

/**
 * 内嵌 `codex app-server`（stdio JSON-RPC / JSONL）驱动一轮对话，并把事件流映射为 UI 友好的增量文本。
 *
 * 注意：在 Expo 里使用该能力需要 **Dev Client + prebuild**，并在 Android 侧集成 `CodexRuntimeManager` 原生模块。
 */
export async function* runCodexTurn(_params: {
  workspace: Workspace;
  sessionId: string;
  input?: string;
  kind?: 'turn' | 'review' | 'rpc';
  reviewTarget?: any;
  collaborationMode?: 'code' | 'plan';
  rpcCalls?: {
    method: string;
    params?: any;
    /**
     * 是否需要自动解析/确保 threadId。为 true 时，如果 params.threadId 未提供，将自动注入当前会话 threadId。
     */
    requiresThread?: boolean;
    /** 是否把结果序列化为文本输出（默认 true）。 */
    emitText?: boolean;
    /** 可选：输出时的标题。 */
    title?: string;
  }[];
}): AsyncGenerator<CodexTurnEvent> {
  if (Platform.OS !== 'android') {
    yield { type: 'error', message: '当前仅实现 Android 端内嵌 codex app-server（stdio JSON-RPC）。' };
    yield { type: 'done' };
    return;
  }

  const { workspace, sessionId } = _params;
  const kind = _params.kind ?? 'turn';
  const inputText = _params.input ?? '';
  if (kind === 'turn' && !inputText.trim()) {
    yield { type: 'error', message: '输入为空。' };
    yield { type: 'done' };
    return;
  }
  if (kind === 'rpc' && (!_params.rpcCalls || _params.rpcCalls.length === 0)) {
    yield { type: 'error', message: 'rpcCalls 为空：无法执行 RPC 命令。' };
    yield { type: 'done' };
    return;
  }

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

    isClosed() {
      return this.closed;
    }

    async shift(timeoutMs?: number): Promise<T | null> {
      if (this.items.length) return this.items.shift() ?? null;
      if (this.closed) return null;
      const ms = typeof timeoutMs === 'number' ? timeoutMs : null;
      if (ms == null || !Number.isFinite(ms) || ms <= 0) {
        return await new Promise<T | null>((resolve) => this.waiters.push(resolve));
      }

      return await new Promise<T | null>((resolve) => {
        let waiter: ((v: T | null) => void) | null = null;
        const timer = setTimeout(() => {
          if (waiter) {
            const idx = this.waiters.indexOf(waiter);
            if (idx !== -1) this.waiters.splice(idx, 1);
          }
          resolve(null);
        }, ms);

        waiter = (v: T | null) => {
          clearTimeout(timer);
          resolve(v);
        };

        this.waiters.push(waiter);
      });
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
  const debugLogEnabled = Boolean(settings.debugLogToFile);
  const retentionDaysRaw = typeof settings.debugLogRetentionDays === 'number' ? settings.debugLogRetentionDays : 7;
  const retentionDays = Number.isFinite(retentionDaysRaw) ? Math.min(90, Math.max(1, Math.floor(retentionDaysRaw))) : 7;

  function logEvent(event: string, message?: string, details?: unknown) {
    if (!debugLogEnabled) return;
    void appendDebugLog({ workspaceId: workspace.id, sessionId, event, message, details });
  }

  if (debugLogEnabled) void pruneDebugLogs(workspace.id, retentionDays);
  if (!settings.enabled) {
    logEvent('blocked', 'Codex 未开启。');
    yield { type: 'error', message: 'Codex 未开启：请到「设置」中开启。' };
    yield { type: 'done' };
    return;
  }

  const apiKey = await getCodexApiKey();
  if (!apiKey) {
    logEvent('blocked', '未设置密钥。');
    yield { type: 'error', message: '未设置密钥：请到「设置」中设置。' };
    yield { type: 'done' };
    return;
  }

  const session = await getSession(workspace.id, sessionId);
  const enabledMcpServerIdsRaw = session?.mcpEnabledServerIds ?? workspace.mcpDefaultEnabledServerIds ?? [];
  const enabledMcpServerIds = Array.from(new Set((enabledMcpServerIdsRaw ?? []).filter(Boolean)));
  let mcpServers: Awaited<ReturnType<typeof listMcpServers>> = [];
  if (enabledMcpServerIds.length) {
    try {
      mcpServers = await listMcpServers();
    } catch {
      mcpServers = [];
    }
  }

  const { codexHomeUri } = await materializeCodexConfigFiles({ mcpServers, enabledMcpServerIds });

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

  logEvent('turn_start', undefined, {
    kind,
    inputLength: inputText.length,
    mcpEnabledServers: enabledMcpServerIds.length,
  });

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

  // UI-friendly streaming: Codex may emit very frequent deltas (token-level). Updating UI for every
  // delta can freeze React Native and make it appear "non-streaming". We coalesce deltas and flush
  // at most ~30fps, or when the buffer grows large, and always flush on terminal events.
  const FLUSH_INTERVAL_MS = 33;
  const FLUSH_CHUNK_CHARS = 512;
  let pendingText = '';
  let sawAnyDelta = false;
  let lastFlushMs = Date.now();

  function takeFlush(force = false): string | null {
    if (!pendingText) return null;
    const now = Date.now();
    if (force || now - lastFlushMs >= FLUSH_INTERVAL_MS || pendingText.length >= FLUSH_CHUNK_CHARS) {
      const out = pendingText;
      pendingText = '';
      lastFlushMs = now;
      return out;
    }
    return null;
  }

  function pushDelta(delta: string): string | null {
    pendingText += delta;
    return takeFlush(false);
  }

  function extractDelta(delta: unknown): string | null {
    if (typeof delta === 'string') return delta;
    if (delta && typeof delta === 'object') {
      const t = (delta as any).text;
      if (typeof t === 'string') return t;
    }
    return null;
  }

  function extractCompletedItemText(item: unknown): string | null {
    if (!item || typeof item !== 'object') return null;
    const anyItem = item as any;

    const direct = anyItem.text ?? anyItem.message ?? anyItem.content;
    if (typeof direct === 'string' && direct) return direct;

    const maybeParts = anyItem.output ?? anyItem.message?.output ?? anyItem.message?.content ?? anyItem.content;
    if (!Array.isArray(maybeParts)) return null;

    let out = '';
    for (const part of maybeParts) {
      if (!part) continue;
      if (typeof part === 'string') {
        out += part;
        continue;
      }
      if (typeof part === 'object') {
        if (typeof (part as any).text === 'string') out += (part as any).text;
        else if (typeof (part as any).content === 'string') out += (part as any).content;
      }
    }
    return out || null;
  }

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
      clientInfo: { name: 'codexm_android', title: 'CodexM Android', version: '0.0.3' },
    });
    await rpc.notify('initialized', {});

    // Thread (only if needed)
    const needsThread =
      kind !== 'rpc' || (_params.rpcCalls ?? []).some((c) => Boolean(c.requiresThread));

    const s = needsThread ? session : null;
    let threadId = needsThread ? s?.codexThreadId ?? null : null;

    if (needsThread && threadId) {
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

    if (needsThread && !threadId) {
      const res = await rpc.request<any>('thread/start', {
        cwd: fileUriToPath(cwdUri),
        approvalPolicy: settings.approvalPolicy,
        personality: settings.personality,
      });
      threadId = res?.thread?.id ?? null;
      if (threadId) await setSessionCodexThreadId(workspace.id, sessionId, threadId);
    }

    if (needsThread && !threadId) throw new Error('Codex threadId 缺失：thread/start 或 thread/resume 返回异常。');

    if (kind === 'rpc') {
      const calls = _params.rpcCalls ?? [];
      for (const call of calls) {
        const params: any = call.params ? { ...call.params } : {};
        if (call.requiresThread && params.threadId == null) params.threadId = threadId;

        const result = await rpc.request<any>(call.method, params);
        yield { type: 'rpc_result', method: call.method, result };

        if (call.emitText ?? true) {
          if (call.title?.trim()) yield { type: 'text', text: `${call.title.trim()}\n` };
          yield { type: 'text', text: JSON.stringify(result, null, 2) };
          yield { type: 'text', text: '\n' };
        }

        // Special-case: thread/compact/start triggers async work; keep the server alive until it finishes.
        if (call.method === 'thread/compact/start') {
          let done = false;
          while (!done) {
            const n = await notifQueue.shift();
            if (!n) break;
            if (n.method === 'item/completed') {
              const item = n.params?.item;
              if (item && typeof item === 'object' && (item as any).type === 'contextCompaction') {
                done = true;
                continue;
              }
            }
            if (n.method === 'turn/completed') {
              done = true;
            }
          }
        }
      }
      const tail = takeFlush(true);
      if (tail) yield { type: 'text', text: tail };
      return;
    }

    // Start turn
    let turnId: string | null = null;
    if (kind === 'review') {
      const reviewRes = await rpc.request<any>('review/start', {
        threadId,
        delivery: 'inline',
        target: _params.reviewTarget ?? { type: 'uncommittedChanges' },
      });
      turnId = reviewRes?.turn?.id ?? null;
    } else {
      const turnParams: any = {
        threadId,
        cwd: fileUriToPath(cwdUri),
        approvalPolicy: settings.approvalPolicy,
        input: [{ type: 'text', text: inputText }],
      };
      if (_params.collaborationMode) turnParams.collaborationMode = _params.collaborationMode;
      const turnRes = await rpc.request<any>('turn/start', turnParams);
      turnId = turnRes?.turn?.id ?? null;
    }

    // Stream events until this turn completes
    let completed = false;
    while (!completed) {
      // 如果 Codex 在短时间内把输出一次性写完（尤其是短回答），可能不会再有新的通知来触发 takeFlush，
      // 导致 UI 只能在 turn/completed 时“一次性出现”。这里用超时轮询把 pendingText 定期刷出来。
      if (pendingText && Date.now() - lastFlushMs >= FLUSH_INTERVAL_MS) {
        const chunk = takeFlush(true);
        if (chunk) yield { type: 'text', text: chunk };
      }

      const timeoutMs = pendingText ? Math.max(1, FLUSH_INTERVAL_MS - (Date.now() - lastFlushMs)) : undefined;
      const n = await notifQueue.shift(timeoutMs);
      if (!n) {
        const chunk = takeFlush(true);
        if (chunk) yield { type: 'text', text: chunk };
        if (notifQueue.isClosed()) break;
        continue;
      }

      if (n.method === 'item/agentMessage/delta') {
        const delta = extractDelta(n.params?.delta);
        if (delta) {
          sawAnyDelta = true;
          const chunk = pushDelta(delta);
          if (chunk) yield { type: 'text', text: chunk };
        }
        continue;
      }

      if (typeof n.method === 'string' && n.method.endsWith('/outputDelta')) {
        const delta = extractDelta(n.params?.delta);
        if (delta) {
          sawAnyDelta = true;
          const chunk = pushDelta(delta);
          if (chunk) yield { type: 'text', text: chunk };
        }
        continue;
      }

      if (n.method === 'error') {
        const chunk = takeFlush(true);
        if (chunk) yield { type: 'text', text: chunk };
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
        logEvent('runtime_error', String(msg), parts.filter(Boolean).join('\n'));
        yield { type: 'error', message: parts.filter(Boolean).join('\n') };
        continue;
      }

      if (n.method === 'item/completed') {
        const item = n.params?.item;
        if (item && typeof item === 'object' && item.type === 'exitedReviewMode') {
          const review = (item as any).review;
          if (typeof review === 'string' && review.trim()) {
            const chunk = takeFlush(true);
            if (chunk) yield { type: 'text', text: chunk };
            yield { type: 'text', text: review };
          }
        }
        // 兼容：某些版本可能不发 delta，而是在 item/completed 里直接给出完整 agent message。
        if (!sawAnyDelta && item && typeof item === 'object') {
          const t = (item as any).type;
          if (t === 'agentMessage' || t === 'assistantMessage') {
            const full = extractCompletedItemText(item);
            if (typeof full === 'string' && full) {
              const chunk = takeFlush(true);
              if (chunk) yield { type: 'text', text: chunk };
              yield { type: 'text', text: full };
              sawAnyDelta = true;
            }
          }
        }
        continue;
      }

      if (n.method === 'turn/completed') {
        const chunk = takeFlush(true);
        if (chunk) yield { type: 'text', text: chunk };
        const t = n.params?.turn;
        const id = t?.id ?? n.params?.turnId;
        if (!turnId || id === turnId) {
          if (t?.status === 'failed') {
            const msg = t?.error?.message ?? 'Codex turn failed';
            logEvent('turn_failed', String(msg));
            yield { type: 'error', message: String(msg) };
          }
          completed = true;
        }
        continue;
      }
    }

    // If the turn ended without a terminal event we recognized, flush any pending deltas.
    const tail = takeFlush(true);
    if (tail) yield { type: 'text', text: tail };
  } catch (e) {
    rpc.rejectAllPending(e);
    const tail = takeFlush(true);
    if (tail) yield { type: 'text', text: tail };
    const message = formatRpcError(e);
    logEvent('exception', '运行异常', message);
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
    const tail = takeFlush(true);
    if (tail) yield { type: 'text', text: tail };
    logEvent('turn_end');
    yield { type: 'done' };
  }
}
