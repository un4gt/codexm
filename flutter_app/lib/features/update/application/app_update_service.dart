import 'dart:convert';
import 'dart:io';

import 'package:codexm_native/codexm_native.dart';
import 'package:flutter/services.dart';

import '../../../shared/persistence/app_directory_service.dart';
import 'app_update_models.dart';
import 'app_update_state_store.dart';

class AppUpdateService {
  AppUpdateService({
    CodexmNative? native,
    AppDirectoryService? appDirectoryService,
    AppUpdateStateStore? stateStore,
    HttpClient? httpClient,
    Uri? latestReleaseUri,
  }) : _native = native ?? const CodexmNative(),
       _appDirectoryService = appDirectoryService ?? AppDirectoryService(),
       _stateStore =
           stateStore ??
           AppUpdateStateStore(appDirectoryService: appDirectoryService),
       _httpClient = httpClient ?? HttpClient(),
       _latestReleaseUri =
           latestReleaseUri ??
           Uri.parse('https://api.github.com/repos/un4gt/codexm/releases/latest');

  final CodexmNative _native;
  final AppDirectoryService _appDirectoryService;
  final AppUpdateStateStore _stateStore;
  final HttpClient _httpClient;
  final Uri _latestReleaseUri;

  Future<AppUpdateAppInfo> getCurrentAppInfo() {
    return _native.getAppUpdateAppInfo();
  }

  Future<AppUpdateState> getState() {
    return _stateStore.getState();
  }

  bool hasUpdate({
    required String currentVersion,
    required String remoteVersion,
  }) {
    return compareVersions(remoteVersion, currentVersion) > 0;
  }

  int compareVersions(String left, String right) {
    final leftParts = _normalizeVersionParts(left);
    final rightParts = _normalizeVersionParts(right);
    final maxLength = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var index = 0; index < maxLength; index += 1) {
      final leftPart = index < leftParts.length ? leftParts[index] : 0;
      final rightPart = index < rightParts.length ? rightParts[index] : 0;
      if (leftPart != rightPart) {
        return leftPart.compareTo(rightPart);
      }
    }
    return 0;
  }

  Future<AppUpdateCheckResult> checkForUpdate({
    bool useConditionalRequest = true,
  }) async {
    final currentApp = await getCurrentAppInfo();
    final state = await _stateStore.getState();
    final request = await _httpClient.getUrl(_latestReleaseUri);
    request.headers.set(HttpHeaders.userAgentHeader, 'CodexM-Android');
    request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final etag = state.etag?.trim();
    if (useConditionalRequest && etag?.isNotEmpty == true) {
      request.headers.set(HttpHeaders.ifNoneMatchHeader, etag!);
    }

    final response = await request.close();
    final checkedAt = DateTime.now().millisecondsSinceEpoch;
    if (response.statusCode == HttpStatus.notModified) {
      final latestRelease = state.latestRelease;
      if (latestRelease == null) {
        throw StateError('未找到可复用的更新缓存。');
      }
      await _stateStore.saveState(state.copyWith(lastCheckedAt: checkedAt));
      return AppUpdateCheckResult(
        currentApp: currentApp,
        latestRelease: latestRelease,
        updateAvailable: hasUpdate(
          currentVersion: currentApp.versionName,
          remoteVersion: latestRelease.version,
        ),
        reusedCachedRelease: true,
      );
    }

    if (response.statusCode == HttpStatus.ok) {
      final payload = await utf8.decoder.bind(response).join();
      final parsed = jsonDecode(payload);
      if (parsed is! Map) {
        throw StateError('更新接口返回了无效数据。');
      }
      final latestRelease = _parseRelease(Map<String, Object?>.from(parsed));
      await _stateStore.saveState(
        state.copyWith(
          etag: response.headers.value(HttpHeaders.etagHeader),
          lastCheckedAt: checkedAt,
          latestRelease: latestRelease,
        ),
      );
      return AppUpdateCheckResult(
        currentApp: currentApp,
        latestRelease: latestRelease,
        updateAvailable: hasUpdate(
          currentVersion: currentApp.versionName,
          remoteVersion: latestRelease.version,
        ),
        reusedCachedRelease: false,
      );
    }

    final responseBody = await utf8.decoder.bind(response).join();
    if ((response.statusCode == HttpStatus.forbidden ||
            response.statusCode == 429) &&
        state.latestRelease != null) {
      await _stateStore.saveState(state.copyWith(lastCheckedAt: checkedAt));
      final latestRelease = state.latestRelease!;
      return AppUpdateCheckResult(
        currentApp: currentApp,
        latestRelease: latestRelease,
        updateAvailable: hasUpdate(
          currentVersion: currentApp.versionName,
          remoteVersion: latestRelease.version,
        ),
        reusedCachedRelease: true,
      );
    }

    throw HttpException(
      '检查更新失败：${response.statusCode} ${responseBody.trim()}'.trim(),
      uri: _latestReleaseUri,
    );
  }

  Future<AppDownloadedApk?> downloadedApkForRelease(AppUpdateRelease release) async {
    final state = await _stateStore.getState();
    final downloadedApk = state.downloadedApk;
    if (downloadedApk == null) {
      return null;
    }
    if (!_matchesDownloadedApkRelease(downloadedApk, release)) {
      await _stateStore.saveState(state.copyWith(clearDownloadedApk: true));
      return null;
    }
    if (!File(downloadedApk.filePath).existsSync()) {
      await _stateStore.saveState(state.copyWith(clearDownloadedApk: true));
      return null;
    }
    return downloadedApk;
  }

  Future<AppDownloadedApk> downloadRelease(
    AppUpdateRelease release, {
    void Function(AppUpdateDownloadProgress progress)? onProgress,
  }) async {
    final asset = release.asset;
    if (asset == null) {
      throw StateError('当前版本未提供可直接安装的更新包。');
    }

    final updatesDir = await _appDirectoryService.updatesDir();
    await _cleanupUpdatesDirectory(updatesDir, keepFileNames: <String>{
      asset.name,
      '${asset.name}.part',
    });

    final downloadFile = File('${updatesDir.path}/${asset.name}');
    final tempFile = File('${updatesDir.path}/${asset.name}.part');
    if (downloadFile.existsSync()) {
      await downloadFile.delete();
    }
    if (tempFile.existsSync()) {
      await tempFile.delete();
    }

    final request = await _httpClient.getUrl(Uri.parse(asset.downloadUrl));
    request.headers.set(HttpHeaders.userAgentHeader, 'CodexM-Android');
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await utf8.decoder.bind(response).join();
      throw HttpException(
        '下载更新失败：${response.statusCode} ${body.trim()}'.trim(),
        uri: Uri.parse(asset.downloadUrl),
      );
    }

    await tempFile.parent.create(recursive: true);
    final sink = tempFile.openWrite();
    var bytesReceived = 0;
    final totalBytes = response.contentLength > 0 ? response.contentLength : null;
    onProgress?.call(
      AppUpdateDownloadProgress(
        bytesReceived: bytesReceived,
        totalBytes: totalBytes,
      ),
    );

    try {
      await for (final chunk in response) {
        sink.add(chunk);
        bytesReceived += chunk.length;
        onProgress?.call(
          AppUpdateDownloadProgress(
            bytesReceived: bytesReceived,
            totalBytes: totalBytes,
          ),
        );
      }
      await sink.close();
      await tempFile.rename(downloadFile.path);
      final downloadedApk = AppDownloadedApk(
        version: release.version,
        fileName: asset.name,
        filePath: downloadFile.path,
        downloadedAt: DateTime.now().millisecondsSinceEpoch,
        assetKey: asset.cacheKey,
      );
      await _stateStore.updateState(
        (current) => current.copyWith(downloadedApk: downloadedApk),
      );
      return downloadedApk;
    } catch (_) {
      await sink.close();
      if (tempFile.existsSync()) {
        await tempFile.delete();
      }
      rethrow;
    }
  }

  Future<AppUpdateInstallResult> installDownloadedApk(
    AppDownloadedApk downloadedApk,
  ) async {
    final file = File(downloadedApk.filePath);
    if (!file.existsSync()) {
      await _stateStore.updateState(
        (current) => current.copyWith(clearDownloadedApk: true),
      );
      throw StateError('更新包不存在，请重新下载。');
    }

    final hasPermission = await _native.canRequestInstallPackages();
    if (!hasPermission) {
      return AppUpdateInstallResult(
        status: AppUpdateInstallStatus.permissionRequired,
        downloadedApk: downloadedApk,
      );
    }

    try {
      await _native.installApk(apkPath: downloadedApk.filePath);
    } on PlatformException catch (error) {
      if (error.code == 'E_UPDATE_INSTALL_PERMISSION') {
        return AppUpdateInstallResult(
          status: AppUpdateInstallStatus.permissionRequired,
          downloadedApk: downloadedApk,
        );
      }
      rethrow;
    }
    return AppUpdateInstallResult(
      status: AppUpdateInstallStatus.launched,
      downloadedApk: downloadedApk,
    );
  }

  Future<void> openUnknownSourcesSettings() {
    return _native.openUnknownSourcesSettings();
  }

  Future<void> openReleasePage(String url) {
    return _native.openUrl(url: url);
  }

  AppUpdateRelease _parseRelease(Map<String, Object?> data) {
    final assets = (data['assets'] as List? ?? const <Object?>[])
        .whereType<Map>()
        .map((item) => Map<String, Object?>.from(item))
        .toList(growable: false);
    return AppUpdateRelease(
      version: _normalizeVersionString(data['tag_name']?.toString() ?? ''),
      releaseUrl: data['html_url']?.toString() ?? '',
      releaseNotes: data['body']?.toString().trim() ?? '',
      publishedAt: data['published_at']?.toString(),
      asset: _pickArm64Asset(assets),
    );
  }

  AppUpdateAsset? _pickArm64Asset(List<Map<String, Object?>> assets) {
    for (final asset in assets) {
      final name = asset['name']?.toString() ?? '';
      if (!name.endsWith('.apk') || !name.contains('arm64-v8a')) {
        continue;
      }
      return AppUpdateAsset(
        id: (asset['id'] as num?)?.toInt(),
        name: name,
        downloadUrl: asset['browser_download_url']?.toString() ?? '',
        size: (asset['size'] as num?)?.toInt() ?? 0,
        abi: 'arm64-v8a',
        updatedAt: asset['updated_at']?.toString(),
      );
    }
    return null;
  }

  bool _matchesDownloadedApkRelease(
    AppDownloadedApk downloadedApk,
    AppUpdateRelease release,
  ) {
    final asset = release.asset;
    if (asset == null) {
      return false;
    }
    if (downloadedApk.version != release.version) {
      return false;
    }
    if (downloadedApk.fileName != asset.name) {
      return false;
    }
    if (downloadedApk.assetKey != asset.cacheKey) {
      return false;
    }
    return true;
  }

  List<int> _normalizeVersionParts(String input) {
    final cleaned = _normalizeVersionString(input);
    return cleaned
        .split('.')
        .where((part) => part.trim().isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList(growable: false);
  }

  String _normalizeVersionString(String input) {
    var cleaned = input.trim();
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }
    cleaned = cleaned.split('+').first;
    cleaned = cleaned.split('-').first;
    return cleaned;
  }

  Future<void> _cleanupUpdatesDirectory(
    Directory directory, {
    required Set<String> keepFileNames,
  }) async {
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
      return;
    }
    await for (final entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      final name = entity.uri.pathSegments.isEmpty
          ? entity.path
          : entity.uri.pathSegments.last;
      if (keepFileNames.contains(name)) {
        continue;
      }
      await entity.delete();
    }
  }
}
