import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../shared/persistence/app_directory_service.dart';
import 'workspace_models.dart';
import 'workspace_paths.dart';

class WorkspaceStore {
  WorkspaceStore({
    AppDirectoryService? appDirectoryService,
    WorkspaceDirectoryService? workspaceDirectoryService,
    Uuid? uuid,
  }) : _appDirectoryService = appDirectoryService ?? AppDirectoryService(),
       _workspaceDirectoryService =
           workspaceDirectoryService ?? WorkspaceDirectoryService(),
       _uuid = uuid ?? const Uuid();

  final AppDirectoryService _appDirectoryService;
  final WorkspaceDirectoryService _workspaceDirectoryService;
  final Uuid _uuid;

  Future<List<Workspace>> listWorkspaces() async {
    final index = await _readIndex();
    return index.workspaces;
  }

  Future<Workspace?> getWorkspace(WorkspaceId id) async {
    final all = await listWorkspaces();
    for (final workspace in all) {
      if (workspace.id == id) {
        return workspace;
      }
    }
    return null;
  }

  Future<WorkspaceId?> getActiveWorkspaceId() async {
    final file = await _activeFile();
    if (!file.existsSync()) {
      return null;
    }
    final raw = await file.readAsString();
    final parsed = jsonDecode(raw);
    if (parsed is Map) {
      return parsed['id']?.toString();
    }
    return null;
  }

  Future<Workspace?> getActiveWorkspace() async {
    final activeId = await getActiveWorkspaceId();
    if (activeId == null) {
      return null;
    }
    return getWorkspace(activeId);
  }

  Future<void> setActiveWorkspaceId(WorkspaceId? id) async {
    final file = await _activeFile();
    if (id == null || id.trim().isEmpty) {
      if (file.existsSync()) {
        await file.delete();
      }
      return;
    }
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({'id': id}),
    );
  }

  Future<Workspace> createWorkspace({
    required String name,
    WorkspaceGitConfig? git,
    WorkspaceWebDavConfig? webdav,
  }) async {
    final id = _uuid.v4();
    final paths = await _workspaceDirectoryService.prepareWorkspace(
      workspaceId: id,
      workspaceName: name,
      reset: false,
    );

    final workspace = Workspace(
      id: id,
      name: name.trim().isEmpty ? '新工作区' : name.trim(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
      localPath: '${paths.workspaceRoot.path}/',
      git: git,
      webdav: webdav,
    );

    await upsertWorkspace(workspace);
    await _writeWorkspaceManifest(workspace);
    return workspace;
  }

  Future<void> upsertWorkspace(Workspace workspace) async {
    final index = await _readIndex();
    final next = <Workspace>[];
    var replaced = false;
    for (final current in index.workspaces) {
      if (current.id == workspace.id) {
        next.add(workspace);
        replaced = true;
      } else {
        next.add(current);
      }
    }
    if (!replaced) {
      next.insert(0, workspace);
    }
    await _writeIndex(_WorkspaceIndex(version: 1, workspaces: next));
    await _writeWorkspaceManifest(workspace);
  }

  Future<void> removeWorkspace(WorkspaceId id) async {
    final index = await _readIndex();
    final next = index.workspaces
        .where((workspace) => workspace.id != id)
        .toList();
    await _writeIndex(_WorkspaceIndex(version: 1, workspaces: next));

    final activeId = await getActiveWorkspaceId();
    if (activeId == id) {
      await setActiveWorkspaceId(null);
    }

    final paths = await _workspaceDirectoryService.pathsFor(id);
    if (paths.workspaceRoot.existsSync()) {
      await paths.workspaceRoot.delete(recursive: true);
    }
    final tempRoot = paths.tmpDir.parent.parent;
    if (tempRoot.existsSync()) {
      await tempRoot.delete(recursive: true);
    }
  }

  Future<void> _writeWorkspaceManifest(Workspace workspace) async {
    final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
    await paths.metaDir.create(recursive: true);
    await paths.workspaceJsonFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(workspace.toMap()),
    );
  }

  Future<_WorkspaceIndex> _readIndex() async {
    final file = await _indexFile();
    if (!file.existsSync()) {
      return const _WorkspaceIndex(version: 1, workspaces: <Workspace>[]);
    }
    final raw = await file.readAsString();
    final parsed = jsonDecode(raw);
    if (parsed is! Map) {
      return const _WorkspaceIndex(version: 1, workspaces: <Workspace>[]);
    }
    final rawWorkspaces = parsed['workspaces'] as List? ?? const [];
    return _WorkspaceIndex(
      version: (parsed['version'] as num?)?.toInt() ?? 1,
      workspaces: rawWorkspaces
          .whereType<Map>()
          .map((item) => Workspace.fromMap(Map<String, Object?>.from(item)))
          .toList(growable: false),
    );
  }

  Future<void> _writeIndex(_WorkspaceIndex index) async {
    final file = await _indexFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(index.toMap()),
    );
  }

  Future<File> _indexFile() async {
    final workspacesDir = await _appDirectoryService.workspacesDir();
    final indexDir = Directory('${workspacesDir.path}/.index');
    await indexDir.create(recursive: true);
    return File('${indexDir.path}/workspaces.json');
  }

  Future<File> _activeFile() async {
    final workspacesDir = await _appDirectoryService.workspacesDir();
    final indexDir = Directory('${workspacesDir.path}/.index');
    await indexDir.create(recursive: true);
    return File('${indexDir.path}/active.json');
  }
}

class _WorkspaceIndex {
  const _WorkspaceIndex({required this.version, required this.workspaces});

  final int version;
  final List<Workspace> workspaces;

  Map<String, Object?> toMap() {
    return {
      'version': version,
      'workspaces': workspaces.map((workspace) => workspace.toMap()).toList(),
    };
  }
}
