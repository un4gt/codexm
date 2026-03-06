import 'dart:io';
import 'dart:convert';

import 'package:codexm_flutter/features/mcp/application/mcp_models.dart';
import 'package:codexm_flutter/features/settings/application/auth_store.dart';
import 'package:codexm_flutter/features/settings/application/codex_settings_store.dart';
import 'package:codexm_flutter/shared/persistence/app_directory_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saves settings, secure auth and materializes runtime config', () async {
    final documentsDir = await Directory.systemTemp.createTemp('codexm_docs_');
    final temporaryDir = await Directory.systemTemp.createTemp('codexm_tmp_');
    addTearDown(() async {
      if (documentsDir.existsSync()) {
        await documentsDir.delete(recursive: true);
      }
      if (temporaryDir.existsSync()) {
        await temporaryDir.delete(recursive: true);
      }
    });

    final appDirectoryService = AppDirectoryService(
      documentsResolver: () async => documentsDir,
      temporaryResolver: () async => temporaryDir,
    );
    final authStore = AuthStore(
      secureStore: _MemorySecureStore(),
    );
    final settingsStore = CodexSettingsStore(
      appDirectoryService: appDirectoryService,
      authStore: authStore,
    );

    await settingsStore.saveSettings(
      const CodexSettings(
        model: 'gpt-test',
        openaiBaseUrl: 'https://example.com',
        featuresMultiAgent: true,
      ),
    );
    await settingsStore.saveCodexApiKey('sk-test-1234567890');

    final result = await settingsStore.materializeCodexConfigFiles(
      mcpServers: const <McpServer>[
        McpServer(
          id: 'server-1',
          kind: 'rmcp',
          name: 'Demo MCP',
          configKey: 'demo_mcp',
          transport: 'stdio',
          command: 'codex',
          args: <String>['mcp', 'serve'],
          createdAt: 1,
          updatedAt: 1,
        ),
      ],
      enabledMcpServerIds: const <String>['server-1'],
    );

    expect(result.configToml, contains('model = "gpt-test"'));
    expect(result.configToml, contains('base_url = "https://example.com/v1"'));
    expect(result.configToml, contains('[mcp_servers.demo_mcp]'));
    expect(await File(result.authJsonPath).readAsString(), contains('OPENAI_API_KEY'));
    expect(result.codexHomePath, contains('codex-home'));
  });

  test('resolves models url and fetches available models from draft credentials',
      () async {
    final documentsDir = await Directory.systemTemp.createTemp('codexm_docs_');
    final temporaryDir = await Directory.systemTemp.createTemp('codexm_tmp_');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      if (documentsDir.existsSync()) {
        await documentsDir.delete(recursive: true);
      }
      if (temporaryDir.existsSync()) {
        await temporaryDir.delete(recursive: true);
      }
    });

    server.listen((request) async {
      expect(request.uri.path, '/v1/models');
      expect(
        request.headers.value(HttpHeaders.authorizationHeader),
        'Bearer sk-local-test',
      );
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode({
          'data': [
            {'id': 'gpt-4o-mini'},
            {'id': 'gpt-4.1'},
            {'id': 'gpt-4o-mini'},
          ],
        }),
      );
      await request.response.close();
    });

    final appDirectoryService = AppDirectoryService(
      documentsResolver: () async => documentsDir,
      temporaryResolver: () async => temporaryDir,
    );
    final settingsStore = CodexSettingsStore(
      appDirectoryService: appDirectoryService,
      authStore: AuthStore(secureStore: _MemorySecureStore()),
    );

    final baseUrl = 'http://127.0.0.1:${server.port}';
    expect(
      settingsStore.resolveModelsListUrl(baseUrl),
      '$baseUrl/v1/models',
    );

    final models = await settingsStore.fetchAvailableModels(
      draftBaseUrl: baseUrl,
      draftApiKey: 'sk-local-test',
    );
    expect(models, <String>['gpt-4.1', 'gpt-4o-mini']);
  });

  test('previews config and validates managed sections', () async {
    final documentsDir = await Directory.systemTemp.createTemp('codexm_docs_');
    final temporaryDir = await Directory.systemTemp.createTemp('codexm_tmp_');
    addTearDown(() async {
      if (documentsDir.existsSync()) {
        await documentsDir.delete(recursive: true);
      }
      if (temporaryDir.existsSync()) {
        await temporaryDir.delete(recursive: true);
      }
    });

    final appDirectoryService = AppDirectoryService(
      documentsResolver: () async => documentsDir,
      temporaryResolver: () async => temporaryDir,
    );
    final settingsStore = CodexSettingsStore(
      appDirectoryService: appDirectoryService,
      authStore: AuthStore(secureStore: _MemorySecureStore()),
    );

    final preview = settingsStore.previewCodexConfigToml(
      settings: const CodexSettings(
        model: 'gpt-4.1',
        openaiBaseUrl: 'https://example.com',
        extraConfigToml: '[sandbox]\nnetwork_access = true',
      ),
    );
    expect(preview.validationError, isNull);
    expect(preview.configToml, contains('model = "gpt-4.1"'));
    expect(preview.configToml, contains('[sandbox]'));

    expect(
      settingsStore.validateExtraConfigToml('model = "duplicate"'),
      contains('重复'),
    );
    expect(
      settingsStore.validateCodexConfigToml('[broken]\nvalue ='),
      contains('缺少“=”号'),
    );
  });
}

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    _data.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return _data[key];
  }

  @override
  Future<void> write({
    required String key,
    required String value,
  }) async {
    _data[key] = value;
  }
}
