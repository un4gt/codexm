import 'dart:io';

import 'package:codexm_flutter/features/codex/application/codex_launch_context_service.dart';
import 'package:codexm_flutter/features/mcp/application/mcp_models.dart';
import 'package:codexm_flutter/features/mcp/application/mcp_store.dart';
import 'package:codexm_flutter/features/sessions/application/session_store.dart';
import 'package:codexm_flutter/features/settings/application/auth_store.dart';
import 'package:codexm_flutter/features/settings/application/codex_settings_store.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_paths.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_store.dart';
import 'package:codexm_flutter/shared/persistence/app_directory_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('builds runtime env and materializes Codex config', () async {
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
    final workspaceDirectoryService = WorkspaceDirectoryService(
      appDirectoryService: appDirectoryService,
    );
    final workspaceStore = WorkspaceStore(
      appDirectoryService: appDirectoryService,
      workspaceDirectoryService: workspaceDirectoryService,
    );
    final sessionStore = SessionStore(
      workspaceDirectoryService: workspaceDirectoryService,
    );
    final mcpStore = McpStore(appDirectoryService: appDirectoryService);
    final authStore = AuthStore(secureStore: _MemorySecureStore());
    final settingsStore = CodexSettingsStore(
      appDirectoryService: appDirectoryService,
      authStore: authStore,
    );

    final workspace = await workspaceStore.createWorkspace(
      name: 'Codex Workspace',
    );
    final server = await mcpStore.addServer(
      const McpServerCreateParams(
        name: 'Demo MCP',
        transport: 'stdio',
        command: 'codex',
        args: <String>['mcp', 'serve'],
      ),
    );
    final session = await sessionStore.createSession(
      workspace.id,
      title: 'Codex Session',
    );

    await settingsStore.saveSettings(
      CodexSettings(
        model: 'gpt-test',
        openaiBaseUrl: 'https://example.com',
        featuresMultiAgent: true,
        enabledGlobalMcpServerIds: <String>[server.id],
      ),
    );
    await settingsStore.saveCodexApiKey('sk-test-1234567890');

    final service = CodexLaunchContextService(
      workspaceDirectoryService: workspaceDirectoryService,
      sessionStore: sessionStore,
      settingsStore: settingsStore,
      mcpStore: mcpStore,
    );
    final context = await service.build(
      workspace: workspace,
      sessionId: session.id,
    );

    expect(context.env['CODEX_HOME'], contains('codex-home'));
    expect(context.env['OPENAI_API_KEY'], 'sk-test-1234567890');
    expect(context.env['OPENAI_BASE_URL'], 'https://example.com/v1');
    expect(context.enabledMcpServerIds, <String>[server.id]);
    expect(
      await File(context.configTomlPath).readAsString(),
      contains('[mcp_servers.demo-mcp]'),
    );
    expect(
      await File(context.authJsonPath).readAsString(),
      contains('OPENAI_API_KEY'),
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
  Future<void> write({required String key, required String value}) async {
    _data[key] = value;
  }
}
