import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codexm_flutter/app/app.dart';
import 'package:codexm_flutter/features/settings/presentation/pages/settings_page.dart';

void main() {
  testWidgets('renders Android-only navigation shell', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.reset());

    await tester.pumpWidget(const CodexmFlutterApp());

    expect(find.text('工作区'), findsAtLeastNWidgets(1));
    expect(find.text('会话'), findsAtLeastNWidgets(1));
    expect(find.text('MCP & Skills'), findsAtLeastNWidgets(1));
    expect(find.text('设置'), findsAtLeastNWidgets(1));
  });

  testWidgets('renders user-facing settings sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
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
    expect(find.text('Android Smoke 验证'), findsNothing);
    expect(find.text('配置预览'), findsNothing);
    expect(find.text('连接与模型'), findsNothing);
  });
}
