export type CodexLocalServerState =
    | { status: 'stopped' }
    | { status: 'starting' }
    | { status: 'running'; baseUrl: string }
    | { status: 'error'; message: string };

export type CodexLocalServerManager = {
    /** Starts a local `codex app-server` and returns the baseUrl (e.g. http://127.0.0.1:8787). */
    start(): Promise<string>;
    stop(): Promise<void>;
    getBaseUrl(): Promise<string | null>;
    getState(): Promise<CodexLocalServerState>;
};

/**
 * Placeholder implementation.
 *
 * In Phase A we will implement Android runtime by embedding a Node runtime or spawning a native binary.
 * Until then, this manager can be wired to an already-running server (dev).
 */
export class ExternalCodexServerManager implements CodexLocalServerManager {
    private baseUrl: string | null;
    private state: CodexLocalServerState = { status: 'stopped' };

    constructor(baseUrl?: string) {
        this.baseUrl = baseUrl ?? null;
        if (this.baseUrl) this.state = { status: 'running', baseUrl: this.baseUrl };
    }

    async start(): Promise<string> {
        if (!this.baseUrl) {
            this.state = { status: 'error', message: 'No baseUrl configured for ExternalCodexServerManager' };
            throw new Error(this.state.message);
        }
        this.state = { status: 'running', baseUrl: this.baseUrl };
        return this.baseUrl;
    }

    async stop(): Promise<void> {
        // no-op
        this.state = { status: 'stopped' };
    }

    async getBaseUrl(): Promise<string | null> {
        return this.baseUrl;
    }

    async getState(): Promise<CodexLocalServerState> {
        return this.state;
    }
}
