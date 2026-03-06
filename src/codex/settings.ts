import parseToml from '@iarna/toml/parse-string';
import * as FileSystem from 'expo-file-system/legacy';

import { deleteAuth, loadAuth, saveAuth } from '@/src/auth/authStore';
import type { CodexProviderAuth } from '@/src/auth/types';
import type { McpServer } from '@/src/mcp/types';
import type { AuthRef } from '@/src/workspaces/types';

export type CodexApprovalPolicy = 'untrusted' | 'on-request' | 'on-failure' | 'never';
export type CodexPersonality = 'none' | 'friendly' | 'pragmatic';

export type CodexSettings = {
  version: 1;
  enabled: boolean;
  authRef?: AuthRef;
  model?: string;
  /** 可选：自定义 OpenAI 服务地址（高级用途）。 */
  openaiBaseUrl?: string;
  approvalPolicy: CodexApprovalPolicy;
  personality: CodexPersonality;
  /** 实验特性：多智能体（对应 config.toml 的 [features].multi_agent）。 */
  featuresMultiAgent?: boolean;
  /** UI：是否在消息中显示思考内容（默认隐藏）。 */
  uiShowThinking?: boolean;
  /** 调试：是否把关键日志写入本机文件（默认关闭）。 */
  debugLogToFile?: boolean;
  /** 调试：日志保留天数（全局）。 */
  debugLogRetentionDays?: number;
  /** 高级配置：追加到自动生成内容后的补充片段。 */
  extraConfigToml?: string;
  /** 专家模式：使用自定义 config.toml 文本。 */
  useRawConfigToml?: boolean;
  /** 专家模式：自定义 config.toml 内容（不要在这里粘贴密钥）。 */
  rawConfigToml?: string;
};

type StoredCodexSettings = Partial<CodexSettings> & { version?: number };

const DOC = (FileSystem as any).documentDirectory as string | null | undefined;
if (!DOC) throw new Error('expo-file-system documentDirectory not available');

function settingsDir() {
  return `${DOC}settings/`;
}

function settingsPath() {
  return `${settingsDir()}codex.json`;
}

export function codexHomeUri() {
  // A stable, global CODEX_HOME replacement for mobile.
  return `${DOC}codex-home/`;
}

export async function ensureCodexHomeDir() {
  await FileSystem.makeDirectoryAsync(codexHomeUri(), { intermediates: true });
}

async function ensureSettingsDir() {
  await FileSystem.makeDirectoryAsync(settingsDir(), { intermediates: true });
}

export function defaultCodexSettings(): CodexSettings {
  return {
    version: 1,
    enabled: true,
    approvalPolicy: 'never',
    personality: 'none',
    featuresMultiAgent: false,
    uiShowThinking: false,
    debugLogToFile: false,
    debugLogRetentionDays: 7,
  };
}

export async function getCodexSettings(): Promise<CodexSettings> {
  await ensureSettingsDir();
  const path = settingsPath();
  const info = await FileSystem.getInfoAsync(path);
  if (!info.exists) return defaultCodexSettings();
  const raw = await FileSystem.readAsStringAsync(path);
  const parsed = JSON.parse(raw) as StoredCodexSettings;

  const base = defaultCodexSettings();
  const merged: CodexSettings = {
    ...base,
    ...parsed,
    version: 1,
    approvalPolicy: (parsed.approvalPolicy ?? base.approvalPolicy) as CodexApprovalPolicy,
    personality: (parsed.personality ?? base.personality) as CodexPersonality,
  };
  return merged;
}

export async function saveCodexSettings(next: CodexSettings): Promise<CodexSettings> {
  await ensureSettingsDir();
  const path = settingsPath();
  const normalized: CodexSettings = { ...defaultCodexSettings(), ...next, version: 1 };
  await FileSystem.writeAsStringAsync(path, JSON.stringify(normalized, null, 2));
  return normalized;
}

export async function updateCodexSettings(patch: Partial<Omit<CodexSettings, 'version'>>): Promise<CodexSettings> {
  const current = await getCodexSettings();
  const next: CodexSettings = { ...current, ...patch, version: 1 };
  return await saveCodexSettings(next);
}

export async function hasCodexApiKey(): Promise<boolean> {
  const s = await getCodexSettings();
  if (!s.authRef) return false;
  try {
    const stored = await loadAuth<CodexProviderAuth>(s.authRef);
    return !!stored?.token;
  } catch {
    // authRef 可能来自旧版本且不符合 SecureStore 的 key 规则，直接丢弃
    await updateCodexSettings({ authRef: undefined });
    return false;
  }
}

export async function setCodexApiKey(apiKey: string | null): Promise<CodexSettings> {
  const s = await getCodexSettings();
  const trimmed = apiKey?.trim() ?? '';

  if (s.authRef) {
    try {
      await deleteAuth(s.authRef);
    } catch {
      // ignore
    }
  }

  if (!trimmed) {
    return await updateCodexSettings({ authRef: undefined });
  }

  const auth: CodexProviderAuth = { type: 'codex_bearer', token: trimmed };
  const authRef = await saveAuth(auth);
  return await updateCodexSettings({ authRef });
}

export async function getCodexApiKey(): Promise<string | null> {
  const s = await getCodexSettings();
  if (!s.authRef) return null;
  try {
    const stored = await loadAuth<CodexProviderAuth>(s.authRef);
    return stored?.token ?? null;
  } catch {
    // authRef 可能来自旧版本且不符合 SecureStore 的 key 规则，直接丢弃
    await updateCodexSettings({ authRef: undefined });
    return null;
  }
}

function tomlString(v: string) {
  // JSON string escaping is valid TOML basic string escaping for our needs.
  return JSON.stringify(v);
}

export function normalizeOpenaiBaseUrlForCodex(input: string) {
  const raw = input.trim();
  if (!raw) return '';
  let base = raw.replace(/\/+$/, '');
  if (base.endsWith('/models')) base = base.slice(0, -'/models'.length);
  if (!base.endsWith('/v1')) base = `${base}/v1`;
  return base;
}

function generateMcpServersToml(servers: McpServer[]) {
  const enabled = (servers ?? []).filter((s) => s && s.configKey?.trim());
  if (!enabled.length) return '';

  const lines: string[] = [];
  lines.push('# MCP servers（由 CodexM 按会话自动注入）');

  for (const s of enabled) {
    const key = s.configKey.trim();
    lines.push('');
    lines.push(`[mcp_servers.${key}]`);
    if (s.transport === 'url') {
      if (s.url?.trim()) lines.push(`url = ${tomlString(s.url.trim())}`);
    } else {
      if (s.command?.trim()) lines.push(`command = ${tomlString(s.command.trim())}`);
      if (Array.isArray(s.args) && s.args.length) lines.push(`args = ${JSON.stringify(s.args)}`);
    }
  }

  return `${lines.join('\n')}\n`;
}

export function generateCodexConfigToml(s: CodexSettings) {
  const lines: string[] = [];
  lines.push('# 由 CodexM 自动生成');
  lines.push('# 如需自定义，请在 App「设置」中编辑');
  lines.push('');

  if (s.model?.trim()) lines.push(`model = ${tomlString(s.model.trim())}`);
  if (s.approvalPolicy) lines.push(`approval_policy = ${tomlString(s.approvalPolicy)}`);

  // 默认使用 Codex 内置 OpenAI provider（配合 auth.json 或 keyring）。
  // 在移动端我们会把用户在 SecureStore 里保存的 API Key 同步到 CODEX_HOME/auth.json（见 materializeCodexConfigFiles）。 
  lines.push(`model_provider = ${tomlString('openai')}`);

  const openaiBaseUrl = s.openaiBaseUrl?.trim();
  if (openaiBaseUrl) {
    const baseUrl = normalizeOpenaiBaseUrlForCodex(openaiBaseUrl);
    if (baseUrl) {
      lines.push('');
      lines.push('[model_providers.openai]');
      lines.push(`base_url = ${tomlString(baseUrl)}`);
    }
  }

  if (s.featuresMultiAgent) {
    lines.push('');
    lines.push('[features]');
    lines.push('multi_agent = true');
  }

  // 移动端：禁用桌面端沙箱实现（某些沙箱在 Android 上不可用/不稳定）。
  // 运行环境本身已受 App Sandbox 限制；这里用 full-access 避免启动时的 runtime 初始化失败。
  lines.push(`sandbox_mode = ${tomlString('danger-full-access')}`);

  // CLI 凭证存储使用文件模式（密钥仍由 App 单独保存）。
  lines.push(`cli_auth_credentials_store = ${tomlString('file')}`);

  lines.push('');
  return `${lines.join('\n')}\n`;
}

function ensureTrailingNewline(text: string) {
  return text.endsWith('\n') ? text : `${text}\n`;
}

function normalizeTomlText(text: string) {
  return text.replace(/\r\n?/g, '\n');
}

export function mergeCodexConfigToml(baseToml: string, extraToml?: string) {
  const base = normalizeTomlText(baseToml).trimEnd();
  const extra = normalizeTomlText(extraToml ?? '').trim();
  if (!extra) return ensureTrailingNewline(base);
  return ensureTrailingNewline(`${base}\n\n${extra}`);
}

function summarizeTomlParseMessage(message: string) {
  const firstLine = message.split('\n')[0]?.trim() ?? '格式有误。';
  if (firstLine.includes('expected "="')) return '这一行缺少“=”号。';
  if (firstLine.includes('Unterminated string')) return '字符串没有正确结束。';
  if (firstLine.includes("Can't redefine existing key")) return '这里和前面的内容重复了，请直接修改对应设置项。';
  if (firstLine.includes('expected whitespace, . or ]')) return '分组标题没有正确结束。';
  return firstLine;
}

export function formatCodexConfigError(error: unknown, label = '配置') {
  const message = error instanceof Error ? error.message : String(error);
  const match = message.match(/row\s+(\d+),\s+col\s+(\d+)/i);
  const location = match ? `第 ${match[1]} 行第 ${match[2]} 列附近` : '';
  const summary = summarizeTomlParseMessage(message);
  return `${label}${location}有格式问题：${summary}`;
}

export function validateCodexConfigToml(content: string, label = '配置') {
  const raw = normalizeTomlText(content).trim();
  if (!raw) return `${label}不能为空。`;
  try {
    parseToml(raw);
    return null;
  } catch (error) {
    return formatCodexConfigError(error, label);
  }
}

export function validateExtraCodexConfigToml(extraToml: string) {
  const trimmed = normalizeTomlText(extraToml).trim();
  if (!trimmed) return null;
  try {
    const parsed = parseToml(trimmed) as Record<string, unknown>;
    if (Object.prototype.hasOwnProperty.call(parsed, 'mcp_servers')) {
      return '服务器配置请在单独的服务器页面管理，这里不要重复填写。';
    }
    if (
      Object.prototype.hasOwnProperty.call(parsed, 'model') ||
      Object.prototype.hasOwnProperty.call(parsed, 'approval_policy') ||
      Object.prototype.hasOwnProperty.call(parsed, 'model_provider') ||
      Object.prototype.hasOwnProperty.call(parsed, 'model_providers') ||
      Object.prototype.hasOwnProperty.call(parsed, 'sandbox_mode') ||
      Object.prototype.hasOwnProperty.call(parsed, 'cli_auth_credentials_store')
    ) {
      return '这部分内容和上方表单重复，请直接修改对应设置项。';
    }
    return null;
  } catch (error) {
    return formatCodexConfigError(error, '补充内容');
  }
}

export function migrateLegacyRawConfigToml(input: { generatedToml: string; rawConfigToml?: string | null }) {
  const generated = normalizeTomlText(input.generatedToml).trim();
  const raw = normalizeTomlText(input.rawConfigToml ?? '').trim();

  if (!raw) {
    return { canMigrate: true, extraConfigToml: '' };
  }

  if (raw === generated) {
    return { canMigrate: true, extraConfigToml: '' };
  }

  if (raw.startsWith(`${generated}\n`)) {
    return {
      canMigrate: true,
      extraConfigToml: raw.slice(generated.length).trim(),
    };
  }

  return { canMigrate: false, extraConfigToml: '' };
}

function composeStoredCodexConfigToml(
  s: CodexSettings,
  opts?: {
    mcpServers?: McpServer[];
    enabledMcpServerIds?: string[];
  }
) {
  const usingRaw = Boolean(s.useRawConfigToml && s.rawConfigToml?.trim());
  let cfgRaw = usingRaw ? normalizeTomlText(s.rawConfigToml ?? '') : mergeCodexConfigToml(generateCodexConfigToml(s), s.extraConfigToml);

  const enabledIds = new Set((opts?.enabledMcpServerIds ?? []).filter(Boolean));
  let warnings: string[] | undefined = undefined;

  if (!usingRaw && enabledIds.size && (opts?.mcpServers?.length ?? 0) > 0) {
    const enabledServers = (opts?.mcpServers ?? []).filter((x) => enabledIds.has(x.id));
    const snippet = generateMcpServersToml(enabledServers);
    if (snippet.trim()) cfgRaw = `${cfgRaw.trimEnd()}\n\n${snippet.trim()}\n`;
  }

  if (usingRaw && enabledIds.size) {
    warnings = ['已启用完整自定义内容：不会自动注入服务器配置，请在完整内容中自行配置。'];
  }

  const cfg = ensureTrailingNewline(cfgRaw.trimEnd());
  return { cfg, warnings, usingRaw };
}

export function generateCodexAuthJson(apiKey: string) {
  // Mirrors codex-rs AuthDotJson for API-key auth:
  // { "auth_mode": "apikey", "OPENAI_API_KEY": "sk-..." }
  const payload = {
    auth_mode: 'apikey',
    OPENAI_API_KEY: apiKey,
  } as const;
  return `${JSON.stringify(payload, null, 2)}\n`;
}

export async function materializeCodexConfigFiles(opts?: {
  mcpServers?: McpServer[];
  enabledMcpServerIds?: string[];
}) {
  const s = await getCodexSettings();
  await ensureCodexHomeDir();
  const { cfg, warnings } = composeStoredCodexConfigToml(s, opts);
  const validationError = validateCodexConfigToml(cfg);
  if (validationError) throw new Error(validationError);
  const configTomlUri = `${codexHomeUri()}config.toml`;
  await FileSystem.writeAsStringAsync(configTomlUri, cfg);

  // Best-effort: keep CODEX_HOME/auth.json in sync so codex openai provider can auth.
  const authJsonUri = `${codexHomeUri()}auth.json`;
  let apiKey: string | null = null;
  if (s.authRef) {
    try {
      const stored = await loadAuth<CodexProviderAuth>(s.authRef);
      apiKey = stored?.token ?? null;
    } catch {
      apiKey = null;
    }
  }
  if (apiKey?.trim()) {
    await FileSystem.writeAsStringAsync(authJsonUri, generateCodexAuthJson(apiKey.trim()));
  } else {
    try {
      await FileSystem.deleteAsync(authJsonUri, { idempotent: true });
    } catch {
      // ignore
    }
  }

  return { settings: s, codexHomeUri: codexHomeUri(), configTomlUri, configToml: cfg, authJsonUri, warnings };
}
