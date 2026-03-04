import { isRunningInExpoGo } from 'expo';
import { Platform } from 'react-native';
import * as Updates from 'expo-updates';

type OtaSupport = { supported: true } | { supported: false; reason: string };

export function getOtaUpdateSupport(): OtaSupport {
  if (Platform.OS === 'web') {
    return { supported: false, reason: '该功能暂不支持 Web。' };
  }
  if (__DEV__ || isRunningInExpoGo() || !Updates.isEnabled) {
    return { supported: false, reason: '该功能仅在独立/发布构建中可用。' };
  }
  return { supported: true };
}

export async function checkForOtaUpdate(): Promise<{ available: boolean; reason?: string }> {
  const support = getOtaUpdateSupport();
  if (!support.supported) return { available: false, reason: support.reason };

  const res = await Updates.checkForUpdateAsync();
  return { available: Boolean(res.isAvailable) };
}

export async function applyOtaUpdate(): Promise<void> {
  const support = getOtaUpdateSupport();
  if (!support.supported) {
    throw new Error(support.reason);
  }

  await Updates.fetchUpdateAsync();
  await Updates.reloadAsync();
}
