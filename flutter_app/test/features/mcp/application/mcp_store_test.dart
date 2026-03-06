import 'dart:io';

import 'package:codexm_flutter/features/mcp/application/mcp_models.dart';
import 'package:codexm_flutter/features/mcp/application/mcp_runnable.dart';
import 'package:codexm_flutter/features/mcp/application/mcp_store.dart';
import 'package:codexm_flutter/shared/persistence/app_directory_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adds unique MCP servers and updates transport details', () async {
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
    final store = McpStore(appDirectoryService: appDirectoryService);
    final checker = const McpRunnableChecker();

    final first = await store.addServer(
      const McpServerCreateParams(
        name: 'Demo MCP',
        transport: 'url',
        url: 'https://example.com/mcp',
      ),
    );
    final second = await store.addServer(
      const McpServerCreateParams(
        name: 'Demo MCP',
        transport: 'stdio',
        command: 'codex',
        args: <String>['mcp', 'serve'],
      ),
    );
    final updated = await store.updateServer(
      second.id,
      const McpServerCreateParams(
        name: 'Demo MCP Local',
        transport: 'stdio',
        command: 'codex',
        args: <String>['mcp', 'serve', '--verbose'],
      ),
    );

    final listed = await store.listServers();
    expect(first.configKey, 'demo-mcp');
    expect(second.configKey, 'demo-mcp-2');
    expect(updated.args, contains('--verbose'));
    expect(await checker.isProbablyRunnable(updated), isTrue);
    expect(listed, hasLength(2));
  });
}
