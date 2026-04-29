import '../../workspaces/application/workspace_models.dart';

typedef SessionId = String;

class Session {
  const Session({
    required this.id,
    required this.workspaceId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.codexThreadId,
    this.codexCollaborationMode,
  });

  final SessionId id;
  final WorkspaceId workspaceId;
  final String title;
  final int createdAt;
  final int updatedAt;
  final String? codexThreadId;
  final String? codexCollaborationMode;

  Session copyWith({
    String? title,
    int? createdAt,
    int? updatedAt,
    String? codexThreadId,
    String? codexCollaborationMode,
    bool clearThreadId = false,
    bool clearCollaborationMode = false,
  }) {
    return Session(
      id: id,
      workspaceId: workspaceId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      codexThreadId: clearThreadId
          ? null
          : (codexThreadId ?? this.codexThreadId),
      codexCollaborationMode: clearCollaborationMode
          ? null
          : (codexCollaborationMode ?? this.codexCollaborationMode),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'workspaceId': workspaceId,
      'title': title,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'codexThreadId': codexThreadId,
      'codexCollaborationMode': codexCollaborationMode,
    };
  }

  factory Session.fromMap(Map<String, Object?> map) {
    return Session(
      id: map['id']?.toString() ?? '',
      workspaceId: map['workspaceId']?.toString() ?? '',
      title: map['title']?.toString() ?? '新会话',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      updatedAt: (map['updatedAt'] as num?)?.toInt() ?? 0,
      codexThreadId: map['codexThreadId']?.toString(),
      codexCollaborationMode: map['codexCollaborationMode']?.toString(),
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sessionId,
    required this.workspaceId,
    required this.role,
    required this.createdAt,
    required this.content,
    this.parts = const <ChatMessagePart>[],
  });

  final String id;
  final SessionId sessionId;
  final WorkspaceId workspaceId;
  final String role;
  final int createdAt;
  final String content;
  final List<ChatMessagePart> parts;

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'sessionId': sessionId,
      'workspaceId': workspaceId,
      'role': role,
      'createdAt': createdAt,
      'content': content,
      if (parts.isNotEmpty)
        'parts': parts.map((part) => part.toMap()).toList(growable: false),
    };
  }

  factory ChatMessage.fromMap(Map<String, Object?> map) {
    final rawParts = map['parts'];
    return ChatMessage(
      id: map['id']?.toString() ?? '',
      sessionId: map['sessionId']?.toString() ?? '',
      workspaceId: map['workspaceId']?.toString() ?? '',
      role: map['role']?.toString() ?? 'user',
      createdAt: (map['createdAt'] as num?)?.toInt() ?? 0,
      content: map['content']?.toString() ?? '',
      parts: rawParts is List
          ? rawParts
                .whereType<Map>()
                .map(
                  (part) =>
                      ChatMessagePart.fromMap(Map<String, Object?>.from(part)),
                )
                .toList(growable: false)
          : const <ChatMessagePart>[],
    );
  }
}

class ChatMessagePart {
  const ChatMessagePart({
    required this.id,
    required this.kind,
    required this.title,
    required this.content,
    this.status,
  });

  final String id;
  final String kind;
  final String title;
  final String content;
  final String? status;

  ChatMessagePart copyWith({String? title, String? content, String? status}) {
    return ChatMessagePart(
      id: id,
      kind: kind,
      title: title ?? this.title,
      content: content ?? this.content,
      status: status ?? this.status,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'kind': kind,
      'title': title,
      'content': content,
      if (status != null) 'status': status,
    };
  }

  factory ChatMessagePart.fromMap(Map<String, Object?> map) {
    return ChatMessagePart(
      id: map['id']?.toString() ?? '',
      kind: map['kind']?.toString() ?? 'event',
      title: map['title']?.toString() ?? '运行信息',
      content: map['content']?.toString() ?? '',
      status: map['status']?.toString(),
    );
  }
}
