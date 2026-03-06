import 'dart:convert';
import 'dart:io';

import 'package:xml/xml.dart';

import 'webdav_types.dart';

class WebDavClient {
  WebDavClient({
    required WebDavConfig config,
    WebDavBasicAuth? basicAuth,
    WebDavBearerAuth? bearerAuth,
    HttpClient? httpClient,
  })  : _config = config,
        _basicAuth = basicAuth,
        _bearerAuth = bearerAuth,
        _httpClient = httpClient ?? HttpClient();

  final WebDavConfig _config;
  final WebDavBasicAuth? _basicAuth;
  final WebDavBearerAuth? _bearerAuth;
  final HttpClient _httpClient;

  Future<bool> head(String path) async {
    final response = await _send('HEAD', path);
    await response.drain<void>();
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Future<({String body, WebDavDownloadResult meta})> downloadString(String path) async {
    final response = await _send('GET', path);
    final body = await utf8.decodeStream(response);
    _ensureSuccess(response, 'WebDAV GET failed');
    return (
      body: body,
      meta: WebDavDownloadResult(
        etag: response.headers.value('etag'),
        contentType: response.headers.contentType?.mimeType,
        contentLength: response.contentLength >= 0 ? response.contentLength : null,
      ),
    );
  }

  Future<({WebDavDownloadResult meta})> downloadToFile(
    String path,
    String filePath,
  ) async {
    final response = await _send('GET', path);
    _ensureSuccess(response, 'WebDAV download failed');
    final file = File(filePath);
    await file.parent.create(recursive: true);
    await response.pipe(file.openWrite());
    return (
      meta: WebDavDownloadResult(
        etag: response.headers.value('etag'),
        contentType: response.headers.contentType?.mimeType,
        contentLength: response.contentLength >= 0 ? response.contentLength : null,
      ),
    );
  }

  Future<({String? etag})> uploadString(
    String path,
    String content, {
    WebDavUploadOptions? options,
  }) async {
    final response = await _send(
      'PUT',
      path,
      bodyBytes: utf8.encode(content),
      headers: {
        if (options?.contentType != null) 'Content-Type': options!.contentType!,
        if (options?.ifMatchETag != null) 'If-Match': options!.ifMatchETag!,
      },
    );
    await response.drain<void>();
    _ensureSuccess(response, 'WebDAV PUT failed');
    return (etag: response.headers.value('etag'));
  }

  Future<({String? etag})> uploadFile(
    String path,
    String filePath, {
    WebDavUploadOptions? options,
  }) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final response = await _send(
      'PUT',
      path,
      bodyBytes: bytes,
      headers: {
        if (options?.contentType != null) 'Content-Type': options!.contentType!,
        if (options?.ifMatchETag != null) 'If-Match': options!.ifMatchETag!,
      },
    );
    await response.drain<void>();
    _ensureSuccess(response, 'WebDAV PUT failed');
    return (etag: response.headers.value('etag'));
  }

  Future<void> mkcol(String path) async {
    final response = await _send('MKCOL', path);
    await response.drain<void>();
    if (response.statusCode == 201 || response.statusCode == 405) {
      return;
    }
    _ensureSuccess(response, 'WebDAV MKCOL failed');
  }

  Future<void> delete(String path) async {
    final response = await _send('DELETE', path);
    await response.drain<void>();
    if (response.statusCode == 404) {
      return;
    }
    _ensureSuccess(response, 'WebDAV DELETE failed');
  }

  Future<List<WebDavEntry>> propfind(
    String path, {
    String depth = '1',
  }) async {
    const body = '''<?xml version="1.0" encoding="utf-8" ?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:resourcetype />
    <d:getetag />
    <d:getcontentlength />
    <d:getlastmodified />
  </d:prop>
</d:propfind>''';
    final response = await _send(
      'PROPFIND',
      path,
      bodyBytes: utf8.encode(body),
      headers: {
        'Depth': depth,
        'Content-Type': 'text/xml',
        'Accept': 'application/xml',
      },
    );
    final xml = await utf8.decodeStream(response);
    if (response.statusCode != 207 &&
        (response.statusCode < 200 || response.statusCode >= 300)) {
      throw HttpException(
        'WebDAV PROPFIND failed: ${response.statusCode}',
      );
    }
    return parsePropfindResponse(
      xml: xml,
      endpoint: _config.endpoint,
      basePath: _config.basePath,
    );
  }

  Future<HttpClientResponse> _send(
    String method,
    String path, {
    List<int>? bodyBytes,
    Map<String, String>? headers,
  }) async {
    final request = await _httpClient.openUrl(
      method,
      Uri.parse(_buildUrl(path)),
    );
    _applyHeaders(request, headers);
    if (bodyBytes != null) {
      request.add(bodyBytes);
    }
    return request.close();
  }

  void _applyHeaders(
    HttpClientRequest request,
    Map<String, String>? extraHeaders,
  ) {
    final basicAuth = _basicAuth;
    if (basicAuth != null) {
      final raw = '${basicAuth.username}:${basicAuth.password}';
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Basic ${base64Encode(utf8.encode(raw))}',
      );
    }
    final bearerAuth = _bearerAuth;
    if (bearerAuth != null) {
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer ${bearerAuth.token}',
      );
    }
    extraHeaders?.forEach(request.headers.set);
  }

  String _buildUrl(String path) {
    final endpoint = _config.endpoint.replaceAll(RegExp(r'/+$'), '');
    final basePath = (_config.basePath ?? '').trim();
    final normalizedBase = basePath.isEmpty
        ? ''
        : '/${basePath.replaceAll(RegExp(r'^/+|/+$'), '')}';
    final normalizedPath = path.trim().isEmpty
        ? ''
        : '/${path.trim().replaceAll(RegExp(r'^/+'), '')}';
    return '$endpoint$normalizedBase$normalizedPath';
  }

  void _ensureSuccess(HttpClientResponse response, String prefix) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('$prefix: ${response.statusCode}');
    }
  }

  static List<WebDavEntry> parsePropfindResponse({
    required String xml,
    required String endpoint,
    String? basePath,
  }) {
    final document = XmlDocument.parse(xml);
    final responses = document.findAllElements('response', namespace: '*');
    final entries = <WebDavEntry>[];
    for (final response in responses) {
      final href = response.findElements('href', namespace: '*').firstOrNull?.innerText.trim();
      if (href == null || href.isEmpty) {
        continue;
      }

      final prop = response.findAllElements('prop', namespace: '*').firstOrNull;
      final resourceType = prop?.findElements('resourcetype', namespace: '*').firstOrNull;
      final isCollection =
          resourceType?.findElements('collection', namespace: '*').isNotEmpty ?? false;
      final etag = prop?.findElements('getetag', namespace: '*').firstOrNull?.innerText.trim();
      final contentLengthText =
          prop?.findElements('getcontentlength', namespace: '*').firstOrNull?.innerText.trim();
      final lastModified =
          prop?.findElements('getlastmodified', namespace: '*').firstOrNull?.innerText.trim();

      entries.add(
        WebDavEntry(
          href: href,
          path: _toRelativePath(href, endpoint, basePath),
          isCollection: isCollection,
          etag: etag?.isEmpty == true ? null : etag,
          contentLength: int.tryParse(contentLengthText ?? ''),
          lastModified: lastModified?.isEmpty == true ? null : lastModified,
        ),
      );
    }
    return entries;
  }

  static String _toRelativePath(String href, String endpoint, String? basePath) {
    final endpointUri = Uri.parse(endpoint);
    final hrefUri = Uri.tryParse(href);
    final hrefPath = hrefUri?.path ?? href;
    final base = (basePath ?? '').trim().replaceAll(RegExp(r'^/+|/+$'), '');
    var path = hrefPath;
    if (path.startsWith(endpointUri.path)) {
      path = path.substring(endpointUri.path.length);
    }
    path = path.replaceAll(RegExp(r'^/+'), '');
    if (base.isNotEmpty && path.startsWith('$base/')) {
      path = path.substring(base.length + 1);
    } else if (path == base) {
      path = '';
    }
    return Uri.decodeComponent(path.replaceAll(RegExp(r'^/+|/+$'), ''));
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
