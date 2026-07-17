import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codexm_flutter/app/app.dart';
import 'package:codexm_flutter/app/theme/app_theme.dart';
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

  testWidgets('keeps bottom navigation on a landscape phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(const CodexmFlutterApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('settings support dark mode and large text on a small phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(
      MaterialApp(
        theme: buildDarkAppTheme(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          );
        },
        locale: const Locale.fromSubtags(
          languageCode: 'zh',
          scriptCode: 'Hans',
        ),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SettingsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('设置'), findsOneWidget);
    expect(find.text('连接与模型'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a settings list with focused detail pages', (
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
    expect(find.text('连接与模型'), findsOneWidget);
    expect(find.text('设置状态'), findsNothing);
    expect(find.text('默认'), findsOneWidget);
    expect(find.text('交互偏好'), findsOneWidget);
    expect(find.text('外观'), findsOneWidget);
    expect(find.text('高级配置'), findsOneWidget);

    await tester.tap(find.text('连接与模型'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('返回设置'), findsOneWidget);
    expect(find.text('API Key'), findsAtLeastNWidgets(1));
    expect(find.text('Base URL（可选）'), findsAtLeastNWidgets(1));
    expect(find.text('应用更新'), findsNothing);

    await tester.tap(find.byTooltip('返回设置'));
    await tester.pumpAndSettle();
    expect(find.text('应用更新'), findsOneWidget);
  });
}
