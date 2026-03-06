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

  testWidgets('hides thinking-only content when disabled', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SimpleMarkdownView(
            content: '<thinking>\n内部推理\n</thinking>',
          ),
        ),
      ),
    );

    expect(find.text('这段回复只包含思考内容，当前已隐藏。'), findsOneWidget);
    expect(find.text('内部推理'), findsNothing);
  });
}
