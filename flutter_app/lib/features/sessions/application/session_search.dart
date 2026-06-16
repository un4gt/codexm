import 'session_models.dart';

List<int> findLocalChatSearchMessageIndexes({
  required List<ChatMessage> messages,
  required String query,
}) {
  final normalizedQuery = query.trim().toLowerCase();
  if (normalizedQuery.isEmpty) {
    return const <int>[];
  }

  final matches = <int>[];
  for (var index = 0; index < messages.length; index += 1) {
    final message = messages[index];
    if (message.content.toLowerCase().contains(normalizedQuery)) {
      matches.add(index);
      continue;
    }
    final partMatched = message.parts.any((part) {
      return part.title.toLowerCase().contains(normalizedQuery) ||
          part.content.toLowerCase().contains(normalizedQuery);
    });
    if (partMatched) {
      matches.add(index);
    }
  }
  return matches;
}
