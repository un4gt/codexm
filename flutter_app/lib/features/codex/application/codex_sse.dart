import 'dart:convert';

import 'codex_models.dart';

Stream<CodexStreamEvent> readSse(Stream<List<int>> stream) async* {
  final decoder = utf8.decoder.bind(stream);
  var buffer = '';

  await for (final chunk in decoder) {
    buffer += chunk.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    var separatorIndex = buffer.indexOf('\n\n');
    while (separatorIndex >= 0) {
      final rawEvent = buffer.substring(0, separatorIndex);
      buffer = buffer.substring(separatorIndex + 2);
      final event = _parseSseEvent(rawEvent);
      if (event == null) {
        separatorIndex = buffer.indexOf('\n\n');
        continue;
      }
      yield event;
      if (event.type == CodexStreamEventType.done) {
        return;
      }
      separatorIndex = buffer.indexOf('\n\n');
    }
  }

  if (buffer.trim().isNotEmpty) {
    final event = _parseSseEvent(buffer);
    if (event != null) {
      yield event;
      if (event.type == CodexStreamEventType.done) {
        return;
      }
    }
  }

  yield const CodexStreamEvent.done();
}

CodexStreamEvent? _parseSseEvent(String rawEvent) {
  final lines = rawEvent.split('\n');
  final dataLines = <String>[];
  for (final line in lines) {
    if (line.startsWith('data:')) {
      dataLines.add(line.substring(5).trimLeft());
    }
  }

  final data = dataLines.join('\n');
  if (data.isEmpty) {
    return null;
  }
  if (data == '[DONE]') {
    return const CodexStreamEvent.done();
  }

  try {
    final parsed = jsonDecode(data);
    if (parsed is Map && parsed['text'] is String) {
      return CodexStreamEvent.text(parsed['text'].toString());
    }
  } catch (_) {
    // Fall through.
  }
  return CodexStreamEvent.text(data);
}
