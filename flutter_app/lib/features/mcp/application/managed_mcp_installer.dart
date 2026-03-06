import 'dart:io';

import 'package:codexm_native/codexm_native.dart';

import '../../../shared/persistence/app_directory_service.dart';

class ManagedMcpInstallResult {
  const ManagedMcpInstallResult({
    required this.execPath,
  });

  final String execPath;
}

class ManagedMcpInstaller {
  ManagedMcpInstaller({
    AppDirectoryService? appDirectoryService,
    CodexmNative? native,
    HttpClient? httpClient,
  })  : _appDirectoryService = appDirectoryService ?? AppDirectoryService(),
        _native = native ?? const CodexmNative(),
        _httpClient = httpClient ?? HttpClient();

  final AppDirectoryService _appDirectoryService;
  final CodexmNative _native;
  final HttpClient _httpClient;

  Future<String> installsRootPath() async {
    final mcpDir = await _appDirectoryService.mcpDir();
    final root = Directory('${mcpDir.path}/installs');
    await root.create(recursive: true);
    return root.path;
  }

  Future<String> managedExecPath(String serverId) async {
    final root = await installsRootPath();
    return '$root/$serverId/server';
  }

  Future<bool> isManagedInstalled(String serverId) async {
    return File(await managedExecPath(serverId)).existsSync();
  }

  Future<void> uninstallManagedMcp(String serverId) async {
    final root = Directory('${await installsRootPath()}/$serverId');
    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
  }

  Future<ManagedMcpInstallResult> installManagedMcpFromUrl({
    required String serverId,
    required String url,
  }) async {
    final trimmedUrl = url.trim();
    if (trimmedUrl.isEmpty) {
      throw ArgumentError('URL 不能为空。');
    }

    final root = Directory('${await installsRootPath()}/$serverId');
    final extractDir = Directory('${root.path}/extract');
    final downloadFile = File('${root.path}/download');
    final execFile = File('${root.path}/server');

    if (root.existsSync()) {
      await root.delete(recursive: true);
    }
    await extractDir.create(recursive: true);

    await _downloadToFile(trimmedUrl, downloadFile);

    final lower = trimmedUrl.toLowerCase();
    if (lower.endsWith('.tar.gz') || lower.endsWith('.tgz')) {
      await _native.extractTarGz(
        archivePath: downloadFile.path,
        destDir: extractDir.path,
      );
      final candidate = await _pickBestExecutableCandidate(extractDir);
      await candidate.copy(execFile.path);
    } else {
      await downloadFile.copy(execFile.path);
    }

    await _native.chmodPath(execFile.path);
    if (extractDir.existsSync()) {
      await extractDir.delete(recursive: true);
    }
    if (downloadFile.existsSync()) {
      await downloadFile.delete();
    }
    return ManagedMcpInstallResult(execPath: execFile.path);
  }

  Future<void> _downloadToFile(String url, File file) async {
    final request = await _httpClient.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('下载 MCP 安装包失败：${response.statusCode}');
    }
    await file.parent.create(recursive: true);
    await response.pipe(file.openWrite());
  }

  Future<File> _pickBestExecutableCandidate(Directory extractDir) async {
    final files = <File>[];
    await for (final entity in extractDir.list(recursive: true)) {
      if (entity is File) {
        files.add(entity);
      }
    }
    if (files.isEmpty) {
      throw StateError('安装包为空，未找到可执行文件。');
    }
    files.sort((left, right) => right.lengthSync().compareTo(left.lengthSync()));
    return files.first;
  }
}
