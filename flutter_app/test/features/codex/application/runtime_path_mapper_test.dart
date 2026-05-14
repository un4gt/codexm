import 'package:codexm_flutter/features/codex/application/runtime_path_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps runtime paths to stable aliases', () {
    final mapper = RuntimePathMapper(
      workspaceRepoDir:
          '/data/user/0/com.unsafe.codexm.flutterapp/app_flutter/workspaces/ws_1/repo',
      codexHomeDir:
          '/data/user/0/com.unsafe.codexm.flutterapp/app_flutter/workspaces/ws_1/.meta/codex',
      tmpDir:
          '/data/user/0/com.unsafe.codexm.flutterapp/cache/workspaces/ws_1/tmp',
      runtimeBinDir:
          '/data/user/0/com.unsafe.codexm.flutterapp/files/codexm/bin/arm64-v8a',
    );

    final text = mapper.realToVirtual(
      [
        'cwd: /data/user/0/com.unsafe.codexm.flutterapp/app_flutter/workspaces/ws_1/repo',
        'file: /data/user/0/com.unsafe.codexm.flutterapp/app_flutter/workspaces/ws_1/repo/lib/main.dart:12',
        'home: /data/user/0/com.unsafe.codexm.flutterapp/app_flutter/workspaces/ws_1/.meta/codex/config.toml',
        'tmp: /data/user/0/com.unsafe.codexm.flutterapp/cache/workspaces/ws_1/tmp/session.sock',
        'bin: /data/user/0/com.unsafe.codexm.flutterapp/files/codexm/bin/arm64-v8a/rg',
      ].join('\n'),
    );

    expect(text, contains('cwd: /workspace'));
    expect(text, contains('file: /workspace/lib/main.dart:12'));
    expect(text, contains('home: /home/codex/config.toml'));
    expect(text, contains('tmp: /tmp/codex/session.sock'));
    expect(text, contains('bin: /runtime/bin/rg'));
    expect(text, isNot(contains('/data/user/0/')));
  });

  test('maps android runtime bin path even when abi is discovered natively', () {
    final mapper = RuntimePathMapper(
      workspaceRepoDir: '/app/workspace/repo',
      codexHomeDir: '/app/workspace/.meta/codex',
      tmpDir: '/app/tmp',
    );

    expect(
      mapper.realToVirtual(
        '/data/user/0/com.unsafe.codexm.flutterapp/files/codexm/bin/arm64-v8a/codex',
      ),
      '/runtime/bin/codex',
    );
  });

  test('maps repo paths inside markdown links', () {
    final mapper = RuntimePathMapper(
      workspaceRepoDir:
          '/data/user/0/com.unsafe.codexm.flutterapp/app_flutter/workspaces/ws_1/repo',
      codexHomeDir:
          '/data/user/0/com.unsafe.codexm.flutterapp/app_flutter/workspaces/ws_1/.meta/codex',
      tmpDir:
          '/data/user/0/com.unsafe.codexm.flutterapp/cache/workspaces/ws_1/tmp',
    );

    final text = mapper.realToVirtual(
      '[main.dart](/data/user/0/com.unsafe.codexm.flutterapp/app_flutter/workspaces/ws_1/repo/flutter_app/lib/main.dart)',
    );

    expect(text, '[main.dart](/workspace/flutter_app/lib/main.dart)');
    expect(text, isNot(contains('/data/user/0/')));
  });

  test('hides android private data prefix for unknown app paths', () {
    final mapper = RuntimePathMapper(
      workspaceRepoDir: '/real/repo',
      codexHomeDir: '/real/home',
      tmpDir: '/real/tmp',
    );

    final text = mapper.realToVirtual(
      '/data/user/0/com.unsafe.codexm.flutterapp/app_flutter/other/file.txt',
    );

    expect(text, '/app/app_flutter/other/file.txt');
    expect(text, isNot(contains('/data/user/0/')));
  });

  test('maps aliases back to real paths for future outbound use', () {
    final mapper = RuntimePathMapper(
      workspaceRepoDir: '/real/repo',
      codexHomeDir: '/real/home',
      tmpDir: '/real/tmp',
      runtimeBinDir: '/real/bin',
    );

    expect(
      mapper.virtualToReal('/workspace/lib/main.dart'),
      '/real/repo/lib/main.dart',
    );
    expect(
      mapper.virtualToReal('/home/codex/config.toml'),
      '/real/home/config.toml',
    );
    expect(mapper.virtualToReal('/tmp/codex/out'), '/real/tmp/out');
    expect(mapper.virtualToReal('/runtime/bin/rg'), '/real/bin/rg');
  });
}
