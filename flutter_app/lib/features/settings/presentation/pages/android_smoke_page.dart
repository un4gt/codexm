import 'dart:async';

import 'package:codexm_native/codexm_native.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/feature_scaffold.dart';
import '../../application/codex_smoke_rpc.dart';
import '../../application/smoke_workspace_paths.dart';

class AndroidSmokePage extends StatefulWidget {
  AndroidSmokePage({
    super.key,
    CodexmNative? native,
    SmokeWorkspacePathService? pathService,
  })  : native = native ?? const CodexmNative(),
        pathService = pathService ?? SmokeWorkspacePathService();

  final CodexmNative native;
  final SmokeWorkspacePathService pathService;

  @override
  State<AndroidSmokePage> createState() => _AndroidSmokePageState();
}

class _AndroidSmokePageState extends State<AndroidSmokePage> {
  static const _runtimeId = 'flutter-smoke-runtime';
  static const _workspaceId = 'flutter-smoke-arm64';
  static const _workspaceName = 'Flutter Android Smoke';

  final _rpc = CodexSmokeRpc();
  final _remoteUrlController = TextEditingController(
    text: 'https://github.com/octocat/Hello-World.git',
  );
  final _promptController = TextEditingController(
    text: '请用一句话回复：Android smoke test OK。',
  );
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _baseUrlController = TextEditingController();

  StreamSubscription<RuntimeLineEvent>? _runtimeSubscription;
  SmokeWorkspacePaths? _paths;
  GitStatus? _gitStatus;
  String _busyLabel = '';
  String _assistantOutput = '';
  String _gitDiffSummary = '尚未执行';
  String _lastRuntimeError = '暂无';
  String? _threadId;
  int _stdoutLines = 0;
  int _stderrLines = 0;
  int? _initializeRequestId;
  int? _threadStartRequestId;
  bool _runtimeStarted = false;
  bool _initialized = false;
  bool _sentInitializedNotification = false;
  final List<String> _statusMessages = <String>[];

  @override
  void initState() {
    super.initState();
    _runtimeSubscription = widget.native.runtimeLineEvents().listen(
      (event) => unawaited(_handleRuntimeLine(event)),
    );
  }

  @override
  void dispose() {
    _runtimeSubscription?.cancel();
    unawaited(widget.native.stopRuntime(runtimeId: _runtimeId));
    _remoteUrlController.dispose();
    _promptController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _prepareWorkspace() {
    return _runAction('准备目录', () async {
      await _prepareWorkspaceInternal();
    });
  }

  Future<SmokeWorkspacePaths> _prepareWorkspaceInternal() async {
    final paths = await widget.pathService.prepareWorkspace(
      workspaceId: _workspaceId,
      workspaceName: _workspaceName,
    );
    await widget.pathService.materializeCodexHome(
      paths: paths,
      approvalPolicy: 'never',
      apiKey: _apiKeyController.text,
      model: _modelController.text,
      openaiBaseUrl: _baseUrlController.text,
    );
    if (!mounted) {
      return paths;
    }
    setState(() {
      _paths = paths;
      _gitStatus = null;
      _gitDiffSummary = '尚未执行';
      _threadId = null;
      _assistantOutput = '';
      _initializeRequestId = null;
      _threadStartRequestId = null;
    });
    _addStatus('测试工作区已重建，并对齐工作区 / 仓库 / 元数据 / 临时目录。');
    return paths;
  }

  Future<void> _startRuntime() {
    return _runAction('启动 Runtime', () async {
      final paths = await _requirePaths();
      await widget.pathService.materializeCodexHome(
        paths: paths,
        approvalPolicy: 'never',
        apiKey: _apiKeyController.text,
        model: _modelController.text,
        openaiBaseUrl: _baseUrlController.text,
      );

      final env = <String, String>{
        'CODEX_HOME': paths.codexHomeDir.path,
        'HOME': paths.codexHomeDir.path,
        'TMPDIR': paths.tmpDir.path,
        'SQLITE_TMPDIR': paths.tmpDir.path,
      };

      final apiKey = _apiKeyController.text.trim();
      if (apiKey.isNotEmpty) {
        env['OPENAI_API_KEY'] = apiKey;
        env['CODEX_API_KEY'] = apiKey;
      }

      final baseUrl = _baseUrlController.text.trim();
      if (baseUrl.isNotEmpty) {
        env['OPENAI_BASE_URL'] = baseUrl;
        env['OPENAI_API_BASE'] = baseUrl;
        env['OPENAI_API_BASE_URL'] = baseUrl;
      }

      await widget.native.startRuntime(
        runtimeId: _runtimeId,
        cwdUri: paths.repoDir.path,
        assetPath: 'codex/{abi}/codex',
        args: const ['app-server', '--listen', 'stdio://'],
        env: env,
      );

      if (!mounted) {
        return;
      }
      setState(() {
        _runtimeStarted = true;
        _initialized = false;
        _sentInitializedNotification = false;
        _assistantOutput = '';
        _lastRuntimeError = '暂无';
        _stdoutLines = 0;
        _stderrLines = 0;
        _threadId = null;
        _initializeRequestId = null;
        _threadStartRequestId = null;
      });
      _addStatus('运行时已启动，可继续执行握手和首轮消息验证。');
    });
  }

  Future<void> _initializeRuntime() {
    return _runAction('初始化握手', () async {
      _ensureRuntimeStarted();
      final requestId = _rpc.nextRequestId();
      await widget.native.sendRuntimeLine(
        runtimeId: _runtimeId,
        line: _rpc.buildInitializeRequest(requestId),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _initializeRequestId = requestId;
      });
      _addStatus('已发送运行时初始化请求。');
    });
  }

  Future<void> _startThread() {
    return _runAction('建立线程', () async {
      final paths = await _requirePaths();
      if (!_initialized) {
        throw StateError('请先完成运行时初始化。');
      }
      final requestId = _rpc.nextRequestId();
      await widget.native.sendRuntimeLine(
        runtimeId: _runtimeId,
        line: _rpc.buildThreadStartRequest(
          requestId: requestId,
          cwd: paths.repoDir.path,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _threadStartRequestId = requestId;
      });
      _addStatus('已发送线程建立请求。');
    });
  }

  Future<void> _startTurn() {
    return _runAction('发送首轮消息', () async {
      final paths = await _requirePaths();
      final prompt = _promptController.text.trim();
      if (prompt.isEmpty) {
        throw StateError('请先填写测试消息。');
      }
      final threadId = _currentThreadId();
      final requestId = _rpc.nextRequestId();
      await widget.native.sendRuntimeLine(
        runtimeId: _runtimeId,
        line: _rpc.buildTurnStartRequest(
          requestId: requestId,
          threadId: threadId,
          cwd: paths.repoDir.path,
          prompt: prompt,
        ),
      );
      _addStatus('已发送首轮消息，等待模型输出。');
    });
  }

  Future<void> _stopRuntime() {
    return _runAction('停止 Runtime', () async {
      await widget.native.stopRuntime(runtimeId: _runtimeId);
      if (!mounted) {
        return;
      }
      setState(() {
        _runtimeStarted = false;
        _initialized = false;
        _sentInitializedNotification = false;
        _threadId = null;
      });
      _addStatus('运行时已停止。');
    });
  }

  Future<void> _cloneRepository() {
    return _runAction('拉取测试仓库', () async {
      final paths = await _requirePaths();
      final remoteUrl = _remoteUrlController.text.trim();
      if (remoteUrl.isEmpty) {
        throw StateError('请先填写测试仓库地址。');
      }
      await widget.native.gitClone(
        remoteUrl: remoteUrl,
        localRepoDirUri: paths.repoDir.path,
      );
      _addStatus('测试仓库已拉取，可继续执行 Git 状态与差异验证。');
    });
  }

  Future<void> _createGitChange() {
    return _runAction('创建 Git 改动', () async {
      final paths = await _requirePaths();
      await widget.pathService.createSmokeChange(paths);
      _addStatus('已写入测试改动文件，用于验证 Git 状态与差异。');
    });
  }

  Future<void> _readGitStatus() {
    return _runAction('读取 Git 状态', () async {
      final paths = await _requirePaths();
      final gitStatus = await widget.native.gitStatus(
        localRepoDirUri: paths.repoDir.path,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _gitStatus = gitStatus;
      });
      _addStatus(
        'Git 状态已更新：已暂存 ${gitStatus.staged.length}，未暂存 ${gitStatus.unstaged.length}，未跟踪 ${gitStatus.untracked.length}。',
      );
    });
  }

  Future<void> _readGitDiff() {
    return _runAction('读取 Git 差异', () async {
      final paths = await _requirePaths();
      final diff = await widget.native.gitDiff(
        localRepoDirUri: paths.repoDir.path,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _gitDiffSummary = diff.isEmpty ? '当前无差异内容。' : '已获取 ${diff.length} 个字符的差异预览。';
      });
      _addStatus(_gitDiffSummary);
    });
  }

  Future<SmokeWorkspacePaths> _requirePaths() async {
    final current = _paths;
    if (current != null) {
      return current;
    }
    return _prepareWorkspaceInternal();
  }

  String _currentThreadId() {
    final threadId = _threadId;
    if (threadId != null && threadId.isNotEmpty) {
      return threadId;
    }
    throw StateError('请先建立测试线程。');
  }

  void _ensureRuntimeStarted() {
    if (!_runtimeStarted) {
      throw StateError('请先启动运行时。');
    }
  }

  Future<void> _handleRuntimeLine(RuntimeLineEvent event) async {
    if (event.runtimeId != _runtimeId) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      if (event.stream == 'stdout') {
        _stdoutLines += 1;
      } else {
        _stderrLines += 1;
        _lastRuntimeError = event.line;
      }
    });

    final message = _rpc.tryDecodeMessage(event.line);
    if (message == null) {
      if (event.stream == 'stderr') {
        _addStatus('收到运行时错误输出，请检查本页状态摘要。');
      }
      return;
    }

    final errorMessage = _rpc.extractErrorMessage(message);
    if (errorMessage != null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _lastRuntimeError = errorMessage;
      });
      _addStatus('运行时返回错误：$errorMessage');
      return;
    }

    final initializeRequestId = _initializeRequestId;
    if (
        initializeRequestId != null &&
        _rpc.isInitializeResponse(message, initializeRequestId) &&
        !_initialized) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
      });
      _addStatus('运行时初始化已完成。');
      if (!_sentInitializedNotification) {
        await widget.native.sendRuntimeLine(
          runtimeId: _runtimeId,
          line: _rpc.buildInitializedNotification(),
        );
        if (!mounted) {
          return;
        }
        setState(() {
          _sentInitializedNotification = true;
        });
        _addStatus('已确认初始化完成，可继续建立测试线程。');
      }
    }

    final threadId = _rpc.extractThreadId(message);
    if (threadId != null && message['id'] == _threadStartRequestId) {
      if (!mounted) {
        return;
      }
      setState(() {
        _threadId = threadId;
      });
      _addStatus('测试线程已建立。');
    }

    final delta = _rpc.extractAssistantDelta(message);
    if (delta != null && delta.isNotEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _assistantOutput = '$_assistantOutput$delta';
      });
    }

    if (_rpc.isTurnCompleted(message)) {
      _addStatus('首轮消息已完成。');
    }
  }

  Future<void> _runAction(String label, Future<void> Function() action) async {
    if (_busyLabel.isNotEmpty) {
      return;
    }

    setState(() {
      _busyLabel = label;
    });

    try {
      await action();
    } catch (error) {
      _addStatus('$label失败：$error');
    } finally {
      if (mounted) {
        setState(() {
          _busyLabel = '';
        });
      }
    }
  }

  void _addStatus(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _statusMessages.insert(0, message);
      if (_statusMessages.length > 8) {
        _statusMessages.removeRange(8, _statusMessages.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paths = _paths;

    return FeatureScaffold(
      title: 'Android Smoke 验证',
      description: '这里用于执行 1.5 阶段的 Android arm64 启动、首轮消息与 Git 基础验证。',
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('验证输入', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Key（可选）',
                    helperText: '未填写时只建议验证启动与握手；需要首轮消息时请填写。',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: '模型（可选）',
                    helperText: '如需指定模型，可在这里填写；留空则使用运行时默认值。',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _baseUrlController,
                  decoration: const InputDecoration(
                    labelText: '服务地址（可选）',
                    helperText: '仅当你使用自定义 OpenAI 兼容地址时填写。',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _remoteUrlController,
                  decoration: const InputDecoration(
                    labelText: '测试仓库地址',
                    helperText: '用于验证 clone / status / diff。',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _promptController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: '首轮测试消息',
                    helperText: '用于验证 runtime -> app-server -> 模型响应链路。',
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonal(onPressed: _prepareWorkspace, child: const Text('1. 准备目录')),
                FilledButton.tonal(onPressed: _startRuntime, child: const Text('2. 启动运行时')),
                FilledButton.tonal(onPressed: _initializeRuntime, child: const Text('3. 初始化握手')),
                FilledButton.tonal(onPressed: _startThread, child: const Text('4. 建立线程')),
                FilledButton(onPressed: _startTurn, child: const Text('5. 发送首轮消息')),
                FilledButton.tonal(onPressed: _cloneRepository, child: const Text('6. 拉取仓库')),
                FilledButton.tonal(onPressed: _createGitChange, child: const Text('7. 创建改动')),
                FilledButton.tonal(onPressed: _readGitStatus, child: const Text('8. Git 状态')),
                FilledButton.tonal(onPressed: _readGitDiff, child: const Text('9. Git 差异')),
                OutlinedButton(onPressed: _stopRuntime, child: const Text('停止运行时')),
              ],
            ),
          ),
        ),
        if (_busyLabel.isNotEmpty)
          Card(
            child: ListTile(
              leading: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('正在执行：$_busyLabel'),
              subtitle: const Text('执行完成后会自动刷新下方状态摘要。'),
            ),
          ),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: const Text('目录契约'),
                subtitle: Text(
                  paths == null
                      ? '尚未准备测试工作区。'
                      : '已就绪：工作区、仓库、元数据、临时目录已建立。',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.terminal_outlined),
                title: const Text('运行时状态'),
                subtitle: Text(
                  _runtimeStarted
                      ? '已启动；stdout $_stdoutLines 行，stderr $_stderrLines 行。'
                      : '尚未启动。',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.sync_outlined),
                title: const Text('握手与线程'),
                subtitle: Text(
                  '初始化：${_initialized ? '已完成' : '未完成'}；线程：${_threadId == null ? '未建立' : '已建立'}',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.history_toggle_off_outlined),
                title: const Text('最近错误'),
                subtitle: Text(_lastRuntimeError),
              ),
              ListTile(
                leading: const Icon(Icons.merge_type_outlined),
                title: const Text('Git 摘要'),
                subtitle: Text(
                  _gitStatus == null
                      ? '尚未执行 Git 验证。'
                      : '已暂存 ${_gitStatus!.staged.length}，未暂存 ${_gitStatus!.unstaged.length}，未跟踪 ${_gitStatus!.untracked.length}。',
                ),
              ),
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Git 差异'),
                subtitle: Text(_gitDiffSummary),
              ),
            ],
          ),
        ),
        if (_assistantOutput.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('首轮响应预览', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  SelectableText(_assistantOutput),
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('最近进展', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                if (_statusMessages.isEmpty)
                  Text(
                    '尚未执行验证步骤。',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  ..._statusMessages.map(
                    (message) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('• '),
                          Expanded(child: Text(message)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
