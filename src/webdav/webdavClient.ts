import * as FileSystem from 'expo-file-system/legacy';
import { FileSystemUploadType } from 'expo-file-system/legacy';
import { XMLParser } from 'fast-xml-parser';
import { fromByteArray } from 'base64-js';

import type { WebDavAuth, WebDavConfig, WebDavDownloadResult, WebDavEntry, WebDavPropfindDepth, WebDavUploadOptions } from './types';

function joinPath(a: string, b: string) {
    if (!a.endsWith('/')) a += '/';
    if (b.startsWith('/')) b = b.slice(1);
    return a + b;
}

function buildUrl(cfg: WebDavConfig, path: string) {
    const base = cfg.basePath ? joinPath(cfg.endpoint, cfg.basePath) : cfg.endpoint;
    return joinPath(base, path);
}

function authHeaders(auth?: WebDavAuth): Record<string, string> {
    if (!auth) return {};
    if (auth.type === 'basic') {
        const bytes = new TextEncoder().encode(`${auth.username}:${auth.password}`);
        const token = fromByteArray(bytes);
        return { Authorization: `Basic ${token}` };
    }
    return { Authorization: `Bearer ${auth.token}` };
}

export class WebDavClient {
    constructor(private cfg: WebDavConfig, private auth?: WebDavAuth) { }

    private basePathname() {
        const base = this.cfg.basePath ? joinPath(this.cfg.endpoint, this.cfg.basePath) : this.cfg.endpoint;
        const pathname = new URL(base).pathname;
        return pathname.endsWith('/') ? pathname : `${pathname}/`;
    }

    private toRelativePath(href: string) {
        const basePathname = this.basePathname();
        let pathname = href;
        try {
            pathname = href.startsWith('http') ? new URL(href).pathname : href;
        } catch {
            pathname = href;
        }
        if (pathname.startsWith(basePathname)) pathname = pathname.slice(basePathname.length);
        if (pathname.startsWith('/')) pathname = pathname.slice(1);
        return decodeURIComponent(pathname);
    }

    async head(path: string): Promise<WebDavDownloadResult> {
        const url = buildUrl(this.cfg, path);
        const res = await fetch(url, {
            method: 'HEAD',
            headers: {
                ...authHeaders(this.auth),
            },
        });
        if (!res.ok) throw new Error(`WebDAV HEAD failed: ${res.status} ${res.statusText}`);
        return {
            etag: res.headers.get('etag') ?? undefined,
            contentType: res.headers.get('content-type') ?? undefined,
            contentLength: res.headers.get('content-length') ? Number(res.headers.get('content-length')) : undefined,
        };
    }

    async downloadToString(path: string): Promise<{ body: string; meta: WebDavDownloadResult }> {
        const url = buildUrl(this.cfg, path);
        const res = await fetch(url, {
            method: 'GET',
            headers: {
                ...authHeaders(this.auth),
            },
        });
        if (!res.ok) throw new Error(`WebDAV GET failed: ${res.status} ${res.statusText}`);
        const body = await res.text();
        const meta: WebDavDownloadResult = {
            etag: res.headers.get('etag') ?? undefined,
            contentType: res.headers.get('content-type') ?? undefined,
            contentLength: res.headers.get('content-length') ? Number(res.headers.get('content-length')) : undefined,
        };
        return { body, meta };
    }

    async downloadToFile(path: string, fileUri: string): Promise<{ meta: WebDavDownloadResult }> {
        const url = buildUrl(this.cfg, path);
        const res = await FileSystem.downloadAsync(url, fileUri, {
            headers: {
                ...authHeaders(this.auth),
            },
        });
        // expo-file-system returns status; 2xx is success.
        if (res.status < 200 || res.status >= 300) {
            throw new Error(`WebDAV download failed: ${res.status}`);
        }
        return { meta: { etag: (res.headers?.etag as string | undefined) ?? undefined } };
    }

    async uploadString(path: string, content: string, options?: WebDavUploadOptions): Promise<{ etag?: string }> {
        const url = buildUrl(this.cfg, path);
        const res = await fetch(url, {
            method: 'PUT',
            headers: {
                ...authHeaders(this.auth),
                ...(options?.contentType ? { 'Content-Type': options.contentType } : {}),
                ...(options?.ifMatchETag ? { 'If-Match': options.ifMatchETag } : {}),
            },
            body: content,
        });
        if (!res.ok) throw new Error(`WebDAV PUT failed: ${res.status} ${res.statusText}`);
        return { etag: res.headers.get('etag') ?? undefined };
    }

    async uploadFile(path: string, fileUri: string, options?: WebDavUploadOptions): Promise<{ etag?: string }> {
        const url = buildUrl(this.cfg, path);
        const res = await FileSystem.uploadAsync(url, fileUri, {
            httpMethod: 'PUT',
            uploadType: FileSystemUploadType.BINARY_CONTENT,
            headers: {
                ...authHeaders(this.auth),
                ...(options?.contentType ? { 'Content-Type': options.contentType } : {}),
                ...(options?.ifMatchETag ? { 'If-Match': options.ifMatchETag } : {}),
            },
        });
        if (res.status < 200 || res.status >= 300) throw new Error(`WebDAV PUT failed: ${res.status}`);
        let etag: string | undefined;
        try {
            const parsed = JSON.parse(res.body ?? '') as { etag?: string };
            etag = parsed.etag;
        } catch {
            // ignore
        }
        return { etag };
    }

    async mkcol(path: string): Promise<void> {
        const url = buildUrl(this.cfg, path.endsWith('/') ? path : `${path}/`);
        const res = await fetch(url, {
            method: 'MKCOL',
            headers: {
                ...authHeaders(this.auth),
            },
        });
        // 201 Created or 405 Method Not Allowed (already exists)
        if (res.status === 201 || res.status === 405) return;
        if (!res.ok) throw new Error(`WebDAV MKCOL failed: ${res.status} ${res.statusText}`);
    }

    async delete(path: string): Promise<void> {
        const url = buildUrl(this.cfg, path);
        const res = await fetch(url, {
            method: 'DELETE',
            headers: {
                ...authHeaders(this.auth),
            },
        });
        if (res.status === 404) return;
        if (!res.ok) throw new Error(`WebDAV DELETE failed: ${res.status} ${res.statusText}`);
    }

    async propfind(path: string, depth: WebDavPropfindDepth = '1'): Promise<WebDavEntry[]> {
        const url = buildUrl(this.cfg, path);
        const body = `<?xml version="1.0" encoding="utf-8" ?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:resourcetype />
    <d:getetag />
    <d:getcontentlength />
    <d:getlastmodified />
  </d:prop>
</d:propfind>`;

        const res = await fetch(url, {
            method: 'PROPFIND',
            headers: {
                ...authHeaders(this.auth),
                Depth: depth,
                'Content-Type': 'text/xml',
                Accept: 'application/xml',
            },
            body,
        });
        if (res.status !== 207 && !res.ok) throw new Error(`WebDAV PROPFIND failed: ${res.status} ${res.statusText}`);
        const xml = await res.text();

        const parser = new XMLParser({
            ignoreAttributes: false,
            attributeNamePrefix: '',
            removeNSPrefix: true,
            // Some servers return invalid entity refs; be lenient.
            processEntities: false,
        });

        type MultiStatus = {
            multistatus?: { response?: unknown };
            response?: unknown;
        };

        const parsed = parser.parse(xml) as MultiStatus;
        const responses = (parsed?.multistatus?.response ?? parsed?.response ?? []) as any;
        const arr = Array.isArray(responses) ? responses : [responses];

        const entries: WebDavEntry[] = [];
        for (const r of arr) {
            const href = String(r?.href ?? '');
            const propstat = Array.isArray(r?.propstat) ? r.propstat[0] : r?.propstat;
            const prop = propstat?.prop ?? {};

            const isCollection = !!prop?.resourcetype?.collection;
            const etag = prop?.getetag ? String(prop.getetag) : undefined;
            const contentLength = prop?.getcontentlength ? Number(prop.getcontentlength) : undefined;
            const lastModified = prop?.getlastmodified ? String(prop.getlastmodified) : undefined;

            if (!href) continue;
            entries.push({
                href,
                path: this.toRelativePath(href),
                isCollection,
                etag,
                contentLength: Number.isFinite(contentLength) ? contentLength : undefined,
                lastModified,
            });
        }

        return entries;
    }
}
