part of 'sessions_page.dart';

extension on String {
  String? get blankAsNull {
    final trimmed = trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

extension _SessionsPageActions on _SessionsPageState {
  Future<String?> _promptSessionName({
    required String title,
    String? initialValue,
    String? hintText,
  }) async {
    final controller = TextEditingController(text: initialValue ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: '会话名称',
              hintText: hintText,
            ),
            onSubmitted: (value) {
              Navigator.of(dialogContext).pop(value.trim());
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
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

  Future<void> _createSession() async {
    final workspace = _activeWorkspace;
    if (workspace == null || _busy || _running) {
      return;
    }
    final name = await _promptSessionName(
      title: '新建会话',
      hintText: '例如：发布问题排查',
    );
    if (name == null) {
      return;
    }
    await _runAction('正在创建会话...', () async {
      final session = await _sessionStore.createSession(
        workspace.id,
        title: name.trim().isEmpty ? '新会话' : name.trim(),
      );
      _selectedSessionId = session.id;
      return '已创建会话：${session.title}';
    });
  }

  Future<void> _renameSession(Session session) async {
    final workspace = _activeWorkspace;
    if (workspace == null || _busy || _running) {
      return;
    }
    final name = await _promptSessionName(
      title: '重命名会话',
      initialValue: session.title,
    );
    if (name == null) {
      return;
    }
    await _runAction('正在保存会话名称...', () async {
      await _sessionStore.renameSession(workspace.id, session.id, name);
      return '已更新会话名称。';
    });
  }

  Future<void> _deleteSession(Session session) async {
    final workspace = _activeWorkspace;
    if (workspace == null || _busy || _running) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除会话'),
          content: Text('确认删除「${session.title}」吗？该会话中的消息将一并删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await _runAction('正在删除会话...', () async {
      await _sessionStore.deleteSession(workspace.id, session.id);
      final remaining = await _sessionStore.listSessions(workspace.id);
      _selectedSessionId = remaining.isEmpty ? null : remaining.first.id;
      return '已删除会话：${session.title}';
    });
  }

  Future<void> _selectSession(Session session) async {
    final workspace = _activeWorkspace;
    if (workspace == null || _busy || _running) {
      return;
    }
    final messages = await _sessionStore.listMessages(workspace.id, session.id);
    if (!mounted) {
      return;
    }
    _updateView(() {
      _selectedSessionId = session.id;
      _messages = messages;
      _status = '已切换到会话：${session.title}';
    });
    widget.onSessionSelected?.call(session);
    _handleComposerChanged();
    _scrollToBottom();
  }

  Future<void> _openSessionSwitcher() async {
    if (_activeWorkspace == null || _busy || _running) {
      return;
    }
    final selected = _selectedSession;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '切换会话',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        await _createSession();
                      },
                      icon: const Icon(Icons.add_comment_outlined),
                      label: const Text('新建'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _sessions.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final session = _sessions[index];
                      final active = session.id == selected?.id;
                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        tileColor: active
                            ? Theme.of(context).colorScheme.primaryContainer
                            : Theme.of(context).colorScheme.surfaceContainerLow,
                        leading: Icon(
                          active
                              ? Icons.chat_bubble
                              : Icons.chat_bubble_outline,
                        ),
                        title: Text(session.title),
                        subtitle: Text(
                          session.codexThreadId?.trim().isNotEmpty == true
                              ? '继续已有对话'
                              : '尚未开始发送消息',
                        ),
                        trailing: PopupMenuButton<_SessionAction>(
                          onSelected: (action) async {
                            Navigator.of(sheetContext).pop();
                            switch (action) {
                              case _SessionAction.rename:
                                await _renameSession(session);
                              case _SessionAction.delete:
                                await _deleteSession(session);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _SessionAction.rename,
                              child: Text('重命名'),
                            ),
                            PopupMenuItem(
                              value: _SessionAction.delete,
                              child: Text('删除'),
                            ),
                          ],
                        ),
                        onTap: () async {
                          Navigator.of(sheetContext).pop();
                          await _selectSession(session);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _runAction(
    String pendingStatus,
    Future<String> Function() action,
  ) async {
    if (_busy || _running) {
      return;
    }

    _updateView(() {
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

  Future<Session> _ensureSession({String? titleHint}) async {
    final workspace = _activeWorkspace;
    if (workspace == null) {
      throw StateError('当前没有可用工作区。');
    }

    final session = await _sessionStore.ensurePrimarySession(
      workspace.id,
      title: titleHint,
    );
    _selectedSessionId = session.id;
    return session;
  }

  Future<void> _appendLocalExchange({
    required String userInput,
    required String content,
    String assistantRole = 'system',
    String? titleHint,
    String? status,
  }) async {
    final workspace = _activeWorkspace;
    if (workspace == null) {
      return;
    }

    final session = await _ensureSession(titleHint: titleHint);
    await _sessionStore.appendMessage(
      workspace.id,
      session.id,
      role: 'user',
      content: userInput,
    );
    await _sessionStore.appendMessage(
      workspace.id,
      session.id,
      role: assistantRole,
      content: content,
    );
    await _refresh(status: status ?? _firstStatusLine(content));
  }

  String _firstStatusLine(String content) {
    final firstLine = content
        .replaceAll(RegExp(r'`{3}.*?`{3}', dotAll: true), '')
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '已完成。');
    return firstLine;
  }

  void _applySlashSuggestion(CodexSlashCommand command) {
    final next = replaceActiveSlashToken(_composerController.text, command.command);
    _composerController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void _applyMentionSuggestion(ComposerMentionSuggestion suggestion) {
    final next = clearActiveMentionToken(_composerController.text);
    final mentions = [..._pendingMentions];
    final exists = mentions.any(
      (item) => item.kind == suggestion.kind && item.value == suggestion.value,
    );
    if (!exists) {
      mentions.add(
        suggestion.kind == ComposerMentionKind.file
            ? ComposerPendingMention.file(
                label: suggestion.label,
                value: suggestion.value,
              )
            : ComposerPendingMention.commit(
                label: suggestion.label,
                value: suggestion.value,
              ),
      );
    }
    _updateView(() {
      _pendingMentions = mentions;
      _mentionSuggestions = const <ComposerMentionSuggestion>[];
      _mentionLoading = false;
      _status = suggestion.kind == ComposerMentionKind.file
          ? '已标记文件：${suggestion.label}'
          : '已标记提交：${suggestion.label}';
    });
    final text = next.isEmpty ? '' : '$next ';
    _composerController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _removePendingMention(ComposerPendingMention mention) {
    _updateView(() {
      _pendingMentions = _pendingMentions
          .where(
            (item) =>
                !(item.kind == mention.kind && item.value == mention.value),
          )
          .toList(growable: false);
      _status = '已移除标记：${mention.label}';
    });
  }

  Future<void> _runLocalCommandAction({
    required String rawText,
    required String pendingStatus,
    required Future<String> Function() action,
    String? titleHint,
  }) async {
    if (_busy || _running) {
      return;
    }

    _updateView(() {
      _busy = true;
      _status = pendingStatus;
    });

    try {
      final content = await action();
      await _appendLocalExchange(
        userInput: rawText,
        content: content,
        titleHint: titleHint,
      );
    } catch (error) {
      await _appendLocalExchange(
        userInput: rawText,
        content: '执行失败：$error',
        titleHint: titleHint,
      );
    } finally {
      if (mounted) {
        _updateView(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final rawText = _composerController.text.trim();
    if (rawText.isEmpty || _running || _busy || _activeWorkspace == null) {
      return;
    }

    final command = findCodexSlashCommand(rawText);
    final firstToken = rawText.split(RegExp(r'\s+')).firstOrNull ?? '';
    final slashArgs = rawText.substring(firstToken.length).trim();

    if (firstToken == '/exit' || firstToken == '/quit') {
      _composerController.clear();
      widget.onOpenWorkspacesRequested?.call();
      return;
    }

    final handledLocally = await _handleLocalSlashCommand(
      rawText: rawText,
      firstToken: firstToken,
      slashArgs: slashArgs,
      knownCommand: command != null,
    );
    if (handledLocally) {
      if (!(firstToken == '/apps' && slashArgs.isNotEmpty)) {
        _composerController.clear();
      }
      return;
    }

    final isSlashPlanToggle = command != null &&
        firstToken == '/plan' &&
        (slashArgs.isEmpty || slashArgs == 'on' || slashArgs == 'off');
    if (firstToken.startsWith('/') &&
        command == null &&
        !isSlashPlanToggle) {
      await _runLocalCommandAction(
        rawText: rawText,
        pendingStatus: '正在处理命令...',
        action: () async =>
            '未知命令：$firstToken\n\n输入 /help 可查看当前移动端支持的命令。',
      );
      _composerController.clear();
      return;
    }

    const planPrefix =
        '你处于计划模式。请先输出一个可执行的计划（步骤、依赖、风险、验证方式），在我确认前不要执行命令或修改文件。\n\n任务：';
    final currentMode = _selectedSession?.codexCollaborationMode == 'plan'
        ? CodexCollaborationMode.plan
        : CodexCollaborationMode.standard;
    final isPlanTurn = command != null && firstToken == '/plan' && slashArgs.isNotEmpty;
    final isReview = command != null && firstToken == '/review';
    final isRpc = command != null &&
        <String>{
          '/compact',
          '/debug-config',
          '/apps',
          '/ps',
        }.contains(firstToken);

    Object? input;
    var userMessage = rawText;
    CodexCollaborationMode? collaborationModeOverride;
    List<CodexRpcCall>? rpcCalls;
    var pendingStatus = '正在向 Codex 发送消息...';
    var successStatus = '本轮会话已完成。';
    var kind = CodexTurnKind.turn;

    if (isReview) {
      kind = CodexTurnKind.review;
      pendingStatus = '正在审查当前工作区...';
      successStatus = '审查结果已返回。';
    } else if (isRpc) {
      kind = CodexTurnKind.rpc;
      pendingStatus = firstToken == '/compact' ? '正在整理上下文...' : '正在执行命令...';
      successStatus = firstToken == '/compact' ? '上下文整理完成。' : '命令执行完成。';
      rpcCalls = switch (firstToken) {
        '/compact' => const <CodexRpcCall>[
            CodexRpcCall(
              method: 'thread/compact/start',
              requiresThread: true,
              title: '上下文整理结果',
            ),
          ],
        '/debug-config' => const <CodexRpcCall>[
            CodexRpcCall(method: 'config/read', title: '配置详情'),
            CodexRpcCall(method: 'configRequirements/read', title: '配置要求'),
          ],
        '/apps' => const <CodexRpcCall>[
            CodexRpcCall(method: 'app/list', title: '可用扩展'),
          ],
        '/ps' => const <CodexRpcCall>[
            CodexRpcCall(
              method: 'thread/backgroundTerminals/list',
              requiresThread: true,
              title: '后台任务',
            ),
          ],
        _ => null,
      };
    } else {
      final turnText = isPlanTurn
          ? '$planPrefix$slashArgs'
          : (currentMode == CodexCollaborationMode.plan
                ? '$planPrefix$rawText'
                : rawText);
      final built = await _buildTurnInput(rawText: rawText, turnText: turnText);
      input = built.$1;
      userMessage = built.$2;
      collaborationModeOverride =
          isPlanTurn || currentMode == CodexCollaborationMode.plan
          ? CodexCollaborationMode.plan
          : CodexCollaborationMode.standard;
      _updateView(() {
        _pendingMentions = const <ComposerPendingMention>[];
      });
    }

    _composerController.clear();
    await _runCodexOperation(
      pendingStatus: pendingStatus,
      successStatus: successStatus,
      kind: kind,
      input: input,
      userMessage: kind == CodexTurnKind.turn ? userMessage : rawText,
      titleHint: _deriveSessionTitle(rawText),
      rpcCalls: rpcCalls,
      collaborationModeOverride: collaborationModeOverride,
    );
  }

  Future<bool> _handleLocalSlashCommand({
    required String rawText,
    required String firstToken,
    required String slashArgs,
    required bool knownCommand,
  }) async {
    if (!firstToken.startsWith('/')) {
      return false;
    }

    if (firstToken == '/plan' &&
        (slashArgs.isEmpty || slashArgs == 'on' || slashArgs == 'off')) {
      final nextMode = slashArgs == 'on'
          ? CodexCollaborationMode.plan
          : slashArgs == 'off'
          ? CodexCollaborationMode.standard
          : ((_selectedSession?.codexCollaborationMode == 'plan')
                ? CodexCollaborationMode.standard
                : CodexCollaborationMode.plan);
      await _runLocalCommandAction(
        rawText: rawText,
        pendingStatus: '正在切换会话模式...',
        action: () async {
          final session = await _ensureSession(titleHint: '主会话');
          await _sessionStore.setSessionCodexCollaborationMode(
            session.workspaceId,
            session.id,
            nextMode.wireValue,
          );
          return nextMode == CodexCollaborationMode.plan
              ? '已切换到计划模式。'
              : '已切换回默认模式。';
        },
      );
      return true;
    }

    switch (firstToken) {
      case '/help':
        await _runLocalCommandAction(
          rawText: rawText,
          pendingStatus: '正在整理命令说明...',
          action: () async => [
            '可用命令（移动端）',
            '',
            '常用',
            '- /plan：切换计划模式（/plan on | /plan off）',
            '- /review：评审当前改动',
            '- /diff：查看当前工作区改动',
            '- /mcp：查看已配置的 MCP 工具',
            '- /status：查看当前会话状态',
            '- /mention：管理待发送的文件/提交标记',
            '',
            '设置',
            '- /model <id>：设置模型',
            '- /permissions <policy>：设置审批策略',
            '- /personality <style>：设置风格',
            '- /logout：清除本地密钥',
            '',
            '说明',
            '- /new、/resume：当前工作区固定单会话，自动恢复最近历史。',
          ].join('\n'),
        );
        return true;
      case '/init':
        await _runLocalCommandAction(
          rawText: rawText,
          pendingStatus: '正在生成仓库协作说明...',
          action: () async {
            final workspace = _activeWorkspace;
            if (workspace == null) {
              return '当前没有可用工作区。';
            }
            final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
            final file = File('${paths.repoDir.path}/AGENTS.md');
            if (file.existsSync()) {
              return 'AGENTS.md 已存在（未覆盖）。';
            }
            await file.writeAsString(
              [
                '# Repository Guidelines',
                '',
                '在这里记录本仓库的协作约定，让 Codex 与贡献者遵循一致的结构、命令与风格。',
                '',
                '## Project Structure',
                '- 在此补充目录约定',
                '',
                '## Build & Dev Commands',
                '- 在此补充常用命令',
                '',
                '## Coding Style',
                '- 在此补充代码风格',
                '',
              ].join('\n'),
            );
            return '已生成 AGENTS.md，请按仓库实际情况补充内容。';
          },
        );
        return true;
      case '/mcp':
        await _runLocalCommandAction(
          rawText: rawText,
          pendingStatus: '正在读取 MCP 配置...',
          action: () async {
            final servers = await _mcpStore.listServers();
            if (servers.isEmpty) {
              return '还没有配置 MCP 工具。你可以在 MCP 页面中添加。';
            }
            final enabled = _settings.enabledGlobalMcpServerIds.toSet();
            final lines = <String>['已配置 MCP 工具（${servers.length}）', ''];
            for (final server in servers) {
              final status = enabled.contains(server.id) ? '已启用' : '未启用';
              lines.add('- ${server.name}：$status');
            }
            return lines.join('\n');
          },
        );
        return true;
      case '/diff':
        await _runLocalCommandAction(
          rawText: rawText,
          pendingStatus: '正在读取工作区变更...',
          action: () async {
            final workspace = _activeWorkspace;
            if (workspace == null) {
              return '当前没有可用工作区。';
            }
            final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
            final diff = await _native.gitDiff(
              localRepoDirUri: paths.repoDir.path,
              maxBytes: 200000,
            );
            if (diff.trim().isEmpty) {
              return '当前工作区没有变更。';
            }
            return '```diff\n$diff\n```';
          },
        );
        return true;
      case '/status':
        await _runLocalCommandAction(
          rawText: rawText,
          pendingStatus: '正在整理当前状态...',
          action: () async {
            final workspace = _activeWorkspace;
            final session = _selectedSession;
            if (workspace == null || session == null) {
              return '当前还没有可用会话。';
            }
            final servers = await _mcpStore.listServers();
            final enabled = _settings.enabledGlobalMcpServerIds.toSet();
            final enabledCount = servers.where((item) => enabled.contains(item.id)).length;
            final lines = [
              '当前状态',
              '- 工作区：${workspace.name}',
              '- 会话：${session.title}',
              '- 单会话模式：已启用',
              '- 历史隐藏会话：$_legacySessionCount',
              '- 模式：${session.codexCollaborationMode == 'plan' ? '计划' : '默认'}',
              '- 模型：${_settings.model?.trim().isNotEmpty == true ? _settings.model : '默认'}',
              '- 权限：${_settings.approvalPolicy}',
              '- 风格：${_settings.personality}',
              '- MCP：启用 $enabledCount/${servers.length}',
            ];
            if (slashArgs == 'raw' || slashArgs == 'debug') {
              lines.addAll(['', '如需更详细的内部诊断信息，请在桌面端进行排查。']);
            }
            return lines.join('\n');
          },
        );
        return true;
      case '/permissions':
        await _runLocalCommandAction(
          rawText: rawText,
          pendingStatus: '正在更新审批策略...',
          action: () async {
            const supported = <String>{
              'untrusted',
              'on-request',
              'on-failure',
              'never',
            };
            final mapped = slashArgs == 'auto' ? 'never' : slashArgs;
            if (mapped.isEmpty || !supported.contains(mapped)) {
              return '当前权限策略：${_settings.approvalPolicy}\n\n用法：/permissions <policy>\n可选：untrusted | on-request | on-failure | never';
            }
            await _settingsStore.updateSettings(
              (current) => current.copyWith(approvalPolicy: mapped),
            );
            await _settingsStore.materializeCodexConfigFiles(
              mcpServers: await _mcpStore.listServers(),
            );
            return '已更新权限策略为：$mapped';
          },
        );
        return true;
      case '/personality':
        await _runLocalCommandAction(
          rawText: rawText,
          pendingStatus: '正在更新回复风格...',
          action: () async {
            const supported = <String>{'friendly', 'pragmatic', 'none'};
            if (slashArgs.isEmpty || !supported.contains(slashArgs)) {
              return '当前风格：${_settings.personality}\n\n用法：/personality <style>\n可选：friendly | pragmatic | none';
            }
            await _settingsStore.updateSettings(
              (current) => current.copyWith(personality: slashArgs),
            );
            await _settingsStore.materializeCodexConfigFiles(
              mcpServers: await _mcpStore.listServers(),
            );
            return '已更新风格为：$slashArgs';
          },
        );
        return true;
      case '/model':
        await _runLocalCommandAction(
          rawText: rawText,
          pendingStatus: '正在更新模型...',
          action: () async {
            if (slashArgs.isEmpty) {
              return '当前模型：${_settings.model ?? '默认'}\n\n用法：/model <model-id>';
            }
            await _settingsStore.updateSettings(
              (current) => current.copyWith(model: slashArgs),
            );
            await _settingsStore.materializeCodexConfigFiles(
              mcpServers: await _mcpStore.listServers(),
            );
            return '已更新模型为：$slashArgs';
          },
        );
        return true;
      case '/experimental':
        await _runLocalCommandAction(
          rawText: rawText,
          pendingStatus: '正在更新实验特性...',
          action: () async {
            final parts = slashArgs.split(RegExp(r'\s+')).where((item) => item.isNotEmpty).toList(growable: false);
            if (parts.isEmpty) {
              return '当前多代理协作：${_settings.featuresMultiAgent ? '已开启' : '已关闭'}\n\n用法：/experimental multi_agent on|off';
            }
            final feature = parts.first.replaceAll('-', '_');
            final value = parts.length > 1 ? parts[1] : '';
            if (feature != 'multi_agent' ||
                !(value == 'on' || value == 'off')) {
              return '用法：/experimental multi_agent on|off';
            }
            final enabled = value == 'on';
            await _settingsStore.updateSettings(
              (current) => current.copyWith(featuresMultiAgent: enabled),
            );
            await _settingsStore.materializeCodexConfigFiles(
              mcpServers: await _mcpStore.listServers(),
            );
            return '已${enabled ? '开启' : '关闭'}多代理协作。';
          },
        );
        return true;
      case '/logout':
        await _runLocalCommandAction(
          rawText: rawText,
          pendingStatus: '正在清除本地密钥...',
          action: () async {
            await _settingsStore.clearCodexApiKey();
            await _settingsStore.materializeCodexConfigFiles(
              mcpServers: await _mcpStore.listServers(),
            );
            return '已清除本地密钥。';
          },
        );
        return true;
      case '/resume':
      case '/new':
        await _runLocalCommandAction(
          rawText: rawText,
          pendingStatus: '正在读取单会话状态...',
          action: () async => '当前工作区固定为单会话：系统会自动继续最近历史，不再创建或切换独立会话。',
        );
        return true;
      case '/mention':
        await _runLocalCommandAction(
          rawText: rawText,
          pendingStatus: '正在更新标记...',
          action: () async {
            if (slashArgs.isEmpty) {
              if (_pendingMentions.isEmpty) {
                return '用法：/mention <path>\n清空：/mention clear\n\n当前没有待发送的标记。';
              }
              final lines = ['已标记内容：'];
              for (final item in _pendingMentions) {
                lines.add(
                  item.kind == ComposerMentionKind.file
                      ? '- 文件：${item.label}'
                      : '- 提交：${item.label}',
                );
              }
              return '${lines.join('\n')}\n\n清空：/mention clear';
            }
            if (slashArgs == 'clear' || slashArgs == '--clear') {
              _updateView(() {
                _pendingMentions = const <ComposerPendingMention>[];
              });
              return '已清空待发送标记。';
            }
            var trimmed = slashArgs.trim();
            if (trimmed.length >= 2 &&
                ((trimmed.startsWith("'") && trimmed.endsWith("'")) ||
                    (trimmed.startsWith('"') && trimmed.endsWith('"')))) {
              trimmed = trimmed.substring(1, trimmed.length - 1).trim();
            }
            if (trimmed.isEmpty) {
              return '路径为空：用法 /mention <path>';
            }
            final next = [..._pendingMentions];
            if (!next.any(
              (item) =>
                  item.kind == ComposerMentionKind.file &&
                  item.value == trimmed,
            )) {
              next.add(
                ComposerPendingMention.file(label: trimmed, value: trimmed),
              );
            }
            _updateView(() {
              _pendingMentions = next;
            });
            return '已标记文件：$trimmed\n下一条消息会自动附带该文件上下文。';
          },
        );
        return true;
      case '/apps':
        if (slashArgs.isNotEmpty) {
          final token = slashArgs.replaceFirst(RegExp(r'^\$+'), '').trim();
          if (token.isNotEmpty) {
            _composerController.value = TextEditingValue(
              text: '\$$token ',
              selection: TextSelection.collapsed(offset: token.length + 2),
            );
            await _runLocalCommandAction(
              rawText: rawText,
              pendingStatus: '正在插入扩展标记...',
              action: () async => '已插入：\$$token',
            );
            return true;
          }
        }
        return false;
      case '/feedback':
        await _runLocalCommandAction(
          rawText: rawText,
          pendingStatus: '正在整理诊断提示...',
          action: () async => '请整理问题现象、触发步骤与当前工作区信息后再反馈，可帮助更快定位问题。',
        );
        return true;
      case '/statusline':
      case '/sandbox-add-read-dir':
      case '/fork':
      case '/agent':
        await _runLocalCommandAction(
          rawText: rawText,
          pendingStatus: '正在整理命令说明...',
          action: () async => '该命令当前仅在桌面端或多线程场景中可用，Android 单会话模式暂不支持。',
        );
        return true;
      default:
        return false;
    }
  }

  Future<(List<CodexInputElement>, String)> _buildTurnInput({
    required String rawText,
    required String turnText,
  }) async {
    final workspace = _activeWorkspace;
    if (workspace == null) {
      return (
        <CodexInputElement>[
          <String, Object?>{'type': 'text', 'text': turnText},
        ],
        rawText,
      );
    }
    final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
    final mentions = [..._pendingMentions];

    final skillInputs = <CodexInputElement>[];
    for (final skillName in extractSkillNames(rawText, _installedSkills)) {
      final file = await _skillsStore.skillFile(skillName);
      skillInputs.add(
        <String, Object?>{
          'type': 'skill',
          'name': skillName,
          'path': file.path,
        },
      );
    }

    final mentionInputs = mentions
        .where((item) => item.kind == ComposerMentionKind.file)
        .map((item) {
          final rawPath = item.value.replaceFirst(RegExp(r'^file://'), '');
          final resolvedPath = rawPath.startsWith('/')
              ? rawPath
              : '${paths.repoDir.path}/$rawPath';
          return <String, Object?>{
            'type': 'mention',
            'name': item.label,
            'path': resolvedPath,
          };
        })
        .toList(growable: false);

    var finalText = turnText;
    final commitMentions = mentions
        .where((item) => item.kind == ComposerMentionKind.commit)
        .toList(growable: false);
    if (commitMentions.isNotEmpty) {
      final cache = <String, String>{..._commitDetails};
      final sections = <String>[];
      for (final mention in commitMentions) {
        var detail = cache[mention.value];
        if (detail == null) {
          try {
            detail = await _native.gitShowCommit(
              localRepoDirUri: paths.repoDir.path,
              hash: mention.value,
              maxBytes: 60000,
            );
          } catch (error) {
            detail = '无法读取提交详情：$error';
          }
          cache[mention.value] = detail;
        }
        sections.add('[提交 ${mention.label}]\n$detail');
      }
      if (mounted) {
        _updateView(() {
          _commitDetails = cache;
        });
      }
      finalText =
          '${turnText.trimRight()}\n\n以下提交也请纳入本轮上下文参考：\n\n${sections.join('\n\n')}';
    }

    return (
      <CodexInputElement>[
        ...skillInputs,
        ...mentionInputs,
        <String, Object?>{'type': 'text', 'text': finalText},
      ],
      buildUserFacingInput(rawText, mentions),
    );
  }

  Future<void> _runCodexOperation({
    required String pendingStatus,
    required String successStatus,
    required CodexTurnKind kind,
    String? userMessage,
    Object? input,
    String? titleHint,
    List<CodexRpcCall>? rpcCalls,
    CodexCollaborationMode? collaborationModeOverride,
  }) async {
    if (_running || _busy) {
      return;
    }

    final workspace = _activeWorkspace;
    if (workspace == null) {
      return;
    }
    if (!_settings.enabled) {
      _updateView(() {
        _status = '当前已暂停 Codex 运行，请先到设置页启用。';
      });
      return;
    }
    if (!_hasApiKey) {
      _updateView(() {
        _status = '还未设置访问令牌，请先到设置页完成配置。';
      });
      return;
    }

    final session = await _ensureSession(titleHint: titleHint);
    final message = userMessage?.blankAsNull;
    if (message != null) {
      await _sessionStore.appendMessage(
        workspace.id,
        session.id,
        role: 'user',
        content: message,
      );
    }

    await _refresh(status: pendingStatus);
    if (!mounted) {
      return;
    }

    final collaborationMode =
        collaborationModeOverride ??
        (_selectedSession?.codexCollaborationMode == 'plan'
            ? CodexCollaborationMode.plan
            : CodexCollaborationMode.standard);
    final buffer = StringBuffer();
    String? errorMessage;

    _updateView(() {
      _running = true;
      _pendingAssistantText = '';
      _pendingStartedAt = DateTime.now().millisecondsSinceEpoch;
      _status = pendingStatus;
    });
    _scrollToBottom();

    try {
      await for (final event in _runner.run(
        workspace: workspace,
        sessionId: session.id,
        input: input,
        kind: kind,
        collaborationMode: collaborationMode,
        rpcCalls: rpcCalls,
      )) {
        if (!mounted) {
          return;
        }

        switch (event.type) {
          case CodexTurnEventType.text:
            buffer.write(event.text ?? '');
            _updateView(() {
              _pendingAssistantText = buffer.toString();
            });
            _scrollToBottom();
          case CodexTurnEventType.error:
            errorMessage = event.message ?? '运行失败。';
            _updateView(() {
              _status = errorMessage!;
            });
          case CodexTurnEventType.rpcResult:
          case CodexTurnEventType.done:
            break;
        }
      }
    } catch (error) {
      errorMessage = '$error';
    }

    final assistantText = buffer.toString().trimRight();
    if (assistantText.isNotEmpty) {
      await _sessionStore.appendMessage(
        workspace.id,
        session.id,
        role: 'assistant',
        content: assistantText,
      );
    }
    if (errorMessage?.trim().isNotEmpty == true) {
      await _sessionStore.appendMessage(
        workspace.id,
        session.id,
        role: 'system',
        content: errorMessage!.trim(),
      );
    }

    if (!mounted) {
      return;
    }
    _updateView(() {
      _running = false;
      _pendingAssistantText = '';
      _pendingStartedAt = 0;
    });
    await _refresh(status: errorMessage ?? successStatus);
  }

  String _deriveSessionTitle(String input) {
    final singleLine = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.isEmpty) {
      return '主会话';
    }
    return singleLine.length <= 24
        ? singleLine
        : '${singleLine.substring(0, 24)}...';
  }
}
