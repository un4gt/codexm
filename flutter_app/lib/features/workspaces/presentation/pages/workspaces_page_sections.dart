part of 'workspaces_page.dart';

enum _WorkspaceAction { details, activate, rename, delete }

class _WorkspaceStitchListSection extends StatelessWidget {
  const _WorkspaceStitchListSection({
    required this.workspaces,
    required this.selectedWorkspaceId,
    required this.activeWorkspaceId,
    required this.busy,
    required this.onSelectWorkspace,
    required this.onActivateWorkspace,
    required this.onOpenWorkspaceDetails,
    required this.onRenameWorkspace,
    required this.onDeleteWorkspace,
  });

  final List<Workspace> workspaces;
  final WorkspaceId? selectedWorkspaceId;
  final WorkspaceId? activeWorkspaceId;
  final bool busy;
  final ValueChanged<Workspace> onSelectWorkspace;
  final ValueChanged<Workspace> onActivateWorkspace;
  final ValueChanged<Workspace> onOpenWorkspaceDetails;
  final ValueChanged<Workspace> onRenameWorkspace;
  final ValueChanged<Workspace> onDeleteWorkspace;

  @override
  Widget build(BuildContext context) {
    if (workspaces.isEmpty) {
      return const SizedBox(
        height: 360,
        child: AppEmptyState(
          icon: Icons.create_new_folder_outlined,
          title: '还没有工作区',
          message: '点击右上角添加本地工作区，或克隆一个 Git 仓库。',
        ),
      );
    }
    return AppListSection(
      title: '最近工作区',
      children: [
        for (final workspace in workspaces)
          _WorkspaceStitchRow(
            workspace: workspace,
            selected: workspace.id == selectedWorkspaceId,
            active: workspace.id == activeWorkspaceId,
            busy: busy,
            onTap: () => onSelectWorkspace(workspace),
            onActivate: () => onActivateWorkspace(workspace),
            onOpenDetails: () => onOpenWorkspaceDetails(workspace),
            onRename: () => onRenameWorkspace(workspace),
            onDelete: () => onDeleteWorkspace(workspace),
          ),
      ],
    );
  }
}

class _WorkspaceStitchRow extends StatelessWidget {
  const _WorkspaceStitchRow({
    required this.workspace,
    required this.selected,
    required this.active,
    required this.busy,
    required this.onTap,
    required this.onActivate,
    required this.onOpenDetails,
    required this.onRename,
    required this.onDelete,
  });

  final Workspace workspace;
  final bool selected;
  final bool active;
  final bool busy;
  final VoidCallback onTap;
  final VoidCallback onActivate;
  final VoidCallback onOpenDetails;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppListTile(
      title: workspace.name,
      subtitle: active
          ? '当前工作区'
          : (workspace.git == null ? '本地工作区' : 'Git 工作区'),
      selected: selected,
      enabled: !busy,
      leading: Icon(active ? Icons.folder : Icons.folder_outlined),
      trailing: PopupMenuButton<_WorkspaceAction>(
        tooltip: '工作区操作',
        enabled: !busy,
        onSelected: (action) {
          switch (action) {
            case _WorkspaceAction.details:
              onOpenDetails();
            case _WorkspaceAction.activate:
              onActivate();
            case _WorkspaceAction.rename:
              onRename();
            case _WorkspaceAction.delete:
              onDelete();
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: _WorkspaceAction.details, child: Text('工作区详情')),
          PopupMenuItem(
            value: _WorkspaceAction.activate,
            child: Text('设为当前工作区'),
          ),
          PopupMenuItem(value: _WorkspaceAction.rename, child: Text('重命名')),
          PopupMenuItem(value: _WorkspaceAction.delete, child: Text('删除')),
        ],
      ),
      onTap: onTap,
    );
  }
}
