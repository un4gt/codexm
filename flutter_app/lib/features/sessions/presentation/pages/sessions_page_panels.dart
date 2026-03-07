part of 'sessions_page.dart';

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.status,
    required this.workspace,
    required this.settingsReady,
    required this.compact,
  });

  final String status;
  final Workspace? workspace;
  final bool settingsReady;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: settingsReady
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  settingsReady ? Icons.chat_outlined : Icons.warning_amber_outlined,
                  color: settingsReady
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    workspace?.name ?? '尚未选择工作区',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Icon(
                      Icons.folder_off_outlined,
                      size: 36,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                SizedBox(height: tokens.compactSpacing),
                Text(
                  '请先创建并激活工作区',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  '会话依附于工作区运行。准备好工作区后，这里会自动恢复主会话与历史对话。',
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

class _SessionOverviewPanel extends StatelessWidget {
  const _SessionOverviewPanel({
    required this.workspace,
    required this.session,
    required this.legacySessionCount,
  });

  final Workspace workspace;
  final Session? session;
  final int legacySessionCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('会话概览', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _InfoTile(
              icon: Icons.folder_special_outlined,
              title: '当前工作区',
              description: workspace.name,
            ),
            _InfoTile(
              icon: Icons.chat_bubble_outline,
              title: '当前会话',
              description: session?.title ?? '主会话',
            ),
            _InfoTile(
              icon: Icons.history_outlined,
              title: '历史恢复',
              description: legacySessionCount > 0
                  ? '检测到 $legacySessionCount 个历史会话，已自动继续最近一条。'
                  : '当前工作区保持单主会话，下次进入会自动恢复历史消息。',
            ),
            _InfoTile(
              icon: Icons.hub_outlined,
              title: '线程状态',
              description: session?.codexThreadId?.trim().isNotEmpty == true
                  ? '已保存，可自动继续。'
                  : '尚未建立，首次发送时会自动创建。',
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.workspace,
    required this.selectedSession,
    required this.messages,
    required this.debugTail,
    required this.showThinking,
    required this.settingsEnabled,
    required this.hasApiKey,
    required this.running,
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
    required this.onRunReview,
    required this.onCompactThread,
    required this.onOpenSettingsRequested,
    required this.currentMode,
    required this.onModeChanged,
    required this.canSend,
    required this.canEditComposer,
  });

  final Workspace workspace;
  final Session? selectedSession;
  final List<ChatMessage> messages;
  final String debugTail;
  final bool showThinking;
  final bool settingsEnabled;
  final bool hasApiKey;
  final bool running;
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
  final VoidCallback onRunReview;
  final VoidCallback onCompactThread;
  final VoidCallback? onOpenSettingsRequested;
  final CodexCollaborationMode currentMode;
  final ValueChanged<CodexCollaborationMode> onModeChanged;
  final bool canSend;
  final bool canEditComposer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;
    final mentionToken = extractMentionToken(composerController.text);
    final showSuggestions = slashSuggestions.isNotEmpty ||
        mentionLoading ||
        mentionSuggestions.isNotEmpty ||
        mentionToken != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            selectedSession?.title ?? '主会话',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            workspace.localPath,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<CodexCollaborationMode>(
                      segments: const [
                        ButtonSegment(
                          value: CodexCollaborationMode.standard,
                          label: Text('默认'),
                        ),
                        ButtonSegment(
                          value: CodexCollaborationMode.plan,
                          label: Text('规划'),
                        ),
                      ],
                      selected: <CodexCollaborationMode>{currentMode},
                      onSelectionChanged: selectedSession == null || running
                          ? null
                          : (selection) => onModeChanged(selection.first),
                    ),
                  ],
                ),
                SizedBox(height: tokens.compactSpacing),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: running || selectedSession == null ? null : onRunReview,
                      icon: const Icon(Icons.rule_folder_outlined),
                      label: const Text('审查工作区'),
                    ),
                    OutlinedButton.icon(
                      onPressed: running ||
                              selectedSession == null ||
                              selectedSession?.codexThreadId?.trim().isEmpty == true
                          ? null
                          : onCompactThread,
                      icon: const Icon(Icons.compress_outlined),
                      label: const Text('整理上下文'),
                    ),
                  ],
                ),
                if (!settingsEnabled || !hasApiKey) ...[
                  SizedBox(height: tokens.compactSpacing),
                  _NoticeBanner(
                    icon: Icons.vpn_key_outlined,
                    title: '连接设置尚未完整',
                    description: settingsEnabled
                        ? '本地命令仍可使用；若要直接对话，请先在设置中补齐访问令牌。'
                        : '当前已暂停 Codex 运行；本地命令仍可使用。',
                    trailing: onOpenSettingsRequested == null
                        ? null
                        : TextButton(
                            onPressed: onOpenSettingsRequested,
                            child: const Text('前往设置'),
                          ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: messages.isEmpty && pendingAssistantText.trim().isEmpty
                ? _ChatEmptyState(
                    workspaceName: workspace.name,
                    showDirectChatHint: settingsEnabled && hasApiKey,
                  )
                : ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
          if (debugTail.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                title: const Text('最近运行日志'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: SelectableText(
                      debugTail,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          DecoratedBox(
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
                16,
                16,
                16,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '在这里输入消息',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    running ? 'Codex 正在回复中，请稍候。' : '支持直接提问，也支持 `/` 命令与 `@` 文件/提交标记。',
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
                  TextField(
                    controller: composerController,
                    enabled: canEditComposer,
                    minLines: 4,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    decoration: const InputDecoration(
                      labelText: '输入消息',
                      hintText: '例如：帮我检查当前工作区，或输入 /review。',
                    ),
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
                  SizedBox(height: tokens.compactSpacing),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          canEditComposer
                              ? '底部输入区始终可用；输入后点右侧“发送”即可。'
                              : '当前无法输入，请等待当前操作完成或先准备工作区。',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        onPressed: canSend ? onSendMessage : null,
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('发送'),
                      ),
                    ],
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
    required this.showDirectChatHint,
  });

  final String workspaceName;
  final bool showDirectChatHint;

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
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Icon(
                    Icons.chat_bubble_outline,
                    size: 32,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '已进入 $workspaceName',
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                showDirectChatHint
                    ? '请直接在页面底部输入消息，然后点击“发送”。也可以先用 /review 审查当前工作区。'
                    : '页面底部就是输入区。若要直接对话，请先在设置中补齐访问令牌。',
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

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    required this.icon,
    required this.title,
    required this.description,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
