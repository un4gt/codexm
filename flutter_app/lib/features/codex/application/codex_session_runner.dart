import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codexm_native/codexm_native.dart';

import '../../sessions/application/debug_log_store.dart';
import '../../sessions/application/session_models.dart';
import '../../sessions/application/session_store.dart';
import '../../workspaces/application/workspace_models.dart';
import 'async_queue.dart';
import 'codex_error_mapper.dart';
import 'codex_launch_context_service.dart';
import 'codex_models.dart';
import 'codex_runtime_bridge.dart';
import 'json_rpc_client.dart';

class CodexSessionRunner {
  CodexSessionRunner({
    CodexLaunchContextService? launchContextService,
    SessionStore? sessionStore,
    DebugLogStore? debugLogStore,
    CodexRuntimeBridge? runtimeBridge,
    bool Function()? platformIsAndroid,
    DateTime Function()? now,
  })  : _launchContextService =
            launchContextService ?? CodexLaunchContextService(),
        _sessionStore = sessionStore ?? SessionStore(),
        _debugLogStore = debugLogStore ?? DebugLogStore(),
        _runtimeBridge = runtimeBridge ?? NativeCodexRuntimeBridge(),
        _platformIsAndroid = platformIsAndroid ?? (() => Platform.isAndroid),
        _now = now ?? DateTime.now;

  final CodexLaunchContextService _launchContextService;
  final SessionStore _sessionStore;
  final DebugLogStore _debugLogStore;
  final CodexRuntimeBridge _runtimeBridge;
  final bool Function() _platformIsAndroid;
  final DateTime Function() _now;

  Stream<CodexTurnEvent> run({
    required Workspace workspace,
    required SessionId sessionId,
    Object? input,
    CodexTurnKind kind = CodexTurnKind.turn,
    Object? reviewTarget,
    CodexCollaborationMode? collaborationMode,
    List<CodexRpcCall>? rpcCalls,
  }) async* {
    if (!_platformIsAndroid()) {
      yield const CodexTurnEvent.error('当前仅支持 Android 设备运行 Codex。');
      yield const CodexTurnEvent.done();
      return;
    }

    final inputElements = _normalizeInput(input);
    if (kind == CodexTurnKind.turn && !_hasTextInput(inputElements)) {
      yield const CodexTurnEvent.error('请输入内容。');
      yield const CodexTurnEvent.done();
      return;
    }
    if (kind == CodexTurnKind.rpc &&
        (rpcCalls == null || rpcCalls.isEmpty)) {
      yield const CodexTurnEvent.error('没有可执行的操作。');
      yield const CodexTurnEvent.done();
      return;
    }

    final firstText = _firstTextInput(inputElements);
    final inputText = firstText?.trim() ?? '';
    final launchContext = await _launchContextService.build(
      workspace: workspace,
      sessionId: sessionId,
    );

    final settings = launchContext.settings;
    final debugLogEnabled = settings.debugLogToFile;
    final retentionDays = _clampRetentionDays(settings.debugLogRetentionDays);

    Future<void> logEvent(
      String event, {
      String? message,
      Object? details,
      bool flush = false,
    }) async {
      if (!debugLogEnabled) {
        return;
      }
      final future = _debugLogStore.appendDebugLog(
        workspaceId: workspace.id,
        sessionId: sessionId,
        event: event,
        message: message,
        details: details,
      );
      if (flush) {
        await future;
      } else {
        unawaited(future);
      }
    }

    if (debugLogEnabled) {
      unawaited(_debugLogStore.pruneDebugLogs(workspace.id, retentionDays));
    }

    await logEvent(
      'turn_start',
      details: <String, Object?>{
        'kind': kind.name,
        'inputLength': inputText.length,
        'mcpEnabledServers': launchContext.enabledMcpServerIds.length,
      },
    );

    final runtimeId =
        '${workspace.id}:$sessionId:${_now().millisecondsSinceEpoch}';
    final lineQueue = AsyncQueue<RuntimeLineEvent>();
    final notificationQueue = AsyncQueue<JsonRpcNotification>();
    final stderrRing = <String>[];

    void pushStderr(String line) {
      stderrRing.add(line);
      if (stderrRing.length > 120) {
        stderrRing.removeRange(0, stderrRing.length - 120);
      }
    }

    String formatStderrTail() => stderrRing.where((line) => line.isNotEmpty).join('\n');

    final rpc = JsonRpcClient((line) {
      return _runtimeBridge.sendRuntimeLine(
        runtimeId: runtimeId,
        line: line,
      );
    });
    final notificationSubscription = rpc.notifications.listen(
      notificationQueue.push,
    );
    rpc.serverRequestHandler = (request) {
      if (request.method.endsWith('/requestApproval')) {
        return <String, Object?>{'decision': 'accept'};
      }
      return <String, Object?>{'decision': 'decline'};
    };

    StreamSubscription<RuntimeLineEvent>? runtimeSubscription;
    Future<void>? pumpFuture;
    var pumpRunning = true;
    var runtimeStarted = false;

    var pendingText = '';
    var sawAnyDelta = false;
    var lastFlushMs = _now().millisecondsSinceEpoch;

    String? takeFlush({bool force = false}) {
      if (pendingText.isEmpty) {
        return null;
      }
      final nowMs = _now().millisecondsSinceEpoch;
      if (force ||
          nowMs - lastFlushMs >= 33 ||
          pendingText.length >= 512) {
        final out = pendingText;
        pendingText = '';
        lastFlushMs = nowMs;
        return out;
      }
      return null;
    }

    String? pushDelta(String delta) {
      pendingText += delta;
      return takeFlush();
    }

    try {
      runtimeSubscription = _runtimeBridge.runtimeLineEvents().listen((event) {
        if (event.runtimeId != runtimeId) {
          return;
        }
        if (event.stream == 'stderr') {
          pushStderr(event.line);
        }
        lineQueue.push(event);
      });

      await _runtimeBridge.startRuntime(
        runtimeId: runtimeId,
        cwdPath: launchContext.paths.repoDir.path,
        assetPath: 'codex/{abi}/codex',
        args: const <String>['app-server', '--listen', 'stdio://'],
        env: launchContext.env,
      );
      runtimeStarted = true;

      pumpFuture = () async {
        while (pumpRunning) {
          final event = await lineQueue.shift();
          if (event == null) {
            break;
          }
          if (event.stream != 'stdout') {
            continue;
          }
          await rpc.handleLine(event.line);
        }
      }();

      await rpc.request<Object?>(
        'initialize',
        params: <String, Object?>{
          'clientInfo': const <String, Object?>{
            'name': 'codexm_android',
            'title': 'CodexM Android',
            'version': '0.0.7',
          },
          'capabilities': const <String, Object?>{
            'experimentalApi': true,
          },
        },
        timeoutMs: 12000,
      );
      await rpc.notify('initialized', params: const <String, Object?>{});

      if (collaborationMode != null) {
        await _sessionStore.setSessionCodexCollaborationMode(
          workspace.id,
          sessionId,
          collaborationMode.wireValue,
        );
      }

      final needsThread = kind != CodexTurnKind.rpc ||
          (rpcCalls ?? const <CodexRpcCall>[])
              .any((call) => call.requiresThread);
      final approvalPolicy = settings.approvalPolicy;
      var threadId =
          needsThread ? launchContext.session.codexThreadId : null;

      if (needsThread && threadId != null && threadId.isNotEmpty) {
        try {
          await rpc.request<Object?>(
            'thread/resume',
            params: <String, Object?>{
              'threadId': threadId,
              'cwd': launchContext.paths.repoDir.path,
              'approvalPolicy': approvalPolicy,
              'personality': settings.personality,
            },
            timeoutMs: 30000,
          );
        } catch (error) {
          if (isMissingThreadState(error)) {
            await _sessionStore.setSessionCodexThreadId(
              workspace.id,
              sessionId,
              null,
            );
            threadId = null;
          } else {
            rethrow;
          }
        }
      }

      if (needsThread && (threadId == null || threadId.isEmpty)) {
        final result = await rpc.request<Object?>(
          'thread/start',
          params: <String, Object?>{
            'cwd': launchContext.paths.repoDir.path,
            'approvalPolicy': approvalPolicy,
            'personality': settings.personality,
          },
          timeoutMs: 30000,
        );
        threadId = _extractThreadId(result);
        if (threadId != null && threadId.isNotEmpty) {
          await _sessionStore.setSessionCodexThreadId(
            workspace.id,
            sessionId,
            threadId,
          );
        }
      }

      if (needsThread && (threadId == null || threadId.isEmpty)) {
        await logEvent(
          'thread_missing',
          message: 'threadId 缺失',
          flush: true,
        );
        throw StateError('无法建立会话，请重试。');
      }

      if (kind == CodexTurnKind.rpc) {
        for (final call in rpcCalls ?? const <CodexRpcCall>[]) {
          final params = <String, Object?>{
            ...?call.params,
          };
          if (call.requiresThread && !params.containsKey('threadId')) {
            params['threadId'] = threadId;
          }
          final result = await rpc.request<Object?>(
            call.method,
            params: params,
            timeoutMs: 30000,
          );
          yield CodexTurnEvent.rpcResult(method: call.method, result: result);
          if (call.emitText) {
            final title = call.title?.trim() ?? '';
            if (title.isNotEmpty) {
              yield CodexTurnEvent.text('$title\n');
            }
            yield CodexTurnEvent.text(_formatJsonBlock(result));
          }
          if (call.method == 'thread/compact/start') {
            var compactDone = false;
            while (!compactDone) {
              final notification = await notificationQueue.shift();
              if (notification == null) {
                break;
              }
              if (notification.method == 'item/completed') {
                final item = _readItem(notification.params);
                if (item?['type'] == 'contextCompaction') {
                  compactDone = true;
                  continue;
                }
              }
              if (notification.method == 'turn/completed') {
                compactDone = true;
              }
            }
          }
        }

        final tail = takeFlush(force: true);
        if (tail != null) {
          yield CodexTurnEvent.text(tail);
        }
        return;
      }

      String? turnId;
      if (kind == CodexTurnKind.review) {
        final result = await rpc.request<Object?>(
          'review/start',
          params: <String, Object?>{
            'threadId': threadId,
            'delivery': 'inline',
            'target': reviewTarget ??
                const <String, Object?>{'type': 'uncommittedChanges'},
          },
          timeoutMs: 120000,
        );
        turnId = _extractTurnId(result);
      } else {
        final params = <String, Object?>{
          'threadId': threadId,
          'cwd': launchContext.paths.repoDir.path,
          'approvalPolicy': approvalPolicy,
          'input': inputElements,
        };
        final model = settings.model?.trim() ?? '';
        if (collaborationMode != null && model.isNotEmpty) {
          params['collaborationMode'] = <String, Object?>{
            'mode': collaborationMode.wireValue,
            'settings': <String, Object?>{
              'model': model,
              'reasoning_effort': null,
              'developer_instructions': null,
            },
          };
        }
        final result = await rpc.request<Object?>(
          'turn/start',
          params: params,
          timeoutMs: 120000,
        );
        turnId = _extractTurnId(result);
      }

      const idlePollMs = 1000;
      const turnIdleTimeoutMs = 180000;
      var lastActivityMs = _now().millisecondsSinceEpoch;
      var completed = false;

      while (!completed) {
        final nowMs = _now().millisecondsSinceEpoch;
        if (pendingText.isNotEmpty && nowMs - lastFlushMs >= 33) {
          final chunk = takeFlush(force: true);
          if (chunk != null) {
            yield CodexTurnEvent.text(chunk);
          }
        }

        final timeoutMs = pendingText.isNotEmpty
            ? (33 - (nowMs - lastFlushMs)).clamp(1, 33)
            : idlePollMs;
        final notification = await notificationQueue.shift(timeoutMs);
        if (notification == null) {
          final chunk = takeFlush(force: true);
          if (chunk != null) {
            yield CodexTurnEvent.text(chunk);
          }
          if (notificationQueue.isClosed) {
            break;
          }
          if (_now().millisecondsSinceEpoch - lastActivityMs >=
              turnIdleTimeoutMs) {
            final stderrTail = formatStderrTail();
            await logEvent(
              'turn_idle_timeout',
              message: '长时间未收到响应。',
              details: stderrTail.isEmpty ? null : 'stderr:\n$stderrTail',
              flush: true,
            );
            yield const CodexTurnEvent.error(
              '长时间未收到响应：请检查网络与「设置」中的服务器地址/密钥，并重试。',
            );
            break;
          }
          continue;
        }

        lastActivityMs = _now().millisecondsSinceEpoch;

        if (notification.method == 'item/agentMessage/delta' ||
            notification.method.endsWith('/outputDelta')) {
          final delta = _extractDelta(notification.params);
          if (delta != null && delta.isNotEmpty) {
            sawAnyDelta = true;
            final chunk = pushDelta(delta);
            if (chunk != null) {
              yield CodexTurnEvent.text(chunk);
            }
          }
          continue;
        }

        if (notification.method == 'error') {
          final chunk = takeFlush(force: true);
          if (chunk != null) {
            yield CodexTurnEvent.text(chunk);
          }
          final message = formatRuntimeNotificationError(notification.params);
          final stderrTail = formatStderrTail();
          await logEvent(
            'runtime_error',
            message: message,
            details: stderrTail.isEmpty ? null : 'stderr:\n$stderrTail',
            flush: true,
          );
          yield CodexTurnEvent.error(message);
          continue;
        }

        if (notification.method == 'item/completed') {
          final item = _readItem(notification.params);
          if (item?['type'] == 'exitedReviewMode') {
            final review = item?['review']?.toString() ?? '';
            if (review.trim().isNotEmpty) {
              final chunk = takeFlush(force: true);
              if (chunk != null) {
                yield CodexTurnEvent.text(chunk);
              }
              yield CodexTurnEvent.text(review);
            }
          }

          if (!sawAnyDelta && item != null) {
            final itemType = item['type']?.toString();
            if (itemType == 'agentMessage' ||
                itemType == 'assistantMessage') {
              final full = _extractCompletedItemText(item);
              if (full != null && full.isNotEmpty) {
                final chunk = takeFlush(force: true);
                if (chunk != null) {
                  yield CodexTurnEvent.text(chunk);
                }
                yield CodexTurnEvent.text(full);
                sawAnyDelta = true;
              }
            }
          }
          continue;
        }

        if (notification.method == 'turn/completed') {
          final chunk = takeFlush(force: true);
          if (chunk != null) {
            yield CodexTurnEvent.text(chunk);
          }
          final turn = _readTurn(notification.params);
          final completedTurnId = turn?['id']?.toString() ??
              (notification.params is Map
                  ? (notification.params as Map)['turnId']?.toString()
                  : null);
          if (turnId == null || completedTurnId == turnId) {
            if (turn?['status'] == 'failed') {
              final message =
                  _readNestedMap(turn, 'error')?['message']?.toString() ??
                      '运行失败。';
              final stderrTail = formatStderrTail();
              await logEvent(
                'turn_failed',
                message: message,
                details: stderrTail.isEmpty ? null : 'stderr:\n$stderrTail',
                flush: true,
              );
              yield CodexTurnEvent.error(message);
            }
            completed = true;
          }
        }
      }

      final tail = takeFlush(force: true);
      if (tail != null) {
        yield CodexTurnEvent.text(tail);
      }
    } catch (error) {
      rpc.rejectAllPending(error);
      final messageForLog = formatRpcErrorForLog(error);
      final messageForUser = formatRpcErrorForUser(error);
      final stderrTail = formatStderrTail();
      await logEvent(
        'exception',
        message: '运行异常',
        details: [
          messageForLog,
          if (stderrTail.isNotEmpty) 'stderr:\n$stderrTail',
        ].join('\n\n'),
        flush: true,
      );
      yield CodexTurnEvent.error(messageForUser);
    } finally {
      pumpRunning = false;
      lineQueue.close();
      notificationQueue.close();
      await runtimeSubscription?.cancel();
      await notificationSubscription.cancel();
      try {
        if (runtimeStarted) {
          await _runtimeBridge.stopRuntime(runtimeId: runtimeId);
        }
      } catch (_) {
        // Ignore runtime stop failures.
      }
      await rpc.close();
      try {
        await pumpFuture;
      } catch (_) {
        // Ignore pump failures on shutdown.
      }
      await logEvent('turn_end');
      yield const CodexTurnEvent.done();
    }
  }

  int _clampRetentionDays(int value) {
    if (value < 1) {
      return 1;
    }
    if (value > 90) {
      return 90;
    }
    return value;
  }

  List<CodexInputElement> _normalizeInput(Object? input) {
    if (input is List) {
      return input
          .whereType<Map>()
          .map((item) => Map<String, Object?>.from(item))
          .toList(growable: false);
    }
    return <CodexInputElement>[
      <String, Object?>{
        'type': 'text',
        'text': input?.toString() ?? '',
      },
    ];
  }

  bool _hasTextInput(List<CodexInputElement> inputElements) {
    for (final item in inputElements) {
      if (item['type'] == 'text' &&
          item['text'] is String &&
          (item['text'] as String).trim().isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  String? _firstTextInput(List<CodexInputElement> inputElements) {
    for (final item in inputElements) {
      if (item['type'] == 'text' && item['text'] is String) {
        return item['text'] as String;
      }
    }
    return null;
  }

  String _formatJsonBlock(Object? result) {
    String body;
    try {
      body = const JsonEncoder.withIndent('  ').convert(result);
    } catch (_) {
      body = result.toString();
    }
    return '```json\n$body\n```\n';
  }

  String? _extractThreadId(Object? result) {
    if (result is! Map) {
      return null;
    }
    final thread = result['thread'];
    if (thread is Map) {
      return thread['id']?.toString();
    }
    return null;
  }

  String? _extractTurnId(Object? result) {
    if (result is! Map) {
      return null;
    }
    final turn = result['turn'];
    if (turn is Map) {
      return turn['id']?.toString();
    }
    return null;
  }

  String? _extractDelta(Object? params) {
    if (params is! Map) {
      return null;
    }
    final delta = params['delta'];
    if (delta is String) {
      return delta;
    }
    if (delta is Map && delta['text'] is String) {
      return delta['text'] as String;
    }
    return null;
  }

  Map<Object?, Object?>? _readItem(Object? params) {
    if (params is! Map || params['item'] is! Map) {
      return null;
    }
    return Map<Object?, Object?>.from(params['item'] as Map);
  }

  Map<Object?, Object?>? _readTurn(Object? params) {
    if (params is! Map || params['turn'] is! Map) {
      return null;
    }
    return Map<Object?, Object?>.from(params['turn'] as Map);
  }

  Map<Object?, Object?>? _readNestedMap(Map<Object?, Object?>? source, String key) {
    if (source == null || source[key] is! Map) {
      return null;
    }
    return Map<Object?, Object?>.from(source[key] as Map);
  }

  String? _extractCompletedItemText(Map<Object?, Object?> item) {
    final direct = item['text'] ?? item['message'] ?? item['content'];
    if (direct is String && direct.isNotEmpty) {
      return direct;
    }

    final maybeParts =
        item['output'] ?? _readNestedMap(item, 'message')?['output'] ??
            _readNestedMap(item, 'message')?['content'] ??
            item['content'];
    if (maybeParts is! List) {
      return null;
    }

    final buffer = StringBuffer();
    for (final part in maybeParts) {
      if (part is String) {
        buffer.write(part);
        continue;
      }
      if (part is Map) {
        if (part['text'] is String) {
          buffer.write(part['text']);
        } else if (part['content'] is String) {
          buffer.write(part['content']);
        }
      }
    }
    final text = buffer.toString();
    return text.isEmpty ? null : text;
  }
}
