import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

Future<void> main(List<String> arguments) async {
  final preview = _LanWebPreview();
  final port = _parsePort(arguments);
  final server = await shelf_io.serve(
    preview.handler,
    InternetAddress.loopbackIPv4,
    port,
    poweredByHeader: null,
  );
  stdout.writeln('CodexM LAN Web preview: http://127.0.0.1:${server.port}');

  ProcessSignal.sigint.watch().listen((_) async {
    await preview.dispose();
    await server.close(force: true);
    exit(0);
  });
}

int _parsePort(List<String> arguments) {
  for (var index = 0; index < arguments.length; index += 1) {
    final argument = arguments[index];
    if (argument.startsWith('--port=')) {
      return int.tryParse(argument.substring('--port='.length)) ?? 4173;
    }
    if (argument == '--port' && index + 1 < arguments.length) {
      return int.tryParse(arguments[index + 1]) ?? 4173;
    }
  }
  return 4173;
}

class _LanWebPreview {
  _LanWebPreview() {
    _socketHandler = webSocketHandler(_onSocketConnected);
    _router = _buildRouter();
  }

  final Set<WebSocketChannel> _sockets = <WebSocketChannel>{};
  final List<Map<String, Object?>> _sessions = <Map<String, Object?>>[
    <String, Object?>{
      'id': 'session-lan',
      'workspaceId': 'workspace-codexm',
      'title': '局域网 Web 工作台',
      'createdAt': 1755705600000,
      'updatedAt': 1755792000000,
      'mode': 'standard',
      'codeState': 'ready',
    },
    <String, Object?>{
      'id': 'session-runtime',
      'workspaceId': 'workspace-codexm',
      'title': 'Android Runtime 打包',
      'createdAt': 1755532800000,
      'updatedAt': 1755705600000,
      'mode': 'plan',
      'codeState': 'ready',
    },
    <String, Object?>{
      'id': 'session-ui',
      'workspaceId': 'workspace-codexm',
      'title': '会话页面细节',
      'createdAt': 1755360000000,
      'updatedAt': 1755619200000,
      'mode': 'standard',
      'codeState': 'ready',
    },
  ];
  final Map<String, List<Map<String, Object?>>> _messages =
      <String, List<Map<String, Object?>>>{
        'session-lan': <Map<String, Object?>>[
          <String, Object?>{
            'id': 'message-1',
            'sessionId': 'session-lan',
            'workspaceId': 'workspace-codexm',
            'role': 'user',
            'createdAt': 1755792120000,
            'content': '新增局域网浏览器工作台，并保持手机端与网页端共享会话状态。',
            'parts': const <Object?>[],
          },
          <String, Object?>{
            'id': 'message-2',
            'sessionId': 'session-lan',
            'workspaceId': 'workspace-codexm',
            'role': 'assistant',
            'createdAt': 1755792180000,
            'content': '''已完成核心链路，并补齐了安全边界。

### 当前能力

- 通过一次性配对码连接浏览器
- 浏览工作区、会话与历史消息
- 普通 / 计划模式和流式输出
- 手机端与网页端共用全局 turn 锁

所有浏览器 API 都不会返回真实路径、线程 ID 或连接凭据。''',
            'parts': <Object?>[
              <String, Object?>{
                'id': 'part-command',
                'kind': 'command',
                'title': '验证 Flutter 测试',
                'content': r'''$ flutter test test/features/lan_access
00:04 +15: All tests passed!''',
                'status': 'completed',
              },
            ],
          },
          <String, Object?>{
            'id': 'message-3',
            'sessionId': 'session-lan',
            'workspaceId': 'workspace-codexm',
            'role': 'system',
            'createdAt': 1755792240000,
            'content': '浏览器已通过本机预览服务连接。',
            'parts': const <Object?>[],
          },
        ],
        'session-runtime': <Map<String, Object?>>[],
        'session-ui': <Map<String, Object?>>[],
      };

  late final Handler _socketHandler;
  late final Router _router;
  final String _csrfToken = 'preview-csrf-token';
  int _revision = 0;
  int _nextSession = 1;
  int _nextTurn = 1;
  int _turnGeneration = 0;
  Map<String, Object?>? _activeTurn;

  Handler get handler => _handle;

  Router _buildRouter() {
    final router = Router();
    router
      ..get('/api/v1/auth/session', _authSession)
      ..post('/api/v1/auth/pair', _authSession)
      ..post('/api/v1/auth/logout', _ok)
      ..get('/api/v1/bootstrap', _bootstrap)
      ..get(
        '/api/v1/workspaces/<workspaceId>/sessions/<sessionId>/messages',
        _sessionMessages,
      )
      ..post('/api/v1/workspaces/<workspaceId>/sessions', _createSession)
      ..patch(
        '/api/v1/workspaces/<workspaceId>/sessions/<sessionId>',
        _updateSession,
      )
      ..post(
        '/api/v1/workspaces/<workspaceId>/sessions/<sessionId>/turns',
        _startTurn,
      )
      ..delete('/api/v1/turns/<turnId>', _stopTurn)
      ..get('/api/v1/events', _events);
    return router;
  }

  Future<Response> _handle(Request request) async {
    final response = await _router.call(request);
    if (response.statusCode != HttpStatus.notFound ||
        request.url.path.startsWith('api/')) {
      return response;
    }
    return _asset(request.url.path);
  }

  Response _authSession(Request request) =>
      _json(<String, Object?>{'csrfToken': _csrfToken});

  Response _ok(Request request) => _json(const <String, Object?>{'ok': true});

  Response _bootstrap(Request request) {
    return _json(<String, Object?>{
      'revision': _revision,
      'locale': 'zh_Hans',
      'workspaces': <Object?>[
        <String, Object?>{
          'id': 'workspace-codexm',
          'name': 'CodexM',
          'createdAt': 1755273600000,
          'sessions': _sessions,
        },
        <String, Object?>{
          'id': 'workspace-notes',
          'name': '产品笔记',
          'createdAt': 1755100800000,
          'sessions': <Object?>[
            <String, Object?>{
              'id': 'session-roadmap',
              'workspaceId': 'workspace-notes',
              'title': '下一版本路线',
              'createdAt': 1755100800000,
              'updatedAt': 1755446400000,
              'mode': 'standard',
              'codeState': 'ready',
            },
          ],
        },
      ],
      'activeTurn': _activeTurn,
    });
  }

  Response _sessionMessages(
    Request request,
    String workspaceId,
    String sessionId,
  ) {
    return _json(<String, Object?>{
      'messages': _messages[sessionId] ?? const <Object?>[],
      'hasMore': false,
      'nextBefore': null,
    });
  }

  Future<Response> _createSession(Request request, String workspaceId) async {
    final body = await _readJson(request);
    final now = DateTime.now().millisecondsSinceEpoch;
    final session = <String, Object?>{
      'id': 'session-preview-${_nextSession++}',
      'workspaceId': workspaceId,
      'title': body['title']?.toString() ?? '新会话',
      'createdAt': now,
      'updatedAt': now,
      'mode': 'standard',
      'codeState': 'ready',
    };
    if (workspaceId == 'workspace-codexm') _sessions.insert(0, session);
    _messages[session['id']! as String] = <Map<String, Object?>>[];
    _broadcast('tree.changed', const <String, Object?>{});
    return _json(<String, Object?>{'session': session}, status: 201);
  }

  Future<Response> _updateSession(
    Request request,
    String workspaceId,
    String sessionId,
  ) async {
    final body = await _readJson(request);
    final session = _sessionById(sessionId);
    if (session == null) return Response.notFound('Session not found');
    if (body['title'] != null) session['title'] = body['title'].toString();
    if (body['mode'] != null) session['mode'] = body['mode'].toString();
    session['updatedAt'] = DateTime.now().millisecondsSinceEpoch;
    _broadcast('tree.changed', const <String, Object?>{});
    return _json(<String, Object?>{'session': session});
  }

  Future<Response> _startTurn(
    Request request,
    String workspaceId,
    String sessionId,
  ) async {
    final body = await _readJson(request);
    final session = _sessionById(sessionId);
    if (session == null) return Response.notFound('Session not found');
    final generation = ++_turnGeneration;
    final now = DateTime.now().millisecondsSinceEpoch;
    final turnId = 'preview-turn-${_nextTurn++}';
    (_messages[sessionId] ??= <Map<String, Object?>>[]).add(<String, Object?>{
      'id': 'preview-user-$now',
      'sessionId': sessionId,
      'workspaceId': workspaceId,
      'role': 'user',
      'createdAt': now,
      'content': body['text']?.toString() ?? '',
      'parts': const <Object?>[],
    });
    _activeTurn = <String, Object?>{
      'turnId': turnId,
      'workspaceId': workspaceId,
      'workspaceName': workspaceId == 'workspace-codexm' ? 'CodexM' : '产品笔记',
      'sessionId': sessionId,
      'sessionTitle': session['title'],
      'origin': 'web',
      'startedAt': now,
      'phase': 'running',
      'pendingStatus': '正在生成回复...',
      'assistantText': '',
      'assistantParts': const <Object?>[],
      'runtimeStatus': null,
      'runtimeStatusIsRetrying': false,
    };
    _broadcastTurnState();
    _schedulePreviewTurn(generation, workspaceId, sessionId, now);
    return _json(<String, Object?>{'turnId': turnId}, status: 202);
  }

  void _schedulePreviewTurn(
    int generation,
    String workspaceId,
    String sessionId,
    int startedAt,
  ) {
    Timer(const Duration(milliseconds: 280), () {
      if (generation != _turnGeneration || _activeTurn == null) return;
      _activeTurn!['assistantText'] = '我正在通过局域网预览通道处理这条消息。';
      _broadcastTurnState();
    });
    Timer(const Duration(milliseconds: 760), () {
      if (generation != _turnGeneration || _activeTurn == null) return;
      const reply = '''我正在通过局域网预览通道处理这条消息。

这段输出模拟真实 Codex Runtime 的流式回复；手机端构建中会由共享协调器持久化最终消息。''';
      _activeTurn!['assistantText'] = reply;
      _broadcastTurnState();
    });
    Timer(const Duration(milliseconds: 1150), () {
      if (generation != _turnGeneration || _activeTurn == null) return;
      final reply = _activeTurn!['assistantText']?.toString() ?? '';
      (_messages[sessionId] ??= <Map<String, Object?>>[]).add(<String, Object?>{
        'id': 'preview-assistant-$startedAt',
        'sessionId': sessionId,
        'workspaceId': workspaceId,
        'role': 'assistant',
        'createdAt': startedAt,
        'content': reply,
        'parts': const <Object?>[],
      });
      _activeTurn = null;
      _broadcastTurnState();
      _broadcast('data.changed', const <String, Object?>{});
    });
  }

  Response _stopTurn(Request request, String turnId) {
    final active = _activeTurn;
    if (active != null && active['turnId'] == turnId) {
      _turnGeneration += 1;
      final sessionId = active['sessionId']! as String;
      final workspaceId = active['workspaceId']! as String;
      final partial = active['assistantText']?.toString() ?? '';
      if (partial.isNotEmpty) {
        (_messages[sessionId] ??= <Map<String, Object?>>[])
            .add(<String, Object?>{
              'id': 'preview-partial-${DateTime.now().microsecondsSinceEpoch}',
              'sessionId': sessionId,
              'workspaceId': workspaceId,
              'role': 'assistant',
              'createdAt': active['startedAt'],
              'content': partial,
              'parts': const <Object?>[],
            });
      }
      (_messages[sessionId] ??= <Map<String, Object?>>[]).add(<String, Object?>{
        'id': 'preview-stopped-${DateTime.now().microsecondsSinceEpoch}',
        'sessionId': sessionId,
        'workspaceId': workspaceId,
        'role': 'system',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'content': '本轮已停止。已发生的项目修改不会自动撤销。',
        'parts': const <Object?>[],
      });
      _activeTurn = null;
      _broadcastTurnState();
      _broadcast('data.changed', const <String, Object?>{});
    }
    return _json(const <String, Object?>{'ok': true}, status: 202);
  }

  FutureOr<Response> _events(Request request) => _socketHandler(request);

  void _onSocketConnected(WebSocketChannel socket, String? protocol) {
    _sockets.add(socket);
    socket.sink.add(
      jsonEncode(<String, Object?>{
        'type': 'hello',
        'revision': _revision,
        'payload': <String, Object?>{'activeTurn': _activeTurn},
      }),
    );
    socket.stream.listen(
      (_) {},
      onError: (_) => _sockets.remove(socket),
      onDone: () => _sockets.remove(socket),
    );
  }

  void _broadcastTurnState() {
    _broadcast('turn.state', <String, Object?>{'activeTurn': _activeTurn});
  }

  void _broadcast(String type, Map<String, Object?> payload) {
    final encoded = jsonEncode(<String, Object?>{
      'type': type,
      'revision': ++_revision,
      'payload': payload,
    });
    for (final socket in _sockets.toList(growable: false)) {
      socket.sink.add(encoded);
    }
  }

  Map<String, Object?>? _sessionById(String id) {
    for (final session in _sessions) {
      if (session['id'] == id) return session;
    }
    return null;
  }

  Future<Map<String, Object?>> _readJson(Request request) async {
    final parsed = jsonDecode(await request.readAsString());
    return Map<String, Object?>.from(parsed as Map);
  }

  Response _asset(String requestedPath) {
    final path = requestedPath.isEmpty || requestedPath == '/'
        ? 'index.html'
        : requestedPath.replaceFirst(RegExp(r'^/'), '');
    const assets = <String>{
      'index.html',
      'styles.css',
      'app.js',
      'vendor/marked.min.js',
      'vendor/purify.min.js',
      'app-icon.png',
    };
    if (!assets.contains(path)) return Response.notFound('Not found');
    final flutterRoot = File.fromUri(Platform.script).parent.parent;
    final file = path == 'app-icon.png'
        ? File(
            '${flutterRoot.path}/android/app/src/main/res/'
            'mipmap-xxxhdpi/ic_launcher.png',
          )
        : File('${flutterRoot.path}/assets/lan_web/$path');
    if (!file.existsSync()) return Response.notFound('Not found');
    return Response.ok(
      file.openRead(),
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: _contentType(path),
        HttpHeaders.cacheControlHeader: 'no-store',
      },
    );
  }

  String _contentType(String path) {
    if (path.endsWith('.html')) return 'text/html; charset=utf-8';
    if (path.endsWith('.css')) return 'text/css; charset=utf-8';
    if (path.endsWith('.js')) return 'text/javascript; charset=utf-8';
    if (path.endsWith('.png')) return 'image/png';
    return 'application/octet-stream';
  }

  Response _json(Map<String, Object?> body, {int status = 200}) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: const <String, String>{
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        HttpHeaders.cacheControlHeader: 'no-store',
      },
    );
  }

  Future<void> dispose() async {
    final sockets = _sockets.toList(growable: false);
    _sockets.clear();
    for (final socket in sockets) {
      await socket.sink.close(4001, 'Preview stopped');
    }
  }
}
