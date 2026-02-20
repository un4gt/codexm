export type AuthRef = string;

export type WorkspaceId = string;

export type WorkspaceGitConfig = {
    remoteUrl: string;
    defaultBranch?: string;
    authRef?: AuthRef;
    allowInsecure?: boolean;
    userName?: string;
    userEmail?: string;
};

export type WorkspaceWebDavConfig = {
    endpoint: string;
    basePath?: string;
    /** Remote folder for this workspace (WebDAV-relative). */
    remoteRoot?: string;
    authRef?: AuthRef;
};

export type Workspace = {
    id: WorkspaceId;
    name: string;
    createdAt: number;
    localPath: string;
    git?: WorkspaceGitConfig;
    webdav?: WorkspaceWebDavConfig;
    /** 可选：新建会话时默认启用的 MCP server（按 id）。 */
    mcpDefaultEnabledServerIds?: string[];
};
