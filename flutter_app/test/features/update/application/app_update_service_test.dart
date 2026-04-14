import 'dart:convert';
import 'dart:io';

import 'package:codexm_flutter/features/update/application/app_update_models.dart';
import 'package:codexm_flutter/features/update/application/app_update_service.dart';
import 'package:codexm_flutter/features/update/application/app_update_state_store.dart';
import 'package:codexm_flutter/shared/persistence/app_directory_service.dart';
import 'package:codexm_native/codexm_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('checks latest release and reuses cached etag response', () async {
    final documentsDir = await Directory.systemTemp.createTemp('codexm_docs_');
    final temporaryDir = await Directory.systemTemp.createTemp('codexm_tmp_');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var latestRequestCount = 0;
    addTearDown(() async {
      await server.close(force: true);
      if (documentsDir.existsSync()) {
        await documentsDir.delete(recursive: true);
      }
      if (temporaryDir.existsSync()) {
        await temporaryDir.delete(recursive: true);
      }
    });

    server.listen((request) async {
      switch (request.uri.path) {
        case '/latest':
          latestRequestCount += 1;
          if (request.headers.value(HttpHeaders.ifNoneMatchHeader) ==
              '"release-etag"') {
            request.response.statusCode = HttpStatus.notModified;
            await request.response.close();
            return;
          }
          request.response.headers.contentType = ContentType.json;
          request.response.headers.set(HttpHeaders.etagHeader, '"release-etag"');
          request.response.write(
            jsonEncode({
              'tag_name': 'v1.2.0',
              'html_url': 'https://example.com/releases/1.2.0',
              'body': '### Changelog\n- Improved updater',
              'published_at': '2026-04-14T12:00:00Z',
              'assets': [
                {
                  'id': 11,
                  'name': 'codexm-1.2.0-arm64-v8a.apk',
                  'browser_download_url':
                      'http://127.0.0.1:${server.port}/downloads/codexm-1.2.0-arm64-v8a.apk',
                  'size': 4096,
                  'updated_at': '2026-04-14T12:00:00Z',
                },
              ],
            }),
          );
          await request.response.close();
          return;
        case '/downloads/codexm-1.2.0-arm64-v8a.apk':
          request.response.add(<int>[0, 1, 2, 3]);
          await request.response.close();
          return;
        default:
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
      }
    });

    final appDirectoryService = AppDirectoryService(
      documentsResolver: () async => documentsDir,
      temporaryResolver: () async => temporaryDir,
    );
    final stateStore = AppUpdateStateStore(
      appDirectoryService: appDirectoryService,
    );
    final service = AppUpdateService(
      native: _FakeCodexmNative(
        appInfo: const AppUpdateAppInfo(
          packageName: 'com.example.codexm',
          versionName: '1.0.0',
          versionCode: 1,
        ),
      ),
      appDirectoryService: appDirectoryService,
      stateStore: stateStore,
      httpClient: HttpClient(),
      latestReleaseUri: Uri.parse('http://127.0.0.1:${server.port}/latest'),
    );

    final first = await service.checkForUpdate();
    expect(first.updateAvailable, isTrue);
    expect(first.latestRelease.version, '1.2.0');
    expect(first.latestRelease.asset?.name, 'codexm-1.2.0-arm64-v8a.apk');
    expect(first.reusedCachedRelease, isFalse);

    final second = await service.checkForUpdate();
    expect(second.updateAvailable, isTrue);
    expect(second.reusedCachedRelease, isTrue);
    expect(latestRequestCount, 2);
    expect((await stateStore.getState()).etag, '"release-etag"');
  });

  test('downloads apk and launches installer when permission is granted', () async {
    final documentsDir = await Directory.systemTemp.createTemp('codexm_docs_');
    final temporaryDir = await Directory.systemTemp.createTemp('codexm_tmp_');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() async {
      await server.close(force: true);
      if (documentsDir.existsSync()) {
        await documentsDir.delete(recursive: true);
      }
      if (temporaryDir.existsSync()) {
        await temporaryDir.delete(recursive: true);
      }
    });

    server.listen((request) async {
      request.response.add(List<int>.generate(1024, (index) => index % 255));
      await request.response.close();
    });

    final appDirectoryService = AppDirectoryService(
      documentsResolver: () async => documentsDir,
      temporaryResolver: () async => temporaryDir,
    );
    final fakeNative = _FakeCodexmNative(
      appInfo: const AppUpdateAppInfo(
        packageName: 'com.example.codexm',
        versionName: '1.0.0',
        versionCode: 1,
      ),
      canInstallPackages: true,
    );
    final service = AppUpdateService(
      native: fakeNative,
      appDirectoryService: appDirectoryService,
      stateStore: AppUpdateStateStore(appDirectoryService: appDirectoryService),
      httpClient: HttpClient(),
      latestReleaseUri: Uri.parse('http://127.0.0.1:${server.port}/latest'),
    );

    final progressEvents = <AppUpdateDownloadProgress>[];
    final release = AppUpdateRelease(
      version: '1.2.0',
      releaseUrl: 'https://example.com/releases/1.2.0',
      releaseNotes: 'Bug fixes',
      asset: AppUpdateAsset(
        id: 22,
        name: 'codexm-1.2.0-arm64-v8a.apk',
        downloadUrl:
            'http://127.0.0.1:${server.port}/codexm-1.2.0-arm64-v8a.apk',
        size: 1024,
        abi: 'arm64-v8a',
        updatedAt: '2026-04-14T12:00:00Z',
      ),
    );

    final downloadedApk = await service.downloadRelease(
      release,
      onProgress: progressEvents.add,
    );
    expect(File(downloadedApk.filePath).existsSync(), isTrue);
    expect(progressEvents, isNotEmpty);

    final installResult = await service.installDownloadedApk(downloadedApk);
    expect(installResult.status, AppUpdateInstallStatus.launched);
    expect(fakeNative.installedApkPaths, [downloadedApk.filePath]);
    expect(
      downloadedApk.assetKey,
      release.asset!.cacheKey,
    );
  });

  test('invalidates cached apk when release asset changes under same version',
      () async {
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
    final stateStore = AppUpdateStateStore(
      appDirectoryService: appDirectoryService,
    );
    final updatesDir = await appDirectoryService.updatesDir();
    final cachedApkFile = File('${updatesDir.path}/codexm-1.2.0-arm64-v8a.apk');
    await cachedApkFile.parent.create(recursive: true);
    await cachedApkFile.writeAsBytes(<int>[0, 1, 2, 3]);

    await stateStore.saveState(
      AppUpdateState(
        downloadedApk: AppDownloadedApk(
          version: '1.2.0',
          fileName: 'codexm-1.2.0-arm64-v8a.apk',
          filePath: cachedApkFile.path,
          downloadedAt: 1700000001111,
          assetKey:
              'id:11|name:codexm-1.2.0-arm64-v8a.apk|url:https://example.com/old.apk|size:4096|abi:arm64-v8a|updatedAt:2026-04-14T12:00:00Z',
        ),
      ),
    );

    final service = AppUpdateService(
      native: _FakeCodexmNative(
        appInfo: const AppUpdateAppInfo(
          packageName: 'com.example.codexm',
          versionName: '1.0.0',
          versionCode: 1,
        ),
      ),
      appDirectoryService: appDirectoryService,
      stateStore: stateStore,
      httpClient: HttpClient(),
    );

    final release = AppUpdateRelease(
      version: '1.2.0',
      releaseUrl: 'https://example.com/releases/1.2.0',
      releaseNotes: 'Bug fixes',
      asset: AppUpdateAsset(
        id: 22,
        name: 'codexm-1.2.0-arm64-v8a.apk',
        downloadUrl: 'https://example.com/new.apk',
        size: 4096,
        abi: 'arm64-v8a',
        updatedAt: '2026-04-15T12:00:00Z',
      ),
    );

    expect(await service.downloadedApkForRelease(release), isNull);
    expect((await stateStore.getState()).downloadedApk, isNull);
  });
}

class _FakeCodexmNative extends CodexmNative {
  _FakeCodexmNative({
    required this.appInfo,
    this.canInstallPackages = true,
  });

  final AppUpdateAppInfo appInfo;
  final bool canInstallPackages;
  final List<String> installedApkPaths = <String>[];
  final List<String> openedUrls = <String>[];
  int openUnknownSourcesCount = 0;

  @override
  Future<AppUpdateAppInfo> getAppUpdateAppInfo() async {
    return appInfo;
  }

  @override
  Future<bool> canRequestInstallPackages() async {
    return canInstallPackages;
  }

  @override
  Future<void> installApk({required String apkPath}) async {
    installedApkPaths.add(apkPath);
  }

  @override
  Future<void> openUnknownSourcesSettings() async {
    openUnknownSourcesCount += 1;
  }

  @override
  Future<void> openUrl({required String url}) async {
    openedUrls.add(url);
  }
}
