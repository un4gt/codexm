import 'package:codexm_flutter/features/settings/application/codex_settings_store.dart';
import 'package:codexm_flutter/features/update/application/app_update_models.dart';
import 'package:codexm_flutter/features/update/application/app_update_service.dart';
import 'package:codexm_flutter/features/update/presentation/update_page.dart';
import 'package:codexm_native/codexm_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('disables update settings toggle until initial snapshot loads',
      (WidgetTester tester) async {
    final settingsStore = _MemoryCodexSettingsStore(
      settings: const CodexSettings(
        authRef: 'auth-1',
        model: 'gpt-test',
        updateCheckOnLaunch: true,
      ),
      getSettingsDelay: const Duration(milliseconds: 100),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UpdatePage(
          updateService: _FakeAppUpdateService(),
          settingsStore: settingsStore,
        ),
      ),
    );

    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(switchTile.onChanged, isNull);
    expect(settingsStore.updateSettingsCalls, 0);
    expect(settingsStore.saveSettingsCalls, 0);

    await tester.pumpAndSettle();

    final loadedSwitchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    expect(loadedSwitchTile.onChanged, isNotNull);
  });

  testWidgets('updates only the launch-check preference after snapshot loads',
      (WidgetTester tester) async {
    final settingsStore = _MemoryCodexSettingsStore(
      settings: const CodexSettings(
        authRef: 'auth-1',
        model: 'gpt-test',
        openaiBaseUrl: 'https://example.com',
        updateCheckOnLaunch: true,
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UpdatePage(
          updateService: _FakeAppUpdateService(),
          settingsStore: settingsStore,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final switchTile = tester.widget<SwitchListTile>(
      find.byType(SwitchListTile),
    );
    switchTile.onChanged!(false);
    await tester.pump();
    await tester.pumpAndSettle();

    expect(settingsStore.updateSettingsCalls, 1);
    expect(settingsStore.saveSettingsCalls, 1);
    expect(settingsStore.settings.updateCheckOnLaunch, isFalse);
    expect(settingsStore.settings.authRef, 'auth-1');
    expect(settingsStore.settings.model, 'gpt-test');
    expect(settingsStore.settings.openaiBaseUrl, 'https://example.com');
  });
}

class _MemoryCodexSettingsStore extends CodexSettingsStore {
  _MemoryCodexSettingsStore({
    required this.settings,
    this.getSettingsDelay = Duration.zero,
  });

  CodexSettings settings;
  final Duration getSettingsDelay;
  int saveSettingsCalls = 0;
  int updateSettingsCalls = 0;

  @override
  Future<CodexSettings> getSettings() async {
    if (getSettingsDelay > Duration.zero) {
      await Future<void>.delayed(getSettingsDelay);
    }
    return settings;
  }

  @override
  Future<CodexSettings> saveSettings(CodexSettings nextSettings) async {
    saveSettingsCalls += 1;
    settings = nextSettings;
    return settings;
  }

  @override
  Future<CodexSettings> updateSettings(
    CodexSettings Function(CodexSettings current) update,
  ) async {
    updateSettingsCalls += 1;
    return saveSettings(update(settings));
  }
}

class _FakeAppUpdateService extends AppUpdateService {
  final AppUpdateAppInfo currentApp = const AppUpdateAppInfo(
    packageName: 'com.example.codexm',
    versionName: '1.0.0',
    versionCode: 1,
  );
  final AppUpdateState state = const AppUpdateState();

  @override
  Future<AppUpdateAppInfo> getCurrentAppInfo() async {
    return currentApp;
  }

  @override
  Future<AppUpdateState> getState() async {
    return state;
  }

  @override
  Future<AppDownloadedApk?> downloadedApkForRelease(
    AppUpdateRelease release,
  ) async {
    return null;
  }
}
