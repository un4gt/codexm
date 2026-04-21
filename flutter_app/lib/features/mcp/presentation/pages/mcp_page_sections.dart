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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StitchSectionHeader(title: '数据摘要'),
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MetricTile(
                  icon: Icons.link_outlined,
                  label: 'Streamable HTTP',
                  value: '$urlCount',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MetricTile(
                  icon: Icons.terminal_outlined,
                  label: 'Rust stdio',
                  value: '$localCount',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.toggle_on_outlined,
                label: '全局启用',
                value: '$enabledCount',
              ),
            ),
          ],
        ),
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StitchSectionHeader(title: '服务列表'),
        const SizedBox(height: 8),
        if (servers.isEmpty)
          const ListTile(
            leading: Icon(Icons.extension_outlined),
            title: Text('无配置服务'),
            subtitle: Text('点击顶部「+」添加。'),
          ),
        for (final server in servers) ...[
          if (servers.first != server) const SizedBox(height: 12),
          _ServerStitchCard(
            server: server,
            busy: busy,
            enabled: enabledGlobalServerIds.contains(server.id),
            runnable: runnableById[server.id] == true,
            installed: installedById[server.id] == true,
            execPath: managedExecPathById[server.id],
            onSetEnabled: (value) => onSetServerEnabled(server, value),
            onEdit: () => onEditServer(server),
            onDelete: () => onDeleteServer(server),
            onInstall: () => onInstallManagedServer(server),
            onUninstall: () => onUninstallManagedServer(server),
          ),
        ],
      ],
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
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 20, color: colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServerStitchCard extends StatelessWidget {
  const _ServerStitchCard({
    required this.server,
    required this.busy,
    required this.enabled,
    required this.runnable,
    required this.installed,
    required this.execPath,
    required this.onSetEnabled,
    required this.onEdit,
    required this.onDelete,
    required this.onInstall,
    required this.onUninstall,
  });

  final McpServer server;
  final bool busy;
  final bool enabled;
  final bool runnable;
  final bool installed;
  final String? execPath;
  final ValueChanged<bool> onSetEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onInstall;
  final VoidCallback onUninstall;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final transportLabel = server.transport == 'url'
        ? 'Streamable HTTP'
        : 'Rust stdio';
    final endpoint = server.transport == 'url'
        ? (server.url?.trim().isNotEmpty == true
              ? server.url!.trim()
              : '未填写服务地址')
        : (server.command?.trim().isNotEmpty == true
              ? server.command!.trim()
              : '未填写可执行文件');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    server.transport == 'url'
                        ? Icons.link_outlined
                        : Icons.terminal_outlined,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        server.name,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '$transportLabel · ${server.configKey}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<_ServerAction>(
                  onSelected: busy
                      ? null
                      : (action) {
                          switch (action) {
                            case _ServerAction.edit:
                              onEdit();
                            case _ServerAction.delete:
                              onDelete();
                          }
                        },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: _ServerAction.edit, child: Text('编辑')),
                    PopupMenuItem(
                      value: _ServerAction.delete,
                      child: Text('删除'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                enabled ? '已启用' : '未启用',
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                runnable ? '可运行' : '可运行性待确认',
                style: theme.textTheme.bodySmall,
              ),
              trailing: Switch.adaptive(
                value: enabled,
                onChanged: busy ? null : onSetEnabled,
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('接入信息', style: theme.textTheme.bodyMedium),
              subtitle: Text(
                endpoint,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (server.transport == 'stdio') ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  installed ? '托管安装：已安装' : '托管安装：未安装',
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: Text(
                  execPath?.trim().isNotEmpty == true ? '已安装配置' : '尚未配置',
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: busy ? null : onInstall,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(installed ? '重新安装' : '下载并安装'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy || !installed ? null : onUninstall,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('卸载本地文件'),
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
