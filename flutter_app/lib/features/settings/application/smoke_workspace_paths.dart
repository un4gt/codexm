import 'dart:convert';
import 'dart:io';

import '../../workspaces/application/workspace_paths.dart';

typedef SmokeWorkspacePaths = WorkspacePaths;

/// Smoke helper built on top of the shared workspace directory service.
class SmokeWorkspacePathService {
  SmokeWorkspacePathService({
    WorkspaceDirectoryService? workspaceDirectoryService,
  }) : _workspaceDirectoryService =
            workspaceDirectoryService ?? WorkspaceDirectoryService();

  final WorkspaceDirectoryService _workspaceDirectoryService;

  /// Recreates the dedicated smoke workspace and ensures all required directories exist.
  Future<SmokeWorkspacePaths> prepareWorkspace({
    required String workspaceId,
    required String workspaceName,
    bool reset = true,
  }) {
    return _workspaceDirectoryService.prepareWorkspace(
      workspaceId: workspaceId,
      workspaceName: workspaceName,
      reset: reset,
    );
  }

  /// Writes a minimal temporary CODEX_HOME config for the smoke validation.
  Future<void> materializeCodexHome({
    required SmokeWorkspacePaths paths,
    required String approvalPolicy,
    String? apiKey,
    String? model,
    String? openaiBaseUrl,
  }) async {
    final lines = <String>[
      '# Flutter smoke 临时配置',
      'approval_policy = ${jsonEncode(approvalPolicy)}',
      'model_provider = ${jsonEncode('openai')}',
      'sandbox_mode = ${jsonEncode('danger-full-access')}',
      'cli_auth_credentials_store = ${jsonEncode('file')}',
    ];

    final trimmedModel = model?.trim() ?? '';
    if (trimmedModel.isNotEmpty) {
      lines.insert(1, 'model = ${jsonEncode(trimmedModel)}');
    }

    final trimmedBaseUrl = openaiBaseUrl?.trim() ?? '';
    if (trimmedBaseUrl.isNotEmpty) {
      lines.add('');
      lines.add('[model_providers.openai]');
      lines.add('base_url = ${jsonEncode(trimmedBaseUrl)}');
    }

    await paths.configTomlFile.writeAsString('${lines.join('\n')}\n');

    final trimmedApiKey = apiKey?.trim() ?? '';
    if (trimmedApiKey.isEmpty) {
      if (paths.authJsonFile.existsSync()) {
        await paths.authJsonFile.delete();
      }
      return;
    }

    await paths.authJsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'auth_mode': 'apikey',
        'OPENAI_API_KEY': trimmedApiKey,
      }),
    );
  }

  /// Creates a local file change so Git status and diff can be verified after clone.
  Future<File> createSmokeChange(SmokeWorkspacePaths paths) async {
    final changeFile = File('${paths.repoDir.path}/SMOKE_TEST.txt');
    final timestamp = DateTime.now().toUtc().toIso8601String();
    await changeFile.writeAsString('Android smoke change created at $timestamp\n');
    return changeFile;
  }
}
