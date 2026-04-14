import 'dart:io';

import 'package:codexm_flutter/features/update/application/app_update_models.dart';
import 'package:codexm_flutter/features/update/application/app_update_state_store.dart';
import 'package:codexm_flutter/shared/persistence/app_directory_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('saves and restores cached release state', () async {
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

    final store = AppUpdateStateStore(
      appDirectoryService: AppDirectoryService(
        documentsResolver: () async => documentsDir,
        temporaryResolver: () async => temporaryDir,
      ),
    );

    await store.saveState(
      const AppUpdateState(
        etag: '"etag-1"',
        lastCheckedAt: 1700000000000,
        latestRelease: AppUpdateRelease(
          version: '1.2.0',
          releaseUrl: 'https://example.com/release',
          releaseNotes: '- first\n- second',
          publishedAt: '2026-04-14T12:00:00Z',
          asset: AppUpdateAsset(
            id: 42,
            name: 'codexm-1.2.0-arm64-v8a.apk',
            downloadUrl: 'https://example.com/codexm.apk',
            size: 1024,
            abi: 'arm64-v8a',
            updatedAt: '2026-04-14T12:00:00Z',
          ),
        ),
        downloadedApk: AppDownloadedApk(
          version: '1.2.0',
          fileName: 'codexm-1.2.0-arm64-v8a.apk',
          filePath: '/tmp/example.apk',
          downloadedAt: 1700000001111,
          assetKey:
              'id:42|name:codexm-1.2.0-arm64-v8a.apk|url:https://example.com/codexm.apk|size:1024|abi:arm64-v8a|updatedAt:2026-04-14T12:00:00Z',
        ),
      ),
    );

    final restored = await store.getState();
    expect(restored.etag, '"etag-1"');
    expect(restored.lastCheckedAt, 1700000000000);
    expect(restored.latestRelease?.version, '1.2.0');
    expect(restored.latestRelease?.asset?.id, 42);
    expect(restored.latestRelease?.asset?.abi, 'arm64-v8a');
    expect(restored.latestRelease?.asset?.updatedAt, '2026-04-14T12:00:00Z');
    expect(restored.downloadedApk?.filePath, '/tmp/example.apk');
    expect(
      restored.downloadedApk?.assetKey,
      'id:42|name:codexm-1.2.0-arm64-v8a.apk|url:https://example.com/codexm.apk|size:1024|abi:arm64-v8a|updatedAt:2026-04-14T12:00:00Z',
    );
  });
}
