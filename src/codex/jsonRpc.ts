export type JsonRpcId = number;

export type JsonRpcResponseError = {
  code?: number;
  message?: string;
  data?: unknown;
};

export class JsonRpcError extends Error {
  code?: number;
  data?: unknown;

  constructor(message: string, opts?: { code?: number; data?: unknown }) {
    super(message);
    this.name = 'JsonRpcError';
    this.code = opts?.code;
    this.data = opts?.data;
  }
}

export type JsonRpcNotification = {
  method: string;
  params?: any;
};

type Pending = {
  resolve: (value: any) => void;
  reject: (err: Error) => void;
};

function toError(err: unknown): Error {
  if (err instanceof Error) return err;
  return new Error(typeof err === 'string' ? err : JSON.stringify(err));
}

export class JsonRpcClient {
  private nextId: JsonRpcId = 1;
  private pending = new Map<JsonRpcId, Pending>();
  private notificationListeners = new Set<(n: JsonRpcNotification) => void>();
  private serverRequestHandler:
    | ((req: { id: JsonRpcId; method: string; params?: any }) => Promise<any> | any)
    | null = null;

  constructor(private sendLine: (line: string) => Promise<void>) {}

  onNotification(fn: (n: JsonRpcNotification) => void) {
    this.notificationListeners.add(fn);
    return () => this.notificationListeners.delete(fn);
  }

  setServerRequestHandler(
    fn: ((req: { id: JsonRpcId; method: string; params?: any }) => Promise<any> | any) | null
  ) {
    this.serverRequestHandler = fn;
  }

  async request<T = any>(method: string, params?: any): Promise<T> {
    const id = this.nextId++;
    const payload = { id, method, params };
    const p = new Promise<T>((resolve, reject) => {
      this.pending.set(id, { resolve, reject });
    });
    await this.sendLine(JSON.stringify(payload));
    return p;
  }

  async notify(method: string, params?: any): Promise<void> {
    const payload = { method, params };
    await this.sendLine(JSON.stringify(payload));
  }

  /** Handle a single JSONL line from the transport. */
  async handleLine(line: string) {
    let msg: any;
    try {
      msg = JSON.parse(line);
    } catch {
      return;
    }
    if (!msg || typeof msg !== 'object') return;

    // Response
    if (msg.id != null && (Object.prototype.hasOwnProperty.call(msg, 'result') || Object.prototype.hasOwnProperty.call(msg, 'error'))) {
      const pending = this.pending.get(msg.id as JsonRpcId);
      if (!pending) return;
      this.pending.delete(msg.id as JsonRpcId);
      if (msg.error) {
        const e = msg.error as JsonRpcResponseError | string;
        if (typeof e === 'string') {
          pending.reject(new Error(e));
        } else {
          const message = e.message || 'JSON-RPC error';
          pending.reject(new JsonRpcError(message, { code: e.code, data: e.data }));
        }
      } else {
        pending.resolve(msg.result);
      }
      return;
    }

    // Server-initiated request
    if (msg.id != null && typeof msg.method === 'string') {
      const id = msg.id as JsonRpcId;
      const method = msg.method as string;
      const params = msg.params;
      try {
        const handler = this.serverRequestHandler;
        if (!handler) throw new Error(`Unhandled server request: ${method}`);
        const result = await handler({ id, method, params });
        await this.sendLine(JSON.stringify({ id, result }));
      } catch (e) {
        const err = toError(e);
        await this.sendLine(JSON.stringify({ id, error: { message: err.message } }));
      }
      return;
    }

    // Notification
    if (typeof msg.method === 'string') {
      const n: JsonRpcNotification = { method: msg.method, params: msg.params };
      for (const fn of this.notificationListeners) fn(n);
    }
  }

  rejectAllPending(reason: unknown) {
    const err = toError(reason);
    for (const [, p] of this.pending) p.reject(err);
    this.pending.clear();
  }
}
