import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../codex/application/codex_models.dart';
import '../../codex/application/session_turn_coordinator.dart';
import '../../sessions/application/session_models.dart';
import '../../sessions/application/session_store.dart';
import '../../settings/application/codex_settings_store.dart';
import '../../workspaces/application/workspace_models.dart';
import '../../workspaces/application/workspace_store.dart';
import 'lan_pairing_manager.dart';

typedef LanAssetLoader = Future<Uint8List?> Function(String assetKey);

abstract interface class LanAccessHttpServer {
  void Function()? get onStateChanged;

  set onStateChanged(void Function()? callback);

  bool get isRunning;

  String? get address;

  int? get port;

  int get connectedBrowserCount;

  Future<void> start({required String address, required int port});

  Future<void> stop();

  void revokeAllBrowsers();

  Future<void> dispose();
}

class LanHttpServer implements LanAccessHttpServer {
  LanHttpServer({
    required WorkspaceStore workspaceStore,
    required SessionStore sessionStore,
    required CodexSettingsStore settingsStore,
    required SessionTurnCoordinator turnCoordinator,
    required LanPairingManager pairingManager,
    LanAssetLoader? assetLoader,
  }) : _workspaceStore = workspaceStore,
       _sessionStore = sessionStore,
       _settingsStore = settingsStore,
       _turnCoordinator = turnCoordinator,
       _pairingManager = pairingManager,
       _assetLoader = assetLoader ?? _loadRootAsset {
    _socketHandler = webSocketHandler(
      _handleSocketConnected,
      pingInterval: const Duration(seconds: 20),
    );
    _router = _buildRouter();
    _turnSubscription = _turnCoordinator.states.listen((active) {
      _broadcast('turn.state', <String, Object?>{
        'activeTurn': active?.toPublicMap(),
      });
    });
  }

  final WorkspaceStore _workspaceStore;
  final SessionStore _sessionStore;
  final CodexSettingsStore _settingsStore;
  final SessionTurnCoordinator _turnCoordinator;
  final LanPairingManager _pairingManager;
  final LanAssetLoader _assetLoader;
  final Set<WebSocketChannel> _sockets = <WebSocketChannel>{};

  late final Handler _socketHandler;
  late final Router _router;
  late final StreamSubscription<ActiveTurnSnapshot?> _turnSubscription;
  HttpServer? _server;
  String? _address;
  int? _port;
  int _revision = 0;

  @override
  void Function()? onStateChanged;

  @override
  bool get isRunning => _server != null;

  @override
  String? get address => _address;

  @override
  int? get port => _port;

  @override
  int get connectedBrowserCount => _sockets.length;

  String? get origin =>
      _address == null || _port == null ? null : 'http://$_address:$_port';

  Handler get handler => _handleRequest;

  @override
  Future<void> start({required String address, required int port}) async {
    if (_server != null && _address == address && _port == port) {
      return;
    }
    await stop();
    final server = await shelf_io.serve(
      _handleRequest,
      InternetAddress(address),
      port,
      poweredByHeader: null,
    );
    server.idleTimeout = const Duration(minutes: 2);
    _server = server;
    _address = address;
    _port = server.port;
    _pairingManager.ensurePairingCode();
    onStateChanged?.call();
  }

  @override
  Future<void> stop() async {
    final server = _server;
    _server = null;
    _address = null;
    _port = null;
    await _closeSockets(4001, 'CodexM 局域网服务已停止。');
    _pairingManager.revokeAll();
    if (server != null) {
      await server.close(force: true);
    }
    onStateChanged?.call();
  }

  @override
  void revokeAllBrowsers() {
    _pairingManager.revokeAll();
    unawaited(_closeSockets(4003, '浏览器配对已撤销。'));
    onStateChanged?.call();
  }

  Router _buildRouter() {
    final router = Router();
    router
      ..get('/health', _health)
      ..post('/api/v1/auth/pair', _pair)
      ..get('/api/v1/auth/session', _authSession)
      ..post('/api/v1/auth/logout', _logout)
      ..get('/api/v1/bootstrap', _bootstrap)
      ..get(
        '/api/v1/workspaces/<workspaceId>/sessions/<sessionId>/messages',
        _messages,
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

  Future<Response> _handleRequest(Request request) async {
    try {
      final routed = await _router.call(request);
      final response =
          routed.statusCode == HttpStatus.notFound &&
              !request.url.path.startsWith('api/') &&
              request.url.path != 'health'
          ? await _staticAsset(request)
          : routed;
      return _withSecurityHeaders(response);
    } on LanPairingException catch (error) {
      final status = error.code == 'pairing_rate_limited'
          ? HttpStatus.tooManyRequests
          : HttpStatus.unauthorized;
      return _withSecurityHeaders(_error(status, error.code, error.message));
    } on TurnBusyException catch (error) {
      return _withSecurityHeaders(
        _json(HttpStatus.conflict, <String, Object?>{
          'error': <String, Object?>{
            'code': 'turn_busy',
            'message': error.toString(),
            'activeTurn': error.activeTurn?.toPublicMap(),
          },
        }),
      );
    } on FormatException catch (error) {
      return _withSecurityHeaders(
        _error(HttpStatus.badRequest, 'invalid_request', error.message),
      );
    } on ArgumentError catch (error) {
      return _withSecurityHeaders(
        _error(
          HttpStatus.badRequest,
          'invalid_request',
          error.message?.toString() ?? '请求内容无效。',
        ),
      );
    } on StateError catch (error) {
      return _withSecurityHeaders(
        _error(HttpStatus.badRequest, 'operation_failed', error.message),
      );
    } on HijackException {
      rethrow;
    } catch (_) {
      return _withSecurityHeaders(
        _error(
          HttpStatus.internalServerError,
          'internal_error',
          '操作失败，请在手机端查看状态后重试。',
        ),
      );
    }
  }

  Response _health(Request request) {
    return _json(HttpStatus.ok, <String, Object?>{'status': 'ok'});
  }

  Future<Response> _pair(Request request) async {
    final originFailure = _requireOrigin(request);
    if (originFailure != null) {
      return originFailure;
    }
    final body = await _readJson(request);
    final code = body['code']?.toString() ?? '';
    final session = _pairingManager.pair(
      code: code,
      remoteAddress: _remoteAddress(request),
    );
    onStateChanged?.call();
    return _json(
      HttpStatus.ok,
      <String, Object?>{'csrfToken': session.csrfToken},
      headers: <String, String>{
        HttpHeaders.setCookieHeader:
            'codexm_session=${session.token}; Path=/; HttpOnly; SameSite=Strict',
      },
    );
  }

  Response _authSession(Request request) {
    final session = _authenticatedSession(request);
    if (session == null) {
      return _unauthorized();
    }
    return _json(HttpStatus.ok, <String, Object?>{
      'csrfToken': session.csrfToken,
    });
  }

  Response _logout(Request request) {
    final auth = _requireMutationAuth(request);
    if (auth.failure != null) {
      return auth.failure!;
    }
    _pairingManager.revoke(auth.session!.token);
    onStateChanged?.call();
    return _json(
      HttpStatus.ok,
      <String, Object?>{'ok': true},
      headers: const <String, String>{
        HttpHeaders.setCookieHeader:
            'codexm_session=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0',
      },
    );
  }

  Future<Response> _bootstrap(Request request) async {
    final failure = _requireReadAuth(request);
    if (failure != null) {
      return failure;
    }
    final workspaces = await _workspaceStore.listWorkspaces();
    final settings = await _settingsStore.getSettings();
    final workspaceMaps = <Map<String, Object?>>[];
    for (final workspace in workspaces) {
      final sessions = await _sessionStore.listSessions(workspace.id);
      workspaceMaps.add(<String, Object?>{
        'id': workspace.id,
        'name': workspace.name,
        'createdAt': workspace.createdAt,
        'sessions': sessions
            .where((session) => session.archivedAt == null)
            .map(_sessionMap)
            .toList(growable: false),
      });
    }
    return _json(HttpStatus.ok, <String, Object?>{
      'revision': _revision,
      'locale': settings.appLocalePreference,
      'workspaces': workspaceMaps,
      'activeTurn': _turnCoordinator.activeTurn?.toPublicMap(),
    });
  }

  Future<Response> _messages(
    Request request,
    String workspaceId,
    String sessionId,
  ) async {
    final failure = _requireReadAuth(request);
    if (failure != null) {
      return failure;
    }
    await _requireSession(workspaceId, sessionId);
    final all = await _sessionStore.listMessages(workspaceId, sessionId);
    final requestedLimit = int.tryParse(
      request.url.queryParameters['limit'] ?? '100',
    );
    final limit = (requestedLimit ?? 100).clamp(1, 100);
    var end = all.length;
    final before = request.url.queryParameters['before'];
    if (before != null && before.isNotEmpty) {
      final index = all.indexWhere((message) => message.id == before);
      if (index >= 0) {
        end = index;
      }
    }
    final start = math.max(0, end - limit);
    final page = all.sublist(start, end);
    return _json(HttpStatus.ok, <String, Object?>{
      'messages': page.map(_messageMap).toList(growable: false),
      'hasMore': start > 0,
      'nextBefore': start > 0 && page.isNotEmpty ? page.first.id : null,
    });
  }

  Future<Response> _createSession(Request request, String workspaceId) async {
    final auth = _requireMutationAuth(request);
    if (auth.failure != null) {
      return auth.failure!;
    }
    final body = await _readJson(request);
    final title = body['title']?.toString().trim() ?? '';
    if (title.isEmpty || title.length > 80) {
      throw const FormatException('会话名称需要为 1 到 80 个字符。');
    }
    final session = await _turnCoordinator.createSession(
      workspaceId: workspaceId,
      title: title,
    );
    _broadcast('tree.changed', const <String, Object?>{});
    return _json(HttpStatus.created, <String, Object?>{
      'session': _sessionMap(session),
    });
  }

  Future<Response> _updateSession(
    Request request,
    String workspaceId,
    String sessionId,
  ) async {
    final auth = _requireMutationAuth(request);
    if (auth.failure != null) {
      return auth.failure!;
    }
    await _requireSession(workspaceId, sessionId);
    final body = await _readJson(request);
    final rawTitle = body['title'];
    if (rawTitle != null) {
      final title = rawTitle.toString().trim();
      if (title.isEmpty || title.length > 80) {
        throw const FormatException('会话名称需要为 1 到 80 个字符。');
      }
      await _turnCoordinator.renameSession(
        workspaceId: workspaceId,
        sessionId: sessionId,
        title: title,
      );
    }
    final rawMode = body['mode'];
    if (rawMode != null) {
      final mode = _parseMode(rawMode.toString());
      await _turnCoordinator.setSessionMode(
        workspaceId: workspaceId,
        sessionId: sessionId,
        mode: mode,
      );
    }
    final updated = await _requireSession(workspaceId, sessionId);
    _broadcast('tree.changed', const <String, Object?>{});
    return _json(HttpStatus.ok, <String, Object?>{
      'session': _sessionMap(updated),
    });
  }

  Future<Response> _startTurn(
    Request request,
    String workspaceId,
    String sessionId,
  ) async {
    final auth = _requireMutationAuth(request);
    if (auth.failure != null) {
      return auth.failure!;
    }
    final workspace = await _workspaceStore.getWorkspace(workspaceId);
    if (workspace == null) {
      throw StateError('工作区不存在。');
    }
    var session = await _requireSession(workspaceId, sessionId);
    final body = await _readJson(request);
    final text = body['text']?.toString().trim() ?? '';
    if (text.isEmpty || text.length > 32768) {
      throw const FormatException('消息需要为 1 到 32768 个字符。');
    }
    final mode = body['mode'] == null
        ? _modeFromSession(session)
        : _parseMode(body['mode'].toString());
    if (session.codexCollaborationMode != mode.wireValue) {
      await _turnCoordinator.setSessionMode(
        workspaceId: workspaceId,
        sessionId: sessionId,
        mode: mode,
      );
      session = await _requireSession(workspaceId, sessionId);
    }
    final turnText = mode == CodexCollaborationMode.plan
        ? '你处于计划模式。请先输出一个可执行的计划（步骤、依赖、风险、验证方式），在我确认前不要执行命令或修改文件。\n\n任务：$text'
        : text;
    final started = Completer<ActiveTurnSnapshot>();
    final resultFuture = _turnCoordinator.runTurn(
      CoordinatedTurnRequest(
        workspace: workspace,
        session: session,
        origin: TurnOrigin.web,
        pendingStatus: '正在向 Codex 发送消息...',
        successStatus: '本轮会话已完成。',
        userMessage: text,
        input: <CodexInputElement>[
          <String, Object?>{'type': 'text', 'text': turnText},
        ],
        collaborationMode: mode,
      ),
      onStarted: (snapshot) {
        if (!started.isCompleted) {
          started.complete(snapshot);
        }
      },
    );
    unawaited(
      resultFuture.then<void>(
        (_) => _broadcast('data.changed', const <String, Object?>{}),
        onError: (Object error, StackTrace stackTrace) {
          if (!started.isCompleted) {
            started.completeError(error, stackTrace);
          }
          _broadcast('data.changed', const <String, Object?>{});
        },
      ),
    );
    final snapshot = await started.future;
    return _json(HttpStatus.accepted, <String, Object?>{
      'turnId': snapshot.turnId,
    });
  }

  Future<Response> _stopTurn(Request request, String turnId) async {
    final auth = _requireMutationAuth(request);
    if (auth.failure != null) {
      return auth.failure!;
    }
    final active = _turnCoordinator.activeTurn;
    if (active == null || active.turnId != turnId) {
      return _error(HttpStatus.notFound, 'turn_not_found', '当前轮次已经结束。');
    }
    unawaited(_turnCoordinator.cancelActiveTurn(turnId: turnId));
    return _json(HttpStatus.accepted, <String, Object?>{'ok': true});
  }

  FutureOr<Response> _events(Request request) {
    final failure = _requireReadAuth(request) ?? _requireOrigin(request);
    if (failure != null) {
      return failure;
    }
    return _socketHandler(request);
  }

  void _handleSocketConnected(WebSocketChannel socket, String? subProtocol) {
    _sockets.add(socket);
    onStateChanged?.call();
    socket.sink.add(
      jsonEncode(<String, Object?>{
        'type': 'hello',
        'revision': _revision,
        'payload': <String, Object?>{
          'activeTurn': _turnCoordinator.activeTurn?.toPublicMap(),
        },
      }),
    );
    socket.stream.listen(
      (_) {},
      onError: (_) => _removeSocket(socket),
      onDone: () => _removeSocket(socket),
      cancelOnError: true,
    );
  }

  Future<Response> _staticAsset(Request request) async {
    final path = request.url.path;
    final route = path.isEmpty || path == '/'
        ? 'index.html'
        : path.startsWith('/')
        ? path.substring(1)
        : path;
    const allowed = <String>{
      'index.html',
      'styles.css',
      'app.js',
      'vendor/marked.min.js',
      'vendor/purify.min.js',
      'app-icon.png',
    };
    if (!allowed.contains(route)) {
      return Response.notFound('Not found');
    }
    final assetKey = route == 'app-icon.png'
        ? 'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png'
        : 'assets/lan_web/$route';
    final bytes = await _assetLoader(assetKey);
    if (bytes == null) {
      return Response.notFound('Not found');
    }
    return Response.ok(
      bytes,
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: _contentType(route),
        HttpHeaders.cacheControlHeader: route == 'index.html'
            ? 'no-store'
            : 'public, max-age=3600',
      },
    );
  }

  Future<Map<String, Object?>> _readJson(Request request) async {
    final contentType = request.headers[HttpHeaders.contentTypeHeader] ?? '';
    if (!contentType.toLowerCase().startsWith('application/json')) {
      throw const FormatException('请求必须使用 JSON。');
    }
    const maxBytes = 65536;
    final bytes = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in request.read()) {
      length += chunk.length;
      if (length > maxBytes) {
        throw const FormatException('请求内容过大。');
      }
      bytes.add(chunk);
    }
    final parsed = jsonDecode(utf8.decode(bytes.takeBytes()));
    if (parsed is! Map) {
      throw const FormatException('JSON 内容必须是对象。');
    }
    return Map<String, Object?>.from(parsed);
  }

  Response? _requireReadAuth(Request request) {
    return _authenticatedSession(request) == null ? _unauthorized() : null;
  }

  ({LanBrowserSession? session, Response? failure}) _requireMutationAuth(
    Request request,
  ) {
    final originFailure = _requireOrigin(request);
    if (originFailure != null) {
      return (session: null, failure: originFailure);
    }
    final session = _authenticatedSession(request);
    if (session == null) {
      return (session: null, failure: _unauthorized());
    }
    final csrf = request.headers['x-codexm-csrf'] ?? '';
    if (csrf != session.csrfToken) {
      return (
        session: null,
        failure: _error(
          HttpStatus.forbidden,
          'csrf_invalid',
          '页面凭证已失效，请刷新后重试。',
        ),
      );
    }
    return (session: session, failure: null);
  }

  Response? _requireOrigin(Request request) {
    final expected = origin;
    final actual = request.headers['origin'];
    if (expected == null || actual != expected) {
      return _error(HttpStatus.forbidden, 'origin_invalid', '请求来源不受信任。');
    }
    return null;
  }

  LanBrowserSession? _authenticatedSession(Request request) {
    return _pairingManager.findSession(
      _cookieValue(request.headers[HttpHeaders.cookieHeader], 'codexm_session'),
    );
  }

  Future<Session> _requireSession(
    WorkspaceId workspaceId,
    SessionId sessionId,
  ) async {
    final session = await _sessionStore.getSession(workspaceId, sessionId);
    if (session == null || session.archivedAt != null) {
      throw StateError('会话不存在。');
    }
    return session;
  }

  CodexCollaborationMode _parseMode(String value) {
    return switch (value.trim()) {
      'plan' => CodexCollaborationMode.plan,
      'standard' || 'default' => CodexCollaborationMode.standard,
      _ => throw const FormatException('不支持的会话模式。'),
    };
  }

  CodexCollaborationMode _modeFromSession(Session session) {
    return session.codexCollaborationMode == 'plan'
        ? CodexCollaborationMode.plan
        : CodexCollaborationMode.standard;
  }

  Map<String, Object?> _sessionMap(Session session) {
    return <String, Object?>{
      'id': session.id,
      'workspaceId': session.workspaceId,
      'title': session.title,
      'createdAt': session.createdAt,
      'updatedAt': session.updatedAt,
      'mode': session.codexCollaborationMode == 'plan' ? 'plan' : 'standard',
      'codeState': session.codeState.name,
    };
  }

  Map<String, Object?> _messageMap(ChatMessage message) {
    return <String, Object?>{
      'id': message.id,
      'sessionId': message.sessionId,
      'workspaceId': message.workspaceId,
      'role': message.role,
      'createdAt': message.createdAt,
      'content': message.content,
      'parts': message.parts
          .map((part) => part.toMap())
          .toList(growable: false),
    };
  }

  void _broadcast(String type, Map<String, Object?> payload) {
    _revision += 1;
    final encoded = jsonEncode(<String, Object?>{
      'type': type,
      'revision': _revision,
      'payload': payload,
    });
    for (final socket in _sockets.toList(growable: false)) {
      try {
        socket.sink.add(encoded);
      } catch (_) {
        _removeSocket(socket);
      }
    }
  }

  void _removeSocket(WebSocketChannel socket) {
    if (_sockets.remove(socket)) {
      onStateChanged?.call();
    }
  }

  Future<void> _closeSockets(int code, String reason) async {
    final sockets = _sockets.toList(growable: false);
    _sockets.clear();
    for (final socket in sockets) {
      try {
        await socket.sink
            .close(code, reason)
            .timeout(const Duration(seconds: 2));
      } catch (_) {
        // Socket is already gone.
      }
    }
  }

  String _remoteAddress(Request request) {
    final info = request.context['shelf.io.connection_info'];
    return info is HttpConnectionInfo ? info.remoteAddress.address : 'unknown';
  }

  String? _cookieValue(String? header, String name) {
    if (header == null) {
      return null;
    }
    for (final item in header.split(';')) {
      final separator = item.indexOf('=');
      if (separator <= 0) {
        continue;
      }
      if (item.substring(0, separator).trim() == name) {
        return item.substring(separator + 1).trim();
      }
    }
    return null;
  }

  Response _unauthorized() {
    return _error(HttpStatus.unauthorized, 'auth_required', '请先使用手机上的配对码连接。');
  }

  Response _error(int status, String code, String message) {
    return _json(status, <String, Object?>{
      'error': <String, Object?>{'code': code, 'message': message},
    });
  }

  Response _json(
    int status,
    Map<String, Object?> body, {
    Map<String, String>? headers,
  }) {
    return Response(
      status,
      body: jsonEncode(body),
      headers: <String, String>{
        HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8',
        HttpHeaders.cacheControlHeader: 'no-store',
        ...?headers,
      },
    );
  }

  Response _withSecurityHeaders(Response response) {
    return response.change(
      headers: <String, String>{
        ...response.headers,
        'content-security-policy':
            "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self' ws:; frame-ancestors 'none'; base-uri 'none'; form-action 'self'",
        'x-content-type-options': 'nosniff',
        'x-frame-options': 'DENY',
        'referrer-policy': 'no-referrer',
        'permissions-policy': 'camera=(), microphone=(), geolocation=()',
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

  static Future<Uint8List?> _loadRootAsset(String assetKey) async {
    try {
      final data = await rootBundle.load(assetKey);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    await _turnSubscription.cancel();
  }
}
