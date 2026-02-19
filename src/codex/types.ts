export type CodexServerConfig = {
    baseUrl: string; // e.g. http://127.0.0.1:8787
    apiKey?: string;
};

export type CodexStreamEvent =
    | { type: 'text'; text: string }
    | { type: 'error'; message: string }
    | { type: 'done' };
