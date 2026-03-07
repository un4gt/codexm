import 'package:codexm_flutter/app/theme/app_theme.dart';
import 'package:codexm_flutter/features/sessions/presentation/pages/sessions_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows workspace empty state guidance', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: const SessionsPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('请先创建并激活工作区'), findsOneWidget);
    expect(find.text('前往工作区'), findsOneWidget);
  });
}
