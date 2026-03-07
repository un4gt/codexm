part of 'workspaces_page.dart';

class _WorkspaceMetricsCard extends StatelessWidget {
  const _WorkspaceMetricsCard({
    required this.workspaces,
    required this.activeWorkspace,
  });

  final List<Workspace> workspaces;
  final Workspace? activeWorkspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('概览', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _MetricCard(
                  icon: Icons.folder_copy_outlined,
                  label: '工作区数量',
                  value: '${workspaces.length}',
                ),
                _MetricCard(
                  icon: Icons.check_circle_outline,
                  label: '当前工作区',
                  value: activeWorkspace?.name ?? '未选择',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkspaceListCard extends StatelessWidget {
  const _WorkspaceListCard({
    required this.workspaces,
    required this.selectedWorkspaceId,
    required this.activeWorkspaceId,
    required this.onSelectWorkspace,
    required this.onActivateWorkspace,
    required this.onRenameWorkspace,
    required this.onDeleteWorkspace,
  });

  final List<Workspace> workspaces;
  final WorkspaceId? selectedWorkspaceId;
  final WorkspaceId? activeWorkspaceId;
  final ValueChanged<Workspace> onSelectWorkspace;
  final ValueChanged<Workspace> onActivateWorkspace;
  final ValueChanged<Workspace> onRenameWorkspace;
  final ValueChanged<Workspace> onDeleteWorkspace;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('工作区列表', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '先选择工作区，再继续查看详情、同步仓库或进入会话。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (workspaces.isEmpty)
              _EmptyHint(
                icon: Icons.create_new_folder_outlined,
                title: '还没有工作区',
                description: '创建或克隆后，这里会自动准备本地目录与运行环境。',
              ),
            for (final workspace in workspaces) ...[
              if (workspaces.first != workspace) const SizedBox(height: 12),
              _WorkspaceListItem(
                workspace: workspace,
                selected: workspace.id == selectedWorkspaceId,
                active: workspace.id == activeWorkspaceId,
                onTap: () => onSelectWorkspace(workspace),
                onActivate: () => onActivateWorkspace(workspace),
                onRename: () => onRenameWorkspace(workspace),
                onDelete: () => onDeleteWorkspace(workspace),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkspaceDetailCard extends StatelessWidget {
  const _WorkspaceDetailCard({
    required this.workspace,
    required this.paths,
    required this.busy,
    required this.activeWorkspaceId,
    required this.formatDate,
    required this.onActivateWorkspace,
    required this.onRenameWorkspace,
    required this.onOpenSessionsRequested,
  });

  final Workspace? workspace;
  final WorkspacePaths? paths;
  final bool busy;
  final WorkspaceId? activeWorkspaceId;
  final String Function(int millis) formatDate;
  final ValueChanged<Workspace> onActivateWorkspace;
  final ValueChanged<Workspace> onRenameWorkspace;
  final VoidCallback? onOpenSessionsRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isActive = workspace?.id == activeWorkspaceId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('当前选中工作区', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '进入会话前，可先确认目录准备情况与当前激活状态。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (workspace == null)
              const _EmptyHint(
                icon: Icons.touch_app_outlined,
                title: '先选择一个工作区',
                description: '选择后即可查看目录、激活状态并继续进入会话。',
              ),
            if (workspace != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      workspace!.name,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  Chip(
                    label: Text(isActive ? '当前工作区' : '未激活'),
                    side: BorderSide.none,
                    backgroundColor: isActive
                        ? theme.colorScheme.primaryContainer
                        : theme.colorScheme.surfaceContainerHighest,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '创建时间：${formatDate(workspace!.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              _PathBlock(
                title: '本地目录',
                items: [
                  _PathEntry(label: '工作区根目录', value: workspace!.localPath),
                  _PathEntry(label: '仓库目录', value: paths?.repoDir.path ?? '尚未准备'),
                  _PathEntry(label: '运行目录', value: paths?.codexHomeDir.path ?? '尚未准备'),
                  _PathEntry(label: '缓存目录', value: paths?.tmpDir.path ?? '尚未准备'),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: onOpenSessionsRequested,
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('进入会话'),
                  ),
                  if (!isActive)
                    FilledButton.tonalIcon(
                      onPressed: busy ? null : () => onActivateWorkspace(workspace!),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('设为当前'),
                    ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => onRenameWorkspace(workspace!),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('编辑名称'),
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

class _WorkspaceGitCard extends StatelessWidget {
  const _WorkspaceGitCard({
    required this.workspace,
    required this.paths,
    required this.busy,
    required this.repoReady,
    required this.onSyncGit,
  });

  final Workspace? workspace;
  final WorkspacePaths? paths;
  final bool busy;
  final bool repoReady;
  final ValueChanged<Workspace> onSyncGit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final git = workspace?.git;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('仓库连接', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '这里展示 clone / pull 需要的来源信息，以及当前仓库准备状态。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (workspace == null)
              const _EmptyHint(
                icon: Icons.cloud_outlined,
                title: '尚未选择工作区',
                description: '选择工作区后，这里会展示仓库地址、认证摘要与同步入口。',
              ),
            if (workspace != null && git == null)
              const _EmptyHint(
                icon: Icons.download_for_offline_outlined,
                title: '当前是空白工作区',
                description: '如需接入代码仓库，请使用顶部“克隆仓库”入口创建新的仓库工作区。',
              ),
            if (workspace != null && git != null) ...[
              _PathBlock(
                title: '来源信息',
                items: [
                  _PathEntry(label: '远端地址', value: git.remoteUrl),
                  _PathEntry(
                    label: '默认分支',
                    value: git.defaultBranch?.trim().isNotEmpty == true
                        ? git.defaultBranch!
                        : '未指定',
                  ),
                  _PathEntry(
                    label: '认证信息',
                    value: git.authRef?.trim().isNotEmpty == true ? '已保存' : '未保存',
                  ),
                  _PathEntry(
                    label: '仓库状态',
                    value: repoReady ? '已准备，可直接拉取。' : '尚未完成克隆。',
                  ),
                  if (git.userName?.trim().isNotEmpty == true ||
                      git.userEmail?.trim().isNotEmpty == true)
                    _PathEntry(
                      label: '提交身份',
                      value:
                          '${git.userName?.trim().isNotEmpty == true ? git.userName : '未设置'} / ${git.userEmail?.trim().isNotEmpty == true ? git.userEmail : '未设置'}',
                    ),
                  if (paths != null)
                    _PathEntry(label: '本地仓库目录', value: paths!.repoDir.path),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: busy ? null : () => onSyncGit(workspace!),
                icon: Icon(
                  repoReady
                      ? Icons.sync_outlined
                      : Icons.download_for_offline_outlined,
                ),
                label: Text(repoReady ? '拉取更新' : '继续克隆'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkspaceBusyCard extends StatelessWidget {
  const _WorkspaceBusyCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('正在更新工作区'),
        subtitle: Text('完成后会自动刷新列表和详情。'),
      ),
    );
  }
}

enum _WorkspaceAction { activate, rename, delete }

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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

    return SizedBox(
      width: 220,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(value, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(label, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkspaceListItem extends StatelessWidget {
  const _WorkspaceListItem({
    required this.workspace,
    required this.selected,
    required this.active,
    required this.onTap,
    required this.onActivate,
    required this.onRename,
    required this.onDelete,
  });

  final Workspace workspace;
  final bool selected;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onActivate;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.45)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? theme.colorScheme.primary.withValues(alpha: 0.35)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: Icon(active ? Icons.folder_special : Icons.folder_open_outlined),
        title: Row(
          children: [
            Expanded(child: Text(workspace.name)),
            if (active)
              Chip(
                label: const Text('当前'),
                side: BorderSide.none,
                backgroundColor: theme.colorScheme.primaryContainer,
              ),
          ],
        ),
        subtitle: Text(
          workspace.localPath,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<_WorkspaceAction>(
          onSelected: (action) {
            switch (action) {
              case _WorkspaceAction.activate:
                onActivate();
              case _WorkspaceAction.rename:
                onRename();
              case _WorkspaceAction.delete:
                onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: _WorkspaceAction.activate,
              child: Text('设为当前工作区'),
            ),
            PopupMenuItem(
              value: _WorkspaceAction.rename,
              child: Text('重命名'),
            ),
            PopupMenuItem(
              value: _WorkspaceAction.delete,
              child: Text('删除'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PathBlock extends StatelessWidget {
  const _PathBlock({
    required this.title,
    required this.items,
  });

  final String title;
  final List<_PathEntry> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            for (final item in items) ...[
              Text(item.label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              Text(
                item.value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (item != items.last) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _PathEntry {
  const _PathEntry({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
