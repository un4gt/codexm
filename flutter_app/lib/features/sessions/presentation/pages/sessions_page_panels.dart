part of 'sessions_page.dart';

enum _SessionAction { rename, delete }

class _WorkspaceEmptyState extends StatelessWidget {
  const _WorkspaceEmptyState({this.onOpenWorkspacesRequested});

  final VoidCallback? onOpenWorkspacesRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Icon(
                      Icons.chat_bubble_outline,
                      size: 36,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                SizedBox(height: tokens.compactSpacing),
                Text(
                  '先准备一个工作区',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '会话会围绕当前工作区展开。准备好工作区后，这里会直接显示消息列表和底部输入区。',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: tokens.sectionSpacing),
                FilledButton.icon(
                  onPressed: onOpenWorkspacesRequested,
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('前往工作区'),
                ),
              ],
            ),
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
    required this.canSend,
    required this.canEditComposer,
    this.preferSidebarSwitcher = false,
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
  final bool canSend;
  final bool canEditComposer;
  final bool preferSidebarSwitcher;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final mentionToken = extractMentionToken(composerController.text);
    final showSuggestions = slashSuggestions.isNotEmpty ||
        mentionLoading ||
        mentionSuggestions.isNotEmpty ||
        mentionToken != null;
    final widthClass = context.adaptiveWidthClass;
    final contentMaxWidth = widthClass.isExpanded ? 980.0 : double.infinity;

    return Align(
      alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: contentMaxWidth),
            child: Column(
              children: [
                _ChatHeader(
                  workspace: workspace,
                  selectedSession: selectedSession,
                  sessionCount: sessions.length,
                  status: status,
                  settingsReady: settingsEnabled && hasApiKey,
                  onOpenSessionSwitcher: onOpenSessionSwitcher,
                  onCreateSession: onCreateSession,
                  showSessionSwitcher: !preferSidebarSwitcher,
                ),
                SizedBox(height: tokens.compactSpacing),
                Expanded(
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Expanded(
                      child: messages.isEmpty && pendingAssistantText.trim().isEmpty
                          ? _ChatEmptyState(
                              workspaceName: workspace.name,
                              canDirectChat: settingsEnabled && hasApiKey,
                            )
                          : ListView(
                              controller: scrollController,
                              padding: EdgeInsets.fromLTRB(
                                widthClass.isExpanded ? 24 : 16,
                                16,
                                widthClass.isExpanded ? 24 : 16,
                                24,
                              ),
                              children: [
                                for (final message in messages)
                                  MessageBubble(
                                    role: message.role,
                                    content: message.content,
                                    createdAt: message.createdAt,
                                    showThinking: showThinking,
                                  ),
                                if (pendingAssistantText.trim().isNotEmpty)
                                  MessageBubble(
                                    role: 'assistant',
                                    content: pendingAssistantText,
                                    createdAt: pendingStartedAt,
                                    showThinking: showThinking,
                                    isStreaming: true,
                                  ),
                              ],
                            ),
                    ),
                    _ComposerPanel(
                      settingsEnabled: settingsEnabled,
                      hasApiKey: hasApiKey,
                      running: running,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.workspace,
    required this.selectedSession,
    required this.sessionCount,
    required this.status,
    required this.settingsReady,
    required this.onOpenSessionSwitcher,
    required this.onCreateSession,
    this.showSessionSwitcher = true,
  });

  final Workspace workspace;
  final Session? selectedSession;
  final int sessionCount;
  final String status;
  final bool settingsReady;
  final VoidCallback onOpenSessionSwitcher;
  final VoidCallback onCreateSession;
  final bool showSessionSwitcher;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;
    final widthClass = context.adaptiveWidthClass;
    final compact = widthClass.isCompact;
    final panelPadding = switch (widthClass) {
      AdaptiveWidthClass.compact => const EdgeInsets.all(16),
      AdaptiveWidthClass.medium => const EdgeInsets.all(20),
      AdaptiveWidthClass.expanded => const EdgeInsets.all(24),
    };
    final sectionGap = widthClass.isExpanded ? 16.0 : 12.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: panelPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedSession?.title ?? '主会话',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        workspace.name,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showSessionSwitcher)
                  IconButton.filledTonal(
                    onPressed: onOpenSessionSwitcher,
                    tooltip: '会话 $sessionCount',
                    icon: const Icon(Icons.swap_horiz_outlined),
                  ),
              ],
            ),
            SizedBox(height: sectionGap),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HeaderBadge(
                  icon: settingsReady
                      ? Icons.check_circle_outline
                      : Icons.vpn_key_outlined,
                  label: settingsReady ? '可直接发送消息' : '发送前需完成连接设置',
                  emphasized: settingsReady,
                ),
                _HeaderBadge(
                  icon: Icons.folder_open_outlined,
                  label: workspace.localPath,
                ),
              ],
            ),
            SizedBox(height: sectionGap),
            Text(
              status,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: sectionGap),
            Align(
              alignment: compact ? Alignment.centerRight : Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: onCreateSession,
                icon: const Icon(Icons.add_comment_outlined),
                label: const Text('新建会话'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  const _HeaderBadge({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: emphasized
            ? colorScheme.primary.withValues(alpha: 0.16)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: colorScheme.primary),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerPanel extends StatelessWidget {
  const _ComposerPanel({
    required this.settingsEnabled,
    required this.hasApiKey,
    required this.running,
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
    final tokens = context.appTokens;
    final widthClass = context.adaptiveWidthClass;
    final compact = widthClass.isCompact;
    final horizontalPadding = switch (widthClass) {
      AdaptiveWidthClass.compact => 16.0,
      AdaptiveWidthClass.medium => 20.0,
      AdaptiveWidthClass.expanded => 24.0,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          14,
          horizontalPadding,
          14 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!settingsEnabled || !hasApiKey)
              _InlineNotice(
                icon: Icons.vpn_key_outlined,
                text: settingsEnabled
                    ? '还未完成连接设置，本地命令仍可使用；直接对话前请先补齐访问令牌。'
                    : '当前已暂停运行能力，暂时只能使用本地命令。',
              ),
            if (!settingsEnabled || !hasApiKey)
              SizedBox(height: tokens.compactSpacing),
            Text(
              '直接输入消息',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              running ? '正在回复中，请稍候。' : '消息输入区固定在底部，支持 `/` 命令与 `@` 文件/提交标记。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (pendingMentions.isNotEmpty) ...[
              SizedBox(height: tokens.compactSpacing),
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
            ],
            SizedBox(height: tokens.compactSpacing),
            compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextField(
                        controller: composerController,
                        enabled: canEditComposer,
                        minLines: 3,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: '输入消息，或输入 /review、@文件名 ...',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton(
                          onPressed: canSend ? onSendMessage : null,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(56, 56),
                            shape: const CircleBorder(),
                            padding: EdgeInsets.zero,
                          ),
                          child: const Icon(Icons.arrow_upward_rounded),
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: composerController,
                          enabled: canEditComposer,
                          minLines: 3,
                          maxLines: 6,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText: '输入消息，或输入 /review、@文件名 ...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: canSend ? onSendMessage : null,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(56, 56),
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                        ),
                        child: const Icon(Icons.arrow_upward_rounded),
                      ),
                    ],
                  ),
            if (showSuggestions) ...[
              SizedBox(height: tokens.compactSpacing),
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
  const _InlineNotice({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
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

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: slashSuggestions.isNotEmpty
          ? Column(
              children: [
                for (final suggestion in slashSuggestions.take(8))
                  ListTile(
                    leading: const Icon(Icons.code_outlined),
                    title: Text(suggestion.command),
                    subtitle: Text(suggestion.purpose),
                    onTap: () => onSelectSlashSuggestion(suggestion),
                  ),
              ],
            )
          : mentionLoading
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('正在查找文件与提交...'),
                ],
              ),
            )
          : mentionSuggestions.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: Text('没有匹配的文件或提交。'),
            )
          : Column(
              children: [
                for (final suggestion in mentionSuggestions)
                  ListTile(
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
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Icon(
                    Icons.forum_outlined,
                    size: 36,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '开始和 $workspaceName 对话',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                canDirectChat
                    ? '页面底部就是输入区。输入你的第一条消息后，发送按钮会立即可用。'
                    : '页面底部就是输入区。补齐连接设置后，即可直接发送消息。',
                style: theme.textTheme.bodyLarge?.copyWith(
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
