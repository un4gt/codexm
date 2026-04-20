import 'package:codexm_flutter/features/codex/application/codex_error_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps missing runtime binaries to install package hint', () {
    final message =
        'PlatformException(E_CODEX_RUNTIME_START, 未能从 nativeLibraryDir 解析 Codex 运行时可执行文件。'
        '\n- missing: libcodex.so, libcodex_exec.so, librg.so, {method: runtime.start})';

    expect(
      formatRpcErrorForUser(message),
      '当前安装包缺少 Codex 运行组件，请安装包含运行时的最新安装包后重试。',
    );
  });

  test('maps runtime startup exit to settings check hint', () {
    const message =
        'PlatformException(E_CODEX_RUNTIME_START, CodexRuntime 启动后立即退出。'
        '\n- exitCode: 1, {method: runtime.start})';

    expect(
      formatRpcErrorForUser(message),
      'Codex 启动失败：请检查「设置 > 连接」中的 API Key / Base URL 后重试。',
    );
  });

  test('maps runtime permission denied to reinstall hint', () {
    const message =
        'PlatformException(E_CODEX_RUNTIME_START, CodexRuntime 无法执行可执行文件（Permission denied）。, {method: runtime.start})';

    expect(formatRpcErrorForUser(message), 'Codex 运行组件权限异常，请重装应用后重试。');
  });

  test('keeps timeout message mapping', () {
    expect(formatRpcErrorForUser('发送请求超时'), '连接超时：请检查网络与「设置」中的服务器地址/密钥是否正确。');
  });
}
