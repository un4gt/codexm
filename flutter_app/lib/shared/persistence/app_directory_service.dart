import 'dart:io';

import 'package:path_provider/path_provider.dart';

typedef DirectoryResolver = Future<Directory> Function();

/// Shared directory roots for Flutter-side persistence.
class AppDirectoryService {
  AppDirectoryService({
    DirectoryResolver? documentsResolver,
    DirectoryResolver? temporaryResolver,
  })  : _documentsResolver =
            documentsResolver ?? getApplicationDocumentsDirectory,
        _temporaryResolver = temporaryResolver ?? getTemporaryDirectory;

  final DirectoryResolver _documentsResolver;
  final DirectoryResolver _temporaryResolver;

  Future<Directory> documentsDir() => _documentsResolver();

  Future<Directory> temporaryDir() => _temporaryResolver();

  Future<Directory> settingsDir() => ensureDocumentsSubdir('settings');

  Future<Directory> codexHomeDir() => ensureDocumentsSubdir('codex-home');

  Future<Directory> mcpDir() => ensureDocumentsSubdir('mcp');

  Future<Directory> workspacesDir() => ensureDocumentsSubdir('workspaces');

  Future<Directory> ensureDocumentsSubdir(String name) async {
    final root = await documentsDir();
    final dir = Directory('${root.path}/$name');
    await dir.create(recursive: true);
    return dir;
  }

  Future<Directory> ensureTemporarySubdir(String name) async {
    final root = await temporaryDir();
    final dir = Directory('${root.path}/$name');
    await dir.create(recursive: true);
    return dir;
  }
}
