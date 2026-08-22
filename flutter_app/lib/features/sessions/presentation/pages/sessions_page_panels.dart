part of 'sessions_page.dart';

enum _SessionAction {
  changes,
  checkpoint,
  merge,
  createFrom,
  rename,
  archive,
  delete,
}

enum _HeaderMenuAction {
  newSession,
  switchSession,
  editModel,
  connectionSettings,
  renameSession,
  deleteSession,
  changes,
  checkpoint,
  merge,
  createFrom,
  archive,
}

String _sessionCodeStatusLabel(Session session) => switch (session.codeState) {
  SessionCodeState.provisioning => '正在准备代码副本',
  SessionCodeState.ready => '代码副本已准备',
  SessionCodeState.conflict => '存在合并冲突',
  SessionCodeState.archived => '已归档',
  SessionCodeState.migrationRequired => '等待迁移',
  SessionCodeState.failed => '代码副本需要修复',
};

class _ChatSearchMatch {
  const _ChatSearchMatch({required this.messageIndex});

  final int messageIndex;
}

class _SessionUiSpecs {
  const _SessionUiSpecs._();

  static const double maxContentWidth = 920;
  static const double compactHorizontalPadding = 12;
  static const double mediumHorizontalPadding = 16;
  static const double expandedHorizontalPadding = 20;
  static const double minTapTarget = 48;
  static const double estimatedMessageExtent = 148;
}

class _WorkspaceEmptyState extends StatelessWidget {
  const _WorkspaceEmptyState({this.onOpenWorkspacesRequested});

  final VoidCallback? onOpenWorkspacesRequested;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      icon: Icons.chat_bubble_outline,
      title: '先准备一个工作区',
      message: '会话围绕当前工作区展开。准备好后即可创建会话并开始发送消息。',
      action: FilledButton.icon(
        onPressed: onOpenWorkspacesRequested,
        icon: const Icon(Icons.folder_open_outlined),
        label: const Text('前往工作区'),
      ),
    );
  }
}

class _WorkspaceMigrationPanel extends StatelessWidget {
  const _WorkspaceMigrationPanel({
    required this.workspace,
    required this.migration,
    required this.busy,
    required this.onContinue,
    required this.onBack,
  });

  final Workspace workspace;
  final SessionCodeMigrationRequiredException migration;
  final bool busy;
  final VoidCallback onContinue;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final changedCount =
        migration.status.staged.length +
        migration.status.unstaged.length +
        migration.status.untracked.length +
        migration.status.conflicted.length;
    return AppPageScaffold(
      title: workspace.name,
      leading: IconButton(
        tooltip: '返回工作区',
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back),
      ),
      body: ListView(
        children: [
          AppStatusNotice(
            message: '检测到 $changedCount 个尚未保存的文件。先保存当前代码基线，才能为每个会话创建独立副本。',
            tone: AppNoticeTone.warning,
          ),
          AppListSection(
            title: '迁移内容',
            children: [
              AppListTile(
                title: '保存当前代码状态',
                subtitle: '现有会话记录和 Codex 上下文都会保留。',
                leading: const Icon(Icons.save_outlined),
              ),
              AppListTile(
                title: '创建独立会话副本',
                subtitle: '之后各会话的文件改动互不覆盖，并可选择合并。',
                leading: const Icon(Icons.call_split_outlined),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: FilledButton.icon(
              onPressed: busy ? null : onContinue,
              icon: busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.arrow_forward),
              label: const Text('查看改动并继续'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionsOverview extends StatelessWidget {
  const _SessionsOverview({
    required this.workspace,
    required this.sessions,
    required this.selectedSessionId,
    required this.runningSessionId,
    required this.busy,
    required this.onOpenWorkspaces,
    required this.onOpenSession,
    required this.onCreateSession,
    required this.onRenameSession,
    required this.onDeleteSession,
    required this.onShowChanges,
    required this.onCheckpoint,
    required this.onMerge,
    required this.onCreateFrom,
    required this.onArchive,
    required this.onContinueMainMerge,
    required this.onAbortMainMerge,
  });

  final Workspace? workspace;
  final List<Session> sessions;
  final SessionId? selectedSessionId;
  final SessionId? runningSessionId;
  final bool busy;
  final VoidCallback? onOpenWorkspaces;
  final ValueChanged<Session> onOpenSession;
  final VoidCallback onCreateSession;
  final ValueChanged<Session> onRenameSession;
  final ValueChanged<Session> onDeleteSession;
  final ValueChanged<Session> onShowChanges;
  final ValueChanged<Session> onCheckpoint;
  final ValueChanged<Session> onMerge;
  final ValueChanged<Session> onCreateFrom;
  final ValueChanged<Session> onArchive;
  final VoidCallback onContinueMainMerge;
  final VoidCallback onAbortMainMerge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Material(
          color: theme.colorScheme.surface,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.only(left: 16, right: 8),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('会话', style: theme.textTheme.titleLarge),
                      if (workspace != null)
                        Text(
                          workspace!.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '切换工作区',
                  onPressed: onOpenWorkspaces,
                  icon: const Icon(Icons.folder_open_outlined),
                ),
                IconButton(
                  tooltip: '新建会话',
                  onPressed: workspace == null || busy ? null : onCreateSession,
                  icon: const Icon(Icons.add_comment_outlined),
                ),
              ],
            ),
          ),
        ),
        if (workspace?.pendingMergeSourceSessionId != null) ...[
          AppStatusNotice(
            message: '主工作区存在合并冲突。处理冲突后完成合并，或放弃本次合并。',
            tone: AppNoticeTone.warning,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: busy ? null : onAbortMainMerge,
                    child: const Text('放弃合并'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: busy ? null : onContinueMainMerge,
                    child: const Text('完成合并'),
                  ),
                ),
              ],
            ),
          ),
        ],
        Expanded(
          child: workspace == null
              ? _WorkspaceEmptyState(
                  onOpenWorkspacesRequested: onOpenWorkspaces,
                )
              : sessions.isEmpty
              ? AppEmptyState(
                  icon: Icons.forum_outlined,
                  title: '还没有会话',
                  message: '创建一个会话，开始处理当前工作区中的任务。',
                  action: FilledButton.icon(
                    onPressed: busy ? null : onCreateSession,
                    icon: const Icon(Icons.add),
                    label: const Text('新建会话'),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: sessions.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    indent: 72,
                    color: theme.colorScheme.outlineVariant.withValues(
                      alpha: 0.65,
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final session = sessions[index];
                    final running = session.id == runningSessionId;
                    return AppListTile(
                      title: session.title,
                      subtitle: running
                          ? '正在生成回复...'
                          : '${_sessionCodeStatusLabel(session)} · ${_formatUpdatedAt(session.updatedAt)}',
                      selected: session.id == selectedSessionId,
                      enabled: !busy,
                      leading: running
                          ? const SizedBox.square(
                              dimension: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chat_bubble_outline),
                      trailing: PopupMenuButton<_SessionAction>(
                        tooltip: '会话操作',
                        enabled: !busy && runningSessionId == null,
                        onSelected: (action) {
                          switch (action) {
                            case _SessionAction.changes:
                              onShowChanges(session);
                            case _SessionAction.checkpoint:
                              onCheckpoint(session);
                            case _SessionAction.merge:
                              onMerge(session);
                            case _SessionAction.createFrom:
                              onCreateFrom(session);
                            case _SessionAction.rename:
                              onRenameSession(session);
                            case _SessionAction.archive:
                              onArchive(session);
                            case _SessionAction.delete:
                              onDeleteSession(session);
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _SessionAction.changes,
                            child: Text('查看代码改动'),
                          ),
                          PopupMenuItem(
                            value: _SessionAction.checkpoint,
                            child: Text('保存代码检查点'),
                          ),
                          PopupMenuItem(
                            value: _SessionAction.merge,
                            child: Text('合并到...'),
                          ),
                          PopupMenuItem(
                            value: _SessionAction.createFrom,
                            child: Text('基于此会话新建'),
                          ),
                          PopupMenuItem(
                            value: _SessionAction.rename,
                            child: Text('重命名'),
                          ),
                          PopupMenuItem(
                            value: _SessionAction.archive,
                            child: Text('归档'),
                          ),
                          PopupMenuItem(
                            value: _SessionAction.delete,
                            child: Text('删除'),
                          ),
                        ],
                      ),
                      onTap: () => onOpenSession(session),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _formatUpdatedAt(int millis) {
    if (millis <= 0) {
      return '尚未开始';
    }
    final value = DateTime.fromMillisecondsSinceEpoch(millis);
    final now = DateTime.now();
    final difference = now.difference(value);
    if (difference.inMinutes < 1) {
      return '刚刚更新';
    }
    if (difference.inHours < 1) {
      return '${difference.inMinutes} 分钟前';
    }
    if (difference.inDays < 1) {
      return '${difference.inHours} 小时前';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} 天前';
    }
    return '${value.month} 月 ${value.day} 日';
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.workspace,
    required this.sessions,
    required this.selectedSession,
    required this.messages,
    required this.showThinking,
    required this.settings,
    required this.chatSearchVisible,
    required this.chatSearchController,
    required this.chatSearchMatches,
    required this.activeChatSearchMatch,
    required this.settingsEnabled,
    required this.hasApiKey,
    required this.running,
    required this.status,
    required this.runtimeStatus,
    required this.runtimeStatusIsRetrying,
    required this.pendingAssistantText,
    required this.pendingAssistantParts,
    required this.pendingStartedAt,
    required this.scrollController,
    required this.showScrollToBottom,
    required this.onScrollToBottom,
    required this.composerController,
    required this.pendingMentions,
    required this.slashSuggestions,
    required this.mentionSuggestions,
    required this.mentionLoading,
    required this.onSelectSlashSuggestion,
    required this.onSelectMentionSuggestion,
    required this.onRemovePendingMention,
    required this.onSendMessage,
    required this.onStopMessage,
    required this.onOpenSessionSwitcher,
    required this.onCreateSession,
    required this.onRenameSession,
    required this.onDeleteSession,
    required this.onShowChanges,
    required this.onCheckpoint,
    required this.onMerge,
    required this.onCreateFrom,
    required this.onArchive,
    required this.onContinueMerge,
    required this.onAbortMerge,
    required this.canSend,
    required this.canEditComposer,
    required this.onToggleChatSearch,
    required this.onChatSearchChanged,
    required this.onMoveChatSearchMatch,
    required this.onOpenSettingsRequested,
    required this.onEditModelRequested,
    required this.onBack,
  });

  final Workspace workspace;
  final List<Session> sessions;
  final Session? selectedSession;
  final List<ChatMessage> messages;
  final bool showThinking;
  final CodexSettings settings;
  final bool chatSearchVisible;
  final TextEditingController chatSearchController;
  final List<_ChatSearchMatch> chatSearchMatches;
  final int activeChatSearchMatch;
  final bool settingsEnabled;
  final bool hasApiKey;
  final bool running;
  final String status;
  final String? runtimeStatus;
  final bool runtimeStatusIsRetrying;
  final String pendingAssistantText;
  final List<ChatMessagePart> pendingAssistantParts;
  final int pendingStartedAt;
  final ScrollController scrollController;
  final bool showScrollToBottom;
  final VoidCallback onScrollToBottom;
  final TextEditingController composerController;
  final List<ComposerPendingMention> pendingMentions;
  final List<CodexSlashCommand> slashSuggestions;
  final List<ComposerMentionSuggestion> mentionSuggestions;
  final bool mentionLoading;
  final ValueChanged<CodexSlashCommand> onSelectSlashSuggestion;
  final ValueChanged<ComposerMentionSuggestion> onSelectMentionSuggestion;
  final ValueChanged<ComposerPendingMention> onRemovePendingMention;
  final VoidCallback onSendMessage;
  final VoidCallback onStopMessage;
  final VoidCallback onOpenSessionSwitcher;
  final VoidCallback onCreateSession;
  final ValueChanged<Session> onRenameSession;
  final ValueChanged<Session> onDeleteSession;
  final ValueChanged<Session> onShowChanges;
  final ValueChanged<Session> onCheckpoint;
  final ValueChanged<Session> onMerge;
  final ValueChanged<Session> onCreateFrom;
  final ValueChanged<Session> onArchive;
  final ValueChanged<Session> onContinueMerge;
  final ValueChanged<Session> onAbortMerge;
  final bool canSend;
  final bool canEditComposer;
  final VoidCallback onToggleChatSearch;
  final ValueChanged<String> onChatSearchChanged;
  final ValueChanged<int> onMoveChatSearchMatch;
  final VoidCallback? onOpenSettingsRequested;
  final VoidCallback onEditModelRequested;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final showSuggestions =
        findComposerTrigger(composerController.value) != null;

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
              settings: settings,
              chatSearchVisible: chatSearchVisible,
              chatSearchController: chatSearchController,
              chatSearchMatches: chatSearchMatches,
              activeChatSearchMatch: activeChatSearchMatch,
              onOpenSessionSwitcher: onOpenSessionSwitcher,
              onToggleChatSearch: onToggleChatSearch,
              onChatSearchChanged: onChatSearchChanged,
              onMoveChatSearchMatch: onMoveChatSearchMatch,
              onOpenSettingsRequested: onOpenSettingsRequested,
              onEditModelRequested: onEditModelRequested,
              onBack: onBack,
              onMenuAction: (action) {
                switch (action) {
                  case _HeaderMenuAction.newSession:
                    onCreateSession();
                    break;
                  case _HeaderMenuAction.switchSession:
                    onOpenSessionSwitcher();
                    break;
                  case _HeaderMenuAction.editModel:
                    onEditModelRequested();
                    break;
                  case _HeaderMenuAction.connectionSettings:
                    onOpenSettingsRequested?.call();
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
                  case _HeaderMenuAction.changes:
                    final session = selectedSession;
                    if (session != null) onShowChanges(session);
                    break;
                  case _HeaderMenuAction.checkpoint:
                    final session = selectedSession;
                    if (session != null) onCheckpoint(session);
                    break;
                  case _HeaderMenuAction.merge:
                    final session = selectedSession;
                    if (session != null) onMerge(session);
                    break;
                  case _HeaderMenuAction.createFrom:
                    final session = selectedSession;
                    if (session != null) onCreateFrom(session);
                    break;
                  case _HeaderMenuAction.archive:
                    final session = selectedSession;
                    if (session != null) onArchive(session);
                    break;
                }
              },
            ),
            if (selectedSession?.codeState == SessionCodeState.conflict)
              AppStatusNotice(
                message: '当前会话存在合并冲突。处理冲突文件后完成合并，或放弃本次合并。',
                tone: AppNoticeTone.warning,
                onTap: () => onContinueMerge(selectedSession!),
              ),
            if (selectedSession?.codeState == SessionCodeState.conflict)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onAbortMerge(selectedSession!),
                        child: const Text('放弃合并'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onContinueMerge(selectedSession!),
                        child: const Text('完成合并'),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: _MessageList(
                      messages: messages,
                      showThinking: showThinking,
                      pendingAssistantText: pendingAssistantText,
                      pendingAssistantParts: pendingAssistantParts,
                      pendingStartedAt: pendingStartedAt,
                      scrollController: scrollController,
                      workspaceName: workspace.name,
                      canDirectChat: settingsEnabled && hasApiKey,
                    ),
                  ),
                  if (showScrollToBottom)
                    Positioned(
                      right: 16,
                      bottom: 12,
                      child: IconButton.filledTonal(
                        key: const ValueKey('scroll-to-bottom-button'),
                        onPressed: onScrollToBottom,
                        tooltip: '回到最新消息',
                        icon: const Icon(Icons.arrow_downward_rounded),
                      ),
                    ),
                ],
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
              onStopMessage: onStopMessage,
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
    required this.settings,
    required this.chatSearchVisible,
    required this.chatSearchController,
    required this.chatSearchMatches,
    required this.activeChatSearchMatch,
    required this.onOpenSessionSwitcher,
    required this.onToggleChatSearch,
    required this.onChatSearchChanged,
    required this.onMoveChatSearchMatch,
    required this.onOpenSettingsRequested,
    required this.onEditModelRequested,
    required this.onBack,
    required this.onMenuAction,
  });

  final Workspace workspace;
  final Session? selectedSession;
  final int sessionCount;
  final String status;
  final bool settingsReady;
  final CodexSettings settings;
  final bool chatSearchVisible;
  final TextEditingController chatSearchController;
  final List<_ChatSearchMatch> chatSearchMatches;
  final int activeChatSearchMatch;
  final VoidCallback onOpenSessionSwitcher;
  final VoidCallback onToggleChatSearch;
  final ValueChanged<String> onChatSearchChanged;
  final ValueChanged<int> onMoveChatSearchMatch;
  final VoidCallback? onOpenSettingsRequested;
  final VoidCallback onEditModelRequested;
  final VoidCallback? onBack;
  final ValueChanged<_HeaderMenuAction> onMenuAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final modelLabel = settings.model?.trim().isNotEmpty == true
        ? settings.model!.trim()
        : '默认模型';
    final searchCount = chatSearchMatches.length;
    final activeSearchLabel = searchCount == 0
        ? '0/0'
        : '${activeChatSearchMatch + 1}/$searchCount';

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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: chatSearchVisible
            ? Row(
                children: [
                  IconButton(
                    tooltip: '关闭搜索',
                    onPressed: onToggleChatSearch,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  Expanded(
                    child: TextField(
                      controller: chatSearchController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: '搜索当前会话',
                        isDense: true,
                        border: InputBorder.none,
                        filled: false,
                      ),
                      onChanged: onChatSearchChanged,
                    ),
                  ),
                  Text(activeSearchLabel, style: theme.textTheme.labelMedium),
                  IconButton(
                    tooltip: '上一个匹配',
                    onPressed: searchCount == 0
                        ? null
                        : () => onMoveChatSearchMatch(-1),
                    icon: const Icon(Icons.keyboard_arrow_up),
                  ),
                  IconButton(
                    tooltip: '下一个匹配',
                    onPressed: searchCount == 0
                        ? null
                        : () => onMoveChatSearchMatch(1),
                    icon: const Icon(Icons.keyboard_arrow_down),
                  ),
                ],
              )
            : Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      tooltip: '返回会话列表',
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedSession?.title ?? '主会话',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium,
                        ),
                        Row(
                          children: [
                            Semantics(
                              label: settingsReady ? '已连接' : '未连接',
                              child: Icon(
                                settingsReady
                                    ? Icons.circle
                                    : Icons.circle_outlined,
                                size: 9,
                                color: settingsReady
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 6),
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
                  IconButton(
                    tooltip: '搜索当前会话',
                    onPressed: onToggleChatSearch,
                    icon: const Icon(Icons.search_outlined),
                  ),
                  PopupMenuButton<_HeaderMenuAction>(
                    tooltip: '更多会话操作',
                    onSelected: onMenuAction,
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: _HeaderMenuAction.newSession,
                        child: Text('新建会话'),
                      ),
                      PopupMenuItem(
                        value: _HeaderMenuAction.switchSession,
                        child: Text('切换会话（$sessionCount）'),
                      ),
                      PopupMenuItem(
                        value: _HeaderMenuAction.editModel,
                        child: Text('模型：$modelLabel'),
                      ),
                      const PopupMenuItem(
                        value: _HeaderMenuAction.connectionSettings,
                        child: Text('连接设置'),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: _HeaderMenuAction.changes,
                        enabled: selectedSession != null,
                        child: const Text('查看代码改动'),
                      ),
                      PopupMenuItem(
                        value: _HeaderMenuAction.checkpoint,
                        enabled: selectedSession != null,
                        child: const Text('保存代码检查点'),
                      ),
                      PopupMenuItem(
                        value: _HeaderMenuAction.merge,
                        enabled: selectedSession != null,
                        child: const Text('合并到...'),
                      ),
                      PopupMenuItem(
                        value: _HeaderMenuAction.createFrom,
                        enabled: selectedSession != null,
                        child: const Text('基于此会话新建'),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem(
                        value: _HeaderMenuAction.renameSession,
                        enabled: selectedSession != null,
                        child: const Text('重命名当前会话'),
                      ),
                      PopupMenuItem(
                        value: _HeaderMenuAction.archive,
                        enabled: selectedSession != null,
                        child: const Text('归档当前会话'),
                      ),
                      PopupMenuItem(
                        value: _HeaderMenuAction.deleteSession,
                        enabled: selectedSession != null,
                        child: const Text('删除当前会话'),
                      ),
                    ],
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
    required this.pendingAssistantParts,
    required this.pendingStartedAt,
    required this.scrollController,
    required this.workspaceName,
    required this.canDirectChat,
  });

  final List<ChatMessage> messages;
  final bool showThinking;
  final String pendingAssistantText;
  final List<ChatMessagePart> pendingAssistantParts;
  final int pendingStartedAt;
  final ScrollController scrollController;
  final String workspaceName;
  final bool canDirectChat;

  @override
  Widget build(BuildContext context) {
    final hasStreaming =
        pendingAssistantText.trim().isNotEmpty ||
        pendingAssistantParts.isNotEmpty;

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
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: totalCount,
        itemBuilder: (context, index) {
          if (index < messages.length) {
            final message = messages[index];
            return MessageBubble(
              role: message.role,
              content: message.content,
              createdAt: message.createdAt,
              showThinking: showThinking,
              parts: message.parts,
            );
          }
          return MessageBubble(
            role: 'assistant',
            content: pendingAssistantText,
            createdAt: pendingStartedAt,
            showThinking: showThinking,
            parts: pendingAssistantParts,
          );
        },
      ),
    );
  }
}

class _SessionInputBar extends StatefulWidget {
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
    required this.onStopMessage,
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
  final VoidCallback onStopMessage;
  final bool canSend;
  final bool canEditComposer;
  final bool showSuggestions;

  @override
  State<_SessionInputBar> createState() => _SessionInputBarState();
}

class _SessionInputBarState extends State<_SessionInputBar> {
  final _layerLink = LayerLink();
  final _anchorKey = GlobalKey();
  final _overlayController = OverlayPortalController();
  final _focusNode = FocusNode();
  final _suggestionsScrollController = ScrollController();
  final _tapRegionGroup = Object();

  double _anchorWidth = 0;
  double _maxOverlayHeight = 320;
  bool _temporarilyDismissed = false;
  String _lastText = '';
  int _highlightedSuggestion = 0;

  @override
  void initState() {
    super.initState();
    _lastText = widget.composerController.text;
    _scheduleOverlaySync();
  }

  @override
  void didUpdateWidget(covariant _SessionInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final text = widget.composerController.text;
    if (text != _lastText) {
      _lastText = text;
      _temporarilyDismissed = false;
      _highlightedSuggestion = 0;
    }
    _scheduleOverlaySync();
  }

  @override
  void dispose() {
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
    _focusNode.dispose();
    _suggestionsScrollController.dispose();
    super.dispose();
  }

  void _scheduleOverlaySync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _updateOverlayGeometry();
      final shouldShow = widget.showSuggestions && !_temporarilyDismissed;
      if (shouldShow && !_overlayController.isShowing) {
        _overlayController.show();
      } else if (!shouldShow && _overlayController.isShowing) {
        _overlayController.hide();
      }
    });
  }

  void _updateOverlayGeometry() {
    final renderObject = _anchorKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      return;
    }
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final safeTop = MediaQuery.paddingOf(context).top;
    final availableAbove = (top - safeTop - 16).clamp(48.0, 320.0);
    final width = renderObject.size.width;
    if ((width - _anchorWidth).abs() < 0.5 &&
        (availableAbove - _maxOverlayHeight).abs() < 0.5) {
      return;
    }
    setState(() {
      _anchorWidth = width;
      _maxOverlayHeight = availableAbove;
    });
  }

  void _dismissSuggestions() {
    _temporarilyDismissed = true;
    if (_overlayController.isShowing) {
      _overlayController.hide();
    }
  }

  void _selectSlashSuggestion(CodexSlashCommand suggestion) {
    widget.onSelectSlashSuggestion(suggestion);
    _focusNode.requestFocus();
  }

  void _selectMentionSuggestion(ComposerMentionSuggestion suggestion) {
    widget.onSelectMentionSuggestion(suggestion);
    _focusNode.requestFocus();
  }

  int get _suggestionCount {
    final trigger = findComposerTrigger(widget.composerController.value);
    return switch (trigger?.kind) {
      ComposerTriggerKind.slash => widget.slashSuggestions.length,
      ComposerTriggerKind.mention => widget.mentionSuggestions.length,
      null => 0,
    };
  }

  void _moveHighlightedSuggestion(int delta) {
    final count = _suggestionCount;
    if (count == 0) {
      return;
    }
    setState(() {
      _highlightedSuggestion = (_highlightedSuggestion + delta) % count;
      if (_highlightedSuggestion < 0) {
        _highlightedSuggestion += count;
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_suggestionsScrollController.hasClients) {
        return;
      }
      final position = _suggestionsScrollController.position;
      final target = (_highlightedSuggestion * 64.0).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      _suggestionsScrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
      );
    });
  }

  void _selectHighlightedSuggestion() {
    final trigger = findComposerTrigger(widget.composerController.value);
    switch (trigger?.kind) {
      case ComposerTriggerKind.slash:
        if (_highlightedSuggestion < widget.slashSuggestions.length) {
          _selectSlashSuggestion(
            widget.slashSuggestions[_highlightedSuggestion],
          );
        }
      case ComposerTriggerKind.mention:
        if (_highlightedSuggestion < widget.mentionSuggestions.length) {
          _selectMentionSuggestion(
            widget.mentionSuggestions[_highlightedSuggestion],
          );
        }
      case null:
        return;
    }
  }

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
    final trimmedRuntimeStatus = widget.runtimeStatus?.trim() ?? '';
    if (!widget.settingsEnabled) {
      helperText = '当前对话能力已关闭，请先在设置中启用。';
    } else if (!widget.hasApiKey) {
      helperText = '请先配置 API Key。';
    } else if (trimmedRuntimeStatus.isNotEmpty) {
      helperText = trimmedRuntimeStatus;
    } else {
      final trimmedStatus = widget.status.trim();
      if (trimmedStatus.contains('失败') || trimmedStatus.contains('请先')) {
        helperText = trimmedStatus;
      }
    }

    final sendButtonTooltip = widget.running
        ? '停止当前轮次'
        : (widget.canSend ? '发送消息' : '请输入内容后发送');
    final sendButtonLabel = widget.running
        ? '停止当前轮次'
        : (widget.canSend ? '发送消息' : '发送消息（不可用）');

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
                icon: widget.runtimeStatusIsRetrying
                    ? Icons.sync
                    : helperText.contains('失败')
                    ? Icons.error_outline
                    : Icons.info_outline,
                text: helperText,
              ),
              const SizedBox(height: 10),
            ],
            if (widget.pendingMentions.isNotEmpty) ...[
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final mention in widget.pendingMentions) ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: InputChip(
                          label: Text(
                            '@${mention.label}',
                            overflow: TextOverflow.ellipsis,
                          ),
                          avatar: Icon(
                            mention.kind == ComposerMentionKind.file
                                ? Icons.insert_drive_file_outlined
                                : Icons.account_tree_outlined,
                            size: 18,
                          ),
                          onDeleted: () =>
                              widget.onRemovePendingMention(mention),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            TapRegion(
              groupId: _tapRegionGroup,
              onTapOutside: (_) {
                _dismissSuggestions();
                _focusNode.unfocus();
              },
              child: OverlayPortal(
                controller: _overlayController,
                overlayChildBuilder: (overlayContext) {
                  final trigger = findComposerTrigger(
                    widget.composerController.value,
                  );
                  return UnconstrainedBox(
                    alignment: Alignment.topLeft,
                    child: CompositedTransformFollower(
                      link: _layerLink,
                      showWhenUnlinked: false,
                      targetAnchor: Alignment.topLeft,
                      followerAnchor: Alignment.bottomLeft,
                      offset: const Offset(0, -8),
                      child: TapRegion(
                        groupId: _tapRegionGroup,
                        child: SizedBox(
                          width: _anchorWidth,
                          child: ConstrainedBox(
                            key: const ValueKey('composer-suggestions-panel'),
                            constraints: BoxConstraints(
                              maxHeight: _maxOverlayHeight,
                            ),
                            child: _ComposerSuggestionsPanel(
                              triggerKind: trigger?.kind,
                              slashSuggestions: widget.slashSuggestions,
                              mentionLoading: widget.mentionLoading,
                              mentionSuggestions: widget.mentionSuggestions,
                              highlightedIndex: _highlightedSuggestion,
                              scrollController: _suggestionsScrollController,
                              onSelectSlashSuggestion: _selectSlashSuggestion,
                              onSelectMentionSuggestion:
                                  _selectMentionSuggestion,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: CompositedTransformTarget(
                  link: _layerLink,
                  child: KeyedSubtree(
                    key: _anchorKey,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Semantics(
                            textField: true,
                            label: '消息输入框',
                            child: CallbackShortcuts(
                              bindings:
                                  widget.showSuggestions &&
                                      _suggestionCount > 0 &&
                                      !_temporarilyDismissed
                                  ? <ShortcutActivator, VoidCallback>{
                                      const SingleActivator(
                                        LogicalKeyboardKey.arrowDown,
                                      ): () =>
                                          _moveHighlightedSuggestion(1),
                                      const SingleActivator(
                                        LogicalKeyboardKey.arrowUp,
                                      ): () =>
                                          _moveHighlightedSuggestion(-1),
                                      const SingleActivator(
                                        LogicalKeyboardKey.enter,
                                      ): _selectHighlightedSuggestion,
                                      const SingleActivator(
                                        LogicalKeyboardKey.numpadEnter,
                                      ): _selectHighlightedSuggestion,
                                      const SingleActivator(
                                        LogicalKeyboardKey.escape,
                                      ): _dismissSuggestions,
                                    }
                                  : const <ShortcutActivator, VoidCallback>{},
                              child: TextField(
                                focusNode: _focusNode,
                                controller: widget.composerController,
                                enabled: widget.canEditComposer,
                                minLines: 1,
                                maxLines: 6,
                                textInputAction: TextInputAction.newline,
                                onTap: () {
                                  _temporarilyDismissed = false;
                                  _scheduleOverlaySync();
                                },
                                decoration: const InputDecoration(
                                  hintText: '在这里输入消息...',
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  isDense: true,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(12),
                                    ),
                                    borderSide: BorderSide.none,
                                  ),
                                  filled: true,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          button: true,
                          enabled: widget.running || widget.canSend,
                          label: sendButtonLabel,
                          child: IconButton.filled(
                            tooltip: sendButtonTooltip,
                            onPressed: widget.running
                                ? widget.onStopMessage
                                : (widget.canSend
                                      ? widget.onSendMessage
                                      : null),
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 180),
                              switchInCurve: Curves.easeOut,
                              switchOutCurve: Curves.easeIn,
                              child: widget.running
                                  ? const Icon(
                                      Icons.stop_rounded,
                                      key: ValueKey('stop-icon'),
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
                  ),
                ),
              ),
            ),
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
    required this.triggerKind,
    required this.slashSuggestions,
    required this.mentionLoading,
    required this.mentionSuggestions,
    required this.highlightedIndex,
    required this.scrollController,
    required this.onSelectSlashSuggestion,
    required this.onSelectMentionSuggestion,
  });

  final ComposerTriggerKind? triggerKind;
  final List<CodexSlashCommand> slashSuggestions;
  final bool mentionLoading;
  final List<ComposerMentionSuggestion> mentionSuggestions;
  final int highlightedIndex;
  final ScrollController scrollController;
  final ValueChanged<CodexSlashCommand> onSelectSlashSuggestion;
  final ValueChanged<ComposerMentionSuggestion> onSelectMentionSuggestion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final Widget content;
    if (triggerKind == ComposerTriggerKind.slash) {
      if (slashSuggestions.isEmpty) {
        content = const ListTile(
          minTileHeight: 48,
          leading: Icon(Icons.search_off_outlined),
          title: Text('没有匹配的命令'),
        );
      } else {
        content = ListView.builder(
          controller: scrollController,
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          itemCount: slashSuggestions.length,
          itemBuilder: (context, index) {
            final suggestion = slashSuggestions[index];
            return ListTile(
              selected: index == highlightedIndex,
              minTileHeight: 48,
              leading: const Icon(Icons.code_outlined),
              title: Text(suggestion.command),
              subtitle: Text(
                suggestion.purpose,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => onSelectSlashSuggestion(suggestion),
            );
          },
        );
      }
    } else if (mentionLoading) {
      content = const ListTile(
        minTileHeight: 48,
        leading: SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('正在查找文件与提交...'),
      );
    } else if (mentionSuggestions.isEmpty) {
      content = const ListTile(
        minTileHeight: 48,
        leading: Icon(Icons.search_off_outlined),
        title: Text('没有匹配的文件或提交'),
      );
    } else {
      content = ListView.builder(
        controller: scrollController,
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: mentionSuggestions.length,
        itemBuilder: (context, index) {
          final suggestion = mentionSuggestions[index];
          return ListTile(
            selected: index == highlightedIndex,
            minTileHeight: 48,
            leading: Icon(
              suggestion.kind == ComposerMentionKind.file
                  ? Icons.insert_drive_file_outlined
                  : Icons.account_tree_outlined,
            ),
            title: Text(
              suggestion.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(suggestion.description),
            onTap: () => onSelectMentionSuggestion(suggestion),
          );
        },
      );
    }

    return Material(
      color: theme.colorScheme.surface,
      elevation: 5,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.18),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
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
