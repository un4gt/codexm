part of 'mcp_page.dart';

class _McpMetricsCard extends StatelessWidget {
  const _McpMetricsCard({
    required this.urlCount,
    required this.localCount,
    required this.enabledCount,
  });

  final int urlCount;
  final int localCount;
  final int enabledCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.link_outlined,
                label: 'Streamable HTTP',
                value: '$urlCount',
              ),
            ),
            Expanded(
              child: _MetricTile(
                icon: Icons.terminal_outlined,
                label: 'Rust stdio',
                value: '$localCount',
              ),
            ),
            Expanded(
              child: _MetricTile(
                icon: Icons.toggle_on_outlined,
                label: '全局启用',
                value: '$enabledCount',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerListCard extends StatelessWidget {
  const _ServerListCard({
    required this.servers,
    required this.busy,
    required this.runnableById,
    required this.installedById,
    required this.managedExecPathById,
    required this.enabledGlobalServerIds,
    required this.onEditServer,
    required this.onDeleteServer,
    required this.onSetServerEnabled,
    required this.onInstallManagedServer,
    required this.onUninstallManagedServer,
  });

  final List<McpServer> servers;
  final bool busy;
  final Map<String, bool> runnableById;
  final Map<String, bool> installedById;
  final Map<String, String> managedExecPathById;
  final Set<String> enabledGlobalServerIds;
  final ValueChanged<McpServer> onEditServer;
  final ValueChanged<McpServer> onDeleteServer;
  final Future<void> Function(McpServer server, bool enabled)
  onSetServerEnabled;
  final ValueChanged<McpServer> onInstallManagedServer;
  final ValueChanged<McpServer> onUninstallManagedServer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('服务列表', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (servers.isEmpty) const Text('还没有扩展服务，添加后会自动写入本地配置。'),
            for (final server in servers) ...[
              if (servers.first != server) const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(server.name, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilterChip(
                              label: Text(
                                enabledGlobalServerIds.contains(server.id)
                                    ? '全局已启用'
                                    : '全局未启用',
                              ),
                              selected: enabledGlobalServerIds.contains(
                                server.id,
                              ),
                              onSelected: busy
                                  ? null
                                  : (value) =>
                                        onSetServerEnabled(server, value),
                            ),
                            Chip(
                              label: Text(
                                runnableById[server.id] == true ? '可运行' : '待确认',
                              ),
                              side: BorderSide.none,
                              backgroundColor: runnableById[server.id] == true
                                  ? theme.colorScheme.primaryContainer
                                  : theme.colorScheme.surfaceContainerHighest,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '接入方式：${server.transport == 'url' ? 'Streamable HTTP/HTTP' : 'Rust stdio（aarch64 可执行文件）'}',
                        ),
                        Text('标识：${server.configKey}'),
                        if (server.url?.trim().isNotEmpty == true)
                          Text('服务地址：${server.url}'),
                        if (server.command?.trim().isNotEmpty == true)
                          Text(
                            '启动程序：${server.command} ${(server.args ?? const <String>[]).join(' ')}',
                          ),
                        const SizedBox(height: 8),
                        Text(
                          '托管安装：${installedById[server.id] == true ? '已安装' : '未安装'}',
                        ),
                        Text(
                          '执行路径：${managedExecPathById[server.id] ?? '尚未生成'}',
                        ),
                        if (server.transport == 'stdio') ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              OutlinedButton.icon(
                                onPressed: busy
                                    ? null
                                    : () => onInstallManagedServer(server),
                                icon: const Icon(Icons.download_outlined),
                                label: Text(
                                  installedById[server.id] == true
                                      ? '重新安装'
                                      : '下载并安装',
                                ),
                              ),
                              TextButton.icon(
                                onPressed:
                                    busy || installedById[server.id] != true
                                    ? null
                                    : () => onUninstallManagedServer(server),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('卸载本地文件'),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<_ServerAction>(
                    onSelected: (action) {
                      switch (action) {
                        case _ServerAction.edit:
                          onEditServer(server);
                        case _ServerAction.delete:
                          onDeleteServer(server);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _ServerAction.edit,
                        child: Text('编辑'),
                      ),
                      PopupMenuItem(
                        value: _ServerAction.delete,
                        child: Text('删除'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _ServerAction { edit, delete }

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon),
      title: Text(value, style: theme.textTheme.titleLarge),
      subtitle: Text(label),
    );
  }
}
