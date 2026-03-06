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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: _MetricTile(
                icon: Icons.folder_copy_outlined,
                label: '工作区数量',
                value: '${workspaces.length}',
              ),
            ),
            Expanded(
              child: _MetricTile(
                icon: Icons.check_circle_outline,
                label: '当前工作区',
                value: activeWorkspace?.name ?? '未选择',
              ),
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
            const SizedBox(height: 12),
            if (workspaces.isEmpty) const Text('还没有工作区，创建后会自动准备本地目录与运行环境。'),
            for (final workspace in workspaces) ...[
              if (workspaces.first != workspace) const Divider(height: 1),
              ListTile(
                selected: workspace.id == selectedWorkspaceId,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  workspace.id == activeWorkspaceId
                      ? Icons.folder_special
                      : Icons.folder_open_outlined,
                ),
                title: Row(
                  children: [
                    Expanded(child: Text(workspace.name)),
                    if (workspace.id == activeWorkspaceId)
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
                onTap: () => onSelectWorkspace(workspace),
                trailing: PopupMenuButton<_WorkspaceAction>(
                  onSelected: (action) {
                    switch (action) {
                      case _WorkspaceAction.activate:
                        onActivateWorkspace(workspace);
                      case _WorkspaceAction.rename:
                        onRenameWorkspace(workspace);
                      case _WorkspaceAction.delete:
                        onDeleteWorkspace(workspace);
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('工作区详情', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (workspace == null) const Text('选择一个工作区后，这里会展示本地目录与运行摘要。'),
            if (workspace != null) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: Text(workspace!.name),
                subtitle: Text('创建时间：${formatDate(workspace!.createdAt)}'),
                trailing: FilledButton.tonal(
                  onPressed: busy
                      ? null
                      : () => onActivateWorkspace(workspace!),
                  child: Text(
                    workspace!.id == activeWorkspaceId ? '已激活' : '设为当前',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _PathTile(
                icon: Icons.folder_open_outlined,
                title: '工作区目录',
                value: paths?.workspaceRoot.path ?? workspace!.localPath,
              ),
              _PathTile(
                icon: Icons.source_outlined,
                title: '仓库目录',
                value: paths?.repoDir.path ?? '尚未准备',
              ),
              _PathTile(
                icon: Icons.play_circle_outline,
                title: '运行目录',
                value: paths?.codexHomeDir.path ?? '尚未准备',
              ),
              _PathTile(
                icon: Icons.timer_outlined,
                title: '临时目录',
                value: paths?.tmpDir.path ?? '尚未准备',
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: onOpenSessionsRequested,
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('进入会话'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy
                        ? null
                        : () => onRenameWorkspace(workspace!),
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
            Text('仓库来源', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (workspace == null)
              const Text('选择一个工作区后，这里会展示仓库地址、认证摘要与同步入口。'),
            if (workspace != null && git == null)
              const Text('当前工作区是空白工作区，尚未绑定仓库来源。'),
            if (workspace != null && git != null) ...[
              _PathTile(
                icon: Icons.cloud_outlined,
                title: '远端地址',
                value: git.remoteUrl,
              ),
              _PathTile(
                icon: Icons.account_tree_outlined,
                title: '默认分支',
                value: git.defaultBranch?.trim().isNotEmpty == true
                    ? git.defaultBranch!
                    : '未指定',
              ),
              _PathTile(
                icon: Icons.key_outlined,
                title: '认证信息',
                value: git.authRef?.trim().isNotEmpty == true ? '已保存' : '未保存',
              ),
              _PathTile(
                icon: Icons.inventory_2_outlined,
                title: '仓库状态',
                value: repoReady ? '已准备' : '尚未完成克隆',
              ),
              if (git.userName?.trim().isNotEmpty == true ||
                  git.userEmail?.trim().isNotEmpty == true)
                _PathTile(
                  icon: Icons.badge_outlined,
                  title: '提交身份',
                  value:
                      '${git.userName?.trim().isNotEmpty == true ? git.userName : '未设置'} / ${git.userEmail?.trim().isNotEmpty == true ? git.userEmail : '未设置'}',
                ),
              if (paths != null)
                _PathTile(
                  icon: Icons.source_outlined,
                  title: '本地仓库目录',
                  value: paths!.repoDir.path,
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
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

class _WorkspaceDebugInfoCard extends StatelessWidget {
  const _WorkspaceDebugInfoCard({
    required this.workspace,
    required this.paths,
    required this.activeWorkspaceId,
  });

  final Workspace? workspace;
  final WorkspacePaths? paths;
  final WorkspaceId? activeWorkspaceId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logsDirPath = paths == null
        ? '尚未准备'
        : '${paths!.codexHomeDir.path}/logs';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('调试信息', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (workspace == null)
              const Text('选择一个工作区后，这里会展示 Android Flutter 迁移线的调试路径信息。'),
            if (workspace != null) ...[
              _PathTile(
                icon: Icons.tag_outlined,
                title: '工作区 ID',
                value: workspace!.id,
              ),
              _PathTile(
                icon: Icons.check_circle_outline,
                title: '当前激活',
                value: workspace!.id == activeWorkspaceId ? '是' : '否',
              ),
              _PathTile(
                icon: Icons.description_outlined,
                title: '清单文件',
                value: paths?.workspaceJsonFile.path ?? '尚未准备',
              ),
              _PathTile(
                icon: Icons.data_object_outlined,
                title: '元数据目录',
                value: paths?.metaDir.path ?? '尚未准备',
              ),
              _PathTile(
                icon: Icons.play_circle_outline,
                title: 'Codex Home',
                value: paths?.codexHomeDir.path ?? '尚未准备',
              ),
              _PathTile(
                icon: Icons.settings_outlined,
                title: '配置文件',
                value: paths?.configTomlFile.path ?? '尚未准备',
              ),
              _PathTile(
                icon: Icons.key_outlined,
                title: '认证文件',
                value: paths?.authJsonFile.path ?? '尚未准备',
              ),
              _PathTile(
                icon: Icons.bug_report_outlined,
                title: '日志目录',
                value: logsDirPath,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _WorkspaceAction { activate, rename, delete }

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

class _PathTile extends StatelessWidget {
  const _PathTile({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
    );
  }
}
