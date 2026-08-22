import 'dart:async';

import 'package:uuid/uuid.dart';

import '../../sessions/application/assistant_part_accumulator.dart';
import '../../sessions/application/session_code_workspace_service.dart';
import '../../sessions/application/session_models.dart';
import '../../sessions/application/session_store.dart';
import '../../settings/application/codex_settings_store.dart';
import '../../workspaces/application/workspace_models.dart';
import '../../workspaces/application/workspace_store.dart';
import 'codex_models.dart';
import 'codex_session_runner.dart';

enum TurnOrigin { mobile, web }

enum CoordinatedTurnPhase { running, stopping }

class TurnBusyException implements Exception {
  const TurnBusyException(this.activeTurn);

  final ActiveTurnSnapshot? activeTurn;

  @override
  String toString() => '当前已有 Codex 会话正在运行。';
}

class CoordinatedTurnRequest {
  const CoordinatedTurnRequest({
    required this.workspace,
    required this.session,
    required this.origin,
    required this.pendingStatus,
    required this.successStatus,
    this.userMessage,
    this.input,
    this.kind = CodexTurnKind.turn,
    this.rpcCalls,
    this.collaborationMode,
  });

  final Workspace workspace;
  final Session session;
  final TurnOrigin origin;
  final String pendingStatus;
  final String successStatus;
  final String? userMessage;
  final Object? input;
  final CodexTurnKind kind;
  final List<CodexRpcCall>? rpcCalls;
  final CodexCollaborationMode? collaborationMode;
}

class CoordinatedTurnResult {
  const CoordinatedTurnResult({
    required this.status,
    required this.cancelled,
    this.errorMessage,
  });

  final String status;
  final bool cancelled;
  final String? errorMessage;
}

class ActiveTurnSnapshot {
  const ActiveTurnSnapshot({
    required this.turnId,
    required this.workspaceId,
    required this.workspaceName,
    required this.sessionId,
    required this.sessionTitle,
    required this.origin,
    required this.startedAt,
    required this.phase,
    required this.pendingStatus,
    required this.assistantText,
    required this.assistantParts,
    this.runtimeStatus,
    this.runtimeStatusIsRetrying = false,
  });

  final String turnId;
  final WorkspaceId workspaceId;
  final String workspaceName;
  final SessionId sessionId;
  final String sessionTitle;
  final TurnOrigin origin;
  final int startedAt;
  final CoordinatedTurnPhase phase;
  final String pendingStatus;
  final String assistantText;
  final List<ChatMessagePart> assistantParts;
  final String? runtimeStatus;
  final bool runtimeStatusIsRetrying;

  ActiveTurnSnapshot copyWith({
    CoordinatedTurnPhase? phase,
    String? pendingStatus,
    String? assistantText,
    List<ChatMessagePart>? assistantParts,
    String? runtimeStatus,
    bool? runtimeStatusIsRetrying,
    bool clearRuntimeStatus = false,
  }) {
    return ActiveTurnSnapshot(
      turnId: turnId,
      workspaceId: workspaceId,
      workspaceName: workspaceName,
      sessionId: sessionId,
      sessionTitle: sessionTitle,
      origin: origin,
      startedAt: startedAt,
      phase: phase ?? this.phase,
      pendingStatus: pendingStatus ?? this.pendingStatus,
      assistantText: assistantText ?? this.assistantText,
      assistantParts: assistantParts ?? this.assistantParts,
      runtimeStatus: clearRuntimeStatus
          ? null
          : (runtimeStatus ?? this.runtimeStatus),
      runtimeStatusIsRetrying:
          runtimeStatusIsRetrying ?? this.runtimeStatusIsRetrying,
    );
  }

  Map<String, Object?> toPublicMap() {
    return <String, Object?>{
      'turnId': turnId,
      'workspaceId': workspaceId,
      'workspaceName': workspaceName,
      'sessionId': sessionId,
      'sessionTitle': sessionTitle,
      'origin': origin.name,
      'startedAt': startedAt,
      'phase': phase.name,
      'pendingStatus': pendingStatus,
      'assistantText': assistantText,
      'assistantParts': assistantParts
          .map((part) => part.toMap())
          .toList(growable: false),
      'runtimeStatus': runtimeStatus,
      'runtimeStatusIsRetrying': runtimeStatusIsRetrying,
    };
  }
}

class SessionTurnCoordinator {
  SessionTurnCoordinator({
    WorkspaceStore? workspaceStore,
    SessionStore? sessionStore,
    SessionCodeWorkspaceService? codeWorkspaceService,
    CodexSettingsStore? settingsStore,
    CodexSessionRunner? runner,
    Uuid? uuid,
    DateTime Function()? now,
  }) : _workspaceStore = workspaceStore ?? WorkspaceStore(),
       _sessionStore = sessionStore ?? SessionStore(),
       _codeWorkspaceService =
           codeWorkspaceService ?? SessionCodeWorkspaceService(),
       _settingsStore = settingsStore ?? CodexSettingsStore(),
       _runner = runner ?? CodexSessionRunner(),
       _uuid = uuid ?? const Uuid(),
       _now = now ?? DateTime.now;

  final WorkspaceStore _workspaceStore;
  final SessionStore _sessionStore;
  final SessionCodeWorkspaceService _codeWorkspaceService;
  final CodexSettingsStore _settingsStore;
  final CodexSessionRunner _runner;
  final Uuid _uuid;
  final DateTime Function() _now;
  final StreamController<ActiveTurnSnapshot?> _states =
      StreamController<ActiveTurnSnapshot?>.broadcast(sync: true);

  ActiveTurnSnapshot? _activeTurn;
  Completer<void>? _cancelSignal;
  Completer<void>? _finishedSignal;
  bool _operationInProgress = false;

  ActiveTurnSnapshot? get activeTurn => _activeTurn;

  Stream<ActiveTurnSnapshot?> get states => _states.stream;

  Future<Session> createSession({
    required WorkspaceId workspaceId,
    required String title,
  }) async {
    return _runExclusiveOperation(() async {
      final workspace = await _workspaceStore.getWorkspace(workspaceId);
      if (workspace == null) {
        throw StateError('工作区不存在。');
      }
      return _codeWorkspaceService.createSession(
        workspace,
        title: title.trim().isEmpty ? '新会话' : title.trim(),
      );
    });
  }

  Future<void> renameSession({
    required WorkspaceId workspaceId,
    required SessionId sessionId,
    required String title,
  }) async {
    await _runExclusiveOperation(() async {
      final normalized = title.trim();
      if (normalized.isEmpty) {
        throw ArgumentError.value(title, 'title', '会话名称不能为空。');
      }
      await _sessionStore.renameSession(workspaceId, sessionId, normalized);
    });
  }

  Future<void> setSessionMode({
    required WorkspaceId workspaceId,
    required SessionId sessionId,
    required CodexCollaborationMode mode,
  }) async {
    await _runExclusiveOperation(() async {
      await _sessionStore.setSessionCodexCollaborationMode(
        workspaceId,
        sessionId,
        mode.wireValue,
      );
    });
  }

  Future<CoordinatedTurnResult> runTurn(
    CoordinatedTurnRequest request, {
    void Function(ActiveTurnSnapshot snapshot)? onStarted,
  }) async {
    _ensureIdle();
    _operationInProgress = true;

    try {
      return await _runTurn(request, onStarted: onStarted);
    } finally {
      _operationInProgress = false;
    }
  }

  Future<CoordinatedTurnResult> _runTurn(
    CoordinatedTurnRequest request, {
    void Function(ActiveTurnSnapshot snapshot)? onStarted,
  }) async {
    final settings = await _settingsStore.getSettings();
    if (!settings.enabled) {
      throw StateError('当前已暂停 Codex 运行，请先到设置页启用。');
    }
    final apiKey = await _settingsStore.getCodexApiKey();
    if (apiKey?.trim().isNotEmpty != true) {
      throw StateError('还未设置访问令牌，请先到设置页完成配置。');
    }

    final readySession = await _codeWorkspaceService.ensureSessionWorktree(
      request.workspace,
      request.session,
    );
    final startedAt = _now().millisecondsSinceEpoch;
    final turnId = _uuid.v4();
    final cancelSignal = Completer<void>();
    final finishedSignal = Completer<void>();
    final accumulator = AssistantPartAccumulator();
    String? errorMessage;
    var cancelled = false;

    _cancelSignal = cancelSignal;
    _finishedSignal = finishedSignal;
    final initialSnapshot = ActiveTurnSnapshot(
      turnId: turnId,
      workspaceId: request.workspace.id,
      workspaceName: request.workspace.name,
      sessionId: readySession.id,
      sessionTitle: readySession.title,
      origin: request.origin,
      startedAt: startedAt,
      phase: CoordinatedTurnPhase.running,
      pendingStatus: request.pendingStatus,
      assistantText: '',
      assistantParts: const <ChatMessagePart>[],
    );
    _setActive(initialSnapshot);

    final userMessage = request.userMessage?.trim();
    if (userMessage != null && userMessage.isNotEmpty) {
      await _sessionStore.appendMessage(
        request.workspace.id,
        readySession.id,
        role: 'user',
        content: userMessage,
      );
    }
    onStarted?.call(initialSnapshot);

    final stream = _runner.run(
      workspace: request.workspace,
      sessionId: readySession.id,
      input: request.input,
      kind: request.kind,
      collaborationMode: request.collaborationMode,
      rpcCalls: request.rpcCalls,
    );
    final streamDone = Completer<void>();
    late final StreamSubscription<CodexTurnEvent> subscription;
    subscription = stream.listen(
      (event) {
        switch (event.type) {
          case CodexTurnEventType.text:
            accumulator.appendText(event.text ?? '');
            _updateActive(
              assistantText: accumulator.text,
              assistantParts: accumulator.parts,
            );
          case CodexTurnEventType.messagePart:
            accumulator.mergePart(
              id: event.partId,
              kind: event.partKind,
              title: event.partTitle,
              content: event.partContent ?? '',
              status: event.partStatus,
            );
            _updateActive(assistantParts: accumulator.parts);
          case CodexTurnEventType.status:
            final message = event.message?.trim();
            _updateActive(
              runtimeStatus: message,
              clearRuntimeStatus: message == null || message.isEmpty,
              runtimeStatusIsRetrying: event.isRetrying,
            );
          case CodexTurnEventType.error:
            errorMessage = event.message ?? '运行失败。';
            _updateActive(
              pendingStatus: errorMessage,
              clearRuntimeStatus: true,
              runtimeStatusIsRetrying: false,
            );
          case CodexTurnEventType.rpcResult:
          case CodexTurnEventType.done:
            _updateActive(
              clearRuntimeStatus: true,
              runtimeStatusIsRetrying: false,
            );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        errorMessage = error.toString();
        if (!streamDone.isCompleted) {
          streamDone.complete();
        }
      },
      onDone: () {
        if (!streamDone.isCompleted) {
          streamDone.complete();
        }
      },
      cancelOnError: false,
    );

    try {
      await Future.any<void>(<Future<void>>[
        streamDone.future,
        cancelSignal.future,
      ]);
      if (cancelSignal.isCompleted && !streamDone.isCompleted) {
        cancelled = true;
        await subscription.cancel();
      } else {
        await subscription.cancel();
      }

      final assistantText = accumulator.text.trimRight();
      final assistantParts = accumulator.parts;
      if (assistantText.isNotEmpty || assistantParts.isNotEmpty) {
        await _sessionStore.appendMessage(
          request.workspace.id,
          readySession.id,
          role: 'assistant',
          content: assistantText,
          parts: assistantParts,
          createdAt: startedAt,
        );
      }
      if (cancelled) {
        await _sessionStore.appendMessage(
          request.workspace.id,
          readySession.id,
          role: 'system',
          content: '本轮已停止。已发生的项目修改不会自动撤销。',
        );
      } else if (errorMessage?.trim().isNotEmpty == true) {
        await _sessionStore.appendMessage(
          request.workspace.id,
          readySession.id,
          role: 'system',
          content: errorMessage!.trim(),
        );
      }

      final status = cancelled
          ? '本轮已停止。'
          : (errorMessage ?? request.successStatus);
      return CoordinatedTurnResult(
        status: status,
        cancelled: cancelled,
        errorMessage: errorMessage,
      );
    } finally {
      _setActive(null);
      _cancelSignal = null;
      _finishedSignal = null;
      if (!finishedSignal.isCompleted) {
        finishedSignal.complete();
      }
    }
  }

  Future<void> cancelActiveTurn({String? turnId}) async {
    final active = _activeTurn;
    if (active == null || (turnId != null && active.turnId != turnId)) {
      return;
    }
    _setActive(
      active.copyWith(
        phase: CoordinatedTurnPhase.stopping,
        pendingStatus: '正在停止当前轮次...',
      ),
    );
    final signal = _cancelSignal;
    if (signal != null && !signal.isCompleted) {
      await _runner.cancelActiveRuns();
      signal.complete();
    }
    await _finishedSignal?.future;
  }

  void _ensureIdle() {
    final active = _activeTurn;
    if (active != null || _operationInProgress) {
      throw TurnBusyException(active);
    }
  }

  Future<T> _runExclusiveOperation<T>(Future<T> Function() operation) async {
    _ensureIdle();
    _operationInProgress = true;
    try {
      return await operation();
    } finally {
      _operationInProgress = false;
    }
  }

  void _setActive(ActiveTurnSnapshot? value) {
    _activeTurn = value;
    if (!_states.isClosed) {
      _states.add(value);
    }
  }

  void _updateActive({
    String? pendingStatus,
    String? assistantText,
    List<ChatMessagePart>? assistantParts,
    String? runtimeStatus,
    bool? runtimeStatusIsRetrying,
    bool clearRuntimeStatus = false,
  }) {
    final active = _activeTurn;
    if (active == null) {
      return;
    }
    _setActive(
      active.copyWith(
        pendingStatus: pendingStatus,
        assistantText: assistantText,
        assistantParts: assistantParts,
        runtimeStatus: runtimeStatus,
        runtimeStatusIsRetrying: runtimeStatusIsRetrying,
        clearRuntimeStatus: clearRuntimeStatus,
      ),
    );
  }

  Future<void> dispose() async {
    await _states.close();
  }
}
