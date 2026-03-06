import 'dart:convert';
import 'dart:io';

import '../../workspaces/application/workspace_models.dart';
import '../../workspaces/application/workspace_paths.dart';

class DebugLogStore {
  DebugLogStore({
    WorkspaceDirectoryService? workspaceDirectoryService,
  }) : _workspaceDirectoryService =
            workspaceDirectoryService ?? WorkspaceDirectoryService();

  final WorkspaceDirectoryService _workspaceDirectoryService;
  final Map<String, Future<void>> _writeQueues = <String, Future<void>>{};

  Future<void> pruneDebugLogs(
    WorkspaceId workspaceId,
    int retentionDays,
  ) async {
    if (retentionDays <= 0) {
      return;
    }
    final dir = await _logDir(workspaceId);
    if (!dir.existsSync()) {
      return;
    }
    final cutoff = DateTime.now().subtract(Duration(days: retentionDays));
    await for (final entity in dir.list()) {
      if (entity is! File) {
        continue;
      }
      final stat = await entity.stat();
      if (stat.modified.isBefore(cutoff)) {
        await entity.delete();
      }
    }
  }

  Future<void> appendDebugLog({
    required WorkspaceId workspaceId,
    required String sessionId,
    required String event,
    String? message,
    Object? details,
  }) async {
    final file = await _sessionLogFile(workspaceId, sessionId);
    final record = <String, Object?>{
      'ts': DateTime.now().toIso8601String(),
      'workspaceId': workspaceId,
      'sessionId': sessionId,
      'event': event,
      'message': _redactSecrets(message),
      'details': _safeDetails(details),
    };
    final line = '${jsonEncode(record)}\n';
    await _enqueue(
      file.path,
      () async {
        await file.parent.create(recursive: true);
        await file.writeAsString(line, mode: FileMode.append, flush: true);
      },
    );
  }

  Future<String> readSessionDebugLogTail({
    required WorkspaceId workspaceId,
    required String sessionId,
    int maxChars = 20000,
  }) async {
    final file = await _sessionLogFile(workspaceId, sessionId);
    return _readLogTail(file, maxChars);
  }

  Future<String> readLatestDebugLogTail({
    required WorkspaceId workspaceId,
    int maxChars = 20000,
  }) async {
    final dir = await _logDir(workspaceId);
    if (!dir.existsSync()) {
      return '';
    }
    File? latest;
    DateTime? latestModified;
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.log')) {
        continue;
      }
      final modified = (await entity.stat()).modified;
      if (latest == null || modified.isAfter(latestModified!)) {
        latest = entity;
        latestModified = modified;
      }
    }
    if (latest == null) {
      return '';
    }
    return _readLogTail(latest, maxChars);
  }

  Future<void> _enqueue(String key, Future<void> Function() task) async {
    final previous = _writeQueues[key] ?? Future<void>.value();
    final next = previous.then((_) => task()).catchError((_) {});
    _writeQueues[key] = next;
    await next;
    if (identical(_writeQueues[key], next)) {
      _writeQueues.remove(key);
    }
  }

  Future<Directory> _logDir(WorkspaceId workspaceId) async {
    final paths = await _workspaceDirectoryService.pathsFor(workspaceId);
    final dir = Directory('${paths.codexHomeDir.path}/logs');
    await dir.create(recursive: true);
    return dir;
  }

  Future<File> _sessionLogFile(WorkspaceId workspaceId, String sessionId) async {
    final dir = await _logDir(workspaceId);
    final safeStem = sessionId
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9._-]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return File('${dir.path}/${(safeStem.isEmpty ? 'session' : safeStem).substring(0, safeStem.length > 64 ? 64 : safeStem.length)}.log');
  }

  Future<String> _readLogTail(File file, int maxChars) async {
    if (!file.existsSync()) {
      return '';
    }
    final text = await file.readAsString();
    final cleaned = text.replaceAll('\u0000', '');
    if (cleaned.length <= maxChars) {
      return cleaned;
    }
    return cleaned.substring(cleaned.length - maxChars);
  }

  String? _safeDetails(Object? details) {
    if (details == null) {
      return null;
    }
    if (details is String) {
      return _redactSecrets(details);
    }
    if (details is Error) {
      return _redactSecrets(details.toString());
    }
    return _redactSecrets(jsonEncode(details));
  }

  String? _redactSecrets(String? text) {
    if (text == null) {
      return null;
    }
    return text
        .replaceAll(RegExp(r'sk-[a-zA-Z0-9_-]{10,}'), 'sk-***')
        .replaceAll(RegExp(r'Bearer\s+[a-zA-Z0-9._-]{10,}'), 'Bearer ***');
  }
}
