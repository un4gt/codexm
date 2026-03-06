part of 'mcp_page.dart';

extension _McpPageActions on _McpPageState {
  Future<_McpServerDraft?> _showServerDialog({McpServer? existing}) async {
    final nameController = TextEditingController(text: existing?.name ?? '');
    final configKeyController = TextEditingController(
      text: existing?.configKey ?? '',
    );
    final urlController = TextEditingController(text: existing?.url ?? '');
    final commandController = TextEditingController(
      text: existing?.command ?? '',
    );
    final argsController = TextEditingController(
      text: (existing?.args ?? const <String>[]).join('\n'),
    );
    final installUrlController = TextEditingController();
    var transport = existing?.transport ?? 'url';

    final result = await showDialog<_McpServerDraft>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: Text(existing == null ? '添加扩展服务' : '编辑扩展服务'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 480,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameController,
                        autofocus: true,
                        decoration: const InputDecoration(labelText: '名称'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: configKeyController,
                        decoration: const InputDecoration(labelText: '标识'),
                      ),
                      const SizedBox(height: 12),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                            value: 'url',
                            label: Text('Streamable HTTP'),
                            icon: Icon(Icons.link_outlined),
                          ),
                          ButtonSegment(
                            value: 'stdio',
                            label: Text('Rust stdio'),
                            icon: Icon(Icons.terminal_outlined),
                          ),
                        ],
                        selected: <String>{transport},
                        onSelectionChanged: (selection) {
                          setModalState(() {
                            transport = selection.first;
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      if (transport == 'url')
                        TextField(
                          controller: urlController,
                          decoration: const InputDecoration(
                            labelText: '服务地址（HTTP/HTTPS）',
                          ),
                        ),
                      if (transport == 'stdio') ...[
                        TextField(
                          controller: commandController,
                          decoration: const InputDecoration(
                            labelText: 'Rust MCP 可执行文件',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: argsController,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(
                            labelText: '启动参数（可选）',
                            hintText: '每行一个参数',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: installUrlController,
                          decoration: const InputDecoration(
                            labelText: '安装地址（可选）',
                            hintText: '填写后会自动下载并写入托管安装目录',
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '提示：仅 Android 支持运行时安装本地 Rust MCP 可执行文件；如不填写安装地址，也可手动填写可执行文件路径。',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    final args = argsController.text
                        .split('\n')
                        .map((item) => item.trim())
                        .where((item) => item.isNotEmpty)
                        .toList(growable: false);
                    Navigator.of(context).pop(
                      _McpServerDraft(
                        params: McpServerCreateParams(
                          id: existing?.id,
                          name: nameController.text.trim(),
                          configKey: configKeyController.text.trim(),
                          transport: transport,
                          url: urlController.text.trim(),
                          command: commandController.text.trim(),
                          args: args,
                        ),
                        installUrl: installUrlController.text.trim(),
                      ),
                    );
                  },
                  child: const Text('保存'),
                ),
              ],
            );
          },
        );
      },
    );

    nameController.dispose();
    configKeyController.dispose();
    urlController.dispose();
    commandController.dispose();
    argsController.dispose();
    installUrlController.dispose();
    return result;
  }

  Future<bool> _confirmDelete(McpServer server) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除扩展服务'),
          content: Text('将删除「${server.name}」的本地配置。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _addServer() async {
    final draft = await _showServerDialog();
    if (draft == null) {
      return;
    }
    await _runAction('正在添加扩展服务...', () async {
      final server = await _addManagedAwareServer(draft);
      return '已添加扩展服务：${server.name}';
    });
  }

  Future<void> _editServer(McpServer server) async {
    final draft = await _showServerDialog(existing: server);
    if (draft == null) {
      return;
    }
    await _runAction('正在更新扩展服务...', () async {
      final updated = await _updateManagedAwareServer(server, draft);
      return '已更新扩展服务：${updated.name}';
    });
  }

  Future<void> _deleteServer(McpServer server) async {
    final confirmed = await _confirmDelete(server);
    if (!confirmed) {
      return;
    }
    await _runAction('正在删除扩展服务...', () async {
      final settings = await _settingsStore.getSettings();
      if (settings.enabledGlobalMcpServerIds.contains(server.id)) {
        await _settingsStore.saveSettings(
          settings.copyWith(
            enabledGlobalMcpServerIds: settings.enabledGlobalMcpServerIds
                .where((id) => id != server.id)
                .toList(growable: false),
          ),
        );
      }
      await _installer.uninstallManagedMcp(server.id);
      await _mcpStore.deleteServer(server.id);
      return '已删除扩展服务：${server.name}';
    });
  }

  Future<McpServer> _addManagedAwareServer(_McpServerDraft draft) async {
    var params = draft.params;
    final installUrl = draft.installUrl.trim();
    String? managedServerId;
    if (params.transport == 'stdio' && installUrl.isNotEmpty) {
      managedServerId = params.id?.trim().isNotEmpty == true
          ? params.id!.trim()
          : _uuid.v4();
      try {
        final installed = await _installer.installManagedMcpFromUrl(
          serverId: managedServerId,
          url: installUrl,
        );
        params = McpServerCreateParams(
          id: managedServerId,
          kind: params.kind,
          name: params.name,
          configKey: params.configKey,
          transport: params.transport,
          url: params.url,
          command: installed.execPath,
          args: params.args,
        );
      } catch (_) {
        await _installer.uninstallManagedMcp(managedServerId);
        rethrow;
      }
    }

    try {
      return await _mcpStore.addServer(params);
    } catch (_) {
      if (managedServerId != null) {
        await _installer.uninstallManagedMcp(managedServerId);
      }
      rethrow;
    }
  }

  Future<McpServer> _updateManagedAwareServer(
    McpServer server,
    _McpServerDraft draft,
  ) async {
    var patch = draft.params;
    final installUrl = draft.installUrl.trim();
    if (patch.transport == 'stdio' && installUrl.isNotEmpty) {
      final installed = await _installer.installManagedMcpFromUrl(
        serverId: server.id,
        url: installUrl,
      );
      patch = McpServerCreateParams(
        id: patch.id,
        kind: patch.kind,
        name: patch.name,
        configKey: patch.configKey,
        transport: patch.transport,
        url: patch.url,
        command: installed.execPath,
        args: patch.args,
      );
    }
    return _mcpStore.updateServer(server.id, patch);
  }

  Future<String?> _promptInstallUrl({required String title}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: '安装地址',
              hintText: '请输入 HTTP/HTTPS 下载地址',
            ),
            onSubmitted: (value) {
              Navigator.of(context).pop(value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('确认'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result?.trim().isEmpty == true ? null : result?.trim();
  }

  Future<bool> _confirmUninstallManagedServer(McpServer server) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('卸载本地文件'),
          content: Text('将删除「${server.name}」的托管安装文件，但保留服务器记录。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('卸载'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  Future<void> _installManagedServer(McpServer server) async {
    final installUrl = await _promptInstallUrl(title: '下载并安装');
    if (installUrl == null) {
      return;
    }
    await _runAction('正在下载并安装扩展服务...', () async {
      final installed = await _installer.installManagedMcpFromUrl(
        serverId: server.id,
        url: installUrl,
      );
      await _mcpStore.updateServer(
        server.id,
        McpServerCreateParams(
          id: server.id,
          kind: server.kind,
          name: server.name,
          configKey: server.configKey,
          transport: server.transport,
          url: server.url,
          command: installed.execPath,
          args: server.args,
        ),
      );
      return '已安装扩展服务：${server.name}';
    });
  }

  Future<void> _uninstallManagedServer(McpServer server) async {
    final confirmed = await _confirmUninstallManagedServer(server);
    if (!confirmed) {
      return;
    }
    await _runAction('正在卸载本地扩展文件...', () async {
      await _installer.uninstallManagedMcp(server.id);
      return '已卸载本地文件：${server.name}';
    });
  }
}

class _McpServerDraft {
  const _McpServerDraft({required this.params, required this.installUrl});

  final McpServerCreateParams params;
  final String installUrl;
}
