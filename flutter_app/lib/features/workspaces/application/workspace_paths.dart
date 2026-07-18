import 'dart:io';
import 'dart:convert';

import '../../../shared/persistence/app_directory_service.dart';

/// Snapshot of the Flutter workspace directory contract.
class WorkspacePaths {
  const WorkspacePaths({
    required this.id,
    required this.workspaceRoot,
    required this.repoDir,
    required this.worktreesDir,
    required this.metaDir,
    required this.codexHomeDir,
    required this.tmpDir,
  });

  final String id;
  final Directory workspaceRoot;
  final Directory repoDir;
  final Directory worktreesDir;
  final Directory metaDir;
  final Directory codexHomeDir;
  final Directory tmpDir;

  File get workspaceJsonFile => File('${metaDir.path}/workspace.json');

  File get configTomlFile => File('${codexHomeDir.path}/config.toml');

  File get authJsonFile => File('${codexHomeDir.path}/auth.json');

  Directory sessionWorktreeDir(String sessionId) =>
      Directory('${worktreesDir.path}/$sessionId');
}

/// Mirrors the RN workspace path rules on Flutter Android.
class WorkspaceDirectoryService {
  WorkspaceDirectoryService({
    AppDirectoryService? appDirectoryService,
    DirectoryResolver? documentsResolver,
    DirectoryResolver? temporaryResolver,
  }) : _appDirectoryService =
           appDirectoryService ??
           AppDirectoryService(
             documentsResolver: documentsResolver,
             temporaryResolver: temporaryResolver,
           );

  final AppDirectoryService _appDirectoryService;

  /// Shared workspace index root, reserved for the next storage phase.
  Future<Directory> workspaceIndexDir() async {
    final workspacesDir = await _appDirectoryService.workspacesDir();
    final indexDir = Directory('${workspacesDir.path}/.index');
    await indexDir.create(recursive: true);
    return indexDir;
  }

  /// Returns the workspace paths without mutating on-disk contents.
  Future<WorkspacePaths> pathsFor(String workspaceId) async {
    final workspacesDir = await _appDirectoryService.workspacesDir();
    final temporaryRoot = await _appDirectoryService.ensureTemporarySubdir(
      'workspaces',
    );

    final workspaceRoot = Directory('${workspacesDir.path}/$workspaceId');
    final tmpRoot = Directory('${temporaryRoot.path}/$workspaceId');
    final repoDir = Directory('${workspaceRoot.path}/repo');
    final worktreesDir = Directory('${workspaceRoot.path}/worktrees');
    final metaDir = Directory('${workspaceRoot.path}/.meta');
    final codexHomeDir = Directory('${metaDir.path}/codex');
    final tmpDir = Directory('${tmpRoot.path}/tmp');

    return WorkspacePaths(
      id: workspaceId,
      workspaceRoot: workspaceRoot,
      repoDir: repoDir,
      worktreesDir: worktreesDir,
      metaDir: metaDir,
      codexHomeDir: codexHomeDir,
      tmpDir: tmpDir,
    );
  }

  /// Creates or recreates the workspace directory contract.
  Future<WorkspacePaths> prepareWorkspace({
    required String workspaceId,
    required String workspaceName,
    bool reset = false,
  }) async {
    final paths = await pathsFor(workspaceId);
    final workspaceRoot = paths.workspaceRoot;
    final tmpRoot = paths.tmpDir.parent.parent;

    if (reset) {
      if (workspaceRoot.existsSync()) {
        await workspaceRoot.delete(recursive: true);
      }
      if (tmpRoot.existsSync()) {
        await tmpRoot.delete(recursive: true);
      }
    }

    for (final directory in [
      paths.repoDir,
      paths.worktreesDir,
      paths.metaDir,
      paths.codexHomeDir,
      paths.tmpDir,
    ]) {
      await directory.create(recursive: true);
    }

    await workspaceIndexDir();

    await paths.workspaceJsonFile.writeAsString(
      _encodeWorkspaceManifest(
        workspaceId: workspaceId,
        workspaceName: workspaceName,
        localPath: '${workspaceRoot.path}/',
      ),
    );

    return paths;
  }

  String _encodeWorkspaceManifest({
    required String workspaceId,
    required String workspaceName,
    required String localPath,
  }) {
    return const JsonEncoder.withIndent('  ').convert({
      'id': workspaceId,
      'name': workspaceName,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
      'localPath': localPath,
    });
  }
}
