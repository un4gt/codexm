import { DeviceEventEmitter, NativeModules } from 'react-native';

export type CodexRuntimeLineEvent = {
  runtimeId: string;
  stream: 'stdout' | 'stderr';
  line: string;
};

type NativeCodexRuntimeManager = {
  start(params: {
    runtimeId: string;
    cwdUri: string;
    executablePath?: string;
    assetPath?: string;
    args?: string[];
    env?: Record<string, string>;
  }): Promise<string>;
  stop(params?: { runtimeId: string }): Promise<void>;
  send(params: { runtimeId: string; line: string }): Promise<void>;
  chmod(params: { path: string }): Promise<void>;
  extractTarGz(params: { archivePath: string; destDir: string }): Promise<void>;
};

function getNativeRuntime(): NativeCodexRuntimeManager {
  const mod = (NativeModules as any).CodexRuntimeManager as NativeCodexRuntimeManager | undefined;
  if (!mod) {
    throw new Error(
      'Native CodexRuntimeManager 未安装。需要使用 Expo Dev Client + prebuild 集成 Android 原生模块后才能运行内嵌 codex app-server。'
    );
  }
  return mod;
}

export function onCodexRuntimeLine(listener: (ev: CodexRuntimeLineEvent) => void) {
  const sub = DeviceEventEmitter.addListener('CodexRuntimeLine', listener);
  return () => sub.remove();
}

export async function startCodexRuntime(params: Parameters<NativeCodexRuntimeManager['start']>[0]) {
  return await getNativeRuntime().start(params);
}

export async function stopCodexRuntime(runtimeId: string) {
  return await getNativeRuntime().stop({ runtimeId });
}

export async function sendCodexLine(runtimeId: string, line: string) {
  return await getNativeRuntime().send({ runtimeId, line });
}

export async function chmodPath(pathOrUri: string) {
  return await getNativeRuntime().chmod({ path: pathOrUri });
}

export async function extractTarGz(archivePathOrUri: string, destDirUri: string) {
  return await getNativeRuntime().extractTarGz({ archivePath: archivePathOrUri, destDir: destDirUri });
}
