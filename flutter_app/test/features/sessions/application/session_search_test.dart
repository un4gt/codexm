import 'package:codexm_flutter/features/sessions/application/session_models.dart';
import 'package:codexm_flutter/features/sessions/application/session_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'searches current loaded message content and part title/content only',
    () {
      final messages = <ChatMessage>[
        const ChatMessage(
          id: 'm1',
          sessionId: 's1',
          workspaceId: 'w1',
          role: 'user',
          createdAt: 1,
          content: 'Please inspect settings',
        ),
        const ChatMessage(
          id: 'm2',
          sessionId: 's1',
          workspaceId: 'w1',
          role: 'assistant',
          createdAt: 2,
          content: '',
          parts: [
            ChatMessagePart(
              id: 'p1',
              kind: 'command',
              title: '命令执行',
              content: 'flutter test',
            ),
          ],
        ),
        const ChatMessage(
          id: 'm3',
          sessionId: 's1',
          workspaceId: 'w1',
          role: 'assistant',
          createdAt: 3,
          content: 'No match here',
        ),
      ];

      expect(
        findLocalChatSearchMessageIndexes(
          messages: messages,
          query: 'SETTINGS',
        ),
        <int>[0],
      );
      expect(
        findLocalChatSearchMessageIndexes(messages: messages, query: '命令'),
        <int>[1],
      );
      expect(
        findLocalChatSearchMessageIndexes(messages: messages, query: 'flutter'),
        <int>[1],
      );
      expect(
        findLocalChatSearchMessageIndexes(messages: messages, query: 'missing'),
        isEmpty,
      );
    },
  );

  test('does not mutate stored message objects', () {
    final messages = <ChatMessage>[
      const ChatMessage(
        id: 'm1',
        sessionId: 's1',
        workspaceId: 'w1',
        role: 'assistant',
        createdAt: 1,
        content: 'Immutable content',
        parts: [
          ChatMessagePart(
            id: 'p1',
            kind: 'agentText',
            title: '回复',
            content: 'Nested immutable content',
          ),
        ],
      ),
    ];
    final before = messages.map((message) => message.toMap()).toList();

    expect(
      findLocalChatSearchMessageIndexes(messages: messages, query: 'nested'),
      <int>[0],
    );

    expect(messages.map((message) => message.toMap()).toList(), before);
  });
}
