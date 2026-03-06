part of 'workspaces_page.dart';

extension _WorkspacesPageWebDavActions on _WorkspacesPageState {
  Future<_WorkspaceWebDavDraftState> _loadWebDavDraft(
    Workspace? workspace,
  ) async {
    final webdav = workspace?.webdav;
    if (webdav == null) {
      return const _WorkspaceWebDavDraftState(
        authType: 'none',
        status: '当前工作区尚未配置 WebDAV。',
      );
    }

    var authType = 'none';
    var basicUser = '';
    var basicPassword = '';
    var bearerToken = '';

    final authRef = webdav.authRef;
    if (authRef != null && authRef.isNotEmpty) {
      final stored = await _authStore.loadAuth(authRef);
      final storedType = stored?['type']?.toString();
      if (storedType == 'webdav_basic') {
        authType = 'basic';
        basicUser = stored?['username']?.toString() ?? '';
        basicPassword = stored?['password']?.toString() ?? '';
      } else if (storedType == 'webdav_bearer') {
        authType = 'bearer';
        bearerToken = stored?['token']?.toString() ?? '';
      }
    }

    return _WorkspaceWebDavDraftState(
      endpoint: webdav.endpoint,
      basePath: webdav.basePath ?? '',
      remoteRoot: webdav.remoteRoot ?? '',
      authType: authType,
      basicUser: basicUser,
      basicPassword: basicPassword,
      bearerToken: bearerToken,
      status: '已加载当前工作区的 WebDAV 配置。',
    );
  }

  void _applyWebDavDraft(_WorkspaceWebDavDraftState draft) {
    _webDavEndpointController.text = draft.endpoint;
    _webDavBasePathController.text = draft.basePath;
    _webDavRemoteRootController.text = draft.remoteRoot;
    _webDavBasicUserController.text = draft.basicUser;
    _webDavBasicPasswordController.text = draft.basicPassword;
    _webDavBearerTokenController.text = draft.bearerToken;
  }

  Future<void> _runWebDavAction(
    String pendingStatus,
    Future<String> Function() action, {
    bool refreshWorkspace = false,
  }) async {
    if (_busy) {
      return;
    }

    _updateView(() {
      _busy = true;
      _status = pendingStatus;
    });

    try {
      try {
        final successStatus = await action();
        if (refreshWorkspace) {
          await _refresh(status: successStatus);
        } else if (mounted) {
          _updateView(() {
            _status = successStatus;
          });
        }
        return;
      } catch (error) {
        _setWebDavStatus('执行失败：$error');
        rethrow;
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      _updateView(() {
        _status = '执行失败：$error';
      });
    } finally {
      if (mounted) {
        _updateView(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _saveWebDavSettings() async {
    final workspace = _selectedWorkspace;
    if (workspace == null) {
      return;
    }

    await _runWebDavAction('正在保存 WebDAV 配置...', () async {
      final endpoint = _trimmedOrNull(_webDavEndpointController.text);
      final previousAuthRef = workspace.webdav?.authRef;

      if (endpoint == null) {
        await _deleteAuthIfNeeded(previousAuthRef);
        await _workspaceStore.upsertWorkspace(
          workspace.copyWith(clearWebDav: true),
        );
        _setWebDavStatus('已清除 WebDAV 配置。');
        return '已清除 WebDAV 配置。';
      }

      final authRef = await _persistWebDavAuth(previousAuthRef);
      final nextWorkspace = workspace.copyWith(
        webdav: WorkspaceWebDavConfig(
          endpoint: endpoint,
          basePath: _trimmedOrNull(_webDavBasePathController.text),
          remoteRoot: _trimmedOrNull(_webDavRemoteRootController.text),
          authRef: authRef,
        ),
      );
      await _workspaceStore.upsertWorkspace(nextWorkspace);
      _setWebDavStatus('已保存 WebDAV 配置。');
      return '已保存 WebDAV 配置。';
    }, refreshWorkspace: true);
  }

  Future<void> _testWebDavConnection() async {
    await _runWebDavAction('正在测试 WebDAV 连接...', () async {
      final client = _buildWebDavClientFromDraft();
      final remoteRoot = _currentRemoteRoot();
      _setWebDavStatus('正在验证远端目录可访问性...');
      final entries = await client.propfind(remoteRoot, depth: '0');
      final targetLabel = remoteRoot.isEmpty ? '/' : remoteRoot;
      _setWebDavStatus('连接成功：已访问 $targetLabel（返回 ${entries.length} 条记录）。');
      return 'WebDAV 连接成功。';
    });
  }

  Future<void> _pullFromWebDav() async {
    final workspace = _selectedWorkspace;
    if (workspace == null) {
      return;
    }

    await _runWebDavAction('正在从 WebDAV 拉取...', () async {
      final paths =
          _selectedPaths ??
          await _workspaceDirectoryService.pathsFor(workspace.id);
      await paths.repoDir.create(recursive: true);
      final client = _buildWebDavClientFromDraft();
      await _webDavSyncService.pull(
        client: client,
        remoteRootDir: _currentRemoteRoot(),
        localRootDirPath: paths.repoDir.path,
        onProgress: (progress) {
          _setWebDavStatus(
            _describeWebDavProgress(progress, direction: 'pull'),
          );
        },
      );
      _setWebDavStatus('已从 WebDAV 拉取到 ${paths.repoDir.path}。');
      return 'WebDAV 拉取完成。';
    });
  }

  Future<void> _pushToWebDav() async {
    final workspace = _selectedWorkspace;
    if (workspace == null) {
      return;
    }

    await _runWebDavAction('正在推送到 WebDAV...', () async {
      final paths =
          _selectedPaths ??
          await _workspaceDirectoryService.pathsFor(workspace.id);
      await paths.repoDir.create(recursive: true);
      final client = _buildWebDavClientFromDraft();
      await _webDavSyncService.push(
        client: client,
        remoteRootDir: _currentRemoteRoot(),
        localRootDirPath: paths.repoDir.path,
        onProgress: (progress) {
          _setWebDavStatus(
            _describeWebDavProgress(progress, direction: 'push'),
          );
        },
      );
      final targetLabel = _currentRemoteRoot().isEmpty
          ? '/'
          : _currentRemoteRoot();
      _setWebDavStatus('已将 ${paths.repoDir.path} 推送到 $targetLabel。');
      return 'WebDAV 推送完成。';
    });
  }

  WebDavClient _buildWebDavClientFromDraft() {
    final endpoint = _trimmedOrNull(_webDavEndpointController.text);
    if (endpoint == null) {
      throw StateError('请先填写 WebDAV 服务地址。');
    }

    final authType = _webDavAuthType;
    WebDavBasicAuth? basicAuth;
    WebDavBearerAuth? bearerAuth;

    if (authType == 'basic') {
      final username = _trimmedOrNull(_webDavBasicUserController.text);
      final password = _webDavBasicPasswordController.text;
      if (username == null || password.isEmpty) {
        throw StateError('Basic 认证需要同时填写用户名和密码。');
      }
      basicAuth = WebDavBasicAuth(username: username, password: password);
    }

    if (authType == 'bearer') {
      final token = _trimmedOrNull(_webDavBearerTokenController.text);
      if (token == null) {
        throw StateError('Bearer 认证需要填写令牌。');
      }
      bearerAuth = WebDavBearerAuth(token: token);
    }

    return WebDavClient(
      config: WebDavConfig(
        endpoint: endpoint,
        basePath: _trimmedOrNull(_webDavBasePathController.text),
      ),
      basicAuth: basicAuth,
      bearerAuth: bearerAuth,
    );
  }

  Future<AuthRef?> _persistWebDavAuth(AuthRef? previousAuthRef) async {
    final authType = _webDavAuthType;
    if (authType == 'none') {
      await _deleteAuthIfNeeded(previousAuthRef);
      return null;
    }

    if (authType == 'basic') {
      final username = _trimmedOrNull(_webDavBasicUserController.text);
      final password = _webDavBasicPasswordController.text;
      if (username == null || password.isEmpty) {
        throw StateError('Basic 认证需要同时填写用户名和密码。');
      }
      final nextRef = await _authStore.saveAuth(
        WebDavBasicStoredAuth(username: username, password: password).toMap(),
      );
      if (previousAuthRef != null && previousAuthRef != nextRef) {
        await _deleteAuthIfNeeded(previousAuthRef);
      }
      return nextRef;
    }

    if (authType == 'bearer') {
      final token = _trimmedOrNull(_webDavBearerTokenController.text);
      if (token == null) {
        throw StateError('Bearer 认证需要填写令牌。');
      }
      final nextRef = await _authStore.saveAuth(
        WebDavBearerStoredAuth(token: token).toMap(),
      );
      if (previousAuthRef != null && previousAuthRef != nextRef) {
        await _deleteAuthIfNeeded(previousAuthRef);
      }
      return nextRef;
    }

    return previousAuthRef;
  }

  Future<void> _deleteAuthIfNeeded(AuthRef? authRef) async {
    if (authRef == null || authRef.isEmpty) {
      return;
    }
    try {
      await _authStore.deleteAuth(authRef);
    } catch (_) {
      // ignore stale secure entries
    }
  }

  String _currentRemoteRoot() {
    return _trimmedOrNull(_webDavRemoteRootController.text) ?? '';
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _setWebDavStatus(String status) {
    _updateView(() {
      _webDavStatus = status;
    });
  }

  String _describeWebDavProgress(
    WebDavSyncProgress progress, {
    required String direction,
  }) {
    final index = progress.current;
    final total = progress.total;
    final path = progress.path;
    final suffix = index != null && total != null ? '（$index/$total）' : '';

    switch (progress.phase) {
      case 'list-local':
        return '正在扫描本地仓库目录...';
      case 'list-remote':
        return '正在扫描远端 WebDAV 目录...';
      case 'mkdir-local':
        return '正在创建本地目录${suffix.isEmpty ? '' : suffix}：${path ?? ''}';
      case 'mkdir-remote':
        return '正在创建远端目录${suffix.isEmpty ? '' : suffix}：${path ?? ''}';
      case 'download':
        return '正在下载文件${suffix.isEmpty ? '' : suffix}：${path ?? ''}';
      case 'upload':
        return '正在上传文件${suffix.isEmpty ? '' : suffix}：${path ?? ''}';
      case 'done':
        return direction == 'pull' ? 'WebDAV 拉取完成。' : 'WebDAV 推送完成。';
      default:
        return '正在同步 WebDAV...';
    }
  }
}

class _WorkspaceWebDavCard extends StatelessWidget {
  const _WorkspaceWebDavCard({
    required this.workspace,
    required this.paths,
    required this.busy,
    required this.endpointController,
    required this.basePathController,
    required this.remoteRootController,
    required this.basicUserController,
    required this.basicPasswordController,
    required this.bearerTokenController,
    required this.authType,
    required this.status,
    required this.onDraftChanged,
    required this.onAuthTypeChanged,
    required this.onSave,
    required this.onTestConnection,
    required this.onPull,
    required this.onPush,
  });

  final Workspace? workspace;
  final WorkspacePaths? paths;
  final bool busy;
  final TextEditingController endpointController;
  final TextEditingController basePathController;
  final TextEditingController remoteRootController;
  final TextEditingController basicUserController;
  final TextEditingController basicPasswordController;
  final TextEditingController bearerTokenController;
  final String authType;
  final String status;
  final VoidCallback onDraftChanged;
  final ValueChanged<String> onAuthTypeChanged;
  final Future<void> Function() onSave;
  final Future<void> Function() onTestConnection;
  final Future<void> Function() onPull;
  final Future<void> Function() onPush;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasEndpoint = endpointController.text.trim().isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('WebDAV', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            if (workspace == null)
              const Text('选择一个工作区后，可在这里配置 WebDAV、测试连通性并执行拉取/推送。'),
            if (workspace != null) ...[
              TextField(
                controller: endpointController,
                onChanged: (_) => onDraftChanged(),
                decoration: const InputDecoration(labelText: '服务地址'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: basePathController,
                onChanged: (_) => onDraftChanged(),
                decoration: const InputDecoration(labelText: 'Base Path（可选）'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remoteRootController,
                onChanged: (_) => onDraftChanged(),
                decoration: const InputDecoration(labelText: '远端根目录（可选）'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'none',
                    label: Text('无认证'),
                    icon: Icon(Icons.lock_open_outlined),
                  ),
                  ButtonSegment(
                    value: 'basic',
                    label: Text('Basic'),
                    icon: Icon(Icons.badge_outlined),
                  ),
                  ButtonSegment(
                    value: 'bearer',
                    label: Text('Bearer'),
                    icon: Icon(Icons.key_outlined),
                  ),
                ],
                selected: <String>{authType},
                onSelectionChanged: busy
                    ? null
                    : (selection) => onAuthTypeChanged(selection.first),
              ),
              const SizedBox(height: 12),
              if (authType == 'basic') ...[
                TextField(
                  controller: basicUserController,
                  onChanged: (_) => onDraftChanged(),
                  decoration: const InputDecoration(labelText: '用户名'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: basicPasswordController,
                  obscureText: true,
                  onChanged: (_) => onDraftChanged(),
                  decoration: const InputDecoration(labelText: '密码'),
                ),
              ],
              if (authType == 'bearer')
                TextField(
                  controller: bearerTokenController,
                  obscureText: true,
                  onChanged: (_) => onDraftChanged(),
                  decoration: const InputDecoration(labelText: '令牌'),
                ),
              const SizedBox(height: 12),
              Text(
                '本地同步目录：${paths?.repoDir.path ?? '尚未准备'}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(status, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : () async => onSave(),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('保存配置'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy || !hasEndpoint
                        ? null
                        : () async => onTestConnection(),
                    icon: const Icon(Icons.network_check_outlined),
                    label: const Text('测试连接'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy || !hasEndpoint
                        ? null
                        : () async => onPull(),
                    icon: const Icon(Icons.download_outlined),
                    label: const Text('拉取到仓库'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy || !hasEndpoint
                        ? null
                        : () async => onPush(),
                    icon: const Icon(Icons.upload_outlined),
                    label: const Text('推送到远端'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text('说明：清空服务地址后点击“保存配置”，可移除当前工作区的 WebDAV 配置与认证引用。'),
            ],
          ],
        ),
      ),
    );
  }
}

class _WorkspaceWebDavDraftState {
  const _WorkspaceWebDavDraftState({
    this.endpoint = '',
    this.basePath = '',
    this.remoteRoot = '',
    required this.authType,
    this.basicUser = '',
    this.basicPassword = '',
    this.bearerToken = '',
    required this.status,
  });

  final String endpoint;
  final String basePath;
  final String remoteRoot;
  final String authType;
  final String basicUser;
  final String basicPassword;
  final String bearerToken;
  final String status;
}
