import 'session_models.dart';

class AssistantPartAccumulator {
  final _legacyTextBuffer = StringBuffer();
  var _parts = <ChatMessagePart>[];
  var _nextTextPartIndex = 0;
  String? _openTextPartId;

  String get text => _legacyTextBuffer.toString();

  List<ChatMessagePart> get parts => List.unmodifiable(_parts);

  void appendText(String value) {
    if (value.isEmpty) {
      return;
    }
    _legacyTextBuffer.write(value);

    final id = _openTextPartId ?? 'agentText:${_nextTextPartIndex++}';
    _openTextPartId = id;
    final existingIndex = _parts.indexWhere((part) => part.id == id);
    if (existingIndex == -1) {
      _parts = [
        ..._parts,
        ChatMessagePart(
          id: id,
          kind: 'agentText',
          title: '回复',
          content: value,
          status: 'completed',
        ),
      ];
      return;
    }

    final current = _parts[existingIndex];
    _parts = [
      ..._parts.take(existingIndex),
      current.copyWith(content: '${current.content}$value'),
      ..._parts.skip(existingIndex + 1),
    ];
  }

  void mergePart({
    required String? id,
    required String? kind,
    required String? title,
    required String content,
    required String? status,
  }) {
    final normalizedId = id?.trim();
    final normalizedKind = kind?.trim();
    final normalizedTitle = title?.trim();
    if (normalizedId == null ||
        normalizedId.isEmpty ||
        normalizedKind == null ||
        normalizedKind.isEmpty ||
        normalizedTitle == null ||
        normalizedTitle.isEmpty) {
      return;
    }

    _openTextPartId = null;
    final normalizedStatus = status?.trim();
    final existingIndex = _parts.indexWhere((part) => part.id == normalizedId);
    if (existingIndex == -1) {
      if (content.isEmpty && normalizedStatus != 'inProgress') {
        return;
      }
      _parts = [
        ..._parts,
        ChatMessagePart(
          id: normalizedId,
          kind: normalizedKind,
          title: normalizedTitle,
          content: content,
          status: normalizedStatus,
        ),
      ];
      return;
    }

    final current = _parts[existingIndex];
    final next = current.copyWith(
      title: normalizedTitle,
      content: '${current.content}$content',
      status: normalizedStatus?.isEmpty == true
          ? current.status
          : normalizedStatus,
    );
    _parts = [
      ..._parts.take(existingIndex),
      next,
      ..._parts.skip(existingIndex + 1),
    ];
  }
}
