import 'dart:async';
import 'dart:io';

import 'package:codexm_flutter/features/codex/application/codex_models.dart';
import 'package:codexm_flutter/features/codex/application/codex_session_runner.dart';
import 'package:codexm_flutter/features/codex/application/session_turn_coordinator.dart';
import 'package:codexm_flutter/features/sessions/application/session_code_workspace_service.dart';
import 'package:codexm_flutter/features/sessions/application/session_models.dart';
import 'package:codexm_flutter/features/sessions/application/session_store.dart';
import 'package:codexm_flutter/features/settings/application/codex_settings_store.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_models.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_paths.dart';
import 'package:codexm_flutter/shared/persistence/app_directory_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory documents;
  late Directory temporary;
  late SessionStore sessionStore;
  late Workspace workspace;
  late Session session;

  setUp(() async {
    documents = await Directory.systemTemp.createTemp('codexm_turn_docs_');
    temporary = await Directory.systemTemp.createTemp('codexm_turn_tmp_');
    final directories = WorkspaceDirectoryService(
      appDirectoryService: AppDirectoryService(
        documentsResolver: () async => documents,
        temporaryResolver: () async => temporary,
      ),
    );
    sessionStore = SessionStore(workspaceDirectoryService: directories);
    workspace = Workspace(
      id: 'workspace-1',
      name: '演示工作区',
      createdAt: 1,
      localPath: '${documents.path}/workspace-1/',
      integrationBranch: 'main',
      sessionGitVersion: 1,
    );
    session = await sessionStore.createSession(
      workspace.id,
      title: '演示会话',
      branchName: 'codexm/session/session-1',
      codeState: SessionCodeState.ready,
    );
  });

  tearDown(() async {
    await documents.delete(recursive: true);
    await temporary.delete(recursive: true);
  });

  test('owns persistence and rejects a second concurrent turn', () async {
    final runner = _ControlledRunner();
    final coordinator = SessionTurnCoordinator(
      sessionStore: sessionStore,
      codeWorkspaceService: _ReadyCodeWorkspaceService(),
      settingsStore: _ReadySettingsStore(),
      runner: runner,
    );
    addTearDown(coordinator.dispose);
    final started = Completer<ActiveTurnSnapshot>();
    final run = coordinator.runTurn(
      _request(workspace, session),
      onStarted: started.complete,
    );
    await started.future;

    expect(coordinator.activeTurn?.sessionId, session.id);
    expect(
      () => coordinator.runTurn(_request(workspace, session)),
      throwsA(isA<TurnBusyException>()),
    );

    runner.complete();
    final result = await run;
    expect(result.cancelled, isFalse);
    expect(result.status, '完成');
    final messages = await sessionStore.listMessages(workspace.id, session.id);
    expect(messages.map((message) => message.role), ['user', 'assistant']);
    expect(messages.first.content, '你好');
    expect(messages.last.content, '回复内容');
    expect(coordinator.activeTurn, isNull);
  });

  test('cancels the runner and persists partial output', () async {
    final runner = _ControlledRunner();
    final coordinator = SessionTurnCoordinator(
      sessionStore: sessionStore,
      codeWorkspaceService: _ReadyCodeWorkspaceService(),
      settingsStore: _ReadySettingsStore(),
      runner: runner,
    );
    addTearDown(coordinator.dispose);
    final started = Completer<ActiveTurnSnapshot>();
    final run = coordinator.runTurn(
      _request(workspace, session),
      onStarted: started.complete,
    );
    final snapshot = await started.future;

    await coordinator.cancelActiveTurn(turnId: snapshot.turnId);
    final result = await run;

    expect(result.cancelled, isTrue);
    expect(runner.cancelCalled, isTrue);
    final messages = await sessionStore.listMessages(workspace.id, session.id);
    expect(messages.map((message) => message.role), [
      'user',
      'assistant',
      'system',
    ]);
    expect(messages[1].content, '回复内容');
    expect(messages.last.content, contains('本轮已停止'));
  });
}

CoordinatedTurnRequest _request(Workspace workspace, Session session) {
  return CoordinatedTurnRequest(
    workspace: workspace,
    session: session,
    origin: TurnOrigin.web,
    pendingStatus: '运行中',
    successStatus: '完成',
    userMessage: '你好',
    input: const <CodexInputElement>[
      <String, Object?>{'type': 'text', 'text': '你好'},
    ],
  );
}

class _ReadySettingsStore extends CodexSettingsStore {
  @override
  Future<CodexSettings> getSettings() async => const CodexSettings();

  @override
  Future<String?> getCodexApiKey() async => 'test-key';
}

class _ReadyCodeWorkspaceService extends SessionCodeWorkspaceService {
  @override
  Future<Session> ensureSessionWorktree(
    Workspace workspace,
    Session session,
  ) async => session;
}

class _ControlledRunner extends CodexSessionRunner {
  final Completer<void> _gate = Completer<void>();
  bool cancelCalled = false;

  void complete() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<void> cancelActiveRuns() async {
    cancelCalled = true;
    complete();
  }

  @override
  Stream<CodexTurnEvent> run({
    required Workspace workspace,
    required SessionId sessionId,
    Object? input,
    CodexTurnKind kind = CodexTurnKind.turn,
    Object? reviewTarget,
    CodexCollaborationMode? collaborationMode,
    List<CodexRpcCall>? rpcCalls,
  }) async* {
    yield const CodexTurnEvent.text('回复内容');
    await _gate.future;
    yield const CodexTurnEvent.done();
  }
}
