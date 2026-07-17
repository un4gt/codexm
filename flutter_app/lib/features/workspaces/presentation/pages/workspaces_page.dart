import 'dart:io';

import 'package:flutter/material.dart';
import 'package:codexm_native/codexm_native.dart';

import '../../../../shared/widgets/app_ui.dart';
import '../../../settings/application/auth_store.dart';
import '../../../settings/application/auth_types.dart' hide AuthRef;
import '../../application/workspace_git_error_mapper.dart';
import '../../application/workspace_models.dart';
import '../../application/workspace_paths.dart';
import '../../application/workspace_store.dart';

part 'workspaces_page_sections.dart';

class WorkspacesPage extends StatefulWidget {
  const WorkspacesPage({
    super.key,
    this.activeWorkspaceId,
    this.onActiveWorkspaceChanged,
    this.onOpenSessionsRequested,
    this.lockedWorkspaceId,
  });

  final WorkspaceId? activeWorkspaceId;
  final ValueChanged<Workspace?>? onActiveWorkspaceChanged;
  final VoidCallback? onOpenSessionsRequested;
  final WorkspaceId? lockedWorkspaceId;

  @override
  State<WorkspacesPage> createState() => _WorkspacesPageState();
}

class _WorkspaceCloneDraft {
  const _WorkspaceCloneDraft({
    required this.name,
    required this.remoteUrl,
    this.branch,
    this.username,
    this.token,
    this.userName,
    this.userEmail,
    this.allowInsecure = false,
  });

  final String name;
  final String remoteUrl;
  final String? branch;
  final String? username;
  final String? token;
  final String? userName;
  final String? userEmail;
  final bool allowInsecure;
}

enum _WorkspaceCloneAuthMode { none, token }

class _WorkspacesPageState extends State<WorkspacesPage> {
  final _native = const CodexmNative();
  final _workspaceStore = WorkspaceStore();
  final _workspaceDirectoryService = WorkspaceDirectoryService();
  final _authStore = AuthStore();

  List<Workspace> _workspaces = const <Workspace>[];
  WorkspaceId? _activeWorkspaceId;
  WorkspaceId? _selectedWorkspaceId;
  WorkspacePaths? _selectedPaths;
  String _status = '正在加载工作区列表...';
  bool _busy = false;

  bool _blockMutationWhileSessionRuns() {
    if (widget.lockedWorkspaceId == null) {
      return false;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前会话仍在运行，完成后可修改工作区。')));
    return true;
  }

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() => super.dispose();

  @override
  void didUpdateWidget(covariant WorkspacesPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeWorkspaceId != widget.activeWorkspaceId) {
      _refresh(
        status: widget.activeWorkspaceId == null ? _status : '已同步当前工作区。',
      );
    }
  }

  Future<void> _refresh({String? status}) async {
    final workspaces = await _workspaceStore.listWorkspaces();
    final activeId =
        widget.activeWorkspaceId ??
        await _workspaceStore.getActiveWorkspaceId();
    final selectedId = _resolveSelectedWorkspaceId(workspaces, activeId);
    final selected = _findWorkspace(workspaces, selectedId);
    final paths = selected == null
        ? null
        : await _workspaceDirectoryService.pathsFor(selected.id);

    if (!mounted) {
      return;
    }

    setState(() {
      _workspaces = workspaces;
      _activeWorkspaceId = activeId;
      _selectedWorkspaceId = selected?.id;
      _selectedPaths = paths;
      _status =
          status ??
          (workspaces.isEmpty
              ? '还没有工作区，创建后即可开始迁移后的 Flutter 工作流。'
              : '已加载 ${workspaces.length} 个工作区。');
    });

    widget.onActiveWorkspaceChanged?.call(_findWorkspace(workspaces, activeId));
  }

  WorkspaceId? _resolveSelectedWorkspaceId(
    List<Workspace> workspaces,
    WorkspaceId? activeId,
  ) {
    final preferred = <WorkspaceId?>[
      widget.activeWorkspaceId,
      _selectedWorkspaceId,
      activeId,
      workspaces.isEmpty ? null : workspaces.first.id,
    ];
    for (final candidate in preferred) {
      if (candidate == null) {
        continue;
      }
      if (workspaces.any((workspace) => workspace.id == candidate)) {
        return candidate;
      }
    }
    return null;
  }

  Workspace? _findWorkspace(List<Workspace> workspaces, WorkspaceId? id) {
    if (id == null) {
      return null;
    }
    for (final workspace in workspaces) {
      if (workspace.id == id) {
        return workspace;
      }
    }
    return null;
  }

  void _updateView(VoidCallback change) {
    if (!mounted) {
      return;
    }
    setState(change);
  }

  Future<void> _runAction(
    String pendingStatus,
    Future<String> Function() action,
  ) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _status = pendingStatus;
    });

    try {
      final successStatus = await action();
      await _refresh(status: successStatus);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = _mapWorkspaceError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _mapWorkspaceError(Object error) {
    return mapWorkspaceGitError(error).message;
  }

  Future<String?> _promptWorkspaceName({
    required String title,
    String? initialValue,
    String? hintText,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(labelText: '名称', hintText: hintText),
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
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('保存'),
            ),
          ],
        );
      },
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirmDelete(Workspace workspace) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除工作区'),
          content: Text('将删除「${workspace.name}」的本地数据。此操作无法撤销。'),
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

  Future<void> _createWorkspace() async {
    if (_blockMutationWhileSessionRuns()) {
      return;
    }
    final name = await _promptWorkspaceName(
      title: '新建工作区',
      hintText: '例如：Flutter 主线',
    );
    if (name == null) {
      return;
    }

    await _runAction('正在创建工作区...', () async {
      final workspace = await _workspaceStore.createWorkspace(name: name);
      await _workspaceStore.setActiveWorkspaceId(workspace.id);
      _selectedWorkspaceId = workspace.id;
      widget.onActiveWorkspaceChanged?.call(workspace);
      return '已创建并激活工作区：${workspace.name}';
    });
  }

  Future<_WorkspaceCloneDraft?> _promptCloneWorkspaceDraft() async {
    final nameController = TextEditingController();
    final remoteUrlController = TextEditingController();
    final branchController = TextEditingController();
    final usernameController = TextEditingController();
    final tokenController = TextEditingController();
    final userNameController = TextEditingController();
    final userEmailController = TextEditingController();
    var allowInsecure = false;
    var authMode = _WorkspaceCloneAuthMode.none;

    final result = await showDialog<_WorkspaceCloneDraft>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final theme = Theme.of(context);
            return Dialog.fullscreen(
              child: SafeArea(
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text('克隆仓库工作区'),
                    leading: IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ),
                  body: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      _CloneFormSection(
                        title: '1. 仓库信息',
                        description: '先填写仓库地址和工作区名称，系统会用它创建本地工作区。',
                        child: Column(
                          children: [
                            TextField(
                              controller: nameController,
                              autofocus: true,
                              decoration: const InputDecoration(
                                labelText: '工作区名称',
                                hintText: '例如：Flutter 主线',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: remoteUrlController,
                              decoration: const InputDecoration(
                                labelText: '仓库地址',
                                hintText: 'https://github.com/org/repo.git',
                              ),
                              onChanged: (value) {
                                final currentName = nameController.text.trim();
                                if (currentName.isNotEmpty) {
                                  return;
                                }
                                final derived =
                                    _deriveWorkspaceNameFromRemoteUrl(value);
                                if (derived == null) {
                                  return;
                                }
                                nameController.text = derived;
                                nameController.selection =
                                    TextSelection.collapsed(
                                      offset: derived.length,
                                    );
                              },
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: branchController,
                              decoration: const InputDecoration(
                                labelText: '分支（可选）',
                                hintText: '留空时使用仓库默认分支',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _CloneFormSection(
                        title: '2. 认证方式',
                        description: '公开仓库可直接连接；私有仓库请填写访问账号和令牌。',
                        child: Column(
                          children: [
                            SegmentedButton<_WorkspaceCloneAuthMode>(
                              segments: const [
                                ButtonSegment(
                                  value: _WorkspaceCloneAuthMode.none,
                                  label: Text('公开仓库'),
                                ),
                                ButtonSegment(
                                  value: _WorkspaceCloneAuthMode.token,
                                  label: Text('账号 + 令牌'),
                                ),
                              ],
                              selected: <_WorkspaceCloneAuthMode>{authMode},
                              onSelectionChanged: (selection) {
                                setLocalState(() {
                                  authMode = selection.first;
                                });
                              },
                            ),
                            if (authMode == _WorkspaceCloneAuthMode.token) ...[
                              const SizedBox(height: 12),
                              TextField(
                                controller: usernameController,
                                decoration: const InputDecoration(
                                  labelText: '访问账号',
                                  hintText:
                                      '例如：git 用户名 / oauth2 / x-access-token',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: tokenController,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: '访问令牌',
                                  hintText: '请输入仓库访问令牌',
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _CloneFormSection(
                        title: '3. 安全与提交身份',
                        description: '仅在需要时填写，用于自签名仓库或后续提交身份设置。',
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              value: allowInsecure,
                              onChanged: (value) {
                                setLocalState(() {
                                  allowInsecure = value;
                                });
                              },
                              title: const Text('允许跳过证书校验'),
                              subtitle: const Text('允许不受信任的证书。'),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: userNameController,
                              decoration: const InputDecoration(
                                labelText: '提交用户名（可选）',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: userEmailController,
                              decoration: const InputDecoration(
                                labelText: '提交邮箱（可选）',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant.withValues(
                              alpha: 0.8,
                            ),
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(14),
                          child: Text('创建后会自动激活工作区；完成仓库准备后，可直接进入会话。'),
                        ),
                      ),
                    ],
                  ),
                  bottomNavigationBar: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(),
                              child: const Text('取消'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(dialogContext).pop(
                                  _WorkspaceCloneDraft(
                                    name: nameController.text.trim(),
                                    remoteUrl: remoteUrlController.text.trim(),
                                    branch: branchController.text.trim().isEmpty
                                        ? null
                                        : branchController.text.trim(),
                                    username:
                                        authMode ==
                                                _WorkspaceCloneAuthMode.token &&
                                            usernameController.text
                                                .trim()
                                                .isNotEmpty
                                        ? usernameController.text.trim()
                                        : null,
                                    token:
                                        authMode ==
                                                _WorkspaceCloneAuthMode.token &&
                                            tokenController.text
                                                .trim()
                                                .isNotEmpty
                                        ? tokenController.text.trim()
                                        : null,
                                    userName:
                                        userNameController.text.trim().isEmpty
                                        ? null
                                        : userNameController.text.trim(),
                                    userEmail:
                                        userEmailController.text.trim().isEmpty
                                        ? null
                                        : userEmailController.text.trim(),
                                    allowInsecure: allowInsecure,
                                  ),
                                );
                              },
                              child: const Text('开始克隆'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    nameController.dispose();
    remoteUrlController.dispose();
    branchController.dispose();
    usernameController.dispose();
    tokenController.dispose();
    userNameController.dispose();
    userEmailController.dispose();
    return result;
  }

  String? _deriveWorkspaceNameFromRemoteUrl(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    var normalized = trimmed;
    final slashIndex = normalized.lastIndexOf('/');
    if (slashIndex >= 0 && slashIndex < normalized.length - 1) {
      normalized = normalized.substring(slashIndex + 1);
    }
    final colonIndex = normalized.lastIndexOf(':');
    if (colonIndex >= 0 && colonIndex < normalized.length - 1) {
      normalized = normalized.substring(colonIndex + 1);
    }
    normalized = normalized.replaceAll(RegExp(r'\.git$'), '');
    normalized = normalized.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    return normalized.isEmpty ? null : normalized;
  }

  Future<Map<String, Object?>?> _loadGitAuth(WorkspaceGitConfig config) {
    final authRef = config.authRef;
    if (authRef == null || authRef.trim().isEmpty) {
      return Future<Map<String, Object?>?>.value(null);
    }
    return _authStore.loadAuth(authRef);
  }

  bool _isRepoReady(WorkspacePaths? paths) {
    if (paths == null) {
      return false;
    }
    return Directory('${paths.repoDir.path}/.git').existsSync();
  }

  Future<void> _cloneWorkspace() async {
    if (_blockMutationWhileSessionRuns()) {
      return;
    }
    final draft = await _promptCloneWorkspaceDraft();
    if (draft == null) {
      return;
    }
    if (draft.remoteUrl.trim().isEmpty) {
      _updateView(() {
        _status = '仓库地址不能为空。';
      });
      return;
    }

    await _runAction('正在克隆仓库...', () async {
      final workspaceName = draft.name.trim().isEmpty
          ? (_deriveWorkspaceNameFromRemoteUrl(draft.remoteUrl) ?? '新工作区')
          : draft.name.trim();
      AuthRef? authRef;
      if (draft.username?.trim().isNotEmpty == true &&
          draft.token?.trim().isNotEmpty == true) {
        authRef = await _authStore.saveAuth(
          GitHttpsAuth(
            username: draft.username!.trim(),
            token: draft.token!.trim(),
          ).toMap(),
        );
      }

      final gitConfig = WorkspaceGitConfig(
        remoteUrl: draft.remoteUrl.trim(),
        defaultBranch: draft.branch?.trim(),
        authRef: authRef,
        allowInsecure: draft.allowInsecure,
        userName: draft.userName?.trim(),
        userEmail: draft.userEmail?.trim(),
      );
      final workspace = await _workspaceStore.createWorkspace(
        name: workspaceName,
        git: gitConfig,
      );
      final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
      _updateView(() {
        _selectedWorkspaceId = workspace.id;
      });
      await _native.gitClone(
        remoteUrl: gitConfig.remoteUrl,
        localRepoDirUri: paths.repoDir.path,
        branch: gitConfig.defaultBranch,
        username: draft.username?.trim(),
        token: draft.token?.trim(),
        userName: gitConfig.userName,
        userEmail: gitConfig.userEmail,
        allowInsecure: gitConfig.allowInsecure,
      );
      await _workspaceStore.setActiveWorkspaceId(workspace.id);
      widget.onActiveWorkspaceChanged?.call(workspace);
      return '已克隆并激活工作区：${workspace.name}';
    });
  }

  Future<void> _syncWorkspaceGit(Workspace workspace) async {
    if (_blockMutationWhileSessionRuns()) {
      return;
    }
    final git = workspace.git;
    final paths =
        _selectedPaths ??
        await _workspaceDirectoryService.pathsFor(workspace.id);
    if (git == null) {
      _updateView(() {
        _status = '当前工作区未配置仓库来源。';
      });
      return;
    }
    final auth = await _loadGitAuth(git);
    final username = auth?['username']?.toString();
    final token = auth?['token']?.toString();
    final repoReady = _isRepoReady(paths);
    await _runAction('正在${repoReady ? '拉取' : '克隆'}仓库...', () async {
      if (repoReady) {
        await _native.gitPull(
          localRepoDirUri: paths.repoDir.path,
          remote: 'origin',
          branch: git.defaultBranch,
          username: username,
          token: token,
          allowInsecure: git.allowInsecure,
        );
        return '已完成仓库拉取。';
      }
      await _native.gitClone(
        remoteUrl: git.remoteUrl,
        localRepoDirUri: paths.repoDir.path,
        branch: git.defaultBranch,
        username: username,
        token: token,
        userName: git.userName,
        userEmail: git.userEmail,
        allowInsecure: git.allowInsecure,
      );
      return '已完成仓库克隆。';
    });
  }

  Future<void> _activateWorkspace(Workspace workspace) async {
    if (_blockMutationWhileSessionRuns()) {
      return;
    }
    await _runAction('正在切换工作区...', () async {
      await _workspaceStore.setActiveWorkspaceId(workspace.id);
      widget.onActiveWorkspaceChanged?.call(workspace);
      return '已切换到工作区：${workspace.name}';
    });
  }

  Future<void> _renameWorkspace(Workspace workspace) async {
    if (_blockMutationWhileSessionRuns()) {
      return;
    }
    final name = await _promptWorkspaceName(
      title: '重命名工作区',
      initialValue: workspace.name,
    );
    if (name == null) {
      return;
    }

    await _runAction('正在保存工作区名称...', () async {
      final nextName = name.trim().isEmpty ? workspace.name : name.trim();
      await _workspaceStore.upsertWorkspace(workspace.copyWith(name: nextName));
      return '已更新工作区名称。';
    });
  }

  Future<bool> _deleteWorkspace(Workspace workspace) async {
    if (_blockMutationWhileSessionRuns()) {
      return false;
    }
    final confirmed = await _confirmDelete(workspace);
    if (!confirmed) {
      return false;
    }

    var deleted = false;
    await _runAction('正在删除工作区...', () async {
      await _workspaceStore.removeWorkspace(workspace.id);
      deleted = true;
      if (_selectedWorkspaceId == workspace.id) {
        _selectedWorkspaceId = null;
      }
      if (_activeWorkspaceId == workspace.id) {
        widget.onActiveWorkspaceChanged?.call(null);
      }
      return '已删除工作区：${workspace.name}';
    });
    return deleted;
  }

  void _selectWorkspace(Workspace workspace) {
    setState(() {
      _selectedWorkspaceId = workspace.id;
      _status = '已查看工作区详情：${workspace.name}';
    });
    _workspaceDirectoryService.pathsFor(workspace.id).then((paths) {
      if (!mounted || _selectedWorkspaceId != workspace.id) {
        return;
      }
      setState(() {
        _selectedPaths = paths;
      });
    });
  }

  Future<void> _showWorkspaceAddActions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: AppListSection(
            children: [
              AppListTile(
                title: '新建空白工作区',
                subtitle: '创建一个本地工作区',
                leading: const Icon(Icons.create_new_folder_outlined),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _createWorkspace();
                },
              ),
              AppListTile(
                title: '克隆 Git 仓库',
                subtitle: '从远程仓库创建工作区',
                leading: const Icon(Icons.download_outlined),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _cloneWorkspace();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openWorkspaceDetails(Workspace workspace) async {
    _selectWorkspace(workspace);
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (detailContext) => _WorkspaceDetailPage(
          workspace: workspace,
          active: workspace.id == _activeWorkspaceId,
          pathsFuture: _workspaceDirectoryService.pathsFor(workspace.id),
          repoReadyResolver: _isRepoReady,
          busy: _busy,
          onActivate: () => _activateWorkspace(workspace),
          onSync: () => _syncWorkspaceGit(workspace),
          onRename: () => _renameWorkspace(workspace),
          onDelete: () async {
            final deleted = await _deleteWorkspace(workspace);
            if (deleted && detailContext.mounted) {
              Navigator.of(detailContext).pop();
            }
            return deleted;
          },
          onOpenSessions: () async {
            if (workspace.id != _activeWorkspaceId) {
              await _activateWorkspace(workspace);
            }
            if (detailContext.mounted) {
              Navigator.of(detailContext).pop();
            }
            widget.onOpenSessionsRequested?.call();
          },
        ),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final showError = _status.contains('失败') || _status.contains('不能为空');
    return AppPageScaffold(
      title: '工作区',
      actions: [
        IconButton(
          onPressed: _busy ? null : _showWorkspaceAddActions,
          tooltip: '添加工作区',
          icon: const Icon(Icons.add),
        ),
      ],
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (showError)
            AppStatusNotice(message: _status, tone: AppNoticeTone.error),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _WorkspaceStitchListSection(
                    workspaces: _workspaces,
                    selectedWorkspaceId: _selectedWorkspaceId,
                    activeWorkspaceId: _activeWorkspaceId,
                    busy: _busy,
                    onSelectWorkspace: _openWorkspaceDetails,
                    onActivateWorkspace: _activateWorkspace,
                    onRenameWorkspace: _renameWorkspace,
                    onDeleteWorkspace: _deleteWorkspace,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceDetailPage extends StatelessWidget {
  const _WorkspaceDetailPage({
    required this.workspace,
    required this.active,
    required this.pathsFuture,
    required this.repoReadyResolver,
    required this.busy,
    required this.onActivate,
    required this.onSync,
    required this.onRename,
    required this.onDelete,
    required this.onOpenSessions,
  });

  final Workspace workspace;
  final bool active;
  final Future<WorkspacePaths> pathsFuture;
  final bool Function(WorkspacePaths? paths) repoReadyResolver;
  final bool busy;
  final Future<void> Function() onActivate;
  final Future<void> Function() onSync;
  final Future<void> Function() onRename;
  final Future<bool> Function() onDelete;
  final Future<void> Function() onOpenSessions;

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: workspace.name,
      actions: [
        PopupMenuButton<String>(
          tooltip: '工作区操作',
          onSelected: (value) {
            if (value == 'rename') {
              onRename();
            } else if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'rename', child: Text('重命名')),
            PopupMenuItem(value: 'delete', child: Text('删除')),
          ],
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          AppListSection(
            title: '概览',
            children: [
              AppListTile(
                title: active ? '当前工作区' : '非当前工作区',
                subtitle: active ? '新会话将在这里运行' : '设为当前后可开始会话',
                leading: Icon(
                  active ? Icons.check_circle : Icons.folder_outlined,
                ),
                trailing: active
                    ? null
                    : TextButton(
                        onPressed: busy ? null : onActivate,
                        child: const Text('设为当前'),
                      ),
              ),
              FutureBuilder<WorkspacePaths>(
                future: pathsFuture,
                builder: (context, snapshot) {
                  final ready = repoReadyResolver(snapshot.data);
                  return AppListTile(
                    title: workspace.git == null ? '本地工作区' : 'Git 仓库',
                    subtitle: workspace.git == null
                        ? '未配置远程仓库'
                        : (ready ? '仓库已准备，可以同步' : '仓库尚未完成克隆'),
                    leading: Icon(
                      ready
                          ? Icons.source_outlined
                          : Icons.cloud_download_outlined,
                    ),
                    trailing: workspace.git == null
                        ? null
                        : TextButton(
                            onPressed: busy ? null : onSync,
                            child: Text(ready ? '拉取更新' : '继续克隆'),
                          ),
                  );
                },
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: FilledButton.icon(
              onPressed: busy ? null : onOpenSessions,
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('进入会话'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloneFormSection extends StatelessWidget {
  const _CloneFormSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            child,
          ],
        ),
      ),
    );
  }
}
