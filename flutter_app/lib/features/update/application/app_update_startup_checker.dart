import 'package:flutter/widgets.dart';

import '../../settings/application/codex_settings_store.dart';
import '../presentation/app_update_dialogs.dart';
import 'app_update_service.dart';

class AppUpdateStartupChecker {
  AppUpdateStartupChecker({
    AppUpdateService? updateService,
    CodexSettingsStore? settingsStore,
  }) : _updateService = updateService ?? AppUpdateService(),
       _settingsStore = settingsStore ?? CodexSettingsStore();

  final AppUpdateService _updateService;
  final CodexSettingsStore _settingsStore;

  Future<void> checkOnLaunch(BuildContext context) async {
    try {
      final settings = await _settingsStore.getSettings();
      if (!settings.updateCheckOnLaunch) {
        return;
      }

      final result = await _updateService.checkForUpdate();
      if (!context.mounted || !result.updateAvailable) {
        return;
      }

      final downloadedApk = await _updateService.downloadedApkForRelease(
        result.latestRelease,
      );
      if (!context.mounted) {
        return;
      }

      final action = await showAppUpdateAvailableDialog(
        context: context,
        result: result,
        actionLabel: downloadedApk == null ? '立即更新' : '继续安装',
      );
      if (!context.mounted || action == null) {
        return;
      }

      switch (action) {
        case AppUpdateAvailableAction.openReleasePage:
          await _updateService.openReleasePage(result.latestRelease.releaseUrl);
          break;
        case AppUpdateAvailableAction.update:
          await startAppUpdateFlow(
            context: context,
            updateService: _updateService,
            release: result.latestRelease,
          );
          break;
      }
    } catch (_) {
      // 启动时检查应保持静默，避免打断主要使用流程。
    }
  }
}
