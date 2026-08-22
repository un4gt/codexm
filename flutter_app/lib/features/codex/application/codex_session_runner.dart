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
import 'runtime_path_mapper.dart';

class CodexSessionRunner {
  CodexSessionRunner({
    CodexLaunchContextService? launchContextService,
    SessionStore? sessionStore,
    DebugLogStore? debugLogStore,
    CodexRuntimeBridge? runtimeBridge,
    bool Function()? platformIsAndroid,
    DateTime Function()? now,
  }) : _launchContextService =
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
  final Map<String, JsonRpcClient> _activeRpcClients =
      <String, JsonRpcClient>{};

  Future<void> cancelActiveRuns() async {
    final active = _activeRpcClients.entries.toList(growable: false);
    for (final entry in active) {
      entry.value.rejectAllPending(StateError('Codex turn cancelled'));
      try {
        await _runtimeBridge.stopRuntime(runtimeId: entry.key);
      } catch (_) {
        // The normal run cleanup handles an already-stopped runtime.
      }
    }
  }

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
    if (kind == CodexTurnKind.rpc && (rpcCalls == null || rpcCalls.isEmpty)) {
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
    final pathMapper = RuntimePathMapper.fromLaunchContext(launchContext);

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

    String formatStderrTail() =>
        stderrRing.where((line) => line.isNotEmpty).join('\n');

    final rpc = JsonRpcClient((line) {
      return _runtimeBridge.sendRuntimeLine(runtimeId: runtimeId, line: line);
    });
    _activeRpcClients[runtimeId] = rpc;
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
    final messagePartInfoById = <String, _RuntimeMessagePartInfo>{};

    String? takeFlush({bool force = false}) {
      if (pendingText.isEmpty) {
        return null;
      }
      final nowMs = _now().millisecondsSinceEpoch;
      if (force || nowMs - lastFlushMs >= 33 || pendingText.length >= 512) {
        final out = pendingText;
        pendingText = '';
        lastFlushMs = nowMs;
        return out;
      }
      return null;
    }

    String? pushDelta(String delta) {
      pendingText += pathMapper.realToVirtual(delta);
      return takeFlush();
    }

    CodexTurnEvent mappedText(String text) {
      return CodexTurnEvent.text(pathMapper.realToVirtual(text));
    }

    CodexTurnEvent mappedStatus(String? message, {bool isRetrying = false}) {
      return CodexTurnEvent.status(
        message == null ? null : pathMapper.realToVirtual(message),
        isRetrying: isRetrying,
      );
    }

    CodexTurnEvent mappedError(String message) {
      return CodexTurnEvent.error(pathMapper.realToVirtual(message));
    }

    CodexTurnEvent mappedEvent(CodexTurnEvent event) {
      return pathMapper.sanitizeEvent(event);
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
        cwdPath: launchContext.workingDirectory,
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
          'capabilities': const <String, Object?>{'experimentalApi': true},
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

      final needsThread =
          kind != CodexTurnKind.rpc ||
          (rpcCalls ?? const <CodexRpcCall>[]).any(
            (call) => call.requiresThread,
          );
      final approvalPolicy = settings.approvalPolicy;
      var threadId = needsThread ? launchContext.session.codexThreadId : null;

      if (needsThread && threadId != null && threadId.isNotEmpty) {
        try {
          await rpc.request<Object?>(
            'thread/resume',
            params: <String, Object?>{
              'threadId': threadId,
              'cwd': launchContext.workingDirectory,
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
            'cwd': launchContext.workingDirectory,
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
        await logEvent('thread_missing', message: 'threadId 缺失', flush: true);
        throw StateError('无法建立会话，请重试。');
      }

      if (kind == CodexTurnKind.rpc) {
        for (final call in rpcCalls ?? const <CodexRpcCall>[]) {
          final params = <String, Object?>{...?call.params};
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
              yield mappedText('$title\n');
            }
            yield mappedText(_formatJsonBlock(result));
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
          yield mappedText(tail);
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
            'target':
                reviewTarget ??
                const <String, Object?>{'type': 'uncommittedChanges'},
          },
          timeoutMs: 120000,
        );
        turnId = _extractTurnId(result);
      } else {
        final params = <String, Object?>{
          'threadId': threadId,
          'cwd': launchContext.workingDirectory,
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
      var retryStatusActive = false;

      while (!completed) {
        final nowMs = _now().millisecondsSinceEpoch;
        if (pendingText.isNotEmpty && nowMs - lastFlushMs >= 33) {
          final chunk = takeFlush(force: true);
          if (chunk != null) {
            yield mappedText(chunk);
          }
        }

        final timeoutMs = pendingText.isNotEmpty
            ? (33 - (nowMs - lastFlushMs)).clamp(1, 33)
            : idlePollMs;
        final notification = await notificationQueue.shift(timeoutMs);
        if (notification == null) {
          final chunk = takeFlush(force: true);
          if (chunk != null) {
            yield mappedText(chunk);
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
        if (notification.method != 'error' && retryStatusActive) {
          retryStatusActive = false;
          yield mappedStatus(null);
        }

        if (notification.method == 'item/agentMessage/delta') {
          final delta = _extractDelta(notification.params);
          if (delta != null && delta.isNotEmpty) {
            sawAnyDelta = true;
            final chunk = pushDelta(delta);
            if (chunk != null) {
              yield mappedText(chunk);
            }
          }
          continue;
        }

        final messagePartEvent = _messagePartEventForNotification(
          notification,
          messagePartInfoById,
        );
        if (messagePartEvent != null) {
          final chunk = takeFlush(force: true);
          if (chunk != null) {
            yield mappedText(chunk);
          }
          yield mappedEvent(messagePartEvent);
          continue;
        }

        if (notification.method == 'error') {
          final chunk = takeFlush(force: true);
          if (chunk != null) {
            yield mappedText(chunk);
          }
          final runtimeError = parseRuntimeNotificationError(
            notification.params,
          );
          if (runtimeError.willRetry) {
            retryStatusActive = true;
            await logEvent(
              'runtime_retry',
              message: runtimeError.message,
              details: runtimeError.additionalDetails,
            );
            yield mappedStatus(runtimeError.message, isRetrying: true);
            continue;
          }
          retryStatusActive = false;
          final message = formatRuntimeNotificationError(notification.params);
          final stderrTail = formatStderrTail();
          await logEvent(
            'runtime_error',
            message: message,
            details: stderrTail.isEmpty ? null : 'stderr:\n$stderrTail',
            flush: true,
          );
          yield mappedError(message);
          completed = true;
          continue;
        }

        if (notification.method == 'item/completed') {
          final item = _readItem(notification.params);
          final messagePartEvent = _messagePartEventForCompletedItem(
            notification.params,
            item,
            messagePartInfoById,
          );
          if (messagePartEvent != null) {
            final chunk = takeFlush(force: true);
            if (chunk != null) {
              yield mappedText(chunk);
            }
            yield mappedEvent(messagePartEvent);
          }
          if (item?['type'] == 'exitedReviewMode') {
            final review = item?['review']?.toString() ?? '';
            if (review.trim().isNotEmpty) {
              final chunk = takeFlush(force: true);
              if (chunk != null) {
                yield mappedText(chunk);
              }
              yield mappedText(review);
            }
          }

          if (!sawAnyDelta && item != null) {
            final itemType = item['type']?.toString();
            if (itemType == 'agentMessage' || itemType == 'assistantMessage') {
              final full = _extractCompletedItemText(item);
              if (full != null && full.isNotEmpty) {
                final chunk = takeFlush(force: true);
                if (chunk != null) {
                  yield mappedText(chunk);
                }
                yield mappedText(full);
                sawAnyDelta = true;
              }
            }
          }
          continue;
        }

        if (notification.method == 'turn/completed') {
          final chunk = takeFlush(force: true);
          if (chunk != null) {
            yield mappedText(chunk);
          }
          final turn = _readTurn(notification.params);
          final completedTurnId =
              turn?['id']?.toString() ??
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
              yield mappedError(message);
            }
            completed = true;
          }
        }
      }

      final tail = takeFlush(force: true);
      if (tail != null) {
        yield mappedText(tail);
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
      yield mappedError(messageForUser);
    } finally {
      _activeRpcClients.remove(runtimeId);
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
      <String, Object?>{'type': 'text', 'text': input?.toString() ?? ''},
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

  CodexTurnEvent? _messagePartEventForNotification(
    JsonRpcNotification notification,
    Map<String, _RuntimeMessagePartInfo> partInfoById,
  ) {
    final method = notification.method;
    if (method == 'item/completed') {
      return null;
    }

    if (method == 'item/started') {
      final item = _readItem(notification.params);
      final info = _messagePartInfoForItem(item);
      if (item == null || info == null) {
        return null;
      }
      final id = _messagePartId(notification.params, info.kind);
      partInfoById[id] = info;
      return CodexTurnEvent.messagePart(
        id: id,
        kind: info.kind,
        title: info.title,
        content: _summarizeStartedItem(item),
        status: _normalizeStatus(item['status']) ?? 'inProgress',
      );
    }

    final isReasoningDelta =
        method == 'item/reasoning/summaryTextDelta' ||
        method == 'item/reasoning/textDelta';
    if (isReasoningDelta) {
      final delta = _extractDelta(notification.params);
      if (delta == null || delta.isEmpty) {
        return null;
      }
      final id = _reasoningPartId(notification.params);
      return CodexTurnEvent.messagePart(
        id: id,
        kind: 'reasoning',
        title: '思考过程',
        content: delta,
        status: 'inProgress',
      );
    }

    if (method == 'item/reasoning/summaryPartAdded') {
      return CodexTurnEvent.messagePart(
        id: _reasoningPartId(notification.params),
        kind: 'reasoning',
        title: '思考过程',
        content: '\n\n',
        status: 'inProgress',
      );
    }

    if (method == 'item/plan/delta') {
      final delta = _extractDelta(notification.params);
      if (delta == null || delta.isEmpty) {
        return null;
      }
      return CodexTurnEvent.messagePart(
        id: _messagePartId(notification.params, 'plan'),
        kind: 'plan',
        title: '计划',
        content: delta,
        status: 'inProgress',
      );
    }

    if (method == 'turn/plan/updated') {
      final text = _summarizePlan(notification.params);
      if (text.isEmpty) {
        return null;
      }
      return CodexTurnEvent.messagePart(
        id: _messagePartId(notification.params, 'plan'),
        kind: 'plan',
        title: '计划',
        content: text,
        status: 'completed',
      );
    }

    if (method == 'item/fileChange/patchUpdated') {
      final content = _extractPatchText(notification.params);
      if (content == null || content.isEmpty) {
        return null;
      }
      final id = _messagePartId(notification.params, 'fileChange');
      final info =
          partInfoById[id] ??
          const _RuntimeMessagePartInfo(kind: 'fileChange', title: '文件变更');
      return CodexTurnEvent.messagePart(
        id: id,
        kind: info.kind,
        title: info.title,
        content: content,
        status: 'inProgress',
      );
    }

    if (method == 'item/mcpToolCall/progress') {
      final content = _summarizeToolProgress(notification.params);
      if (content.isEmpty) {
        return null;
      }
      final id = _messagePartId(notification.params, 'toolCall');
      final info =
          partInfoById[id] ??
          const _RuntimeMessagePartInfo(kind: 'toolCall', title: '工具调用');
      return CodexTurnEvent.messagePart(
        id: id,
        kind: info.kind,
        title: info.title,
        content: content,
        status: 'inProgress',
      );
    }

    if (method.endsWith('/outputDelta')) {
      final delta = _extractDelta(notification.params);
      if (delta == null || delta.isEmpty) {
        return null;
      }
      final id = _messagePartId(
        notification.params,
        method.contains('/commandExecution/')
            ? 'command'
            : method.contains('/fileChange/')
            ? 'fileChange'
            : 'toolCall',
      );
      final info = partInfoById[id] ?? _messagePartInfoForMethod(method);
      return CodexTurnEvent.messagePart(
        id: id,
        kind: info.kind,
        title: info.title,
        content: delta,
        status: 'inProgress',
      );
    }

    return null;
  }

  CodexTurnEvent? _messagePartEventForCompletedItem(
    Object? params,
    Map<Object?, Object?>? item,
    Map<String, _RuntimeMessagePartInfo> partInfoById,
  ) {
    final info = _messagePartInfoForItem(item);
    if (item == null || info == null) {
      return null;
    }
    final id = _messagePartId(params, info.kind);
    partInfoById[id] = info;
    return CodexTurnEvent.messagePart(
      id: id,
      kind: info.kind,
      title: info.title,
      content: _summarizeCompletedItem(item),
      status: _normalizeStatus(item['status']) ?? 'completed',
    );
  }

  _RuntimeMessagePartInfo _messagePartInfoForMethod(String method) {
    if (method.contains('/commandExecution/')) {
      return const _RuntimeMessagePartInfo(kind: 'command', title: '命令执行');
    }
    if (method.contains('/fileChange/')) {
      return const _RuntimeMessagePartInfo(kind: 'fileChange', title: '文件变更');
    }
    if (method.contains('/reasoning/')) {
      return const _RuntimeMessagePartInfo(kind: 'reasoning', title: '思考过程');
    }
    if (method.contains('/plan/')) {
      return const _RuntimeMessagePartInfo(kind: 'plan', title: '计划');
    }
    return const _RuntimeMessagePartInfo(kind: 'toolCall', title: '工具调用');
  }

  _RuntimeMessagePartInfo? _messagePartInfoForItem(
    Map<Object?, Object?>? item,
  ) {
    final type = item?['type']?.toString();
    return switch (type) {
      'commandExecution' => const _RuntimeMessagePartInfo(
        kind: 'command',
        title: '命令执行',
      ),
      'fileChange' => const _RuntimeMessagePartInfo(
        kind: 'fileChange',
        title: '文件变更',
      ),
      'mcpToolCall' || 'collabToolCall' || 'webSearch' =>
        const _RuntimeMessagePartInfo(kind: 'toolCall', title: '工具调用'),
      'reasoning' => const _RuntimeMessagePartInfo(
        kind: 'reasoning',
        title: '思考过程',
      ),
      'plan' => const _RuntimeMessagePartInfo(kind: 'plan', title: '计划'),
      'contextCompaction' || 'modelVerification' =>
        const _RuntimeMessagePartInfo(kind: 'event', title: '运行事件'),
      _ => null,
    };
  }

  String _messagePartId(Object? params, String fallbackKind) {
    final map = _readMap(params);
    final item = _readNestedMap(map, 'item');
    final rawId = map?['itemId'] ?? map?['id'] ?? item?['id'];
    final id = rawId?.toString().trim();
    if (id != null && id.isNotEmpty) {
      return id;
    }
    return '$fallbackKind:${map?['summaryIndex'] ?? 'current'}';
  }

  String _reasoningPartId(Object? params) {
    final map = _readMap(params);
    final itemId = _messagePartId(params, 'reasoning');
    if (itemId != 'reasoning:current') {
      return itemId;
    }
    return 'reasoning:${map?['summaryIndex'] ?? 'current'}';
  }

  String _summarizeStartedItem(Map<Object?, Object?> item) {
    final type = item['type']?.toString();
    if (type == 'commandExecution') {
      final command = _stringFromValue(
        item['command'] ?? item['cmd'] ?? item['argv'],
      );
      final cwd = _stringFromValue(item['cwd']);
      if (command.isEmpty && cwd.isEmpty) {
        return '';
      }
      final buffer = StringBuffer();
      if (command.isNotEmpty) {
        buffer.writeln('\$ $command');
      }
      if (cwd.isNotEmpty) {
        buffer.writeln('cwd: $cwd');
      }
      return buffer.toString();
    }
    if (type == 'fileChange') {
      final path = _stringFromValue(item['path']);
      final kind = _stringFromValue(item['kind']);
      if (path.isEmpty && kind.isEmpty) {
        return '';
      }
      return [if (kind.isNotEmpty) kind, if (path.isNotEmpty) path].join(' ');
    }
    if (type == 'mcpToolCall' || type == 'collabToolCall') {
      final server = _stringFromValue(item['server'] ?? item['serverName']);
      final tool = _stringFromValue(
        item['tool'] ?? item['toolName'] ?? item['name'],
      );
      return [
        if (server.isNotEmpty) server,
        if (tool.isNotEmpty) tool,
      ].join(' / ');
    }
    if (type == 'webSearch') {
      final query = _stringFromValue(item['query']);
      return query.isEmpty ? '正在搜索网页。' : query;
    }
    return _stringFromValue(item['message'] ?? item['title']);
  }

  String _summarizeCompletedItem(Map<Object?, Object?> item) {
    final status = _normalizeStatus(item['status']);
    final output = _stringFromValue(item['output'] ?? item['result']);
    final error = _stringFromValue(
      item['error'] ?? _readNestedMap(item, 'error')?['message'],
    );
    final exitCode = _stringFromValue(item['exitCode']);
    final buffer = StringBuffer();
    if (output.isNotEmpty) {
      buffer.writeln(output);
    }
    if (error.isNotEmpty) {
      buffer.writeln(error);
    }
    if (status == 'failed' && exitCode.isNotEmpty) {
      buffer.writeln('退出码：$exitCode');
    }
    return buffer.toString();
  }

  String _summarizePlan(Object? params) {
    final map = _readMap(params);
    final plan = map?['plan'] ?? map?['items'];
    if (plan is List) {
      final lines = <String>[];
      for (final item in plan) {
        if (item is Map) {
          final step = _stringFromValue(item['step'] ?? item['text']);
          final status = _stringFromValue(item['status']);
          if (step.isNotEmpty) {
            lines.add('- ${status.isEmpty ? step : '[$status] $step'}');
          }
        } else {
          final line = _stringFromValue(item);
          if (line.isNotEmpty) {
            lines.add('- $line');
          }
        }
      }
      return lines.join('\n');
    }
    return _stringFromValue(map?['text'] ?? map?['message']);
  }

  String _summarizeToolProgress(Object? params) {
    final map = _readMap(params);
    return _stringFromValue(
      map?['message'] ?? map?['text'] ?? map?['progress'],
    );
  }

  String? _extractPatchText(Object? params) {
    final map = _readMap(params);
    final direct = _stringFromValue(
      map?['diff'] ?? map?['patch'] ?? map?['text'],
    );
    if (direct.isNotEmpty) {
      return direct;
    }
    final item = _readNestedMap(map, 'item');
    final fromItem = _stringFromValue(item?['diff'] ?? item?['patch']);
    return fromItem.isEmpty ? null : fromItem;
  }

  String? _normalizeStatus(Object? value) {
    final status = value?.toString().trim();
    return status == null || status.isEmpty ? null : status;
  }

  Map<Object?, Object?>? _readMap(Object? value) {
    if (value is! Map) {
      return null;
    }
    return Map<Object?, Object?>.from(value);
  }

  String _stringFromValue(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value.trim();
    }
    if (value is Iterable) {
      return value
          .map(_stringFromValue)
          .where((item) => item.isNotEmpty)
          .join(' ');
    }
    if (value is Map) {
      final text = value['text'] ?? value['message'] ?? value['content'];
      if (text != null) {
        return _stringFromValue(text);
      }
    }
    return value.toString().trim();
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
    final delta = params['delta'] ?? params['chunk'] ?? params['output'];
    if (delta is String) {
      return delta;
    }
    if (delta is Map && delta['text'] is String) {
      return delta['text'] as String;
    }
    if (delta is Map && delta['output'] is String) {
      return delta['output'] as String;
    }
    if (delta is Map && delta['stdout'] is String) {
      return delta['stdout'] as String;
    }
    if (delta is Map && delta['stderr'] is String) {
      return delta['stderr'] as String;
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

  Map<Object?, Object?>? _readNestedMap(
    Map<Object?, Object?>? source,
    String key,
  ) {
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
        item['output'] ??
        _readNestedMap(item, 'message')?['output'] ??
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

class _RuntimeMessagePartInfo {
  const _RuntimeMessagePartInfo({required this.kind, required this.title});

  final String kind;
  final String title;
}
