export type WebDavAuth =
    | { type: 'basic'; username: string; password: string }
    | { type: 'bearer'; token: string };

export type WebDavConfig = {
    endpoint: string; // e.g. https://dav.example.com
    basePath?: string; // e.g. /codexm
    // auth is not stored here long-term; prefer a secure store and reference
    authRef?: string;
};

export type WebDavUploadOptions = {
    contentType?: string;
    ifMatchETag?: string;
};

export type WebDavDownloadResult = {
    etag?: string;
    contentType?: string;
    contentLength?: number;
};

export type WebDavPropfindDepth = '0' | '1' | 'infinity';

export type WebDavEntry = {
    /** Absolute or server-returned href (may be URL or path). */
    href: string;
    /** Path relative to the WebDAV base (endpoint + basePath), decoded. */
    path: string;
    isCollection: boolean;
    etag?: string;
    contentLength?: number;
    lastModified?: string;
};
