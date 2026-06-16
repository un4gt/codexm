import 'package:codexm_flutter/features/sessions/application/session_models.dart';
import 'package:codexm_flutter/features/sessions/presentation/widgets/message_bubble.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    expect(find.byKey(const ValueKey('simple-code-block')), findsOneWidget);
    expect(find.byIcon(Icons.copy_all_outlined), findsOneWidget);
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

  testWidgets(
    'uses 92 percent bubble width on compact and expanded viewports',
    (WidgetTester tester) async {
      Future<void> verifyForWidth(double width) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1.0;

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  MessageBubble(
                    key: ValueKey('user-message'),
                    role: 'user',
                    content: '用户消息',
                    createdAt: 1700000000000,
                    showThinking: true,
                  ),
                  MessageBubble(
                    key: ValueKey('assistant-message'),
                    role: 'assistant',
                    content: '```dart\nprint("hello");\n```',
                    createdAt: 1700000000000,
                    showThinking: true,
                  ),
                  MessageBubble(
                    key: ValueKey('structured-message'),
                    role: 'assistant',
                    content: '',
                    createdAt: 1700000000000,
                    showThinking: true,
                    parts: [
                      ChatMessagePart(
                        id: 'cmd_1',
                        kind: 'command',
                        title: '命令执行',
                        content: 'flutter test',
                        status: 'completed',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump();

        final expected = width * 0.92;
        expect(
          tester.getSize(find.byKey(const ValueKey('user-message-card'))).width,
          closeTo(expected, 0.5),
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('assistant-message-card')))
              .width,
          closeTo(expected, 0.5),
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('structured-message-card')))
              .width,
          closeTo(expected, 0.5),
        );
        expect(
          tester
              .getSize(find.byKey(const ValueKey('simple-code-block')).first)
              .width,
          closeTo(expected - 28, 0.5),
        );
      }

      addTearDown(() => tester.view.reset());
      await verifyForWidth(390);
      await verifyForWidth(1000);
    },
  );

  testWidgets('long press copies full message text', (
    WidgetTester tester,
  ) async {
    final clipboard = <String, Object?>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard
              ..clear()
              ..addAll(Map<String, Object?>.from(call.arguments as Map));
          }
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MessageBubble(
            role: 'user',
            content: '复制这段消息',
            createdAt: 1700000000000,
            showThinking: true,
          ),
        ),
      ),
    );

    await tester.longPress(find.byType(MessageBubble));
    await tester.pump();

    expect(clipboard['text'], '复制这段消息');
    expect(find.text('已复制到剪贴板'), findsOneWidget);
  });
}
