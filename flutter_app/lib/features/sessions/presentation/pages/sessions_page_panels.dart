part of 'sessions_page.dart';

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.status,
    required this.workspace,
    required this.settingsReady,
  });

  final String status;
  final Workspace? workspace;
  final bool settingsReady;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Card(
        child: ListTile(
          leading: Icon(
            settingsReady ? Icons.chat_outlined : Icons.warning_amber_outlined,
          ),
          title: Text(workspace?.name ?? '尚未选择工作区'),
          subtitle: Text(status),
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.folder_off_outlined, size: 36),
                const SizedBox(height: 12),
                Text(
                  '请先创建并激活工作区',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                const Text('会话依附于工作区运行；准备好工作区后，这里会自动恢复主会话与历史对话。'),
                const SizedBox(height: 16),
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
            Text('单会话概览', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.folder_special_outlined),
              title: Text(workspace.name),
              subtitle: Text(
                session?.title ?? '主会话',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_outlined),
              title: const Text('历史恢复'),
              subtitle: Text(
                legacySessionCount > 0
                    ? '检测到 $legacySessionCount 个历史会话，已自动继续最近一条。'
                    : '当前工作区只有一个主会话；下次进入会自动恢复历史消息。',
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.hub_outlined),
              title: const Text('线程状态'),
              subtitle: Text(
                session?.codexThreadId?.trim().isNotEmpty == true
                    ? '已保存，可自动 resume'
                    : '尚未建立，下次发送会自动创建',
              ),
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
    final mentionToken = extractMentionToken(composerController.text);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        workspace.localPath,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
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
            const SizedBox(height: 12),
            if (!settingsEnabled || !hasApiKey)
              Card(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.6),
                child: ListTile(
                  leading: const Icon(Icons.vpn_key_outlined),
                  title: const Text('连接设置尚未完整'),
                  subtitle: Text(
                    settingsEnabled
                        ? '本地 slash 命令仍可使用；若要直接对话，请先在设置中补齐访问令牌。'
                        : '当前已暂停 Codex 运行；本地 slash 命令仍可使用。',
                  ),
                  trailing: TextButton(
                    onPressed: onOpenSettingsRequested,
                    child: const Text('前往设置'),
                  ),
                ),
              ),
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
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: messages.isEmpty && pendingAssistantText.isEmpty
                    ? const Center(
                        child: Text('开始一轮新对话，Codex 的回复会在这里实时展开。'),
                      )
                    : Scrollbar(
                        controller: scrollController,
                        child: ListView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
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
                                isStreaming: running,
                              ),
                          ],
                        ),
                      ),
              ),
            ),
            if (debugTail.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              ExpansionTile(
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
            ],
            if (pendingMentions.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final mention in pendingMentions)
                    InputChip(
                      label: Text(
                        mention.kind == ComposerMentionKind.file
                            ? '@${mention.label}'
                            : '@${mention.label}',
                      ),
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
            const SizedBox(height: 12),
            TextField(
              controller: composerController,
              enabled: canEditComposer,
              minLines: 3,
              maxLines: 6,
              textInputAction: TextInputAction.newline,
              decoration: const InputDecoration(
                labelText: '输入消息',
                hintText: '可直接对话，或输入 / 命令、@ 文件/提交标记。',
              ),
            ),
            if (slashSuggestions.isNotEmpty ||
                mentionLoading ||
                mentionSuggestions.isNotEmpty ||
                mentionToken != null) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: slashSuggestions.isNotEmpty
                    ? Column(
                        children: [
                          for (final suggestion
                              in slashSuggestions.take(8))
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
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    running
                        ? 'Codex 正在回复中...'
                        : '支持单会话历史恢复、slash 命令与 @ 文件/提交标记。',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
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
    );
  }
}
