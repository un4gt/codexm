part of 'sessions_page.dart';

class _SessionsExpandedLayout extends StatelessWidget {
  const _SessionsExpandedLayout({
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
    required this.onSelectSession,
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
  final ValueChanged<Session> onSelectSession;
  final ValueChanged<Session> onRenameSession;
  final ValueChanged<Session> onDeleteSession;
  final bool canSend;
  final bool canEditComposer;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 360,
          child: _SessionsSidebar(
            workspaceName: workspace.name,
            sessions: sessions,
            selectedSession: selectedSession,
            settingsReady: settingsEnabled && hasApiKey,
            status: status,
            onCreateSession: onCreateSession,
            onSelectSession: onSelectSession,
            onRenameSession: onRenameSession,
            onDeleteSession: onDeleteSession,
          ),
        ),
        const SizedBox(width: 18),
        Expanded(
          child: _ChatPanel(
            workspace: workspace,
            sessions: sessions,
            selectedSession: selectedSession,
            messages: messages,
            showThinking: showThinking,
            settingsEnabled: settingsEnabled,
            hasApiKey: hasApiKey,
            running: running,
            status: status,
            pendingAssistantText: pendingAssistantText,
            pendingStartedAt: pendingStartedAt,
            scrollController: scrollController,
            composerController: composerController,
            pendingMentions: pendingMentions,
            slashSuggestions: slashSuggestions,
            mentionSuggestions: mentionSuggestions,
            mentionLoading: mentionLoading,
            onSelectSlashSuggestion: onSelectSlashSuggestion,
            onSelectMentionSuggestion: onSelectMentionSuggestion,
            onRemovePendingMention: onRemovePendingMention,
            onSendMessage: onSendMessage,
            onOpenSessionSwitcher: onOpenSessionSwitcher,
            onCreateSession: onCreateSession,
            canSend: canSend,
            canEditComposer: canEditComposer,
            preferSidebarSwitcher: true,
          ),
        ),
      ],
    );
  }
}

class _SessionsSidebar extends StatelessWidget {
  const _SessionsSidebar({
    required this.workspaceName,
    required this.sessions,
    required this.selectedSession,
    required this.settingsReady,
    required this.status,
    required this.onCreateSession,
    required this.onSelectSession,
    required this.onRenameSession,
    required this.onDeleteSession,
  });

  final String workspaceName;
  final List<Session> sessions;
  final Session? selectedSession;
  final bool settingsReady;
  final String status;
  final VoidCallback onCreateSession;
  final ValueChanged<Session> onSelectSession;
  final ValueChanged<Session> onRenameSession;
  final ValueChanged<Session> onDeleteSession;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tokens = context.appTokens;

    final sessionRows = [
      for (var index = 0; index < sessions.length; index++)
        _SessionListRow(
          session: sessions[index],
          selected: sessions[index].id == selectedSession?.id,
          isFirst: index == 0,
          isLast: index == sessions.length - 1,
          onSelect: onSelectSession,
          onRename: onRenameSession,
          onDelete: onDeleteSession,
        ),
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.85),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '会话',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        workspaceName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: onCreateSession,
                  icon: const Icon(Icons.add_comment_outlined),
                  label: const Text('新建'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                StitchPill(
                  icon: settingsReady
                      ? Icons.check_circle_outline
                      : Icons.vpn_key_outlined,
                  label: settingsReady ? '可直接发送消息' : '发送前需完成连接设置',
                  emphasized: settingsReady,
                ),
                StitchPill(
                  icon: Icons.chat_bubble_outline,
                  label: '${sessions.length} 个会话',
                ),
              ],
            ),
          ),
          Divider(height: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              children: [
                StitchInfoBanner(
                  icon: Icons.info_outline,
                  title: status,
                ),
                const SizedBox(height: 16),
                StitchSectionHeader(title: '最近会话'),
                const SizedBox(height: 10),
                ...sessionRows,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionListRow extends StatelessWidget {
  const _SessionListRow({
    required this.session,
    required this.selected,
    required this.isFirst,
    required this.isLast,
    required this.onSelect,
    required this.onRename,
    required this.onDelete,
  });

  final Session session;
  final bool selected;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<Session> onSelect;
  final ValueChanged<Session> onRename;
  final ValueChanged<Session> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final borderRadius = BorderRadius.vertical(
      top: isFirst ? const Radius.circular(18) : Radius.zero,
      bottom: isLast ? const Radius.circular(18) : Radius.zero,
    );

    final backgroundColor = selected
        ? colorScheme.primary.withValues(alpha: 0.08)
        : colorScheme.surface;

    final titleColor = selected ? colorScheme.onSurface : colorScheme.onSurface;
    final subtitleColor = colorScheme.onSurfaceVariant;
    final statusColor = _sessionStatusColor(colorScheme, session);

    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: selected
              ? colorScheme.primary.withValues(alpha: 0.25)
              : colorScheme.outlineVariant.withValues(alpha: 0.85),
        ),
      ),
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () => onSelect(session),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _SessionAvatar(connected: session.codexThreadId != null),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            session.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: titleColor,
                            ),
                          ),
                        ),
                        PopupMenuButton<_SessionListRowAction>(
                          tooltip: '会话操作',
                          onSelected: (action) {
                            switch (action) {
                              case _SessionListRowAction.rename:
                                onRename(session);
                              case _SessionListRowAction.delete:
                                onDelete(session);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(
                              value: _SessionListRowAction.rename,
                              child: Text('重命名'),
                            ),
                            PopupMenuItem(
                              value: _SessionListRowAction.delete,
                              child: Text('删除'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.codexThreadId?.trim().isNotEmpty == true
                          ? '继续已有对话'
                          : '尚未开始发送消息',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: subtitleColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: statusColor,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _sessionStatusText(session),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

  Color _sessionStatusColor(ColorScheme scheme, Session session) {
    if (_isSessionConnected(session)) {
      return scheme.primary;
    }
    return scheme.onSurfaceVariant;
  }

  String _sessionStatusText(Session session) {
    if (_isSessionConnected(session)) {
      return '已连接';
    }
    return '未开始';
  }

  bool _isSessionConnected(Session session) {
    final threadId = session.codexThreadId?.trim();
    return threadId != null && threadId.isNotEmpty;
  }
}

enum _SessionListRowAction { rename, delete }

class _SessionAvatar extends StatelessWidget {
  const _SessionAvatar({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final backgroundColor = connected
        ? colorScheme.primary.withValues(alpha: 0.12)
        : colorScheme.surfaceContainerHigh.withValues(alpha: 0.6);

    final iconColor =
        connected ? colorScheme.primary : colorScheme.onSurfaceVariant;

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: connected
              ? colorScheme.primary.withValues(alpha: 0.25)
              : colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
      ),
      child: Icon(Icons.chat_bubble_outline, color: iconColor),
    );
  }
}
