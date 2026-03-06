import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../workspaces/application/workspace_models.dart';
import '../../workspaces/application/workspace_paths.dart';
import 'session_models.dart';

class SessionStore {
  SessionStore({
    WorkspaceDirectoryService? workspaceDirectoryService,
    Uuid? uuid,
  }) : _workspaceDirectoryService =
           workspaceDirectoryService ?? WorkspaceDirectoryService(),
       _uuid = uuid ?? const Uuid();

  final WorkspaceDirectoryService _workspaceDirectoryService;
  final Uuid _uuid;

  Future<List<Session>> listSessions(WorkspaceId workspaceId) async {
    final index = await _readIndex(workspaceId);
    final sessions = [...index.sessions];
    sessions.sort((left, right) {
      final updatedCompare = right.updatedAt.compareTo(left.updatedAt);
      if (updatedCompare != 0) {
        return updatedCompare;
      }
      return right.createdAt.compareTo(left.createdAt);
    });
    return sessions;
  }

  Future<Session?> getSession(
    WorkspaceId workspaceId,
    SessionId sessionId,
  ) async {
    final sessions = await listSessions(workspaceId);
    for (final session in sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  Future<Session?> getPrimarySession(WorkspaceId workspaceId) async {
    final sessions = await listSessions(workspaceId);
    return sessions.isEmpty ? null : sessions.first;
  }

  Future<Session> ensurePrimarySession(
    WorkspaceId workspaceId, {
    String? title,
  }) async {
    final existing = await getPrimarySession(workspaceId);
    if (existing != null) {
      return existing;
    }
    return createSession(workspaceId, title: title);
  }

  Future<Session> createSession(
    WorkspaceId workspaceId, {
    String? title,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final session = Session(
      id: _uuid.v4(),
      workspaceId: workspaceId,
      title: title?.trim().isNotEmpty == true ? title!.trim() : '新会话',
      createdAt: now,
      updatedAt: now,
    );

    final index = await _readIndex(workspaceId);
    await _writeIndex(
      workspaceId,
      _SessionsIndex(version: 2, sessions: [session, ...index.sessions]),
    );
    await _writeMessagesFile(workspaceId, session.id, const <ChatMessage>[]);
    return session;
  }

  Future<void> cloneSessionMessages(
    WorkspaceId workspaceId,
    SessionId fromSessionId,
    SessionId toSessionId,
  ) async {
    final source = await _messagesFile(workspaceId, fromSessionId);
    final target = await _messagesFile(workspaceId, toSessionId);
    if (!source.existsSync()) {
      await _writeMessagesFile(workspaceId, toSessionId, const <ChatMessage>[]);
      return;
    }
    await target.writeAsString(await source.readAsString());
  }

  Future<void> renameSession(
    WorkspaceId workspaceId,
    SessionId sessionId,
    String title,
  ) async {
    final index = await _readIndex(workspaceId);
    final next = index.sessions
        .map(
          (session) => session.id == sessionId
              ? session.copyWith(
                  title: title.trim().isEmpty ? session.title : title.trim(),
                  updatedAt: DateTime.now().millisecondsSinceEpoch,
                )
              : session,
        )
        .toList(growable: false);
    await _writeIndex(workspaceId, _SessionsIndex(version: 2, sessions: next));
  }

  Future<void> setSessionCodexThreadId(
    WorkspaceId workspaceId,
    SessionId sessionId,
    String? threadId,
  ) async {
    await _updateSession(
      workspaceId,
      sessionId,
      (session) => session.copyWith(
        codexThreadId: threadId,
        clearThreadId: threadId == null || threadId.isEmpty,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> setSessionCodexCollaborationMode(
    WorkspaceId workspaceId,
    SessionId sessionId,
    String? mode,
  ) async {
    await _updateSession(
      workspaceId,
      sessionId,
      (session) => session.copyWith(
        codexCollaborationMode: mode,
        clearCollaborationMode: mode == null || mode.isEmpty,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> deleteSession(
    WorkspaceId workspaceId,
    SessionId sessionId,
  ) async {
    final index = await _readIndex(workspaceId);
    final next = index.sessions
        .where((session) => session.id != sessionId)
        .toList(growable: false);
    await _writeIndex(workspaceId, _SessionsIndex(version: 2, sessions: next));
    final file = await _messagesFile(workspaceId, sessionId);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  Future<List<ChatMessage>> listMessages(
    WorkspaceId workspaceId,
    SessionId sessionId,
  ) async {
    final file = await _messagesFile(workspaceId, sessionId);
    if (!file.existsSync()) {
      return const <ChatMessage>[];
    }
    final parsed = jsonDecode(await file.readAsString());
    if (parsed is! Map) {
      return const <ChatMessage>[];
    }
    final messages = (parsed['messages'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => ChatMessage.fromMap(Map<String, Object?>.from(item)))
        .toList(growable: false);
    return messages;
  }

  Future<ChatMessage> appendMessage(
    WorkspaceId workspaceId,
    SessionId sessionId, {
    required String role,
    required String content,
    int? createdAt,
  }) async {
    final all = await listMessages(workspaceId, sessionId);
    final message = ChatMessage(
      id: _uuid.v4(),
      sessionId: sessionId,
      workspaceId: workspaceId,
      role: role,
      createdAt: createdAt ?? DateTime.now().millisecondsSinceEpoch,
      content: content,
    );
    await _writeMessagesFile(workspaceId, sessionId, [...all, message]);
    await _updateSession(
      workspaceId,
      sessionId,
      (session) =>
          session.copyWith(updatedAt: DateTime.now().millisecondsSinceEpoch),
    );
    return message;
  }

  Future<void> _updateSession(
    WorkspaceId workspaceId,
    SessionId sessionId,
    Session Function(Session session) transform,
  ) async {
    final index = await _readIndex(workspaceId);
    final next = index.sessions
        .map(
          (session) => session.id == sessionId ? transform(session) : session,
        )
        .toList(growable: false);
    await _writeIndex(workspaceId, _SessionsIndex(version: 2, sessions: next));
  }

  Future<_SessionsIndex> _readIndex(WorkspaceId workspaceId) async {
    final file = await _indexFile(workspaceId);
    if (!file.existsSync()) {
      return const _SessionsIndex(version: 2, sessions: <Session>[]);
    }
    final parsed = jsonDecode(await file.readAsString());
    if (parsed is! Map) {
      return const _SessionsIndex(version: 2, sessions: <Session>[]);
    }
    final version = (parsed['version'] as num?)?.toInt() ?? 1;
    final rawSessions = (parsed['sessions'] as List? ?? const []);
    final sessions = rawSessions
        .whereType<Map>()
        .map((item) => Session.fromMap(Map<String, Object?>.from(item)))
        .toList(growable: false);
    return _SessionsIndex(version: version == 2 ? 2 : 2, sessions: sessions);
  }

  Future<void> _writeIndex(
    WorkspaceId workspaceId,
    _SessionsIndex index,
  ) async {
    final file = await _indexFile(workspaceId);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(index.toMap()),
    );
  }

  Future<File> _indexFile(WorkspaceId workspaceId) async {
    final dir = await _sessionsDir(workspaceId);
    return File('${dir.path}/index.json');
  }

  Future<File> _messagesFile(
    WorkspaceId workspaceId,
    SessionId sessionId,
  ) async {
    final dir = await _sessionsDir(workspaceId);
    return File('${dir.path}/$sessionId.json');
  }

  Future<Directory> _sessionsDir(WorkspaceId workspaceId) async {
    final paths = await _workspaceDirectoryService.pathsFor(workspaceId);
    final dir = Directory('${paths.metaDir.path}/sessions');
    await dir.create(recursive: true);
    return dir;
  }

  Future<void> _writeMessagesFile(
    WorkspaceId workspaceId,
    SessionId sessionId,
    List<ChatMessage> messages,
  ) async {
    final file = await _messagesFile(workspaceId, sessionId);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'messages': messages.map((message) => message.toMap()).toList(),
      }),
    );
  }
}

class _SessionsIndex {
  const _SessionsIndex({required this.version, required this.sessions});

  final int version;
  final List<Session> sessions;

  Map<String, Object?> toMap() {
    return {
      'version': version,
      'sessions': sessions.map((session) => session.toMap()).toList(),
    };
  }
}
