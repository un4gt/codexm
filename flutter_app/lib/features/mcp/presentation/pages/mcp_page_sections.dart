part of 'mcp_page.dart';

class _ServerListCard extends StatelessWidget {
  const _ServerListCard({
    required this.servers,
    required this.busy,
    required this.runnableById,
    required this.installedById,
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
  final Set<String> enabledGlobalServerIds;
  final ValueChanged<McpServer> onEditServer;
  final ValueChanged<McpServer> onDeleteServer;
  final Future<void> Function(McpServer server, bool enabled)
  onSetServerEnabled;
  final ValueChanged<McpServer> onInstallManagedServer;
  final ValueChanged<McpServer> onUninstallManagedServer;

  @override
  Widget build(BuildContext context) {
    if (servers.isEmpty) {
      return const AppEmptyState(
        icon: Icons.extension_outlined,
        title: '还没有扩展服务',
        message: '点击顶部添加服务。',
      );
    }
    return AppListSection(
      title: '服务',
      children: [
        for (final server in servers)
          _ServerListTile(
            server: server,
            busy: busy,
            enabled: enabledGlobalServerIds.contains(server.id),
            runnable: runnableById[server.id] == true,
            installed: installedById[server.id] == true,
            onSetEnabled: (value) => onSetServerEnabled(server, value),
            onEdit: () => onEditServer(server),
            onDelete: () => onDeleteServer(server),
            onInstall: () => onInstallManagedServer(server),
            onUninstall: () => onUninstallManagedServer(server),
          ),
      ],
    );
  }
}

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({
    required this.installedSkills,
    required this.busy,
    required this.showEditor,
    required this.skillNameController,
    required this.skillContentController,
    required this.onBack,
    required this.onLoadSkill,
    required this.onSaveSkill,
    required this.onDeleteSkill,
  });

  final List<String> installedSkills;
  final bool busy;
  final bool showEditor;
  final TextEditingController skillNameController;
  final TextEditingController skillContentController;
  final VoidCallback onBack;
  final Future<void> Function(String name) onLoadSkill;
  final Future<void> Function() onSaveSkill;
  final Future<void> Function() onDeleteSkill;

  @override
  Widget build(BuildContext context) {
    if (!showEditor) {
      if (installedSkills.isEmpty) {
        return const AppEmptyState(
          icon: Icons.extension_off_outlined,
          title: '还没有全局技能',
          message: '点击顶部新建技能。',
        );
      }
      return AppListSection(
        title: '已安装 ${installedSkills.length} 项',
        children: [
          for (final skill in installedSkills)
            AppListTile(
              title: '\$$skill',
              leading: const Icon(Icons.extension_outlined),
              enabled: !busy,
              onTap: busy ? null : () => onLoadSkill(skill),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: busy ? null : onBack,
              tooltip: '返回技能列表',
              icon: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                skillNameController.text.trim().isEmpty ? '新建技能' : '编辑技能',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: skillNameController,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: '技能名称',
            hintText: '例如 ui-ux-pro-max',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: skillContentController,
          enabled: !busy,
          minLines: 6,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: '技能内容',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final widthClass = context.adaptiveWidthClassOf(
              constraints.maxWidth,
            );
            final compact = widthClass.isCompact;
            final actions = <Widget>[
              FilledButton.icon(
                onPressed: busy ? null : onSaveSkill,
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存技能'),
              ),
              OutlinedButton.icon(
                onPressed: busy ? null : onDeleteSkill,
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除技能'),
              ),
            ];
            return compact
                ? Column(
                    children: [
                      for (final action in actions) ...[
                        SizedBox(width: double.infinity, child: action),
                        if (action != actions.last) const SizedBox(height: 12),
                      ],
                    ],
                  )
                : Row(
                    children: [
                      for (final action in actions) ...[
                        Expanded(child: action),
                        if (action != actions.last) const SizedBox(width: 12),
                      ],
                    ],
                  );
          },
        ),
      ],
    );
  }
}

enum _ServerAction { edit, install, uninstall, delete }

class _ServerListTile extends StatelessWidget {
  const _ServerListTile({
    required this.server,
    required this.busy,
    required this.enabled,
    required this.runnable,
    required this.installed,
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
  final ValueChanged<bool> onSetEnabled;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onInstall;
  final VoidCallback onUninstall;

  @override
  Widget build(BuildContext context) {
    final transportLabel = server.transport == 'url'
        ? 'Streamable HTTP'
        : 'Rust stdio';
    final availabilityLabel = runnable ? '可运行' : '需要检查配置';
    final installLabel = server.transport == 'stdio'
        ? (installed ? ' · 已安装' : ' · 未安装')
        : '';

    return AppListTile(
      title: server.name,
      subtitle: '$transportLabel · $availabilityLabel$installLabel',
      leading: Icon(
        server.transport == 'url'
            ? Icons.link_outlined
            : Icons.terminal_outlined,
      ),
      onTap: busy ? null : onEdit,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch.adaptive(
            value: enabled,
            onChanged: busy ? null : onSetEnabled,
          ),
          PopupMenuButton<_ServerAction>(
            enabled: !busy,
            tooltip: '更多操作',
            onSelected: (action) {
              switch (action) {
                case _ServerAction.edit:
                  onEdit();
                case _ServerAction.install:
                  onInstall();
                case _ServerAction.uninstall:
                  onUninstall();
                case _ServerAction.delete:
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: _ServerAction.edit, child: Text('编辑')),
              if (server.transport == 'stdio')
                PopupMenuItem(
                  value: _ServerAction.install,
                  child: Text(installed ? '重新安装' : '下载并安装'),
                ),
              if (server.transport == 'stdio' && installed)
                const PopupMenuItem(
                  value: _ServerAction.uninstall,
                  child: Text('卸载'),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _ServerAction.delete,
                child: Text('删除'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
