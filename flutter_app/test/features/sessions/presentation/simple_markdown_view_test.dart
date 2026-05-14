import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codexm_flutter/features/sessions/presentation/widgets/simple_markdown_view.dart';

void main() {
  testWidgets('renders fenced code blocks', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SimpleMarkdownView(
            content: '```dart\nprint("hello");\n```',
            showThinking: true,
          ),
        ),
      ),
    );

    expect(find.text('dart'), findsOneWidget);
    expect(find.text('print("hello");'), findsOneWidget);
  });

  testWidgets('hides thinking-only content when disabled', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SimpleMarkdownView(content: '<thinking>\n内部推理\n</thinking>'),
        ),
      ),
    );

    expect(find.text('这段回复只包含思考内容，当前已隐藏。'), findsOneWidget);
    expect(find.text('内部推理'), findsNothing);
  });

  testWidgets('renders unordered lists as bullet rows', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SimpleMarkdownView(
            content: '说明\n\n- 第一项\n- 运行 `flutter test`\n\n结论',
          ),
        ),
      ),
    );

    expect(find.text('说明'), findsOneWidget);
    expect(find.text('第一项'), findsOneWidget);
    expect(find.textContaining('运行'), findsOneWidget);
    expect(find.text('•'), findsNWidgets(2));
    expect(find.text('结论'), findsOneWidget);
    expect(find.text('- 第一项\n- 运行 `flutter test`'), findsNothing);
  });
}
