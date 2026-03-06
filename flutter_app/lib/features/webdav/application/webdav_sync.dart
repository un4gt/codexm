import 'dart:io';

import 'webdav_client.dart';
import 'webdav_types.dart';

class WebDavSyncService {
  const WebDavSyncService();

  Future<void> pull({
    required WebDavClient client,
    required String remoteRootDir,
    required String localRootDirPath,
    void Function(WebDavSyncProgress progress)? onProgress,
  }) async {
    final remoteTree = await _listRemoteTree(
      client,
      remoteRootDir,
      onProgress: onProgress,
    );

    final dirs = remoteTree.dirs.toList()..sort();
    for (var index = 0; index < dirs.length; index += 1) {
      final relDir = dirs[index];
      onProgress?.call(
        WebDavSyncProgress(
          phase: 'mkdir-local',
          current: index + 1,
          total: dirs.length,
          path: relDir,
        ),
      );
      await Directory('$localRootDirPath/$relDir').create(recursive: true);
    }

    final entries = remoteTree.files.entries.toList();
    for (var index = 0; index < entries.length; index += 1) {
      final entry = entries[index];
      onProgress?.call(
        WebDavSyncProgress(
          phase: 'download',
          current: index + 1,
          total: entries.length,
          path: entry.key,
        ),
      );
      final localFile = File('$localRootDirPath/${entry.key}');
      await localFile.parent.create(recursive: true);
      await client.downloadToFile('${remoteTree.root}${entry.key}', localFile.path);
    }

    onProgress?.call(const WebDavSyncProgress(phase: 'done'));
  }

  Future<void> push({
    required WebDavClient client,
    required String remoteRootDir,
    required String localRootDirPath,
    void Function(WebDavSyncProgress progress)? onProgress,
  }) async {
    final localTree = await _listLocalTree(localRootDirPath, onProgress: onProgress);
    final remoteTree = await _listRemoteTree(
      client,
      remoteRootDir,
      onProgress: onProgress,
    );

    final dirs = localTree.dirs.toList()..sort();
    for (var index = 0; index < dirs.length; index += 1) {
      final relDir = dirs[index];
      onProgress?.call(
        WebDavSyncProgress(
          phase: 'mkdir-remote',
          current: index + 1,
          total: dirs.length,
          path: relDir,
        ),
      );
      await client.mkcol('${remoteTree.root}$relDir/');
    }

    final entries = localTree.files.entries.toList();
    for (var index = 0; index < entries.length; index += 1) {
      final entry = entries[index];
      onProgress?.call(
        WebDavSyncProgress(
          phase: 'upload',
          current: index + 1,
          total: entries.length,
          path: entry.key,
        ),
      );
      await client.uploadFile('${remoteTree.root}${entry.key}', entry.value.path);
    }

    onProgress?.call(const WebDavSyncProgress(phase: 'done'));
  }

  Future<_LocalTree> _listLocalTree(
    String rootDirPath, {
    void Function(WebDavSyncProgress progress)? onProgress,
  }) async {
    onProgress?.call(const WebDavSyncProgress(phase: 'list-local'));
    final root = Directory(rootDirPath);
    final files = <String, File>{};
    final dirs = <String>{};

    Future<void> walk(Directory dir, String relPrefix) async {
      await for (final entity in dir.list()) {
        final pathSegments = entity.uri.pathSegments
            .where((segment) => segment.isNotEmpty)
            .toList(growable: false);
        final name = pathSegments.isNotEmpty
            ? pathSegments.last
            : entity.path.split(Platform.pathSeparator).last;
        final rel = relPrefix.isEmpty ? name : '$relPrefix/$name';
        if (_shouldExclude(rel)) {
          continue;
        }
        if (entity is Directory) {
          dirs.add(rel);
          await walk(entity, rel);
        } else if (entity is File) {
          files[rel] = entity;
        }
      }
    }

    await walk(root, '');
    return _LocalTree(files: files, dirs: dirs);
  }

  Future<_RemoteTree> _listRemoteTree(
    WebDavClient client,
    String remoteRootDir, {
    void Function(WebDavSyncProgress progress)? onProgress,
  }) async {
    final root = _normalizeRemoteDir(remoteRootDir);
    final rootNoSlash = root.replaceAll(RegExp(r'/$'), '');
    final files = <String, WebDavEntry>{};
    final dirs = <String>{};

    onProgress?.call(const WebDavSyncProgress(phase: 'list-remote'));

    Future<void> walk(String dir) async {
      final currentDir = dir.replaceAll(RegExp(r'/$'), '');
      final entries = await client.propfind(dir, depth: '1');
      for (final entry in entries) {
        final full = entry.path.replaceAll(RegExp(r'/$'), '');
        if (full == currentDir) {
          continue;
        }
        if (rootNoSlash.isNotEmpty && full == rootNoSlash) {
          continue;
        }
        if (rootNoSlash.isEmpty && full.isEmpty) {
          continue;
        }
        var rel = full;
        if (rootNoSlash.isNotEmpty && full.startsWith('$rootNoSlash/')) {
          rel = full.substring(rootNoSlash.length + 1);
        }
        if (rel.isEmpty || _shouldExclude(rel)) {
          continue;
        }
        if (entry.isCollection) {
          dirs.add(rel);
          await walk('$full/');
        } else {
          files[rel] = entry;
        }
      }
    }

    await walk(root);
    return _RemoteTree(files: files, dirs: dirs, root: root);
  }

  String _normalizeRemoteDir(String path) {
    var value = path.trim();
    value = value.replaceAll(RegExp(r'^/+'), '');
    if (value.isNotEmpty && !value.endsWith('/')) {
      value = '$value/';
    }
    return value;
  }

  bool _shouldExclude(String relPath) {
    const excludeDirs = <String>{'.git', 'node_modules', '.expo', 'dist', 'build'};
    final parts = relPath.split('/').where((part) => part.isNotEmpty);
    return parts.any(excludeDirs.contains);
  }
}

class _LocalTree {
  const _LocalTree({
    required this.files,
    required this.dirs,
  });

  final Map<String, File> files;
  final Set<String> dirs;
}

class _RemoteTree {
  const _RemoteTree({
    required this.files,
    required this.dirs,
    required this.root,
  });

  final Map<String, WebDavEntry> files;
  final Set<String> dirs;
  final String root;
}
