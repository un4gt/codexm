import 'dart:io';

import 'mcp_models.dart';

class McpRunnableChecker {
  const McpRunnableChecker();

  Future<bool> isProbablyRunnable(McpServer server) async {
    if (server.transport == 'url') {
      return (server.url?.trim().isNotEmpty ?? false);
    }

    final command = server.command?.trim() ?? '';
    if (command.isEmpty) {
      return false;
    }

    if (!command.startsWith('/') && !command.startsWith('file://')) {
      return true;
    }

    final path = command.startsWith('file://')
        ? command.substring('file://'.length)
        : command;
    return File(path).existsSync();
  }
}
