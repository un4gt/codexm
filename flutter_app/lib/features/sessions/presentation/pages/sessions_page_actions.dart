part of 'sessions_page.dart';

extension on String {
  String? get blankAsNull {
    final trimmed = trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

extension _SessionsPageActions on _SessionsPageState {
  Future<Workspace?> _ensureGitIdentity() async {
    final workspace = _activeWorkspace;
    if (workspace == null) {
      return null;
    }
    final existingName = workspace.gitUserName ?? workspace.git?.userName;
    final existingEmail = workspace.gitUserEmail ?? workspace.git?.userEmail;
    if (existingName?.trim().isNotEmpty == true &&
        existingEmail?.trim().isNotEmpty == true) {
      return workspace;
    }
    final nameController = TextEditingController(text: existingName ?? '');
    final emailController = TextEditingController(text: existingEmail ?? '');
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('设置 Git 提交身份'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: '姓名'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '邮箱'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final email = emailController.text.trim();
              if (name.isNotEmpty && email.isNotEmpty) {
                Navigator.of(dialogContext).pop((name, email));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    nameController.dispose();
    emailController.dispose();
    if (result == null) {
      return null;
    }
    final updated = await _codeWorkspaceService.updateGitIdentity(
      workspace,
      userName: result.$1,
      userEmail: result.$2,
    );
    _updateView(() {
      _activeWorkspace = updated;
    });
    widget.onActiveWorkspaceChanged?.call(updated);
    return updated;
  }

  Future<void> _completeWorkspaceMigration() async {
    final migration = _migrationRequired;
    if (migration == null || _busy || _running) {
      return;
    }
    final workspace = await _ensureGitIdentity();
    if (workspace == null || !mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('保存工作区基线'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: SelectableText(
              migration.diff.trim().isEmpty
                  ? '检测到未提交文件。保存后，所有历史会话将从这个基线创建独立代码副本。'
                  : migration.diff,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('保存并继续'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _runAction('正在准备独立会话...', () async {
      await _codeWorkspaceService.checkpointMigrationBaseline(
        workspace,
        message: 'Save workspace baseline before session migration',
        userName: workspace.gitUserName!,
        userEmail: workspace.gitUserEmail!,
      );
      return '工作区已完成独立会话迁移。';
    });
  }

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
            decoration: InputDecoration(labelText: '会话名称', hintText: hintText),
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

  Future<void> _createSession({Session? sourceSession}) async {
    final workspace = _activeWorkspace;
    if (workspace == null || _busy || _running) {
      return;
    }
    if (sourceSession != null) {
      final ready = await _checkpointSession(
        sourceSession,
        onlyWhenDirty: true,
      );
      if (!ready) {
        return;
      }
    }
    final name = await _promptSessionName(
      title: sourceSession == null ? '新建会话' : '基于此会话新建',
      hintText: '例如：发布问题排查',
    );
    if (name == null) {
      return;
    }
    await _runAction('正在创建会话...', () async {
      final session = await _codeWorkspaceService.createSession(
        workspace,
        title: name.trim().isEmpty ? '新会话' : name.trim(),
        sourceSession: sourceSession,
      );
      _selectedSessionId = session.id;
      return '已创建会话：${session.title}';
    });
  }

  Future<void> _showSessionChanges(Session session) async {
    final workspace = _activeWorkspace;
    if (workspace == null || _busy || _running) {
      return;
    }
    final workingDirectory = await _workingDirectoryForSession(session);
    if (workingDirectory == null || !mounted) {
      return;
    }
    final status = await _codeWorkspaceService.statusFor(workspace, session);
    final diff = await _native.gitDiff(
      localRepoDirUri: workingDirectory.path,
      maxBytes: 200000,
    );
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${session.title}的改动'),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: SelectableText(
              status.isClean
                  ? '当前没有未保存改动。'
                  : (diff.trim().isEmpty
                        ? '未跟踪文件：\n${status.untracked.join('\n')}'
                        : diff),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkpointSession(
    Session session, {
    bool onlyWhenDirty = false,
  }) async {
    final workspace = _activeWorkspace;
    if (workspace == null || _busy || _running) {
      return false;
    }
    final status = await _codeWorkspaceService.statusFor(workspace, session);
    if (status.isClean) {
      return true;
    }
    final identifiedWorkspace = await _ensureGitIdentity();
    if (identifiedWorkspace == null || !mounted) {
      return false;
    }
    final workingDirectory = await _workingDirectoryForSession(session);
    if (workingDirectory == null) {
      return false;
    }
    final diff = await _native.gitDiff(
      localRepoDirUri: workingDirectory.path,
      maxBytes: 200000,
    );
    if (!mounted) {
      return false;
    }
    final messageController = TextEditingController(
      text: 'Save changes from ${session.title}',
    );
    final message = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('保存代码检查点'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: messageController,
                decoration: const InputDecoration(labelText: '提交说明'),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: SelectableText(
                    diff.trim().isEmpty
                        ? '未跟踪文件：\n${status.untracked.join('\n')}'
                        : diff,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = messageController.text.trim();
              if (value.isNotEmpty) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    messageController.dispose();
    if (message == null) {
      return false;
    }
    var completed = false;
    await _runAction('正在保存代码检查点...', () async {
      await _codeWorkspaceService.checkpoint(
        identifiedWorkspace,
        session,
        message: message,
      );
      completed = true;
      return '已保存 ${session.title} 的代码检查点。';
    });
    return completed;
  }

  Future<void> _mergeSession(Session source) async {
    final workspace = _activeWorkspace;
    if (workspace == null || _busy || _running) {
      return;
    }
    if (!await _checkpointSession(source, onlyWhenDirty: true)) {
      return;
    }
    final identifiedWorkspace = await _ensureGitIdentity();
    if (identifiedWorkspace == null || !mounted) {
      return;
    }
    final targetId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: AppListSection(
          title: '合并 ${source.title} 到',
          children: [
            AppListTile(
              title: '主工作区',
              subtitle: identifiedWorkspace.integrationBranch ?? 'main',
              leading: const Icon(Icons.account_tree_outlined),
              onTap: () => Navigator.of(sheetContext).pop('__main__'),
            ),
            for (final session in _sessions)
              if (session.id != source.id &&
                  session.codeState != SessionCodeState.archived)
                AppListTile(
                  title: session.title,
                  subtitle: _sessionCodeStatusLabel(session),
                  leading: const Icon(Icons.chat_bubble_outline),
                  enabled: session.codeState == SessionCodeState.ready,
                  onTap: () => Navigator.of(sheetContext).pop(session.id),
                ),
          ],
        ),
      ),
    );
    if (targetId == null) {
      return;
    }
    final target = targetId == '__main__'
        ? null
        : _findSessionById(_sessions, targetId);
    await _runAction('正在合并会话代码...', () async {
      final result = await _codeWorkspaceService.merge(
        identifiedWorkspace,
        source: source,
        target: target,
      );
      if (result.outcome == GitMergeOutcome.conflicts) {
        if (target != null) {
          _selectedSessionId = target.id;
        }
        return '合并存在冲突，请在目标${target == null ? '工作区' : '会话'}中解决。';
      }
      return switch (result.outcome) {
        GitMergeOutcome.upToDate => '目标已包含该会话的全部改动。',
        GitMergeOutcome.fastForward => '已快速合并 ${source.title}。',
        GitMergeOutcome.merged => '已合并 ${source.title}。',
        GitMergeOutcome.conflicts => '合并存在冲突。',
      };
    });
  }

  Future<void> _archiveSession(Session session) async {
    final workspace = _activeWorkspace;
    if (workspace == null || _busy || _running) {
      return;
    }
    if (!await _checkpointSession(session, onlyWhenDirty: true)) {
      return;
    }
    await _runAction('正在归档会话...', () async {
      await _codeWorkspaceService.archive(workspace, session);
      return '已归档会话：${session.title}';
    });
  }

  Future<void> _continueSessionMerge(Session session) async {
    final workspace = await _ensureGitIdentity();
    if (workspace == null || _busy || _running) {
      return;
    }
    await _runAction('正在完成合并...', () async {
      final result = await _codeWorkspaceService.continueMerge(
        workspace,
        target: session,
      );
      return result.outcome == GitMergeOutcome.conflicts
          ? '仍有 ${result.conflictPaths.length} 个冲突文件需要处理。'
          : '已完成会话代码合并。';
    });
  }

  Future<void> _abortSessionMerge(Session session) async {
    final workspace = _activeWorkspace;
    if (workspace == null || _busy || _running) {
      return;
    }
    await _runAction('正在放弃合并...', () async {
      await _codeWorkspaceService.abortMerge(workspace, target: session);
      return '已放弃本次合并，目标会话已恢复。';
    });
  }

  Future<void> _continueMainMerge() async {
    final workspace = await _ensureGitIdentity();
    if (workspace == null || _busy || _running) return;
    await _runAction('正在完成主工作区合并...', () async {
      final result = await _codeWorkspaceService.continueMerge(workspace);
      return result.outcome == GitMergeOutcome.conflicts
          ? '主工作区仍有 ${result.conflictPaths.length} 个冲突文件。'
          : '已完成主工作区合并。';
    });
  }

  Future<void> _abortMainMerge() async {
    final workspace = _activeWorkspace;
    if (workspace == null || _busy || _running) return;
    await _runAction('正在放弃主工作区合并...', () async {
      await _codeWorkspaceService.abortMerge(workspace);
      return '已放弃主工作区合并。';
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
          content: Text(
            '删除「${session.title}」将移除聊天记录、代码工作副本和专属分支。若有未保存或未合并的代码，将再次向你确认。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除会话'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await _runAction('正在删除会话...', () async {
      try {
        await _codeWorkspaceService.delete(workspace, session, force: false);
      } on SessionCodeDirtyException catch (_) {
        final force = await _confirmForceDeleteSession(session);
        if (!force) return '已取消删除。';
        await _codeWorkspaceService.delete(workspace, session, force: true);
      } on SessionCodeUnmergedException catch (_) {
        final force = await _confirmForceDeleteSession(session);
        if (!force) return '已取消删除。';
        await _codeWorkspaceService.delete(workspace, session, force: true);
      }
      final remaining = await _sessionStore.listSessions(workspace.id);
      _selectedSessionId = remaining.isEmpty ? null : remaining.first.id;
      return '已删除会话：${session.title}';
    });
  }

  Future<bool> _confirmForceDeleteSession(Session session) async {
    if (!mounted) return false;
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('永久删除代码与会话'),
        content: Text(
          '「${session.title}」仍有未保存或未合并的代码。永久删除将移除代码副本、分支和聊天记录，且无法恢复。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('保留会话'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('仍要永久删除'),
          ),
        ],
      ),
    );
    return result ?? false;
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
    _scrollToBottom(force: true);
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
                              case _SessionAction.changes:
                                await _showSessionChanges(session);
                              case _SessionAction.checkpoint:
                                await _checkpointSession(session);
                              case _SessionAction.merge:
                                await _mergeSession(session);
                              case _SessionAction.createFrom:
                                await _createSession(sourceSession: session);
                              case _SessionAction.rename:
                                await _renameSession(session);
                              case _SessionAction.archive:
                                await _archiveSession(session);
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
    } catch (error, stackTrace) {
      if (!mounted) {
        return;
      }
      final details = mapSessionCodeError(error);
      debugPrint(
        'Session code action failed: ${details.debugMessage}\n$stackTrace',
      );
      _updateView(() {
        _status = details.message;
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

    final session = await _codeWorkspaceService.ensurePrimarySession(workspace);
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
    final displayContent = await _displayTextForActiveWorkspace(content);
    final displayUserInput = await _displayTextForActiveWorkspace(userInput);
    await _sessionStore.appendMessage(
      workspace.id,
      session.id,
      role: 'user',
      content: displayUserInput,
    );
    await _sessionStore.appendMessage(
      workspace.id,
      session.id,
      role: assistantRole,
      content: displayContent,
    );
    await _refresh(status: status ?? _firstStatusLine(displayContent));
  }

  Future<String> _displayTextForActiveWorkspace(String value) async {
    final workspace = _activeWorkspace;
    if (workspace == null || value.trim().isEmpty) {
      return value;
    }
    final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
    final workingDirectory = await _workingDirectoryForSession();
    return RuntimePathMapper(
      workspaceRepoDir: workingDirectory?.path ?? paths.repoDir.path,
      codexHomeDir: paths.codexHomeDir.path,
      tmpDir: paths.tmpDir.path,
    ).realToVirtual(value);
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
    final current = _composerController.value;
    final trigger = findComposerTrigger(current);
    if (trigger?.kind == ComposerTriggerKind.slash) {
      _composerController.value = applyComposerSuggestion(
        current,
        trigger!,
        command.command,
      );
      return;
    }
    final next = replaceActiveSlashToken(current.text, command.command);
    _composerController.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void _applyMentionSuggestion(ComposerMentionSuggestion suggestion) {
    final current = _composerController.value;
    final trigger = findComposerTrigger(current);
    final nextValue = trigger?.kind == ComposerTriggerKind.mention
        ? removeComposerTrigger(current, trigger!)
        : TextEditingValue(
            text: clearActiveMentionToken(current.text),
            selection: TextSelection.collapsed(
              offset: clearActiveMentionToken(current.text).length,
            ),
          );
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
    final text = nextValue.text.isEmpty ? '' : '${nextValue.text} ';
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

    final isSlashPlanToggle =
        command != null &&
        firstToken == '/plan' &&
        (slashArgs.isEmpty || slashArgs == 'on' || slashArgs == 'off');
    if (firstToken.startsWith('/') && command == null && !isSlashPlanToggle) {
      await _runLocalCommandAction(
        rawText: rawText,
        pendingStatus: '正在处理命令...',
        action: () async => '未知命令：$firstToken\n\n输入 /help 可查看当前移动端支持的命令。',
      );
      _composerController.clear();
      return;
    }

    const planPrefix =
        '你处于计划模式。请先输出一个可执行的计划（步骤、依赖、风险、验证方式），在我确认前不要执行命令或修改文件。\n\n任务：';
    final currentMode = _selectedSession?.codexCollaborationMode == 'plan'
        ? CodexCollaborationMode.plan
        : CodexCollaborationMode.standard;
    final isPlanTurn =
        command != null && firstToken == '/plan' && slashArgs.isNotEmpty;
    final isReview = command != null && firstToken == '/review';
    final isRpc =
        command != null &&
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
            '- /new：创建独立会话；/resume：继续当前会话。',
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
            final workingDirectory = await _workingDirectoryForSession();
            if (workingDirectory == null) {
              return '当前还没有可用会话。';
            }
            final file = File('${workingDirectory.path}/AGENTS.md');
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
            final workingDirectory = await _workingDirectoryForSession();
            if (workingDirectory == null) {
              return '当前还没有可用会话。';
            }
            final diff = await _native.gitDiff(
              localRepoDirUri: workingDirectory.path,
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
            final enabledCount = servers
                .where((item) => enabled.contains(item.id))
                .length;
            final lines = [
              '当前状态',
              '- 工作区：${workspace.name}',
              '- 会话：${session.title}',
              '- 工作区会话：${_sessions.length}',
              '- 代码环境：${_sessionCodeStatusLabel(session)}',
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
            final parts = slashArgs
                .split(RegExp(r'\s+'))
                .where((item) => item.isNotEmpty)
                .toList(growable: false);
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
            final workspace = _activeWorkspace;
            final workingDirectory = await _workingDirectoryForSession();
            final label = workspace == null
                ? trimmed
                : displayPathForWorkspace(
                    await _workspaceDirectoryService.pathsFor(workspace.id),
                    trimmed,
                    workspaceRepoDir: workingDirectory?.path,
                  );
            final next = [..._pendingMentions];
            if (!next.any(
              (item) =>
                  item.kind == ComposerMentionKind.file &&
                  item.value == trimmed,
            )) {
              next.add(
                ComposerPendingMention.file(label: label, value: trimmed),
              );
            }
            _updateView(() {
              _pendingMentions = next;
            });
            return '已标记文件：$label\n下一条消息会自动附带该文件上下文。';
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
          action: () async => '该命令当前在 Android 版本中暂不支持。',
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
    final workingDirectory = await _workingDirectoryForSession();
    if (workingDirectory == null) {
      throw StateError('当前会话代码环境不可用。');
    }
    final mentions = [..._pendingMentions];

    final skillInputs = <CodexInputElement>[];
    for (final skillName in extractSkillNames(rawText, _installedSkills)) {
      final file = await _skillsStore.skillFile(skillName);
      skillInputs.add(<String, Object?>{
        'type': 'skill',
        'name': skillName,
        'path': file.path,
      });
    }

    final mentionInputs = mentions
        .where((item) => item.kind == ComposerMentionKind.file)
        .map((item) {
          final rawPath = item.value.replaceFirst(RegExp(r'^file://'), '');
          final resolvedPath = rawPath.startsWith('/')
              ? rawPath
              : '${workingDirectory.path}/$rawPath';
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
              localRepoDirUri: workingDirectory.path,
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

    final startedAt = DateTime.now().millisecondsSinceEpoch;
    final accumulator = AssistantPartAccumulator();
    String? errorMessage;
    Session? session;

    _updateView(() {
      _running = true;
      _pendingAssistantText = '';
      _pendingAssistantParts = const <ChatMessagePart>[];
      _pendingStartedAt = startedAt;
      _runtimeStatus = null;
      _runtimeStatusIsRetrying = false;
      _status = pendingStatus;
    });
    _emitActivityState();

    try {
      final ensuredSession = await _ensureSession(titleHint: titleHint);
      session = ensuredSession;
      final message = userMessage?.blankAsNull;
      if (message != null) {
        final displayMessage = await _displayTextForActiveWorkspace(message);
        await _sessionStore.appendMessage(
          workspace.id,
          ensuredSession.id,
          role: 'user',
          content: displayMessage,
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

      _scrollToBottom(animated: false, force: true);
      await for (final event in _runner.run(
        workspace: workspace,
        sessionId: ensuredSession.id,
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
            accumulator.appendText(event.text ?? '');
            _updateView(() {
              _pendingAssistantText = accumulator.text;
              _pendingAssistantParts = accumulator.parts;
            });
            _scrollToBottom(animated: false);
          case CodexTurnEventType.messagePart:
            accumulator.mergePart(
              id: event.partId,
              kind: event.partKind,
              title: event.partTitle,
              content: event.partContent ?? '',
              status: event.partStatus,
            );
            _updateView(() {
              _pendingAssistantParts = accumulator.parts;
            });
            _scrollToBottom(animated: false);
          case CodexTurnEventType.status:
            final message = event.message?.trim() ?? '';
            _updateView(() {
              _runtimeStatus = message.isEmpty
                  ? (_running ? '已重新连接，继续生成...' : null)
                  : message;
              _runtimeStatusIsRetrying = message.isNotEmpty && event.isRetrying;
            });
          case CodexTurnEventType.error:
            errorMessage = event.message ?? '运行失败。';
            _updateView(() {
              _runtimeStatus = null;
              _runtimeStatusIsRetrying = false;
              _status = errorMessage!;
            });
          case CodexTurnEventType.rpcResult:
          case CodexTurnEventType.done:
            _updateView(() {
              _runtimeStatus = null;
              _runtimeStatusIsRetrying = false;
            });
            break;
        }
      }
    } catch (error) {
      errorMessage = '$error';
    }

    ChatMessage? assistantMessage;
    ChatMessage? systemMessage;
    final activeSession = session;
    final assistantText = accumulator.text.trimRight();
    final assistantParts = accumulator.parts;
    if (activeSession != null &&
        (assistantText.isNotEmpty || assistantParts.isNotEmpty)) {
      assistantMessage = await _sessionStore.appendMessage(
        workspace.id,
        activeSession.id,
        role: 'assistant',
        content: assistantText,
        parts: assistantParts,
        createdAt: startedAt,
      );
    }
    if (activeSession != null && errorMessage?.trim().isNotEmpty == true) {
      final displayError = await _displayTextForActiveWorkspace(
        errorMessage!.trim(),
      );
      systemMessage = await _sessionStore.appendMessage(
        workspace.id,
        activeSession.id,
        role: 'system',
        content: displayError,
      );
      errorMessage = displayError;
    }
    final updatedSessions = activeSession == null
        ? null
        : await _sessionStore.listSessions(workspace.id);

    if (!mounted) {
      return;
    }
    final shouldUpdateVisibleMessages =
        activeSession != null &&
        _activeWorkspace?.id == workspace.id &&
        _selectedSessionId == activeSession.id;
    _updateView(() {
      _running = false;
      _pendingAssistantText = '';
      _pendingAssistantParts = const <ChatMessagePart>[];
      _pendingStartedAt = 0;
      _runtimeStatus = null;
      _runtimeStatusIsRetrying = false;
      _status = errorMessage ?? successStatus;
      if (updatedSessions != null && _activeWorkspace?.id == workspace.id) {
        _sessions = updatedSessions;
      }
      if (shouldUpdateVisibleMessages) {
        _messages = [..._messages, ?assistantMessage, ?systemMessage];
      }
    });
    _emitActivityState();
    if (shouldUpdateVisibleMessages) {
      _scrollToBottom(animated: false);
    } else {
      await _refresh(status: errorMessage ?? successStatus);
    }
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
