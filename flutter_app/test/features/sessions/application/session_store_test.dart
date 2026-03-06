import 'dart:io';

import 'package:codexm_flutter/features/sessions/application/debug_log_store.dart';
import 'package:codexm_flutter/features/sessions/application/session_store.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_paths.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_store.dart';
import 'package:codexm_flutter/shared/persistence/app_directory_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('persists sessions, messages and redacted debug logs', () async {
    final documentsDir = await Directory.systemTemp.createTemp('codexm_docs_');
    final temporaryDir = await Directory.systemTemp.createTemp('codexm_tmp_');
    addTearDown(() async {
      if (documentsDir.existsSync()) {
        await documentsDir.delete(recursive: true);
      }
      if (temporaryDir.existsSync()) {
        await temporaryDir.delete(recursive: true);
      }
    });

    final appDirectoryService = AppDirectoryService(
      documentsResolver: () async => documentsDir,
      temporaryResolver: () async => temporaryDir,
    );
    final workspaceDirectoryService = WorkspaceDirectoryService(
      appDirectoryService: appDirectoryService,
    );
    final workspaceStore = WorkspaceStore(
      appDirectoryService: appDirectoryService,
      workspaceDirectoryService: workspaceDirectoryService,
    );
    final sessionStore = SessionStore(
      workspaceDirectoryService: workspaceDirectoryService,
    );
    final debugLogStore = DebugLogStore(
      workspaceDirectoryService: workspaceDirectoryService,
    );

    final workspace = await workspaceStore.createWorkspace(name: 'Session Workspace');
    final session = await sessionStore.createSession(
      workspace.id,
      title: 'Demo Session',
    );

    await sessionStore.appendMessage(
      workspace.id,
      session.id,
      role: 'user',
      content: 'hello',
    );
    await sessionStore.appendMessage(
      workspace.id,
      session.id,
      role: 'assistant',
      content: 'world',
    );
    await sessionStore.renameSession(workspace.id, session.id, 'Renamed Session');
    await sessionStore.setSessionCodexThreadId(
      workspace.id,
      session.id,
      'thread_123',
    );
    await debugLogStore.appendDebugLog(
      workspaceId: workspace.id,
      sessionId: session.id,
      event: 'turn.done',
      message: 'Bearer abcdefghijklmnop',
      details: 'sk-test-1234567890',
    );

    final sessions = await sessionStore.listSessions(workspace.id);
    final messages = await sessionStore.listMessages(workspace.id, session.id);
    final logTail = await debugLogStore.readSessionDebugLogTail(
      workspaceId: workspace.id,
      sessionId: session.id,
    );

    expect(sessions, hasLength(1));
    expect(sessions.first.title, 'Renamed Session');
    expect(sessions.first.codexThreadId, 'thread_123');
    expect(messages, hasLength(2));
    expect(messages.last.content, 'world');
    expect(logTail, contains('Bearer ***'));
    expect(logTail, contains('sk-***'));
  });

  test('ensures primary session and keeps latest session first', () async {
    final documentsDir = await Directory.systemTemp.createTemp('codexm_docs_');
    final temporaryDir = await Directory.systemTemp.createTemp('codexm_tmp_');
    addTearDown(() async {
      if (documentsDir.existsSync()) {
        await documentsDir.delete(recursive: true);
      }
      if (temporaryDir.existsSync()) {
        await temporaryDir.delete(recursive: true);
      }
    });

    final appDirectoryService = AppDirectoryService(
      documentsResolver: () async => documentsDir,
      temporaryResolver: () async => temporaryDir,
    );
    final workspaceDirectoryService = WorkspaceDirectoryService(
      appDirectoryService: appDirectoryService,
    );
    final workspaceStore = WorkspaceStore(
      appDirectoryService: appDirectoryService,
      workspaceDirectoryService: workspaceDirectoryService,
    );
    final sessionStore = SessionStore(
      workspaceDirectoryService: workspaceDirectoryService,
    );

    final workspace = await workspaceStore.createWorkspace(name: 'Primary Session');
    final created = await sessionStore.ensurePrimarySession(workspace.id);
    expect(created.title, '新会话');

    await Future<void>.delayed(const Duration(milliseconds: 2));
    final second = await sessionStore.createSession(
      workspace.id,
      title: 'Secondary',
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await sessionStore.setSessionCodexThreadId(
      workspace.id,
      created.id,
      'thread_latest',
    );

    final sessions = await sessionStore.listSessions(workspace.id);
    final primary = await sessionStore.getPrimarySession(workspace.id);
    final ensuredAgain = await sessionStore.ensurePrimarySession(workspace.id);

    expect(sessions, hasLength(2));
    expect(sessions.first.id, created.id);
    expect(sessions.last.id, second.id);
    expect(primary?.id, created.id);
    expect(ensuredAgain.id, created.id);
  });
}
