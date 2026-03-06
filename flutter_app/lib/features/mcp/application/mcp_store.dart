import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import '../../../shared/persistence/app_directory_service.dart';
import 'mcp_models.dart';

class McpStore {
  McpStore({AppDirectoryService? appDirectoryService, Uuid? uuid})
    : _appDirectoryService = appDirectoryService ?? AppDirectoryService(),
      _uuid = uuid ?? const Uuid();

  final AppDirectoryService _appDirectoryService;
  final Uuid _uuid;

  Future<List<McpServer>> listServers() async {
    final index = await _readIndex();
    return index;
  }

  Future<McpServer> addServer(McpServerCreateParams params) async {
    final existing = await listServers();
    final requestedId = params.id?.trim();
    if (requestedId != null && requestedId.isNotEmpty) {
      if (existing.any((server) => server.id == requestedId)) {
        throw ArgumentError('MCP id 已存在，请重试。');
      }
    }

    final existingKeys = existing
        .map((server) => server.configKey.toLowerCase())
        .where((key) => key.isNotEmpty)
        .toSet();
    final baseKey = _sanitizeConfigKey(
      params.configKey?.trim().isNotEmpty == true
          ? params.configKey!
          : params.name,
    );
    final configKey = _ensureUniqueConfigKey(baseKey, existingKeys);
    final now = DateTime.now().millisecondsSinceEpoch;
    final server = McpServer(
      id: requestedId?.isNotEmpty == true ? requestedId! : _uuid.v4(),
      kind: 'rmcp',
      name: params.name.trim(),
      configKey: configKey,
      transport: params.transport,
      url: params.transport == 'url' ? params.url?.trim() : null,
      command: params.transport == 'stdio' ? params.command?.trim() : null,
      args: params.transport == 'stdio'
          ? (params.args ?? const <String>[])
          : null,
      createdAt: now,
      updatedAt: now,
    );
    _validateServer(server);
    await _writeIndex([server, ...existing]);
    return server;
  }

  Future<McpServer> updateServer(
    McpServerId id,
    McpServerCreateParams patch,
  ) async {
    final existing = await listServers();
    final current = existing.where((server) => server.id == id).firstOrNull;
    if (current == null) {
      throw ArgumentError('MCP server not found: $id');
    }

    final existingKeys = existing
        .where((server) => server.id != id)
        .map((server) => server.configKey.toLowerCase())
        .where((key) => key.isNotEmpty)
        .toSet();
    final rawConfigKey = patch.configKey?.trim().isNotEmpty == true
        ? patch.configKey!
        : current.configKey;
    final configKey = _ensureUniqueConfigKey(
      _sanitizeConfigKey(rawConfigKey),
      existingKeys,
    );

    final next = McpServer(
      id: current.id,
      kind: current.kind,
      name: patch.name.trim().isNotEmpty ? patch.name.trim() : current.name,
      configKey: configKey,
      transport: patch.transport,
      url: patch.transport == 'url' ? patch.url?.trim() : null,
      command: patch.transport == 'stdio' ? patch.command?.trim() : null,
      args: patch.transport == 'stdio'
          ? (patch.args ?? current.args ?? const <String>[])
          : null,
      createdAt: current.createdAt,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    _validateServer(next);

    final updated = existing
        .map((server) => server.id == id ? next : server)
        .toList(growable: false);
    await _writeIndex(updated);
    return next;
  }

  Future<void> deleteServer(McpServerId id) async {
    final existing = await listServers();
    await _writeIndex(
      existing.where((server) => server.id != id).toList(growable: false),
    );
  }

  Future<List<McpServer>> _readIndex() async {
    final file = await _indexFile();
    if (!file.existsSync()) {
      return const <McpServer>[];
    }
    final parsed = jsonDecode(await file.readAsString());
    if (parsed is! Map) {
      return const <McpServer>[];
    }
    final servers = parsed['servers'] as List? ?? const [];
    return servers
        .whereType<Map>()
        .map((item) => McpServer.fromMap(Map<String, Object?>.from(item)))
        .toList(growable: false);
  }

  Future<void> _writeIndex(List<McpServer> servers) async {
    final file = await _indexFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'servers': servers.map((server) => server.toMap()).toList(),
      }),
    );
  }

  Future<File> _indexFile() async {
    final dir = await _appDirectoryService.mcpDir();
    return File('${dir.path}/index.json');
  }

  String _sanitizeConfigKey(String input) {
    final lowered = input.trim().toLowerCase();
    final replaced = lowered
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return replaced.isEmpty ? 'mcp' : replaced;
  }

  String _ensureUniqueConfigKey(String base, Set<String> existing) {
    if (!existing.contains(base)) {
      return base;
    }
    for (var index = 2; index < 10000; index += 1) {
      final candidate = '$base-$index';
      if (!existing.contains(candidate)) {
        return candidate;
      }
    }
    return '$base-${DateTime.now().millisecondsSinceEpoch}';
  }

  void _validateServer(McpServer server) {
    if (server.name.trim().isEmpty) {
      throw ArgumentError('MCP 名称不能为空。');
    }
    if (server.configKey.trim().isEmpty) {
      throw ArgumentError('MCP configKey 不能为空。');
    }
    if (server.transport != 'url' && server.transport != 'stdio') {
      throw ArgumentError('仅支持 streamable HTTP/HTTP 或 Rust stdio 两类 MCP。');
    }
    if (server.transport == 'url') {
      final url = server.url?.trim() ?? '';
      if (url.isEmpty) {
        throw ArgumentError('Streamable HTTP 服务地址不能为空。');
      }
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        throw ArgumentError('服务地址必须以 http:// 或 https:// 开头。');
      }
    }
    if (server.transport == 'stdio') {
      final command = server.command?.trim() ?? '';
      if (command.isEmpty) {
        throw ArgumentError('Rust MCP 可执行文件路径不能为空。');
      }
    }
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
