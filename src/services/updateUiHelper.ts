import * as Application from 'expo-application';
import * as Updates from 'expo-updates';

import { getOtaUpdateSupport } from '@/src/services/updateService';

export function formatOtaSubtitle(): string {
  const appVersion = Application.nativeApplicationVersion ?? '—';
  const buildVersion = Application.nativeBuildVersion;
  const versionText = buildVersion ? `${appVersion} (${buildVersion})` : appVersion;

  const channel = Updates.channel ?? '—';
  const base = `版本 ${versionText} · 渠道 ${channel}`;

  const support = getOtaUpdateSupport();
  if (!support.supported) return `${base}\n${support.reason}`;
  return base;
}

export function formatOtaError(e: unknown): string {
  const msg = e instanceof Error ? e.message : String(e);
  const lower = msg.toLowerCase();

  if (
    lower.includes('network') ||
    lower.includes('timeout') ||
    lower.includes('timed out') ||
    lower.includes('fetch')
  ) {
    return '网络异常，无法连接更新服务。请稍后重试。';
  }

  if (
    lower.includes('expo go') ||
    lower.includes('not enabled') ||
    lower.includes('disabled') ||
    lower.includes('not supported')
  ) {
    return '该功能仅在独立/发布构建中可用。';
  }

  return '更新失败，请稍后重试。';
}

