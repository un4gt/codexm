import * as FileSystem from 'expo-file-system/legacy';

import { deleteAuth, loadAuth, saveAuth } from '@/src/auth/authStore';
import type { CodexProviderAuth } from '@/src/auth/types';
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

  // sandbox_mode 暂不在此写入；未来可按会话覆盖。
  // lines.push(`sandbox_mode = ${tomlString('read-only')}`);

  // CLI 凭证存储使用文件模式（密钥仍由 App 单独保存）。
  lines.push(`cli_auth_credentials_store = ${tomlString('file')}`);

  lines.push('');
  return `${lines.join('\n')}\n`;
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

export async function materializeCodexConfigFiles() {
  const s = await getCodexSettings();
  await ensureCodexHomeDir();
  const cfgRaw = s.useRawConfigToml && s.rawConfigToml?.trim() ? s.rawConfigToml : generateCodexConfigToml(s);
  const cfg = cfgRaw.endsWith('\n') ? cfgRaw : `${cfgRaw}\n`;
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

  return { settings: s, codexHomeUri: codexHomeUri(), configTomlUri, configToml: cfg, authJsonUri };
}
