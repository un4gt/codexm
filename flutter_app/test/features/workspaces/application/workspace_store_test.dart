import 'dart:io';

import 'package:codexm_flutter/features/workspaces/application/workspace_store.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_paths.dart';
import 'package:codexm_flutter/shared/persistence/app_directory_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('creates workspace index and active workspace record', () async {
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
    final store = WorkspaceStore(
      appDirectoryService: appDirectoryService,
      workspaceDirectoryService: workspaceDirectoryService,
    );

    final created = await store.createWorkspace(name: 'Alpha Workspace');
    final listed = await store.listWorkspaces();
    expect(listed, hasLength(1));
    expect(listed.first.name, 'Alpha Workspace');

    await store.setActiveWorkspaceId(created.id);
    final active = await store.getActiveWorkspace();
    expect(active?.id, created.id);
    expect(active?.localPath, created.localPath);
  });
}
