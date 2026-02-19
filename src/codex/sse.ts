import type { CodexStreamEvent } from './types';

// Minimal SSE reader using fetch + ReadableStream (works in modern RN/Expo runtimes).
export async function* readSSE(res: Response): AsyncGenerator<CodexStreamEvent> {
    if (!res.body) {
        yield { type: 'error', message: 'Response body is null (streaming unsupported in this runtime)' };
        return;
    }

    const reader = res.body.getReader();
    const decoder = new TextDecoder('utf-8');
    let buf = '';

    while (true) {
        const { value, done } = await reader.read();
        if (done) break;
        buf += decoder.decode(value, { stream: true });

        // SSE events separated by blank line
        let idx: number;
        while ((idx = buf.indexOf('\n\n')) >= 0) {
            const chunk = buf.slice(0, idx);
            buf = buf.slice(idx + 2);

            // parse lines: data:, event:
            const lines = chunk.split(/\r?\n/);
            const dataLines: string[] = [];
            for (const line of lines) {
                if (line.startsWith('data:')) dataLines.push(line.slice(5).trimStart());
            }
            const data = dataLines.join('\n');
            if (!data) continue;

            if (data === '[DONE]') {
                yield { type: 'done' };
                return;
            }

            // Try parse JSON, otherwise treat as plain text
            try {
                const parsed = JSON.parse(data);
                if (typeof parsed?.text === 'string') {
                    yield { type: 'text', text: parsed.text };
                } else {
                    yield { type: 'text', text: data };
                }
            } catch {
                yield { type: 'text', text: data };
            }
        }
    }

    yield { type: 'done' };
}
