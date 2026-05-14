import 'package:codexm_flutter/features/sessions/application/assistant_part_accumulator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps assistant text and runtime parts in arrival order', () {
    final accumulator = AssistantPartAccumulator()
      ..appendText('先说明')
      ..mergePart(
        id: 'cmd_1',
        kind: 'command',
        title: '命令执行',
        content: r'$ ls',
        status: 'inProgress',
      )
      ..mergePart(
        id: 'cmd_1',
        kind: 'command',
        title: '命令执行',
        content: '\npubspec.yaml',
        status: 'completed',
      )
      ..appendText('再总结');

    expect(accumulator.text, '先说明再总结');
    expect(accumulator.parts.map((part) => part.kind), <String>[
      'agentText',
      'command',
      'agentText',
    ]);
    expect(accumulator.parts[0].content, '先说明');
    expect(
      accumulator.parts[1].content,
      r'$ ls'
      '\npubspec.yaml',
    );
    expect(accumulator.parts[1].status, 'completed');
    expect(accumulator.parts[2].content, '再总结');
  });

  test('updates existing runtime part without moving it to the end', () {
    final accumulator = AssistantPartAccumulator()
      ..mergePart(
        id: 'tool_1',
        kind: 'toolCall',
        title: '工具调用',
        content: '开始',
        status: 'inProgress',
      )
      ..appendText('中间回复')
      ..mergePart(
        id: 'tool_1',
        kind: 'toolCall',
        title: '工具调用',
        content: '\n结束',
        status: 'completed',
      );

    expect(accumulator.parts.map((part) => part.id), <String>[
      'tool_1',
      'agentText:0',
    ]);
    expect(accumulator.parts.first.content, '开始\n结束');
    expect(accumulator.parts.first.status, 'completed');
  });
}
