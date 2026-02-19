import { readSSE } from './sse';
import type { CodexServerConfig, CodexStreamEvent } from './types';

function withSlash(url: string) {
    return url.endsWith('/') ? url : `${url}/`;
}

export class CodexClient {
    constructor(private cfg: CodexServerConfig) { }

    private headers(extra?: Record<string, string>) {
        return {
            ...(this.cfg.apiKey ? { Authorization: `Bearer ${this.cfg.apiKey}` } : {}),
            ...(extra ?? {}),
        };
    }

    /**
     * Health check (best-effort). Many servers may not implement /health.
     * Returns true if server responds 2xx.
     */
    async health(path = 'health'): Promise<boolean> {
        try {
            const url = new URL(path, withSlash(this.cfg.baseUrl)).toString();
            const res = await fetch(url, { method: 'GET', headers: this.headers() });
            return res.ok;
        } catch {
            return false;
        }
    }

    /**
     * Generic streaming endpoint wrapper.
     * Because Codex app-server exact endpoints may vary by version, this is intentionally generic.
     */
    async *stream(endpointPath: string, body: unknown): AsyncGenerator<CodexStreamEvent> {
        const url = new URL(endpointPath, withSlash(this.cfg.baseUrl)).toString();
        const res = await fetch(url, {
            method: 'POST',
            headers: this.headers({ 'Content-Type': 'application/json', Accept: 'text/event-stream' }),
            body: JSON.stringify(body ?? {}),
        });

        if (!res.ok) {
            yield { type: 'error', message: `Codex stream failed: ${res.status} ${res.statusText}` };
            return;
        }

        yield* readSSE(res);
    }
}
