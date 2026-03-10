part of 'workspaces_page.dart';

enum _WorkspaceAction { activate, rename, delete }

class _WorkspaceStitchListSection extends StatelessWidget {
  const _WorkspaceStitchListSection({
    required this.workspaces,
    required this.selectedWorkspaceId,
    required this.activeWorkspaceId,
    required this.selectedPaths,
    required this.busy,
    required this.onSelectWorkspace,
    required this.onActivateWorkspace,
    required this.onRenameWorkspace,
    required this.onDeleteWorkspace,
    required this.onSyncGit,
    required this.onOpenSessionsRequested,
    required this.repoReadyResolver,
  });

  final List<Workspace> workspaces;
  final WorkspaceId? selectedWorkspaceId;
  final WorkspaceId? activeWorkspaceId;
  final WorkspacePaths? selectedPaths;
  final bool busy;
  final ValueChanged<Workspace> onSelectWorkspace;
  final ValueChanged<Workspace> onActivateWorkspace;
  final ValueChanged<Workspace> onRenameWorkspace;
  final ValueChanged<Workspace> onDeleteWorkspace;
  final ValueChanged<Workspace> onSyncGit;
  final VoidCallback? onOpenSessionsRequested;
  final bool Function(WorkspacePaths? paths) repoReadyResolver;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StitchSectionHeader(title: '最近工作区'),
        SizedBox(height: tokens.compactSpacing),
        if (workspaces.isEmpty)
          const StitchListItem(
            title: '还没有工作区',
            subtitle: '点击右下角「新建工作区」，或使用顶部按钮克隆仓库。',
            leading: Icon(Icons.create_new_folder_outlined),
          ),
        for (final workspace in workspaces) ...[
          if (workspaces.first != workspace) const SizedBox(height: 12),
          _WorkspaceStitchRow(
            workspace: workspace,
            selected: workspace.id == selectedWorkspaceId,
            active: workspace.id == activeWorkspaceId,
            repoReady: workspace.id == selectedWorkspaceId
                ? repoReadyResolver(selectedPaths)
                : workspace.git != null,
            busy: busy,
            onTap: () => onSelectWorkspace(workspace),
            onActivate: () => onActivateWorkspace(workspace),
            onRename: () => onRenameWorkspace(workspace),
            onDelete: () => onDeleteWorkspace(workspace),
            onOpenSession: onOpenSessionsRequested,
            onSyncGit: () => onSyncGit(workspace),
          ),
        ],
      ],
    );
  }
}

class _WorkspaceStitchRow extends StatelessWidget {
  const _WorkspaceStitchRow({
    required this.workspace,
    required this.selected,
    required this.active,
    required this.repoReady,
    required this.busy,
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
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onActivate;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  final VoidCallback? onOpenSession;
  final VoidCallback onSyncGit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = context.appTokens;

    final metaLine = active ? '当前工作区 · ${workspace.localPath}' : workspace.localPath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StitchListItem(
          title: workspace.name,
          subtitle: metaLine,
          highlighted: selected,
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected
                  ? colorScheme.primary.withValues(alpha: 0.14)
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              active ? Icons.folder : Icons.folder_outlined,
              color: colorScheme.primary,
            ),
          ),
          trailing: PopupMenuButton<_WorkspaceAction>(
            onSelected: busy
                ? null
                : (action) {
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
          onTap: onTap,
        ),
        SizedBox(height: tokens.compactSpacing),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: busy ? null : onOpenSession,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('进入会话'),
            ),
            OutlinedButton.icon(
              onPressed: busy ? null : onSyncGit,
              icon: Icon(
                repoReady ? Icons.sync_outlined : Icons.download_outlined,
              ),
              label: Text(repoReady ? '拉取更新' : '继续克隆'),
            ),
            OutlinedButton.icon(
              onPressed: busy || active ? null : onActivate,
              icon: Icon(
                active
                    ? Icons.check_circle_outline
                    : Icons.playlist_add_check_circle_outlined,
              ),
              label: Text(active ? '当前工作区' : '设为当前'),
            ),
          ],
        ),
      ],
    );
  }
}
