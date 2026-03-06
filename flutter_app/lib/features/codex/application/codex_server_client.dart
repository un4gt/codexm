import 'dart:convert';
import 'dart:io';

import 'codex_models.dart';
import 'codex_sse.dart';

class CodexServerClient {
  CodexServerClient({
    required CodexServerConfig config,
    HttpClient? httpClient,
  })  : _config = config,
        _httpClient = httpClient ?? HttpClient();

  final CodexServerConfig _config;
  final HttpClient _httpClient;

  Future<bool> health({String path = 'health'}) async {
    try {
      final request = await _openRequest('GET', path);
      final response = await request.close();
      await response.drain<void>();
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Stream<CodexStreamEvent> stream(
    String endpointPath, {
    required Object? body,
  }) async* {
    final request = await _openRequest('POST', endpointPath);
    request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
    request.headers.set(HttpHeaders.acceptHeader, 'text/event-stream');
    request.add(utf8.encode(jsonEncode(body ?? const <String, Object?>{})));
    final response = await request.close();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      yield CodexStreamEvent.error(
        'Codex stream failed: ${response.statusCode} ${response.reasonPhrase}'.trim(),
      );
      return;
    }

    yield* readSse(response);
  }

  Future<HttpClientRequest> _openRequest(String method, String path) {
    return _httpClient.openUrl(method, Uri.parse(_buildUrl(path))).then((request) {
      final apiKey = _config.apiKey?.trim() ?? '';
      if (apiKey.isNotEmpty) {
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $apiKey',
        );
      }
      return request;
    });
  }

  String _buildUrl(String path) {
    final base = _config.baseUrl.endsWith('/')
        ? _config.baseUrl
        : '${_config.baseUrl}/';
    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;
    return '$base$normalizedPath';
  }
}
