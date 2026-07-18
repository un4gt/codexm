import 'dart:convert';
import 'dart:io';

import 'package:codexm_flutter/features/workspaces/application/workspace_paths.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prepares workspace contract and shared index dir', () async {
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

    final service = WorkspaceDirectoryService(
      documentsResolver: () async => documentsDir,
      temporaryResolver: () async => temporaryDir,
    );

    final paths = await service.prepareWorkspace(
      workspaceId: 'workspace-case',
      workspaceName: 'Workspace Case',
      reset: true,
    );

    expect(paths.workspaceRoot.existsSync(), isTrue);
    expect(paths.repoDir.existsSync(), isTrue);
    expect(paths.worktreesDir.existsSync(), isTrue);
    expect(
      paths.sessionWorktreeDir('session-1').path,
      '${paths.worktreesDir.path}/session-1',
    );
    expect(paths.metaDir.existsSync(), isTrue);
    expect(paths.codexHomeDir.existsSync(), isTrue);
    expect(paths.tmpDir.existsSync(), isTrue);

    final workspaceJson =
        jsonDecode(await paths.workspaceJsonFile.readAsString())
            as Map<String, dynamic>;
    expect(workspaceJson['id'], 'workspace-case');
    expect(workspaceJson['name'], 'Workspace Case');

    final indexDir = await service.workspaceIndexDir();
    expect(indexDir.path, '${documentsDir.path}/workspaces/.index');
    expect(indexDir.existsSync(), isTrue);
  });
}
