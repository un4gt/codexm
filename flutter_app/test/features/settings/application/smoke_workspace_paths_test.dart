import 'dart:io';

import 'package:codexm_flutter/features/settings/application/smoke_workspace_paths.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('materializes smoke codex home and creates smoke change', () async {
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

    final workspaceDirectoryService = WorkspaceDirectoryService(
      documentsResolver: () async => documentsDir,
      temporaryResolver: () async => temporaryDir,
    );
    final service = SmokeWorkspacePathService(
      workspaceDirectoryService: workspaceDirectoryService,
    );

    final paths = await service.prepareWorkspace(
      workspaceId: 'smoke-case',
      workspaceName: 'Smoke Case',
    );

    await service.materializeCodexHome(
      paths: paths,
      approvalPolicy: 'never',
      apiKey: 'sk-test',
      model: 'gpt-test',
      openaiBaseUrl: 'https://example.com/v1',
    );

    final configToml = await paths.configTomlFile.readAsString();
    expect(configToml, contains('approval_policy = "never"'));
    expect(configToml, contains('model = "gpt-test"'));
    expect(configToml, contains('openai_base_url = "https://example.com/v1"'));
    expect(configToml, isNot(contains('[model_providers.openai]')));
    expect(
      await paths.authJsonFile.readAsString(),
      contains('"OPENAI_API_KEY": "sk-test"'),
    );

    final changeFile = await service.createSmokeChange(paths);
    expect(changeFile.existsSync(), isTrue);
  });
}
