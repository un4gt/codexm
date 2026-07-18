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
    expect(find.byIcon(Icons.chat_bubble_outline), findsNothing);
    expect(find.byIcon(Icons.extension_outlined), findsAtLeastNWidgets(1));
    expect(find.byIcon(Icons.settings_outlined), findsAtLeastNWidgets(1));
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).destinations,
      hasLength(3),
    );
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
            final l10n = AppLocalizations.of(context);
            return Column(
              children: [
                Text(l10n.navWorkspaces),
                Text(l10n.navMcpSkills),
                Text(l10n.navSettings),
              ],
            );
          },
        ),
      ),
    );

    expect(find.text('工作区'), findsOneWidget);
    expect(find.text('MCP 与技能'), findsOneWidget);
    expect(find.text('设置'), findsOneWidget);
  });

  testWidgets('keeps bottom navigation on a landscape phone', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(const CodexmFlutterApp());

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
      hasLength(3),
    );
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('three-root navigation supports phone accessibility settings', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
          disableAnimations: true,
          reduceMotion: true,
        );
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearPlatformBrightnessTestValue();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });

    await tester.pumpWidget(const CodexmFlutterApp());
    await tester.pumpAndSettle();

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations, hasLength(3));
    final labels = navigation.destinations
        .whereType<NavigationDestination>()
        .map((destination) => destination.label)
        .toList(growable: false);
    expect(labels, everyElement(isNotEmpty));
    expect(labels.toSet(), hasLength(3));
    expect(tester.takeException(), isNull);
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
