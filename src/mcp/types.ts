export type McpServerId = string;

// 当前仅考虑 rmcp 生态（Rust 原生/可执行），不面向 Node/Python runtime 进行适配。
export type McpServerKind = 'rmcp';

export type McpTransport = 'url' | 'stdio';

export type McpServer = {
  id: McpServerId;
  kind: McpServerKind;
  /** 展示名称。 */
  name: string;
  /**
   * 写入 config.toml 时使用的 key：`[mcp_servers.<configKey>]`
   * 需要是“可安全落地为 TOML key”的简化字符串。
   */
  configKey: string;
  transport: McpTransport;
  url?: string;
  command?: string;
  args?: string[];
  createdAt: number;
  updatedAt: number;
};

export type McpIndex = {
  version: 1;
  servers: McpServer[];
};

export type McpServerCreateParams = {
  /** 可选：用于可重复安装/引用的稳定 id；不提供则自动生成。 */
  id?: McpServerId;
  kind: McpServerKind;
  /** 展示名称。 */
  name: string;
  /** 可选：若不提供将基于 name 自动生成并确保唯一。 */
  configKey?: string;
  transport: McpTransport;
  url?: string;
  command?: string;
  args?: string[];
};
