import 'dart:io';

import 'package:codexm_flutter/features/webdav/application/webdav_client.dart';
import 'package:codexm_flutter/features/webdav/application/webdav_sync.dart';
import 'package:codexm_flutter/features/webdav/application/webdav_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses PROPFIND response into relative entries', () {
    const xml = '''
<?xml version="1.0" encoding="utf-8"?>
<d:multistatus xmlns:d="DAV:">
  <d:response>
    <d:href>/dav/root/</d:href>
    <d:propstat>
      <d:prop>
        <d:resourcetype><d:collection/></d:resourcetype>
      </d:prop>
    </d:propstat>
  </d:response>
  <d:response>
    <d:href>/dav/root/notes/todo.txt</d:href>
    <d:propstat>
      <d:prop>
        <d:resourcetype/>
        <d:getetag>"abc"</d:getetag>
        <d:getcontentlength>12</d:getcontentlength>
      </d:prop>
    </d:propstat>
  </d:response>
</d:multistatus>
''';

    final entries = WebDavClient.parsePropfindResponse(
      xml: xml,
      endpoint: 'https://example.com/dav',
      basePath: null,
    );

    expect(entries, hasLength(2));
    expect(entries.last.path, 'root/notes/todo.txt');
    expect(entries.last.contentLength, 12);
    expect(entries.last.isCollection, isFalse);
  });

  test('pulls and pushes WebDAV trees with directory creation', () async {
    final localRoot = await Directory.systemTemp.createTemp('codexm_webdav_');
    final httpClient = HttpClient();
    addTearDown(() async {
      httpClient.close(force: true);
      if (localRoot.existsSync()) {
        await localRoot.delete(recursive: true);
      }
    });

    final client = _FakeWebDavClient(
      httpClient: httpClient,
      listings: <String, List<WebDavEntry>>{
        'root/': const <WebDavEntry>[
          WebDavEntry(href: '/root/', path: 'root', isCollection: true),
          WebDavEntry(href: '/root/docs/', path: 'root/docs', isCollection: true),
          WebDavEntry(href: '/root/readme.txt', path: 'root/readme.txt', isCollection: false, contentLength: 5),
        ],
        'root/docs/': const <WebDavEntry>[
          WebDavEntry(href: '/root/docs/', path: 'root/docs', isCollection: true),
          WebDavEntry(href: '/root/docs/note.txt', path: 'root/docs/note.txt', isCollection: false, contentLength: 4),
        ],
      },
      remoteFiles: <String, String>{
        'root/readme.txt': 'hello',
        'root/docs/note.txt': 'note',
      },
    );
    const service = WebDavSyncService();

    await service.pull(
      client: client,
      remoteRootDir: 'root',
      localRootDirPath: localRoot.path,
    );

    expect(File('${localRoot.path}/readme.txt').existsSync(), isTrue);
    expect(File('${localRoot.path}/docs/note.txt').existsSync(), isTrue);
    expect(client.downloadedPaths, containsAll(<String>[
      'root/readme.txt',
      'root/docs/note.txt',
    ]));

    final uploadFile = File('${localRoot.path}/docs/local.txt');
    await uploadFile.parent.create(recursive: true);
    await uploadFile.writeAsString('local');

    await service.push(
      client: client,
      remoteRootDir: 'root',
      localRootDirPath: localRoot.path,
    );

    expect(client.createdDirs, contains('root/docs/'));
    expect(client.uploadedPaths, contains('root/docs/local.txt'));
  });
}

class _FakeWebDavClient extends WebDavClient {
  _FakeWebDavClient({
    required HttpClient httpClient,
    required this.listings,
    required Map<String, String> remoteFiles,
  })  : _remoteFiles = remoteFiles,
        super(
          config: const WebDavConfig(endpoint: 'https://example.com'),
          httpClient: httpClient,
        );

  final Map<String, List<WebDavEntry>> listings;
  final Map<String, String> _remoteFiles;
  final List<String> downloadedPaths = <String>[];
  final List<String> uploadedPaths = <String>[];
  final List<String> createdDirs = <String>[];

  @override
  Future<({WebDavDownloadResult meta})> downloadToFile(
    String path,
    String filePath,
  ) async {
    downloadedPaths.add(path);
    final file = File(filePath);
    await file.parent.create(recursive: true);
    final content = _remoteFiles[path] ?? '';
    await file.writeAsString(content);
    return (
      meta: WebDavDownloadResult(contentLength: content.length),
    );
  }

  @override
  Future<void> mkcol(String path) async {
    createdDirs.add(path);
  }

  @override
  Future<List<WebDavEntry>> propfind(
    String path, {
    String depth = '1',
  }) async {
    return listings[path] ?? const <WebDavEntry>[];
  }

  @override
  Future<({String? etag})> uploadFile(
    String path,
    String filePath, {
    WebDavUploadOptions? options,
  }) async {
    uploadedPaths.add(path);
    return (etag: null);
  }
}
