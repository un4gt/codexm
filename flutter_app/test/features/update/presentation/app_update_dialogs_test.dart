import 'package:codexm_flutter/features/update/application/app_update_models.dart';
import 'package:codexm_flutter/features/update/presentation/app_update_dialogs.dart';
import 'package:codexm_native/codexm_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('returns the selected dialog action for release page',
      (WidgetTester tester) async {
    late BuildContext context;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final dialogFuture = showAppUpdateAvailableDialog(
      context: context,
      result: AppUpdateCheckResult(
        currentApp: const AppUpdateAppInfo(
          packageName: 'com.example.codexm',
          versionName: '1.0.0',
          versionCode: 1,
        ),
        latestRelease: AppUpdateRelease(
          version: '1.2.0',
          releaseUrl: 'https://example.com/releases/1.2.0',
          releaseNotes: 'Bug fixes',
          asset: AppUpdateAsset(
            name: 'codexm-1.2.0-arm64-v8a.apk',
            downloadUrl: 'https://example.com/codexm.apk',
            size: 1024,
            abi: 'arm64-v8a',
          ),
        ),
        updateAvailable: true,
        reusedCachedRelease: false,
      ),
      actionLabel: '立即更新',
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('查看发布页'));
    await tester.pumpAndSettle();

    expect(
      await dialogFuture,
      AppUpdateAvailableAction.openReleasePage,
    );
  });
}
