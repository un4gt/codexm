import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codexm_flutter/features/codex/application/codex_launch_context_service.dart';
import 'package:codexm_flutter/features/codex/application/codex_models.dart';
import 'package:codexm_flutter/features/codex/application/codex_runtime_bridge.dart';
import 'package:codexm_flutter/features/codex/application/codex_session_runner.dart';
import 'package:codexm_flutter/features/sessions/application/debug_log_store.dart';
import 'package:codexm_flutter/features/sessions/application/session_models.dart';
import 'package:codexm_flutter/features/sessions/application/session_store.dart';
import 'package:codexm_flutter/features/settings/application/auth_store.dart';
import 'package:codexm_flutter/features/settings/application/codex_settings_store.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_models.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_paths.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_store.dart';
import 'package:codexm_flutter/shared/persistence/app_directory_service.dart';
import 'package:codexm_native/codexm_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runs a turn, streams deltas and persists thread state', () async {
    final bridge = _FakeRuntimeBridge();
    final fixture = await _createRunnerFixture(bridge);
    addTearDown(fixture.dispose);

    final events = await fixture.runner
        .run(
          workspace: fixture.workspace,
          sessionId: fixture.session.id,
          input: '请回复 hello world',
          collaborationMode: CodexCollaborationMode.plan,
        )
        .toList();

    final text = events
        .where((event) => event.type == CodexTurnEventType.text)
        .map((event) => event.text ?? '')
        .join();
    final storedSession = await fixture.sessionStore.getSession(
      fixture.workspace.id,
      fixture.session.id,
    );

    expect(text, 'hello world');
    expect(events.last.type, CodexTurnEventType.done);
    expect(storedSession?.codexThreadId, 'thread_1');
    expect(storedSession?.codexCollaborationMode, 'plan');
    expect(bridge.startedEnv?['OPENAI_API_KEY'], 'sk-test-1234567890');
  });

  test('emits reconnect status without adding assistant text', () async {
    final bridge = _FakeRuntimeBridge(emitRetryBeforeResponse: true);
    final fixture = await _createRunnerFixture(bridge);
    addTearDown(fixture.dispose);

    final events = await fixture.runner
        .run(
          workspace: fixture.workspace,
          sessionId: fixture.session.id,
          input: '请回复 hello world',
        )
        .toList();

    final text = events
        .where((event) => event.type == CodexTurnEventType.text)
        .map((event) => event.text ?? '')
        .join();
    final statuses = events
        .where((event) => event.type == CodexTurnEventType.status)
        .toList();
    final errors = events
        .where((event) => event.type == CodexTurnEventType.error)
        .toList();

    expect(text, 'hello world');
    expect(errors, isEmpty);
    expect(statuses.first.message, 'Reconnecting... 1/5');
    expect(statuses.first.isRetrying, isTrue);
    expect(statuses.any((event) => event.message == null), isTrue);
    expect(events.last.type, CodexTurnEventType.done);
  });

  test('turns retry limit notification into a final error', () async {
    final bridge = _FakeRuntimeBridge(
      emitRetryBeforeResponse: true,
      failAfterRetry: true,
    );
    final fixture = await _createRunnerFixture(bridge);
    addTearDown(fixture.dispose);

    final events = await fixture.runner
        .run(
          workspace: fixture.workspace,
          sessionId: fixture.session.id,
          input: '请回复 hello world',
        )
        .toList();

    final text = events
        .where((event) => event.type == CodexTurnEventType.text)
        .map((event) => event.text ?? '')
        .join();
    final errors = events
        .where((event) => event.type == CodexTurnEventType.error)
        .toList();
    final statuses = events
        .where((event) => event.type == CodexTurnEventType.status)
        .toList();

    expect(text, isEmpty);
    expect(statuses, hasLength(1));
    expect(statuses.single.message, 'Reconnecting... 1/5');
    expect(errors, hasLength(1));
    expect(errors.single.message, contains('重连失败'));
    expect(events.last.type, CodexTurnEventType.done);
  });
}

class _FakeRuntimeBridge implements CodexRuntimeBridge {
  _FakeRuntimeBridge({
    this.emitRetryBeforeResponse = false,
    this.failAfterRetry = false,
  });

  final bool emitRetryBeforeResponse;
  final bool failAfterRetry;

  final StreamController<RuntimeLineEvent> _controller =
      StreamController<RuntimeLineEvent>.broadcast();

  Map<String, String>? startedEnv;
  String? _runtimeId;

  @override
  Stream<RuntimeLineEvent> runtimeLineEvents() => _controller.stream;

  @override
  Future<void> sendRuntimeLine({
    required String runtimeId,
    required String line,
  }) async {
    final message = jsonDecode(line) as Map<String, dynamic>;
    final method = message['method']?.toString();
    if (method == 'initialize') {
      _emit(
        jsonEncode(<String, Object?>{
          'id': message['id'],
          'result': const <String, Object?>{'ok': true},
        }),
      );
      return;
    }
    if (method == 'thread/start') {
      _emit(
        jsonEncode(<String, Object?>{
          'id': message['id'],
          'result': const <String, Object?>{
            'thread': <String, Object?>{'id': 'thread_1'},
          },
        }),
      );
      return;
    }
    if (method == 'turn/start') {
      _emit(
        jsonEncode(<String, Object?>{
          'id': message['id'],
          'result': const <String, Object?>{
            'turn': <String, Object?>{'id': 'turn_1'},
          },
        }),
      );
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 1), () async {
          if (emitRetryBeforeResponse) {
            _emit(
              jsonEncode(<String, Object?>{
                'method': 'error',
                'params': const <String, Object?>{
                  'threadId': 'thread_1',
                  'turnId': 'turn_1',
                  'willRetry': true,
                  'error': <String, Object?>{
                    'message': 'Reconnecting... 1/5',
                    'codexErrorInfo': <String, Object?>{
                      'responseStreamDisconnected': <String, Object?>{
                        'httpStatusCode': null,
                      },
                    },
                  },
                },
              }),
            );
          }
          if (failAfterRetry) {
            _emit(
              jsonEncode(<String, Object?>{
                'method': 'error',
                'params': const <String, Object?>{
                  'threadId': 'thread_1',
                  'turnId': 'turn_1',
                  'willRetry': false,
                  'error': <String, Object?>{
                    'message': 'Reached retry limit for responses.',
                    'codexErrorInfo': <String, Object?>{
                      'responseTooManyFailedAttempts': <String, Object?>{
                        'httpStatusCode': null,
                      },
                    },
                  },
                },
              }),
            );
            return;
          }
          _emit(
            jsonEncode(<String, Object?>{
              'method': 'item/agentMessage/delta',
              'params': const <String, Object?>{
                'delta': <String, Object?>{'text': 'hello '},
              },
            }),
          );
          _emit(
            jsonEncode(<String, Object?>{
              'method': 'item/agentMessage/delta',
              'params': const <String, Object?>{
                'delta': <String, Object?>{'text': 'world'},
              },
            }),
          );
          _emit(
            jsonEncode(<String, Object?>{
              'method': 'turn/completed',
              'params': const <String, Object?>{
                'turn': <String, Object?>{
                  'id': 'turn_1',
                  'status': 'completed',
                },
              },
            }),
          );
        }),
      );
    }
  }

  @override
  Future<void> startRuntime({
    required String runtimeId,
    required String cwdPath,
    String? executablePath,
    String? assetPath,
    List<String>? args,
    Map<String, String>? env,
  }) async {
    _runtimeId = runtimeId;
    startedEnv = env;
  }

  @override
  Future<void> stopRuntime({String? runtimeId}) async {
    await _controller.close();
  }

  void _emit(String line) {
    _controller.add(
      RuntimeLineEvent(
        runtimeId: _runtimeId ?? 'runtime',
        stream: 'stdout',
        line: line,
      ),
    );
  }
}

Future<_RunnerFixture> _createRunnerFixture(_FakeRuntimeBridge bridge) async {
  final documentsDir = await Directory.systemTemp.createTemp('codexm_docs_');
  final temporaryDir = await Directory.systemTemp.createTemp('codexm_tmp_');
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
  final authStore = AuthStore(secureStore: _MemorySecureStore());
  final settingsStore = CodexSettingsStore(
    appDirectoryService: appDirectoryService,
    authStore: authStore,
  );
  final debugLogStore = DebugLogStore(
    workspaceDirectoryService: workspaceDirectoryService,
  );

  final workspace = await workspaceStore.createWorkspace(
    name: 'Runner Workspace',
  );
  final session = await sessionStore.createSession(
    workspace.id,
    title: 'Runner Session',
  );
  await settingsStore.saveSettings(
    const CodexSettings(model: 'gpt-test', debugLogToFile: true),
  );
  await settingsStore.saveCodexApiKey('sk-test-1234567890');

  final runner = CodexSessionRunner(
    launchContextService: CodexLaunchContextService(
      workspaceDirectoryService: workspaceDirectoryService,
      sessionStore: sessionStore,
      settingsStore: settingsStore,
    ),
    sessionStore: sessionStore,
    debugLogStore: debugLogStore,
    runtimeBridge: bridge,
    platformIsAndroid: () => true,
    now: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
  );

  return _RunnerFixture(
    documentsDir: documentsDir,
    temporaryDir: temporaryDir,
    workspace: workspace,
    session: session,
    sessionStore: sessionStore,
    runner: runner,
  );
}

class _RunnerFixture {
  const _RunnerFixture({
    required this.documentsDir,
    required this.temporaryDir,
    required this.workspace,
    required this.session,
    required this.sessionStore,
    required this.runner,
  });

  final Directory documentsDir;
  final Directory temporaryDir;
  final Workspace workspace;
  final Session session;
  final SessionStore sessionStore;
  final CodexSessionRunner runner;

  Future<void> dispose() async {
    await _deleteTempDirectory(documentsDir);
    await _deleteTempDirectory(temporaryDir);
  }
}

Future<void> _deleteTempDirectory(Directory directory) async {
  for (var attempt = 0; attempt < 3; attempt += 1) {
    if (!directory.existsSync()) {
      return;
    }
    try {
      await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      if (attempt == 2) {
        rethrow;
      }
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }
}

class _MemorySecureStore implements SecureKeyValueStore {
  final Map<String, String> _data = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    _data.remove(key);
  }

  @override
  Future<String?> read({required String key}) async {
    return _data[key];
  }

  @override
  Future<void> write({required String key, required String value}) async {
    _data[key] = value;
  }
}
