import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:codexm_flutter/features/codex/application/session_turn_coordinator.dart';
import 'package:codexm_flutter/features/lan_access/application/lan_http_server.dart';
import 'package:codexm_flutter/features/lan_access/application/lan_pairing_manager.dart';
import 'package:codexm_flutter/features/sessions/application/session_code_workspace_service.dart';
import 'package:codexm_flutter/features/sessions/application/session_models.dart';
import 'package:codexm_flutter/features/sessions/application/session_store.dart';
import 'package:codexm_flutter/features/settings/application/codex_settings_store.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_models.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_paths.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_store.dart';
import 'package:codexm_flutter/shared/persistence/app_directory_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LanHttpServer', () {
    late _HttpFixture fixture;

    setUp(() async {
      fixture = await _HttpFixture.create();
    });

    tearDown(() => fixture.dispose());

    test('serves local assets with browser security headers', () async {
      final response = await fixture.request('GET', '/');

      expect(response.statusCode, HttpStatus.ok);
      expect(response.body, contains('<title>CodexM test</title>'));
      expect(
        response.headers['content-security-policy'],
        contains("default-src 'self'"),
      );
      expect(response.headers['x-content-type-options'], 'nosniff');
      expect(response.headers['x-frame-options'], 'DENY');
      expect(response.headers['referrer-policy'], 'no-referrer');
      expect(response.headers['permissions-policy'], contains('camera=()'));
      expect(response.headers[HttpHeaders.serverHeader], isNull);
    });

    test('pairs once, enforces origin and CSRF, and redacts bootstrap', () async {
      final rejected = await fixture.request(
        'POST',
        '/api/v1/auth/pair',
        headers: const <String, String>{'origin': 'http://attacker.invalid'},
        jsonBody: <String, Object?>{'code': fixture.pairingManager.pairingCode},
      );
      expect(rejected.statusCode, HttpStatus.forbidden);
      expect(rejected.json['error'], containsPair('code', 'origin_invalid'));

      final auth = await fixture.pair();
      final missingCsrf = await fixture.request(
        'PATCH',
        '/api/v1/workspaces/${fixture.workspace.id}/sessions/${fixture.session.id}',
        headers: <String, String>{
          HttpHeaders.cookieHeader: auth.cookie,
          'origin': fixture.origin,
        },
        jsonBody: const <String, Object?>{'title': '不应保存'},
      );
      expect(missingCsrf.statusCode, HttpStatus.forbidden);
      expect(missingCsrf.json['error'], containsPair('code', 'csrf_invalid'));

      final bootstrap = await fixture.request(
        'GET',
        '/api/v1/bootstrap',
        headers: <String, String>{HttpHeaders.cookieHeader: auth.cookie},
      );
      expect(bootstrap.statusCode, HttpStatus.ok);
      expect(bootstrap.json['locale'], 'zh_Hans');
      expect(bootstrap.body, contains('私密工作区'));
      expect(bootstrap.body, isNot(contains('/private/device/path')));
      expect(bootstrap.body, isNot(contains('thread-private-value')));
      expect(bootstrap.body, isNot(contains('api-key-private-value')));
      expect(bootstrap.body, isNot(contains('auth-ref-private-value')));
      expect(bootstrap.body, isNot(contains('openaiBaseUrl')));
      expect(bootstrap.body, isNot(contains('localPath')));
      expect(bootstrap.body, isNot(contains('codexThreadId')));

      final renamed = await fixture.request(
        'PATCH',
        '/api/v1/workspaces/${fixture.workspace.id}/sessions/${fixture.session.id}',
        headers: <String, String>{
          HttpHeaders.cookieHeader: auth.cookie,
          'x-codexm-csrf': auth.csrfToken,
          'origin': fixture.origin,
        },
        jsonBody: const <String, Object?>{'title': '网页重命名', 'mode': 'plan'},
      );
      expect(renamed.statusCode, HttpStatus.ok);
      final renamedSession = renamed.json['session']! as Map<String, dynamic>;
      expect(renamedSession['title'], '网页重命名');
      expect(renamedSession['mode'], 'plan');
    });

    test('authorizes WebSocket hello and revokes sessions on stop', () async {
      final auth = await fixture.pair();
      final socket = await WebSocket.connect(
        'ws://127.0.0.1:${fixture.server.port}/api/v1/events',
        headers: <String, String>{
          HttpHeaders.cookieHeader: auth.cookie,
          'origin': fixture.origin,
        },
      );
      final helloReceived = Completer<Map<String, dynamic>>();
      final socketClosed = Completer<void>();
      final subscription = socket.listen(
        (event) {
          if (!helloReceived.isCompleted && event is String) {
            helloReceived.complete(jsonDecode(event) as Map<String, dynamic>);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!helloReceived.isCompleted) {
            helloReceived.completeError(error, stackTrace);
          }
        },
        onDone: socketClosed.complete,
      );
      final hello = await helloReceived.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError('WebSocket hello was not received.'),
      );
      expect(hello['type'], 'hello');
      expect(hello['revision'], isA<int>());

      await fixture.server.stop().timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError('LAN server did not stop.'),
      );
      await socketClosed.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError('WebSocket close was not received.'),
      );
      expect(socket.closeCode, 4001);
      expect(fixture.pairingManager.sessionCount, 0);

      await fixture.server.start(address: '127.0.0.1', port: 0);
      final staleSession = await fixture.request(
        'GET',
        '/api/v1/bootstrap',
        headers: <String, String>{HttpHeaders.cookieHeader: auth.cookie},
      );
      expect(staleSession.statusCode, HttpStatus.unauthorized);
      await subscription.cancel();
    });

    test(
      'disconnects paired WebSockets when all browsers are revoked',
      () async {
        final auth = await fixture.pair();
        final socket = await WebSocket.connect(
          'ws://127.0.0.1:${fixture.server.port}/api/v1/events',
          headers: <String, String>{
            HttpHeaders.cookieHeader: auth.cookie,
            'origin': fixture.origin,
          },
        );
        final helloReceived = Completer<void>();
        final socketClosed = Completer<void>();
        final subscription = socket.listen((_) {
          if (!helloReceived.isCompleted) helloReceived.complete();
        }, onDone: socketClosed.complete);
        await helloReceived.future.timeout(const Duration(seconds: 3));

        fixture.server.revokeAllBrowsers();
        await socketClosed.future.timeout(const Duration(seconds: 3));

        expect(socket.closeCode, 4003);
        expect(fixture.pairingManager.sessionCount, 0);
        final staleSession = await fixture.request(
          'GET',
          '/api/v1/bootstrap',
          headers: <String, String>{HttpHeaders.cookieHeader: auth.cookie},
        );
        expect(staleSession.statusCode, HttpStatus.unauthorized);
        await subscription.cancel();
      },
    );
  });
}

class _HttpFixture {
  _HttpFixture._({
    required this.documents,
    required this.temporary,
    required this.workspace,
    required this.session,
    required this.pairingManager,
    required this.coordinator,
    required this.server,
  });

  final Directory documents;
  final Directory temporary;
  final Workspace workspace;
  final Session session;
  final LanPairingManager pairingManager;
  final SessionTurnCoordinator coordinator;
  final LanHttpServer server;
  final HttpClient _client = HttpClient();

  String get origin => server.origin!;

  static Future<_HttpFixture> create() async {
    final documents = await Directory.systemTemp.createTemp(
      'codexm_http_docs_',
    );
    final temporary = await Directory.systemTemp.createTemp('codexm_http_tmp_');
    final appDirectories = AppDirectoryService(
      documentsResolver: () async => documents,
      temporaryResolver: () async => temporary,
    );
    final workspaceDirectories = WorkspaceDirectoryService(
      appDirectoryService: appDirectories,
    );
    final workspaceStore = WorkspaceStore(
      appDirectoryService: appDirectories,
      workspaceDirectoryService: workspaceDirectories,
    );
    final sessionStore = SessionStore(
      workspaceDirectoryService: workspaceDirectories,
    );
    const workspace = Workspace(
      id: 'workspace-private',
      name: '私密工作区',
      createdAt: 10,
      localPath: '/private/device/path/',
      integrationBranch: 'main',
      sessionGitVersion: 1,
      git: WorkspaceGitConfig(
        remoteUrl: 'https://private.invalid/repository.git',
        authRef: 'git-auth-private-value',
      ),
      webdav: WorkspaceWebDavConfig(
        endpoint: 'https://private.invalid/webdav',
        authRef: 'webdav-auth-private-value',
      ),
    );
    await workspaceStore.upsertWorkspace(workspace);
    final session = await sessionStore.createSession(
      workspace.id,
      title: '本机会话',
      branchName: 'codexm/session/private',
      codeState: SessionCodeState.ready,
    );
    await sessionStore.setSessionCodexThreadId(
      workspace.id,
      session.id,
      'thread-private-value',
    );
    await sessionStore.appendMessage(
      workspace.id,
      session.id,
      role: 'user',
      content: '历史消息',
    );

    final settingsStore = _PrivateSettingsStore();
    final pairingManager = LanPairingManager(random: Random(7));
    final coordinator = SessionTurnCoordinator(
      workspaceStore: workspaceStore,
      sessionStore: sessionStore,
      codeWorkspaceService: _TestCodeWorkspaceService(sessionStore),
      settingsStore: settingsStore,
    );
    final server = LanHttpServer(
      workspaceStore: workspaceStore,
      sessionStore: sessionStore,
      settingsStore: settingsStore,
      turnCoordinator: coordinator,
      pairingManager: pairingManager,
      assetLoader: (assetKey) async {
        if (assetKey.endsWith('index.html')) {
          return Uint8List.fromList(
            utf8.encode('<!doctype html><title>CodexM test</title>'),
          );
        }
        return null;
      },
    );
    await server.start(address: '127.0.0.1', port: 0);
    return _HttpFixture._(
      documents: documents,
      temporary: temporary,
      workspace: workspace,
      session: session,
      pairingManager: pairingManager,
      coordinator: coordinator,
      server: server,
    );
  }

  Future<_BrowserAuth> pair() async {
    final response = await request(
      'POST',
      '/api/v1/auth/pair',
      headers: <String, String>{'origin': origin},
      jsonBody: <String, Object?>{'code': pairingManager.pairingCode},
    );
    expect(response.statusCode, HttpStatus.ok);
    final setCookie = response.headers[HttpHeaders.setCookieHeader];
    expect(setCookie, isNotNull);
    return _BrowserAuth(
      cookie: setCookie!.split(';').first,
      csrfToken: response.json['csrfToken']! as String,
    );
  }

  Future<_TestHttpResponse> request(
    String method,
    String path, {
    Map<String, String> headers = const <String, String>{},
    Map<String, Object?>? jsonBody,
  }) async {
    final request = await _client.openUrl(method, Uri.parse('$origin$path'));
    headers.forEach(request.headers.set);
    if (jsonBody != null) {
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(jsonBody));
    }
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    final responseHeaders = <String, String>{};
    response.headers.forEach((name, values) {
      responseHeaders[name] = values.join(', ');
    });
    return _TestHttpResponse(
      statusCode: response.statusCode,
      headers: responseHeaders,
      body: body,
    );
  }

  Future<void> dispose() async {
    _client.close(force: true);
    await server.dispose();
    await coordinator.dispose();
    if (documents.existsSync()) await documents.delete(recursive: true);
    if (temporary.existsSync()) await temporary.delete(recursive: true);
  }
}

class _TestHttpResponse {
  const _TestHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final String body;

  Map<String, dynamic> get json => jsonDecode(body) as Map<String, dynamic>;
}

class _BrowserAuth {
  const _BrowserAuth({required this.cookie, required this.csrfToken});

  final String cookie;
  final String csrfToken;
}

class _PrivateSettingsStore extends CodexSettingsStore {
  @override
  Future<CodexSettings> getSettings() async => const CodexSettings(
    authRef: 'auth-ref-private-value',
    openaiBaseUrl: 'https://private.invalid/v1',
    appLocalePreference: CodexLocalePreference.simplifiedChinese,
  );

  @override
  Future<String?> getCodexApiKey() async => 'api-key-private-value';
}

class _TestCodeWorkspaceService extends SessionCodeWorkspaceService {
  _TestCodeWorkspaceService(this.sessionStore);

  final SessionStore sessionStore;

  @override
  Future<Session> createSession(
    Workspace workspace, {
    required String title,
    Session? sourceSession,
  }) {
    return sessionStore.createSession(
      workspace.id,
      title: title,
      codeState: SessionCodeState.ready,
    );
  }

  @override
  Future<Session> ensureSessionWorktree(
    Workspace workspace,
    Session session,
  ) async => session;
}
