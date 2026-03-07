import 'dart:io';

import 'package:flutter/material.dart';
import 'package:codexm_native/codexm_native.dart';

import '../../../../shared/widgets/feature_scaffold.dart';
import '../../../settings/application/auth_store.dart';
import '../../../settings/application/auth_types.dart' hide AuthRef;
import '../../application/workspace_models.dart';
import '../../application/workspace_paths.dart';
import '../../application/workspace_store.dart';
import '../../../webdav/application/webdav_client.dart';
import '../../../webdav/application/webdav_sync.dart';
import '../../../webdav/application/webdav_types.dart';

part 'workspaces_page_sections.dart';
part 'workspaces_page_webdav.dart';

class WorkspacesPage extends StatefulWidget {
  const WorkspacesPage({
    super.key,
    this.activeWorkspaceId,
    this.onActiveWorkspaceChanged,
    this.onOpenSessionsRequested,
  });

  final WorkspaceId? activeWorkspaceId;
  final ValueChanged<Workspace?>? onActiveWorkspaceChanged;
  final VoidCallback? onOpenSessionsRequested;

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

class _WorkspacesPageState extends State<WorkspacesPage> {
  final _native = const CodexmNative();
  final _workspaceStore = WorkspaceStore();
  final _workspaceDirectoryService = WorkspaceDirectoryService();
  final _authStore = AuthStore();
  final _webDavSyncService = const WebDavSyncService();

  late final TextEditingController _webDavEndpointController;
  late final TextEditingController _webDavBasePathController;
  late final TextEditingController _webDavRemoteRootController;
  late final TextEditingController _webDavBasicUserController;
  late final TextEditingController _webDavBasicPasswordController;
  late final TextEditingController _webDavBearerTokenController;

  List<Workspace> _workspaces = const <Workspace>[];
  WorkspaceId? _activeWorkspaceId;
  WorkspaceId? _selectedWorkspaceId;
  WorkspacePaths? _selectedPaths;
  String _status = '正在加载工作区列表...';
  String _webDavStatus = '当前工作区尚未配置 WebDAV。';
  String _webDavAuthType = 'none';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _webDavEndpointController = TextEditingController();
    _webDavBasePathController = TextEditingController();
    _webDavRemoteRootController = TextEditingController();
    _webDavBasicUserController = TextEditingController();
    _webDavBasicPasswordController = TextEditingController();
    _webDavBearerTokenController = TextEditingController();
    _refresh();
  }

  @override
  void dispose() {
    _webDavEndpointController.dispose();
    _webDavBasePathController.dispose();
    _webDavRemoteRootController.dispose();
    _webDavBasicUserController.dispose();
    _webDavBasicPasswordController.dispose();
    _webDavBearerTokenController.dispose();
    super.dispose();
  }

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
    final webDavDraft = await _loadWebDavDraft(selected);

    if (!mounted) {
      return;
    }

    _applyWebDavDraft(webDavDraft);
    setState(() {
      _workspaces = workspaces;
      _activeWorkspaceId = activeId;
      _selectedWorkspaceId = selected?.id;
      _selectedPaths = paths;
      _webDavAuthType = webDavDraft.authType;
      _webDavStatus = webDavDraft.status;
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

  Workspace? get _selectedWorkspace =>
      _findWorkspace(_workspaces, _selectedWorkspaceId);

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
        _status = '执行失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
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

    final result = await showDialog<_WorkspaceCloneDraft>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              title: const Text('克隆仓库工作区'),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
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
                          final derived = _deriveWorkspaceNameFromRemoteUrl(value);
                          if (derived == null) {
                            return;
                          }
                          nameController.text = derived;
                          nameController.selection = TextSelection.collapsed(
                            offset: derived.length,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: branchController,
                        decoration: const InputDecoration(
                          labelText: '分支（可选）',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: usernameController,
                        decoration: const InputDecoration(
                          labelText: '访问账号（可选）',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: tokenController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: '访问令牌（可选）',
                        ),
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
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: allowInsecure,
                        onChanged: (value) {
                          setLocalState(() {
                            allowInsecure = value;
                          });
                        },
                        title: const Text('允许跳过证书校验'),
                        subtitle: const Text('仅在内网或自签名证书场景下使用。'),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(
                      _WorkspaceCloneDraft(
                        name: nameController.text.trim(),
                        remoteUrl: remoteUrlController.text.trim(),
                        branch: branchController.text.trim().isEmpty
                            ? null
                            : branchController.text.trim(),
                        username: usernameController.text.trim().isEmpty
                            ? null
                            : usernameController.text.trim(),
                        token: tokenController.text.trim().isEmpty
                            ? null
                            : tokenController.text.trim(),
                        userName: userNameController.text.trim().isEmpty
                            ? null
                            : userNameController.text.trim(),
                        userEmail: userEmailController.text.trim().isEmpty
                            ? null
                            : userEmailController.text.trim(),
                        allowInsecure: allowInsecure,
                      ),
                    );
                  },
                  child: const Text('开始克隆'),
                ),
              ],
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
    final git = workspace.git;
    final paths = _selectedPaths ??
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
    await _runAction('正在切换工作区...', () async {
      await _workspaceStore.setActiveWorkspaceId(workspace.id);
      widget.onActiveWorkspaceChanged?.call(workspace);
      return '已切换到工作区：${workspace.name}';
    });
  }

  Future<void> _renameWorkspace(Workspace workspace) async {
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

  Future<void> _deleteWorkspace(Workspace workspace) async {
    final confirmed = await _confirmDelete(workspace);
    if (!confirmed) {
      return;
    }

    await _runAction('正在删除工作区...', () async {
      await _workspaceStore.removeWorkspace(workspace.id);
      if (_selectedWorkspaceId == workspace.id) {
        _selectedWorkspaceId = null;
      }
      if (_activeWorkspaceId == workspace.id) {
        widget.onActiveWorkspaceChanged?.call(null);
      }
      return '已删除工作区：${workspace.name}';
    });
  }

  void _selectWorkspace(Workspace workspace) {
    setState(() {
      _selectedWorkspaceId = workspace.id;
      _status = '已查看工作区详情：${workspace.name}';
    });
    _workspaceDirectoryService.pathsFor(workspace.id).then((paths) async {
      final webDavDraft = await _loadWebDavDraft(workspace);
      if (!mounted || _selectedWorkspaceId != workspace.id) {
        return;
      }
      _applyWebDavDraft(webDavDraft);
      setState(() {
        _selectedPaths = paths;
        _webDavAuthType = webDavDraft.authType;
        _webDavStatus = webDavDraft.status;
      });
    });
  }

  String _formatDate(int millis) {
    if (millis <= 0) {
      return '未知';
    }
    final value = DateTime.fromMillisecondsSinceEpoch(millis);
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: '工作区',
      description: '管理 Flutter 迁移线的本地工作区，支持创建、激活、查看目录摘要与继续进入会话。',
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.folder_outlined),
            title: const Text('当前状态'),
            subtitle: Text(_status),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : _createWorkspace,
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: const Text('新建工作区'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy ? null : _cloneWorkspace,
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: const Text('克隆仓库'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _refresh(),
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('刷新列表'),
                ),
                if (_activeWorkspaceId != null)
                  TextButton.icon(
                    onPressed: widget.onOpenSessionsRequested,
                    icon: const Icon(Icons.chat_outlined),
                    label: const Text('进入当前会话'),
                  ),
              ],
            ),
          ),
        ),
        _WorkspaceMetricsCard(
          workspaces: _workspaces,
          activeWorkspace: _findWorkspace(_workspaces, _activeWorkspaceId),
        ),
        _WorkspaceListCard(
          workspaces: _workspaces,
          selectedWorkspaceId: _selectedWorkspaceId,
          activeWorkspaceId: _activeWorkspaceId,
          onSelectWorkspace: _selectWorkspace,
          onActivateWorkspace: _activateWorkspace,
          onRenameWorkspace: _renameWorkspace,
          onDeleteWorkspace: _deleteWorkspace,
        ),
        _WorkspaceDetailCard(
          workspace: _selectedWorkspace,
          paths: _selectedPaths,
          busy: _busy,
          activeWorkspaceId: _activeWorkspaceId,
          formatDate: _formatDate,
          onActivateWorkspace: _activateWorkspace,
          onRenameWorkspace: _renameWorkspace,
          onOpenSessionsRequested: widget.onOpenSessionsRequested,
        ),
        _WorkspaceGitCard(
          workspace: _selectedWorkspace,
          paths: _selectedPaths,
          busy: _busy,
          repoReady: _isRepoReady(_selectedPaths),
          onSyncGit: _syncWorkspaceGit,
        ),
        _WorkspaceWebDavCard(
          workspace: _selectedWorkspace,
          paths: _selectedPaths,
          busy: _busy,
          endpointController: _webDavEndpointController,
          basePathController: _webDavBasePathController,
          remoteRootController: _webDavRemoteRootController,
          basicUserController: _webDavBasicUserController,
          basicPasswordController: _webDavBasicPasswordController,
          bearerTokenController: _webDavBearerTokenController,
          authType: _webDavAuthType,
          status: _webDavStatus,
          onDraftChanged: () {
            if (!mounted) {
              return;
            }
            setState(() {});
          },
          onAuthTypeChanged: (value) {
            setState(() {
              _webDavAuthType = value;
            });
          },
          onSave: _saveWebDavSettings,
          onTestConnection: _testWebDavConnection,
          onPull: _pullFromWebDav,
          onPush: _pushToWebDav,
        ),
        if (_busy) const _WorkspaceBusyCard(),
      ],
    );
  }
}
