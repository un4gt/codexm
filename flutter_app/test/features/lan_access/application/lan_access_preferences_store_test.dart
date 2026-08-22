import 'dart:io';

import 'package:codexm_flutter/features/lan_access/application/lan_access_models.dart';
import 'package:codexm_flutter/features/lan_access/application/lan_access_preferences_store.dart';
import 'package:codexm_flutter/shared/persistence/app_directory_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists enabled state and a validated listening port', () async {
    final documents = await Directory.systemTemp.createTemp('codexm_lan_docs_');
    final temporary = await Directory.systemTemp.createTemp('codexm_lan_tmp_');
    addTearDown(() async {
      await documents.delete(recursive: true);
      await temporary.delete(recursive: true);
    });
    final store = LanAccessPreferencesStore(
      appDirectoryService: AppDirectoryService(
        documentsResolver: () async => documents,
        temporaryResolver: () async => temporary,
      ),
    );

    expect(await store.load(), isA<LanAccessPreferences>());
    await store.save(const LanAccessPreferences(enabled: true, port: 9123));

    final restored = await store.load();
    expect(restored.enabled, isTrue);
    expect(restored.port, 9123);
    expect(
      () => store.save(const LanAccessPreferences(port: 80)),
      throwsArgumentError,
    );
  });
}
