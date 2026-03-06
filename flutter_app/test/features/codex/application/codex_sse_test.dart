import 'dart:convert';

import 'package:codexm_flutter/features/codex/application/codex_models.dart';
import 'package:codexm_flutter/features/codex/application/codex_sse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses SSE text and done events', () async {
    final events = await readSse(
      Stream<List<int>>.fromIterable(
        <List<int>>[
          utf8.encode('data: {"text":"hello"}\n\n'),
          utf8.encode('data: [DONE]\n\n'),
        ],
      ),
    ).toList();

    expect(events.first.type, CodexStreamEventType.text);
    expect(events.first.text, 'hello');
    expect(events.last.type, CodexStreamEventType.done);
  });
}
