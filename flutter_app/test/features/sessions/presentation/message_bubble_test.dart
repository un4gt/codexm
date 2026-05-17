import 'package:codexm_flutter/features/sessions/application/session_models.dart';
import 'package:codexm_flutter/features/sessions/presentation/widgets/message_bubble.dart';
import 'package:codexm_flutter/l10n/app_localizations.dart';
import 'package:codexm_flutter/shared/widgets/codex_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:codexm_flutter/app/theme/app_theme.dart';

Widget _testApp(Widget child) {
  return MaterialApp(
    theme: buildAppTheme(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('renders legacy assistant runtime parts as separate sections', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const MessageBubble(
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
      _testApp(
        const MessageBubble(
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
      _testApp(
        const MessageBubble(
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
      _testApp(
        const MessageBubble(
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
    );

    expect(find.text('工具调用'), findsOneWidget);
    expect(find.textContaining('fetch docs'), findsOneWidget);
    expect(find.textContaining('等待结果'), findsOneWidget);
  });

  testWidgets('uses timeline defaults for reasoning, failed, and plan parts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const MessageBubble(
          role: 'assistant',
          content: '',
          createdAt: 1700000000000,
          showThinking: true,
          parts: [
            ChatMessagePart(
              id: 'reasoning_1',
              kind: 'reasoning',
              title: '思考过程',
              content: '隐藏的推理摘要',
              status: 'completed',
            ),
            ChatMessagePart(
              id: 'cmd_1',
              kind: 'command',
              title: '命令执行',
              content: 'exit 1\n错误摘要',
              status: 'failed',
            ),
            ChatMessagePart(
              id: 'plan_1',
              kind: 'plan',
              title: '计划',
              content: '1. 检查\n2. 修复',
              status: 'completed',
            ),
          ],
        ),
      ),
    );

    expect(find.text('思考过程'), findsOneWidget);
    expect(find.text('隐藏的推理摘要'), findsOneWidget);
    expect(find.textContaining('错误摘要'), findsOneWidget);
    expect(find.textContaining('2. 修复'), findsNothing);

    await tester.tap(find.text('计划'));
    await tester.pumpAndSettle();

    expect(find.textContaining('2. 修复'), findsOneWidget);
  });

  testWidgets('CodexStatusChip exposes text, icon or spinner, and semantics', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const Wrap(
          children: [
            CodexStatusChip(label: '完成', tone: CodexStatusTone.success),
            CodexStatusChip(label: '失败', tone: CodexStatusTone.error),
            CodexStatusChip(label: '进行中', tone: CodexStatusTone.running),
          ],
        ),
      ),
    );

    expect(find.text('完成'), findsOneWidget);
    expect(find.text('失败'), findsOneWidget);
    expect(find.text('进行中'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(
      find.byKey(const ValueKey('codex-status-running-spinner')),
      findsOneWidget,
    );

    final semantics = tester.getSemantics(find.text('完成'));
    expect(semantics.label, contains('完成'));
  });
}
