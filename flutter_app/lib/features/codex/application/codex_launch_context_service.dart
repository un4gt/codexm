import 'dart:io';

import '../../mcp/application/mcp_models.dart';
import '../../mcp/application/mcp_store.dart';
import '../../sessions/application/session_models.dart';
import '../../sessions/application/session_store.dart';
import '../../settings/application/codex_settings_store.dart';
import '../../workspaces/application/workspace_models.dart';
import '../../workspaces/application/workspace_paths.dart';
import 'codex_models.dart';

class CodexLaunchContextService {
  CodexLaunchContextService({
    WorkspaceDirectoryService? workspaceDirectoryService,
    SessionStore? sessionStore,
    CodexSettingsStore? settingsStore,
    McpStore? mcpStore,
  }) : _workspaceDirectoryService =
           workspaceDirectoryService ?? WorkspaceDirectoryService(),
       _sessionStore = sessionStore ?? SessionStore(),
       _settingsStore = settingsStore ?? CodexSettingsStore(),
       _mcpStore = mcpStore ?? McpStore();

  final WorkspaceDirectoryService _workspaceDirectoryService;
  final SessionStore _sessionStore;
  final CodexSettingsStore _settingsStore;
  final McpStore _mcpStore;

  Future<CodexRuntimeLaunchContext> build({
    required Workspace workspace,
    required SessionId sessionId,
  }) async {
    final session = await _sessionStore.getSession(workspace.id, sessionId);
    if (session == null) {
      throw StateError('会话不存在：$sessionId');
    }

    final paths = await _ensureWorkspacePaths(workspace.id);
    final settings = await _settingsStore.getSettings();
    final apiKey = await _settingsStore.getCodexApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw StateError('未设置密钥：请到「设置」中设置。');
    }

    final enabledMcpServerIds = _enabledMcpServerIds(settings);
    final mcpServers = enabledMcpServerIds.isEmpty
        ? const <McpServer>[]
        : await _mcpStore.listServers();
    final config = await _settingsStore.materializeCodexConfigFiles(
      mcpServers: mcpServers,
      enabledMcpServerIds: enabledMcpServerIds,
    );

    final env = <String, String>{
      'CODEX_HOME': config.codexHomePath,
      'HOME': config.codexHomePath,
      'TMPDIR': paths.tmpDir.path,
      'SQLITE_TMPDIR': paths.tmpDir.path,
      'OPENAI_API_KEY': apiKey.trim(),
      'CODEX_API_KEY': apiKey.trim(),
    };

    final baseUrl = settings.openaiBaseUrl?.trim() ?? '';
    if (baseUrl.isNotEmpty) {
      final normalized = _settingsStore.normalizeOpenaiBaseUrlForCodex(baseUrl);
      if (normalized.isNotEmpty) {
        env['OPENAI_BASE_URL'] = normalized;
        env['OPENAI_API_BASE'] = normalized;
        env['OPENAI_API_BASE_URL'] = normalized;
      }
    }

    return CodexRuntimeLaunchContext(
      workspace: workspace,
      session: session,
      settings: config.settings,
      paths: paths,
      codexHomePath: config.codexHomePath,
      configTomlPath: config.configTomlPath,
      authJsonPath: config.authJsonPath,
      env: env,
      enabledMcpServerIds: enabledMcpServerIds,
      apiKey: apiKey.trim(),
      warnings: config.warnings,
    );
  }

  Future<WorkspacePaths> _ensureWorkspacePaths(WorkspaceId workspaceId) async {
    final paths = await _workspaceDirectoryService.pathsFor(workspaceId);
    for (final directory in <Directory>[
      paths.repoDir,
      paths.metaDir,
      paths.codexHomeDir,
      paths.tmpDir,
    ]) {
      await directory.create(recursive: true);
    }
    await _workspaceDirectoryService.workspaceIndexDir();
    return paths;
  }

  List<String> _enabledMcpServerIds(CodexSettings settings) {
    final raw = settings.enabledGlobalMcpServerIds;
    final seen = <String>{};
    final out = <String>[];
    for (final item in raw) {
      final id = item.trim();
      if (id.isEmpty || seen.contains(id)) {
        continue;
      }
      seen.add(id);
      out.add(id);
    }
    return out;
  }
}
