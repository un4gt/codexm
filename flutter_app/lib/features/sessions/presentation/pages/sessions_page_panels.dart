part of 'sessions_page.dart';

enum _SessionAction { rename, delete }

enum _HeaderMenuAction { newSession, renameSession, deleteSession }

class _SessionUiSpecs {
  const _SessionUiSpecs._();

  static const double maxContentWidth = 920;
  static const double compactHorizontalPadding = 14;
  static const double mediumHorizontalPadding = 18;
  static const double expandedHorizontalPadding = 20;
  static const double minTapTarget = 48;
}

class _WorkspaceEmptyState extends StatelessWidget {
  const _WorkspaceEmptyState({this.onOpenWorkspacesRequested});

  final VoidCallback? onOpenWorkspacesRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline,
                size: 36,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 14),
              Text(
                '先准备一个工作区',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '会话围绕当前工作区展开。准备好后，这里会显示连续消息流和底部输入栏。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: onOpenWorkspacesRequested,
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('前往工作区'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.workspace,
    required this.sessions,
    required this.selectedSession,
    required this.messages,
    required this.showThinking,
    required this.settingsEnabled,
    required this.hasApiKey,
    required this.running,
    required this.status,
    required this.runtimeStatus,
    required this.runtimeStatusIsRetrying,
    required this.pendingAssistantText,
    required this.pendingStartedAt,
    required this.scrollController,
    required this.composerController,
    required this.pendingMentions,
    required this.slashSuggestions,
    required this.mentionSuggestions,
    required this.mentionLoading,
    required this.onSelectSlashSuggestion,
    required this.onSelectMentionSuggestion,
    required this.onRemovePendingMention,
    required this.onSendMessage,
    required this.onOpenSessionSwitcher,
    required this.onCreateSession,
    required this.onRenameSession,
    required this.onDeleteSession,
    required this.canSend,
    required this.canEditComposer,
  });

  final Workspace workspace;
  final List<Session> sessions;
  final Session? selectedSession;
  final List<ChatMessage> messages;
  final bool showThinking;
  final bool settingsEnabled;
  final bool hasApiKey;
  final bool running;
  final String status;
  final String? runtimeStatus;
  final bool runtimeStatusIsRetrying;
  final String pendingAssistantText;
  final int pendingStartedAt;
  final ScrollController scrollController;
  final TextEditingController composerController;
  final List<ComposerPendingMention> pendingMentions;
  final List<CodexSlashCommand> slashSuggestions;
  final List<ComposerMentionSuggestion> mentionSuggestions;
  final bool mentionLoading;
  final ValueChanged<CodexSlashCommand> onSelectSlashSuggestion;
  final ValueChanged<ComposerMentionSuggestion> onSelectMentionSuggestion;
  final ValueChanged<ComposerPendingMention> onRemovePendingMention;
  final VoidCallback onSendMessage;
  final VoidCallback onOpenSessionSwitcher;
  final VoidCallback onCreateSession;
  final ValueChanged<Session> onRenameSession;
  final ValueChanged<Session> onDeleteSession;
  final bool canSend;
  final bool canEditComposer;

  @override
  Widget build(BuildContext context) {
    final mentionToken = extractMentionToken(composerController.text);
    final showSuggestions =
        slashSuggestions.isNotEmpty ||
        mentionLoading ||
        mentionSuggestions.isNotEmpty ||
        mentionToken != null;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _SessionUiSpecs.maxContentWidth,
        ),
        child: Column(
          children: [
            _SessionHeader(
              workspace: workspace,
              selectedSession: selectedSession,
              sessionCount: sessions.length,
              status: status,
              settingsReady: settingsEnabled && hasApiKey,
              onOpenSessionSwitcher: onOpenSessionSwitcher,
              onMenuAction: (action) {
                switch (action) {
                  case _HeaderMenuAction.newSession:
                    onCreateSession();
                    break;
                  case _HeaderMenuAction.renameSession:
                    final session = selectedSession;
                    if (session != null) {
                      onRenameSession(session);
                    }
                    break;
                  case _HeaderMenuAction.deleteSession:
                    final session = selectedSession;
                    if (session != null) {
                      onDeleteSession(session);
                    }
                    break;
                }
              },
            ),
            Expanded(
              child: _MessageList(
                messages: messages,
                showThinking: showThinking,
                pendingAssistantText: pendingAssistantText,
                pendingStartedAt: pendingStartedAt,
                scrollController: scrollController,
                workspaceName: workspace.name,
                canDirectChat: settingsEnabled && hasApiKey,
              ),
            ),
            _SessionInputBar(
              settingsEnabled: settingsEnabled,
              hasApiKey: hasApiKey,
              running: running,
              status: status,
              runtimeStatus: runtimeStatus,
              runtimeStatusIsRetrying: runtimeStatusIsRetrying,
              composerController: composerController,
              pendingMentions: pendingMentions,
              slashSuggestions: slashSuggestions,
              mentionSuggestions: mentionSuggestions,
              mentionLoading: mentionLoading,
              onSelectSlashSuggestion: onSelectSlashSuggestion,
              onSelectMentionSuggestion: onSelectMentionSuggestion,
              onRemovePendingMention: onRemovePendingMention,
              onSendMessage: onSendMessage,
              canSend: canSend,
              canEditComposer: canEditComposer,
              showSuggestions: showSuggestions,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.workspace,
    required this.selectedSession,
    required this.sessionCount,
    required this.status,
    required this.settingsReady,
    required this.onOpenSessionSwitcher,
    required this.onMenuAction,
  });

  final Workspace workspace;
  final Session? selectedSession;
  final int sessionCount;
  final String status;
  final bool settingsReady;
  final VoidCallback onOpenSessionSwitcher;
  final ValueChanged<_HeaderMenuAction> onMenuAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final widthClass = context.adaptiveWidthClass;
    final horizontalPadding = switch (widthClass) {
      AdaptiveWidthClass.compact => _SessionUiSpecs.compactHorizontalPadding,
      AdaptiveWidthClass.medium => _SessionUiSpecs.mediumHorizontalPadding,
      AdaptiveWidthClass.expanded => _SessionUiSpecs.expandedHorizontalPadding,
    };
    final trimmedStatus = status.trim();
    final shouldShowStatus =
        trimmedStatus.isNotEmpty &&
        (trimmedStatus.contains('失败') ||
            trimmedStatus.contains('请先') ||
            trimmedStatus.contains('未连接'));

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          10,
          horizontalPadding,
          10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedSession?.title ?? '主会话',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (widthClass.isExpanded) ...[
                            _ConnectionStatusChip(connected: settingsReady),
                            const SizedBox(width: 8),
                          ] else if (widthClass.isMedium) ...[
                            Icon(
                              settingsReady
                                  ? Icons.check_circle_outline
                                  : Icons.vpn_key_outlined,
                              size: 14,
                              color: settingsReady
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              workspace.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: _SessionUiSpecs.minTapTarget,
                  height: _SessionUiSpecs.minTapTarget,
                  child: IconButton(
                    tooltip: '切换会话（$sessionCount）',
                    onPressed: onOpenSessionSwitcher,
                    icon: const Icon(Icons.swap_horiz_outlined),
                  ),
                ),
                SizedBox(
                  width: _SessionUiSpecs.minTapTarget,
                  height: _SessionUiSpecs.minTapTarget,
                  child: PopupMenuButton<_HeaderMenuAction>(
                    tooltip: '更多会话操作',
                    icon: const Icon(Icons.more_horiz),
                    onSelected: onMenuAction,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _HeaderMenuAction.newSession,
                        child: Text('新建会话'),
                      ),
                      PopupMenuItem(
                        value: _HeaderMenuAction.renameSession,
                        enabled: selectedSession != null,
                        child: const Text('重命名当前会话'),
                      ),
                      PopupMenuItem(
                        value: _HeaderMenuAction.deleteSession,
                        enabled: selectedSession != null,
                        child: const Text('删除当前会话'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (shouldShowStatus) ...[
              const SizedBox(height: 8),
              Text(
                trimmedStatus,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ConnectionStatusChip extends StatelessWidget {
  const _ConnectionStatusChip({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final icon = connected
        ? Icons.check_circle_outline
        : Icons.vpn_key_outlined;
    final label = connected ? '已连接，可直接发送' : '未连接，请先完成设置';

    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: connected
              ? colorScheme.primary.withValues(alpha: 0.14)
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: connected
                ? colorScheme.primary.withValues(alpha: 0.24)
                : colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: connected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.messages,
    required this.showThinking,
    required this.pendingAssistantText,
    required this.pendingStartedAt,
    required this.scrollController,
    required this.workspaceName,
    required this.canDirectChat,
  });

  final List<ChatMessage> messages;
  final bool showThinking;
  final String pendingAssistantText;
  final int pendingStartedAt;
  final ScrollController scrollController;
  final String workspaceName;
  final bool canDirectChat;

  @override
  Widget build(BuildContext context) {
    final hasStreaming = pendingAssistantText.trim().isNotEmpty;
    final widthClass = context.adaptiveWidthClass;
    final horizontalPadding = switch (widthClass) {
      AdaptiveWidthClass.compact => _SessionUiSpecs.compactHorizontalPadding,
      AdaptiveWidthClass.medium => _SessionUiSpecs.mediumHorizontalPadding,
      AdaptiveWidthClass.expanded => _SessionUiSpecs.expandedHorizontalPadding,
    };

    if (messages.isEmpty && !hasStreaming) {
      return _ChatEmptyState(
        workspaceName: workspaceName,
        canDirectChat: canDirectChat,
      );
    }

    final totalCount = messages.length + (hasStreaming ? 1 : 0);

    return Scrollbar(
      controller: scrollController,
      child: ListView.builder(
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          12,
          horizontalPadding,
          12,
        ),
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (index < messages.length) {
            final message = messages[index];
            return MessageBubble(
              role: message.role,
              content: message.content,
              createdAt: message.createdAt,
              showThinking: showThinking,
            );
          }
          return MessageBubble(
            role: 'assistant',
            content: pendingAssistantText,
            createdAt: pendingStartedAt,
            showThinking: showThinking,
            isStreaming: true,
          );
        },
      ),
    );
  }
}

class _SessionInputBar extends StatelessWidget {
  const _SessionInputBar({
    required this.settingsEnabled,
    required this.hasApiKey,
    required this.running,
    required this.status,
    required this.runtimeStatus,
    required this.runtimeStatusIsRetrying,
    required this.composerController,
    required this.pendingMentions,
    required this.slashSuggestions,
    required this.mentionSuggestions,
    required this.mentionLoading,
    required this.onSelectSlashSuggestion,
    required this.onSelectMentionSuggestion,
    required this.onRemovePendingMention,
    required this.onSendMessage,
    required this.canSend,
    required this.canEditComposer,
    required this.showSuggestions,
  });

  final bool settingsEnabled;
  final bool hasApiKey;
  final bool running;
  final String status;
  final String? runtimeStatus;
  final bool runtimeStatusIsRetrying;
  final TextEditingController composerController;
  final List<ComposerPendingMention> pendingMentions;
  final List<CodexSlashCommand> slashSuggestions;
  final List<ComposerMentionSuggestion> mentionSuggestions;
  final bool mentionLoading;
  final ValueChanged<CodexSlashCommand> onSelectSlashSuggestion;
  final ValueChanged<ComposerMentionSuggestion> onSelectMentionSuggestion;
  final ValueChanged<ComposerPendingMention> onRemovePendingMention;
  final VoidCallback onSendMessage;
  final bool canSend;
  final bool canEditComposer;
  final bool showSuggestions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final widthClass = context.adaptiveWidthClass;
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bottomPadding = keyboardVisible
        ? 8.0
        : 8.0 + MediaQuery.paddingOf(context).bottom;
    final horizontalPadding = switch (widthClass) {
      AdaptiveWidthClass.compact => _SessionUiSpecs.compactHorizontalPadding,
      AdaptiveWidthClass.medium => _SessionUiSpecs.mediumHorizontalPadding,
      AdaptiveWidthClass.expanded => _SessionUiSpecs.expandedHorizontalPadding,
    };

    String? helperText;
    final trimmedRuntimeStatus = runtimeStatus?.trim() ?? '';
    if (!settingsEnabled) {
      helperText = '当前对话能力已关闭，请先在设置中启用。';
    } else if (!hasApiKey) {
      helperText = '请先配置 API Key。';
    } else if (trimmedRuntimeStatus.isNotEmpty) {
      helperText = trimmedRuntimeStatus;
    } else {
      final trimmedStatus = status.trim();
      if (trimmedStatus.contains('失败') || trimmedStatus.contains('请先')) {
        helperText = trimmedStatus;
      }
    }

    final sendButtonTooltip = running
        ? '正在等待 Codex 回复'
        : (canSend ? '发送消息' : '请输入内容后发送');
    final sendButtonLabel = running
        ? '正在等待 Codex 回复'
        : (canSend ? '发送消息' : '发送消息（不可用）');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          10,
          horizontalPadding,
          bottomPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (helperText != null) ...[
              _InlineNotice(
                icon: runtimeStatusIsRetrying
                    ? Icons.sync
                    : helperText.contains('失败')
                    ? Icons.error_outline
                    : Icons.info_outline,
                text: helperText,
              ),
              const SizedBox(height: 10),
            ],
            if (pendingMentions.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mention in pendingMentions)
                    InputChip(
                      label: Text('@${mention.label}'),
                      avatar: Icon(
                        mention.kind == ComposerMentionKind.file
                            ? Icons.insert_drive_file_outlined
                            : Icons.account_tree_outlined,
                        size: 18,
                      ),
                      onDeleted: () => onRemovePendingMention(mention),
                    ),
                ],
              ),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Semantics(
                    textField: true,
                    label: '消息输入框',
                    child: TextField(
                      controller: composerController,
                      enabled: canEditComposer,
                      minLines: 1,
                      maxLines: 6,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: '在这里输入消息...',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(24)),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Semantics(
                  button: true,
                  enabled: canSend,
                  label: sendButtonLabel,
                  child: IconButton.filled(
                    tooltip: sendButtonTooltip,
                    onPressed: canSend ? onSendMessage : null,
                    icon: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: running
                          ? SizedBox(
                              key: const ValueKey('send-loading'),
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_upward_rounded,
                              key: ValueKey('send-icon'),
                            ),
                    ),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(
                        _SessionUiSpecs.minTapTarget,
                        _SessionUiSpecs.minTapTarget,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (showSuggestions) ...[
              const SizedBox(height: 10),
              _ComposerSuggestionsPanel(
                slashSuggestions: slashSuggestions,
                mentionLoading: mentionLoading,
                mentionSuggestions: mentionSuggestions,
                onSelectSlashSuggestion: onSelectSlashSuggestion,
                onSelectMentionSuggestion: onSelectMentionSuggestion,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerSuggestionsPanel extends StatelessWidget {
  const _ComposerSuggestionsPanel({
    required this.slashSuggestions,
    required this.mentionLoading,
    required this.mentionSuggestions,
    required this.onSelectSlashSuggestion,
    required this.onSelectMentionSuggestion,
  });

  final List<CodexSlashCommand> slashSuggestions;
  final bool mentionLoading;
  final List<ComposerMentionSuggestion> mentionSuggestions;
  final ValueChanged<CodexSlashCommand> onSelectSlashSuggestion;
  final ValueChanged<ComposerMentionSuggestion> onSelectMentionSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: slashSuggestions.isNotEmpty
          ? Column(
              children: [
                for (final suggestion in slashSuggestions.take(8))
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.code_outlined),
                    title: Text(suggestion.command),
                    subtitle: Text(suggestion.purpose),
                    onTap: () => onSelectSlashSuggestion(suggestion),
                  ),
              ],
            )
          : mentionLoading
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Text('正在查找文件与提交...'),
                ],
              ),
            )
          : mentionSuggestions.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: Text('没有匹配的文件或提交。'),
            )
          : Column(
              children: [
                for (final suggestion in mentionSuggestions)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      suggestion.kind == ComposerMentionKind.file
                          ? Icons.insert_drive_file_outlined
                          : Icons.account_tree_outlined,
                    ),
                    title: Text(suggestion.label),
                    subtitle: Text(suggestion.description),
                    onTap: () => onSelectMentionSuggestion(suggestion),
                  ),
              ],
            ),
    );
  }
}

class _ChatEmptyState extends StatelessWidget {
  const _ChatEmptyState({
    required this.workspaceName,
    required this.canDirectChat,
  });

  final String workspaceName;
  final bool canDirectChat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_outlined,
                size: 34,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                '开始和 $workspaceName 对话',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                canDirectChat ? '在下方输入内容后发送。' : '请先完成连接设置，再开始发送消息。',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
