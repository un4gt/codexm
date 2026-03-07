part of 'workspaces_page.dart';

enum _WorkspaceAction { activate, rename, delete }

class _WorkspacePrimaryActionsRow extends StatelessWidget {
  const _WorkspacePrimaryActionsRow({
    required this.busy,
    required this.hasActiveWorkspace,
    required this.onCreateWorkspace,
    required this.onCloneWorkspace,
    required this.onRefresh,
    required this.onOpenSessionsRequested,
  });

  final bool busy;
  final bool hasActiveWorkspace;
  final VoidCallback onCreateWorkspace;
  final VoidCallback onCloneWorkspace;
  final Future<void> Function({String? status}) onRefresh;
  final VoidCallback? onOpenSessionsRequested;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final widthClass = context.adaptiveWidthClassOf(constraints.maxWidth);
        final compact = widthClass.isCompact;
        final actions = <Widget>[
          _PrimaryActionButton(
            label: '新建工作区',
            icon: Icons.create_new_folder_outlined,
            onPressed: busy ? null : onCreateWorkspace,
            filled: true,
          ),
          _PrimaryActionButton(
            label: '克隆仓库',
            icon: Icons.download_for_offline_outlined,
            onPressed: busy ? null : onCloneWorkspace,
            filled: true,
          ),
          _PrimaryActionButton(
            label: '刷新列表',
            icon: Icons.refresh_outlined,
            onPressed: busy ? null : () => onRefresh(),
          ),
          if (hasActiveWorkspace)
            _PrimaryActionButton(
              label: '进入当前会话',
              icon: Icons.chat_outlined,
              onPressed: busy ? null : onOpenSessionsRequested,
            ),
        ];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: compact
                ? Column(
                    children: [
                      for (final action in actions) ...[
                        action,
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
                  ),
          ),
        );
      },
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final button = filled
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );

    return SizedBox(
      height: 52,
      child: button,
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
    required this.onOpenSessionsRequested,
    required this.onSyncGit,
    required this.repoReadyResolver,
    required this.selectedPaths,
  });

  final List<Workspace> workspaces;
  final WorkspaceId? selectedWorkspaceId;
  final WorkspaceId? activeWorkspaceId;
  final ValueChanged<Workspace> onSelectWorkspace;
  final ValueChanged<Workspace> onActivateWorkspace;
  final ValueChanged<Workspace> onRenameWorkspace;
  final ValueChanged<Workspace> onDeleteWorkspace;
  final VoidCallback? onOpenSessionsRequested;
  final ValueChanged<Workspace> onSyncGit;
  final bool Function(WorkspacePaths? paths) repoReadyResolver;
  final WorkspacePaths? selectedPaths;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('工作区', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '只保留最小必要入口：选择工作区、进入会话、拉取或继续克隆。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            if (workspaces.isEmpty)
              const _EmptyHint(
                icon: Icons.create_new_folder_outlined,
                title: '还没有工作区',
                description: '创建或克隆后，这里会显示所有工作区，并保持操作按钮整齐对齐。',
              ),
            for (final workspace in workspaces) ...[
              if (workspaces.first != workspace) const SizedBox(height: 12),
              _WorkspaceListItem(
                workspace: workspace,
                selected: workspace.id == selectedWorkspaceId,
                active: workspace.id == activeWorkspaceId,
                repoReady: workspace.id == selectedWorkspaceId
                    ? repoReadyResolver(selectedPaths)
                    : workspace.git != null,
                onTap: () => onSelectWorkspace(workspace),
                onActivate: () => onActivateWorkspace(workspace),
                onRename: () => onRenameWorkspace(workspace),
                onDelete: () => onDeleteWorkspace(workspace),
                onOpenSession: onOpenSessionsRequested,
                onSyncGit: () => onSyncGit(workspace),
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
        title: Text('正在处理工作区'),
        subtitle: Text('完成后会自动刷新列表。'),
      ),
    );
  }
}

class _WorkspaceListItem extends StatelessWidget {
  const _WorkspaceListItem({
    required this.workspace,
    required this.selected,
    required this.active,
    required this.repoReady,
    required this.onTap,
    required this.onActivate,
    required this.onRename,
    required this.onDelete,
    required this.onOpenSession,
    required this.onSyncGit,
  });

  final Workspace workspace;
  final bool selected;
  final bool active;
  final bool repoReady;
  final VoidCallback onTap;
  final VoidCallback onActivate;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback? onOpenSession;
  final VoidCallback onSyncGit;

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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onTap,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  workspace.name,
                                  style: theme.textTheme.titleMedium,
                                ),
                              ),
                              if (active)
                                Chip(
                                  label: const Text('当前'),
                                  side: BorderSide.none,
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            workspace.localPath,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                PopupMenuButton<_WorkspaceAction>(
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
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final widthClass = context.adaptiveWidthClassOf(
                  constraints.maxWidth,
                );
                final compact = widthClass.isCompact;
                final actions = <Widget>[
                  _CompactWorkspaceButton(
                    label: '进入会话',
                    icon: Icons.chat_outlined,
                    onPressed: onOpenSession,
                    filled: true,
                  ),
                  _CompactWorkspaceButton(
                    label: repoReady ? '拉取更新' : '继续克隆',
                    icon: repoReady
                        ? Icons.sync_outlined
                        : Icons.download_for_offline_outlined,
                    onPressed: onSyncGit,
                  ),
                  _CompactWorkspaceButton(
                    label: active ? '当前工作区' : '设为当前',
                    icon: active
                        ? Icons.check_circle_outline
                        : Icons.playlist_add_check_circle_outlined,
                    onPressed: active ? null : onActivate,
                  ),
                ];
                return compact
                    ? Column(
                        children: [
                          for (final action in actions) ...[
                            action,
                            if (action != actions.last)
                              const SizedBox(height: 10),
                          ],
                        ],
                      )
                    : Row(
                        children: [
                          for (final action in actions) ...[
                            Expanded(child: action),
                            if (action != actions.last)
                              const SizedBox(width: 10),
                          ],
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactWorkspaceButton extends StatelessWidget {
  const _CompactWorkspaceButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final button = filled
        ? FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(label),
          );
    return SizedBox(height: 46, child: button);
  }
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
