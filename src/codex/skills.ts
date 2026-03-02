import * as FileSystem from 'expo-file-system';

import { codexHomeUri } from './settings';

function uriToPath(uri: string) {
  return uri.startsWith('file://') ? uri.replace('file://', '') : uri;
}

function skillsDirUri() {
  return `${codexHomeUri()}skills/`;
}

export function normalizeSkillName(raw: string) {
  const trimmed = raw.trim().replace(/^\$+/, '').trim().toLowerCase();
  const cleaned = trimmed
    .replace(/[^a-z0-9_-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^[-_]+|[-_]+$/g, '');
  return cleaned;
}

export function skillFileUri(name: string) {
  const n = normalizeSkillName(name);
  return `${skillsDirUri()}${n}/SKILL.md`;
}

export function skillFilePath(name: string) {
  return uriToPath(skillFileUri(name));
}

export async function ensureSkillsDir() {
  await FileSystem.makeDirectoryAsync(skillsDirUri(), { intermediates: true });
}

export async function listInstalledSkills(): Promise<string[]> {
  try {
    await ensureSkillsDir();
    const entries = await FileSystem.readDirectoryAsync(skillsDirUri());
    const out: string[] = [];
    for (const entry of entries) {
      const n = normalizeSkillName(entry);
      if (!n) continue;
      const fileUri = skillFileUri(n);
      const info = await FileSystem.getInfoAsync(fileUri);
      if (info.exists && !info.isDirectory) out.push(n);
    }
    return out.sort((a, b) => a.localeCompare(b));
  } catch {
    return [];
  }
}

export async function writeSkill(params: { name: string; content: string }) {
  const name = normalizeSkillName(params.name);
  if (!name) throw new Error('名称为空。');
  const content = params.content.trim();
  if (!content) throw new Error('内容为空。');

  await ensureSkillsDir();
  const dirUri = `${skillsDirUri()}${name}/`;
  await FileSystem.makeDirectoryAsync(dirUri, { intermediates: true });
  await FileSystem.writeAsStringAsync(`${dirUri}SKILL.md`, `${content}\n`);
  return { name };
}

export async function deleteSkill(name: string) {
  const n = normalizeSkillName(name);
  if (!n) return;
  const dirUri = `${skillsDirUri()}${n}/`;
  await FileSystem.deleteAsync(dirUri, { idempotent: true });
}
