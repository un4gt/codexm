import 'package:codexm_flutter/features/sessions/application/session_models.dart';
import 'package:codexm_flutter/features/sessions/presentation/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders assistant runtime parts as separate sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            role: 'assistant',
            content: '最终回复',
            createdAt: 1700000000000,
            showThinking: true,
            parts: [
              ChatMessagePart(
                id: 'reasoning_1',
                kind: 'reasoning',
                title: '思考过程',
                content: '先检查现状。',
                status: 'completed',
              ),
              ChatMessagePart(
                id: 'cmd_1',
                kind: 'command',
                title: '命令执行',
                content: r'$ ls\npubspec.yaml',
                status: 'completed',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('回复'), findsOneWidget);
    expect(find.text('最终回复'), findsOneWidget);
    expect(find.text('思考过程'), findsOneWidget);
    expect(find.text('先检查现状。'), findsOneWidget);
    expect(find.text('命令执行'), findsOneWidget);
    expect(find.text(r'$ ls\npubspec.yaml'), findsOneWidget);
  });
}
