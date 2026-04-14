import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codexm_flutter/app/app.dart';
import 'package:codexm_flutter/features/settings/presentation/pages/settings_page.dart';

void main() {
  testWidgets('renders Android-only navigation shell', (WidgetTester tester) async {
    await tester.pumpWidget(const CodexmFlutterApp());

    expect(find.text('工作区'), findsAtLeastNWidgets(1));
    expect(find.text('会话'), findsAtLeastNWidgets(1));
    expect(find.text('MCP'), findsAtLeastNWidgets(1));
    expect(find.text('设置'), findsAtLeastNWidgets(1));
  });

  testWidgets('renders user-facing settings sections', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();
    
    expect(find.text('应用更新'), findsOneWidget);
    expect(find.text('连接设置'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('交互偏好'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('交互偏好'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('全局 Skills'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('全局 Skills'), findsOneWidget);
    expect(find.text('Android Smoke 验证'), findsNothing);
    expect(find.text('配置预览'), findsNothing);
    expect(find.text('连接与模型'), findsNothing);
  });
}
