import 'package:codexm_flutter/features/sessions/application/session_models.dart';
import 'package:codexm_flutter/features/sessions/presentation/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders legacy assistant runtime parts as separate sections', (
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

  testWidgets('renders ordered assistant parts without prepending content', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            role: 'assistant',
            content: '先说明再总结',
            createdAt: 1700000000000,
            showThinking: true,
            parts: [
              ChatMessagePart(
                id: 'agentText:0',
                kind: 'agentText',
                title: '回复',
                content: '先说明',
                status: 'completed',
              ),
              ChatMessagePart(
                id: 'cmd_1',
                kind: 'command',
                title: '命令执行',
                content: r'$ ls',
                status: 'completed',
              ),
              ChatMessagePart(
                id: 'agentText:1',
                kind: 'agentText',
                title: '回复',
                content: '再总结',
                status: 'completed',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('先说明再总结'), findsNothing);
    final firstTextTop = tester.getTopLeft(find.text('先说明')).dy;
    final commandTop = tester.getTopLeft(find.text('命令执行')).dy;
    final secondTextTop = tester.getTopLeft(find.text('再总结')).dy;

    expect(firstTextTop, lessThan(commandTop));
    expect(commandTop, lessThan(secondTextTop));
  });

  testWidgets('collapses completed commands and expands on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            role: 'assistant',
            content: '',
            createdAt: 1700000000000,
            showThinking: true,
            parts: [
              ChatMessagePart(
                id: 'cmd_1',
                kind: 'command',
                title: '命令执行',
                content:
                    r'$ ls'
                    '\npubspec.yaml',
                status: 'completed',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('命令执行'), findsOneWidget);
    expect(find.text(r'$ ls'), findsOneWidget);
    expect(
      find.text(
        r'$ ls'
        '\npubspec.yaml',
      ),
      findsNothing,
    );

    await tester.tap(find.text('命令执行'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        r'$ ls'
        '\npubspec.yaml',
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps in-progress tools expanded', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            role: 'assistant',
            content: '',
            createdAt: 1700000000000,
            showThinking: true,
            parts: [
              ChatMessagePart(
                id: 'tool_1',
                kind: 'toolCall',
                title: '工具调用',
                content: 'fetch docs\n等待结果',
                status: 'inProgress',
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('工具调用'), findsOneWidget);
    expect(find.textContaining('fetch docs'), findsOneWidget);
    expect(find.textContaining('等待结果'), findsOneWidget);
  });
}
