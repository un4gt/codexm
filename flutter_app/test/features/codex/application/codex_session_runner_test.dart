import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codexm_flutter/features/codex/application/codex_launch_context_service.dart';
import 'package:codexm_flutter/features/codex/application/codex_models.dart';
import 'package:codexm_flutter/features/codex/application/codex_runtime_bridge.dart';
import 'package:codexm_flutter/features/codex/application/codex_session_runner.dart';
import 'package:codexm_flutter/features/sessions/application/debug_log_store.dart';
import 'package:codexm_flutter/features/sessions/application/session_store.dart';
import 'package:codexm_flutter/features/settings/application/auth_store.dart';
import 'package:codexm_flutter/features/settings/application/codex_settings_store.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_paths.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_store.dart';
import 'package:codexm_flutter/shared/persistence/app_directory_service.dart';
import 'package:codexm_native/codexm_native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('runs a turn, streams deltas and persists thread state', () async {
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
    final authStore = AuthStore(secureStore: _MemorySecureStore());
    final settingsStore = CodexSettingsStore(
      appDirectoryService: appDirectoryService,
      authStore: authStore,
    );
    final debugLogStore = DebugLogStore(
      workspaceDirectoryService: workspaceDirectoryService,
    );

    final workspace = await workspaceStore.createWorkspace(name: 'Runner Workspace');
    final session = await sessionStore.createSession(
      workspace.id,
      title: 'Runner Session',
    );
    await settingsStore.saveSettings(
      const CodexSettings(
        model: 'gpt-test',
        debugLogToFile: true,
      ),
    );
    await settingsStore.saveCodexApiKey('sk-test-1234567890');

    final bridge = _FakeRuntimeBridge();
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

    final events = await runner
        .run(
          workspace: workspace,
          sessionId: session.id,
          input: '请回复 hello world',
          collaborationMode: CodexCollaborationMode.plan,
        )
        .toList();

    final text = events
        .where((event) => event.type == CodexTurnEventType.text)
        .map((event) => event.text ?? '')
        .join();
    final storedSession = await sessionStore.getSession(workspace.id, session.id);

    expect(text, 'hello world');
    expect(events.last.type, CodexTurnEventType.done);
    expect(storedSession?.codexThreadId, 'thread_1');
    expect(storedSession?.codexCollaborationMode, 'plan');
    expect(bridge.startedEnv?['OPENAI_API_KEY'], 'sk-test-1234567890');
  });
}

class _FakeRuntimeBridge implements CodexRuntimeBridge {
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
      unawaited(Future<void>.delayed(const Duration(milliseconds: 1), () async {
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
      }));
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
  Future<void> write({
    required String key,
    required String value,
  }) async {
    _data[key] = value;
  }
}
