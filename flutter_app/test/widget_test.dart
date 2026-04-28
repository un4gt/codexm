import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codexm_flutter/app/app.dart';
import 'package:codexm_flutter/features/settings/presentation/pages/settings_page.dart';
import 'package:codexm_flutter/l10n/app_localizations.dart';

void main() {
  testWidgets('renders Android-only navigation shell', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.localeTestValue = const Locale('zh');
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearLocaleTestValue();
    });

    await tester.pumpWidget(const CodexmFlutterApp());

    expect(find.byIcon(Icons.folder), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.chat_bubble_outline), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.extension_outlined), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.settings_outlined), findsAtLeastNWidgets(1));
  });

  testWidgets('generated localizations follow the system locale', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.localeTestValue = const Locale.fromSubtags(
      languageCode: 'zh',
      scriptCode: 'Hans',
    );
    tester.platformDispatcher.localesTestValue = const [
      Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
    ];
    addTearDown(() {
      tester.platformDispatcher.clearLocaleTestValue();
      tester.platformDispatcher.clearLocalesTestValue();
    });

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return Text(AppLocalizations.of(context).navSessions);
          },
        ),
      ),
    );

    expect(find.text('会话'), findsOneWidget);
  });

  testWidgets('renders user-facing settings sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('应用更新'), findsOneWidget);
    expect(find.text('连接'), findsOneWidget);
    expect(find.text('设置状态'), findsNothing);
    expect(find.text('默认模型'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('生效预览'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('生效预览'), findsOneWidget);
    expect(find.text('附加配置'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('交互偏好'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('交互偏好'), findsOneWidget);
    expect(find.text('应用语言'), findsOneWidget);
    expect(find.text('跟随系统'), findsOneWidget);
    expect(find.text('Android Smoke 验证'), findsNothing);
    expect(find.text('配置预览'), findsNothing);
    expect(find.text('连接与模型'), findsNothing);
  });
}
