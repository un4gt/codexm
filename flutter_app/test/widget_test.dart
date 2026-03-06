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

  testWidgets('renders smoke entry on settings page', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsPage()));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('全局 Skills'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('全局 Skills'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Android Smoke 验证'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Android Smoke 验证'), findsOneWidget);
  });
}
