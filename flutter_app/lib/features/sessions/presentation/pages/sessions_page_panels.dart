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

class _ChatPanel extends StatefulWidget {
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
    required this.pendingAssistantParts,
    required this.pendingStartedAt,
    required this.scrollController,
    required this.composerController,
    required this.composerFocusNode,
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
  final List<ChatMessagePart> pendingAssistantParts;
  final int pendingStartedAt;
  final ScrollController scrollController;
  final TextEditingController composerController;
  final FocusNode composerFocusNode;
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
  State<_ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<_ChatPanel> {
  double _composerHeight = 132;
  int _highlightedSuggestionIndex = 0;

  bool get _showSuggestions {
    final mentionToken = extractMentionToken(widget.composerController.text);
    return widget.slashSuggestions.isNotEmpty ||
        widget.mentionLoading ||
        widget.mentionSuggestions.isNotEmpty ||
        mentionToken != null;
  }

  int get _suggestionCount {
    if (widget.slashSuggestions.isNotEmpty) {
      return widget.slashSuggestions.take(8).length;
    }
    if (widget.mentionLoading || widget.mentionSuggestions.isEmpty) {
      return 0;
    }
    return widget.mentionSuggestions.length;
  }

  @override
  void didUpdateWidget(covariant _ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final count = _suggestionCount;
    if (count == 0) {
      _highlightedSuggestionIndex = 0;
      return;
    }
    if (_highlightedSuggestionIndex >= count) {
      _highlightedSuggestionIndex = count - 1;
    }
  }

  KeyEventResult _handleKeyboardEvent(FocusNode node, KeyEvent event) {
    if (!_showSuggestions || event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    final count = _suggestionCount;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(() {
        _highlightedSuggestionIndex = 0;
      });
      widget.composerFocusNode.requestFocus();
      return KeyEventResult.handled;
    }
    if (count == 0) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _highlightedSuggestionIndex = (_highlightedSuggestionIndex + 1).clamp(
          0,
          count - 1,
        );
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _highlightedSuggestionIndex = (_highlightedSuggestionIndex - 1).clamp(
          0,
          count - 1,
        );
      });
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.tab) {
      _selectHighlightedSuggestion();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _selectHighlightedSuggestion() {
    if (widget.slashSuggestions.isNotEmpty) {
      final visible = widget.slashSuggestions.take(8).toList(growable: false);
      if (visible.isEmpty) {
        return;
      }
      widget.onSelectSlashSuggestion(visible[_highlightedSuggestionIndex]);
      return;
    }
    if (widget.mentionSuggestions.isEmpty) {
      return;
    }
    widget.onSelectMentionSuggestion(
      widget.mentionSuggestions[_highlightedSuggestionIndex],
    );
  }

  void _handleComposerSizeChanged(Size size) {
    if ((size.height - _composerHeight).abs() < 0.5) {
      return;
    }
    setState(() {
      _composerHeight = size.height;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: _SessionUiSpecs.maxContentWidth,
        ),
        child: Column(
          children: [
            _SessionHeader(
              workspace: widget.workspace,
              selectedSession: widget.selectedSession,
              sessionCount: widget.sessions.length,
              status: widget.status,
              settingsReady: widget.settingsEnabled && widget.hasApiKey,
              onOpenSessionSwitcher: widget.onOpenSessionSwitcher,
              onMenuAction: (action) {
                switch (action) {
                  case _HeaderMenuAction.newSession:
                    widget.onCreateSession();
                    break;
                  case _HeaderMenuAction.renameSession:
                    final session = widget.selectedSession;
                    if (session != null) {
                      widget.onRenameSession(session);
                    }
                    break;
                  case _HeaderMenuAction.deleteSession:
                    final session = widget.selectedSession;
                    if (session != null) {
                      widget.onDeleteSession(session);
                    }
                    break;
                }
              },
            ),
            Expanded(
              child: Focus(
                onKeyEvent: _handleKeyboardEvent,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _MessageList(
                        messages: widget.messages,
                        showThinking: widget.showThinking,
                        pendingAssistantText: widget.pendingAssistantText,
                        pendingAssistantParts: widget.pendingAssistantParts,
                        pendingStartedAt: widget.pendingStartedAt,
                        scrollController: widget.scrollController,
                        workspaceName: widget.workspace.name,
                        canDirectChat:
                            widget.settingsEnabled && widget.hasApiKey,
                        bottomReserve:
                            _composerHeight +
                            (_showSuggestions ? 132 : CodexMSpacing.sm),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: _MeasureSize(
                        onChange: _handleComposerSizeChanged,
                        child: _SessionInputBar(
                          settingsEnabled: widget.settingsEnabled,
                          hasApiKey: widget.hasApiKey,
                          running: widget.running,
                          status: widget.status,
                          runtimeStatus: widget.runtimeStatus,
                          runtimeStatusIsRetrying:
                              widget.runtimeStatusIsRetrying,
                          composerController: widget.composerController,
                          composerFocusNode: widget.composerFocusNode,
                          pendingMentions: widget.pendingMentions,
                          onRemovePendingMention: widget.onRemovePendingMention,
                          onSendMessage: widget.onSendMessage,
                          canSend: widget.canSend,
                          canEditComposer: widget.canEditComposer,
                        ),
                      ),
                    ),
                    _ComposerSuggestionsOverlay(
                      visible: _showSuggestions,
                      composerHeight: _composerHeight,
                      slashSuggestions: widget.slashSuggestions,
                      mentionLoading: widget.mentionLoading,
                      mentionSuggestions: widget.mentionSuggestions,
                      highlightedIndex: _highlightedSuggestionIndex,
                      onHighlightChanged: (index) {
                        setState(() {
                          _highlightedSuggestionIndex = index;
                        });
                      },
                      onSelectSlashSuggestion: widget.onSelectSlashSuggestion,
                      onSelectMentionSuggestion:
                          widget.onSelectMentionSuggestion,
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
    required this.pendingAssistantParts,
    required this.pendingStartedAt,
    required this.scrollController,
    required this.workspaceName,
    required this.canDirectChat,
    required this.bottomReserve,
  });

  final List<ChatMessage> messages;
  final bool showThinking;
  final String pendingAssistantText;
  final List<ChatMessagePart> pendingAssistantParts;
  final int pendingStartedAt;
  final ScrollController scrollController;
  final String workspaceName;
  final bool canDirectChat;
  final double bottomReserve;

  @override
  Widget build(BuildContext context) {
    final hasStreaming =
        pendingAssistantText.trim().isNotEmpty ||
        pendingAssistantParts.isNotEmpty;
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
          12 + bottomReserve,
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

class _SessionInputBar extends StatelessWidget {
  const _SessionInputBar({
    required this.settingsEnabled,
    required this.hasApiKey,
    required this.running,
    required this.status,
    required this.runtimeStatus,
    required this.runtimeStatusIsRetrying,
    required this.composerController,
    required this.composerFocusNode,
    required this.pendingMentions,
    required this.onRemovePendingMention,
    required this.onSendMessage,
    required this.canSend,
    required this.canEditComposer,
  });

  final bool settingsEnabled;
  final bool hasApiKey;
  final bool running;
  final String status;
  final String? runtimeStatus;
  final bool runtimeStatusIsRetrying;
  final TextEditingController composerController;
  final FocusNode composerFocusNode;
  final List<ComposerPendingMention> pendingMentions;
  final ValueChanged<ComposerPendingMention> onRemovePendingMention;
  final VoidCallback onSendMessage;
  final bool canSend;
  final bool canEditComposer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.codexColors;
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
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.divider)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -4),
          ),
        ],
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
                      labelStyle: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colors.text,
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
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 52),
                    child: Semantics(
                      textField: true,
                      label: '消息输入框',
                      child: TextField(
                        focusNode: composerFocusNode,
                        controller: composerController,
                        enabled: canEditComposer,
                        minLines: 1,
                        maxLines: 6,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: '在这里输入消息...',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 14,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: colors.surfaceMuted,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(CodexMRadii.lg),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(CodexMRadii.lg),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(CodexMRadii.lg),
                            borderSide: BorderSide(color: colors.primary),
                          ),
                        ),
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
                                color: colors.primary,
                              ),
                            )
                          : const Icon(
                              Icons.arrow_upward_rounded,
                              key: ValueKey('send-icon'),
                            ),
                    ),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(52, 52),
                      fixedSize: const Size(52, 52),
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: colors.surfaceMuted,
                      disabledForegroundColor: colors.textSubtle,
                    ),
                  ),
                ),
              ],
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
    final colors = context.codexColors;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surfaceMuted,
        borderRadius: BorderRadius.circular(CodexMRadii.md),
        border: Border.all(color: colors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: colors.textMuted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerSuggestionsOverlay extends StatelessWidget {
  const _ComposerSuggestionsOverlay({
    required this.visible,
    required this.composerHeight,
    required this.slashSuggestions,
    required this.mentionLoading,
    required this.mentionSuggestions,
    required this.highlightedIndex,
    required this.onHighlightChanged,
    required this.onSelectSlashSuggestion,
    required this.onSelectMentionSuggestion,
  });

  final bool visible;
  final double composerHeight;
  final List<CodexSlashCommand> slashSuggestions;
  final bool mentionLoading;
  final List<ComposerMentionSuggestion> mentionSuggestions;
  final int highlightedIndex;
  final ValueChanged<int> onHighlightChanged;
  final ValueChanged<CodexSlashCommand> onSelectSlashSuggestion;
  final ValueChanged<ComposerMentionSuggestion> onSelectMentionSuggestion;

  @override
  Widget build(BuildContext context) {
    final colors = context.codexColors;
    final bottom = composerHeight + CodexMSpacing.xs;
    if (!visible) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: bottom,
        child: const SizedBox.shrink(),
      );
    }

    return Positioned(
      left: switch (context.adaptiveWidthClass) {
        AdaptiveWidthClass.compact => _SessionUiSpecs.compactHorizontalPadding,
        AdaptiveWidthClass.medium => _SessionUiSpecs.mediumHorizontalPadding,
        AdaptiveWidthClass.expanded =>
          _SessionUiSpecs.expandedHorizontalPadding,
      },
      right: switch (context.adaptiveWidthClass) {
        AdaptiveWidthClass.compact => _SessionUiSpecs.compactHorizontalPadding,
        AdaptiveWidthClass.medium => _SessionUiSpecs.mediumHorizontalPadding,
        AdaptiveWidthClass.expanded =>
          _SessionUiSpecs.expandedHorizontalPadding,
      },
      bottom: bottom,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        offset: Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          opacity: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final availableHeight = MediaQuery.sizeOf(context).height;
              final maxHeight = (availableHeight * 0.45).clamp(160.0, 360.0);
              return ConstrainedBox(
                key: const ValueKey('composer-suggestions-overlay'),
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: Material(
                  color: colors.surfaceElevated,
                  elevation: 10,
                  shadowColor: Theme.of(
                    context,
                  ).colorScheme.shadow.withValues(alpha: 0.14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CodexMRadii.lg),
                    side: BorderSide(color: colors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _ComposerSuggestionsPanel(
                    slashSuggestions: slashSuggestions,
                    mentionLoading: mentionLoading,
                    mentionSuggestions: mentionSuggestions,
                    highlightedIndex: highlightedIndex,
                    onHighlightChanged: onHighlightChanged,
                    onSelectSlashSuggestion: onSelectSlashSuggestion,
                    onSelectMentionSuggestion: onSelectMentionSuggestion,
                  ),
                ),
              );
            },
          ),
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
    required this.highlightedIndex,
    required this.onHighlightChanged,
    required this.onSelectSlashSuggestion,
    required this.onSelectMentionSuggestion,
  });

  final List<CodexSlashCommand> slashSuggestions;
  final bool mentionLoading;
  final List<ComposerMentionSuggestion> mentionSuggestions;
  final int highlightedIndex;
  final ValueChanged<int> onHighlightChanged;
  final ValueChanged<CodexSlashCommand> onSelectSlashSuggestion;
  final ValueChanged<ComposerMentionSuggestion> onSelectMentionSuggestion;

  @override
  Widget build(BuildContext context) {
    if (slashSuggestions.isNotEmpty) {
      final visible = slashSuggestions.take(8).toList(growable: false);
      return ListView.builder(
        key: const ValueKey('composer-slash-suggestions'),
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final suggestion = visible[index];
          return _SlashSuggestionRow(
            suggestion: suggestion,
            highlighted: index == highlightedIndex,
            onHover: () => onHighlightChanged(index),
            onTap: () => onSelectSlashSuggestion(suggestion),
          );
        },
      );
    }

    if (mentionLoading) {
      return _SuggestionStateRow(
        key: const ValueKey('composer-mention-loading'),
        icon: Icons.search,
        text: AppLocalizations.of(context).sessionComposerMentionLoading,
        loading: true,
      );
    }

    if (mentionSuggestions.isEmpty) {
      return _SuggestionStateRow(
        key: const ValueKey('composer-mention-empty'),
        icon: Icons.search_off_outlined,
        text: AppLocalizations.of(context).sessionComposerMentionEmpty,
      );
    }

    return ListView.builder(
      key: const ValueKey('composer-mention-suggestions'),
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: mentionSuggestions.length,
      itemBuilder: (context, index) {
        final suggestion = mentionSuggestions[index];
        return _MentionSuggestionRow(
          suggestion: suggestion,
          highlighted: index == highlightedIndex,
          onHover: () => onHighlightChanged(index),
          onTap: () => onSelectMentionSuggestion(suggestion),
        );
      },
    );
  }
}

class _SlashSuggestionRow extends StatelessWidget {
  const _SlashSuggestionRow({
    required this.suggestion,
    required this.highlighted,
    required this.onHover,
    required this.onTap,
  });

  final CodexSlashCommand suggestion;
  final bool highlighted;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.codexColors;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: Material(
        color: highlighted ? colors.primarySoft : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 58),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(CodexMRadii.sm),
                    ),
                    child: Icon(Icons.code_outlined, color: colors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          suggestion.command,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: colors.textStrong,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          suggestion.purpose,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.keyboard_return,
                    size: 18,
                    color: colors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MentionSuggestionRow extends StatelessWidget {
  const _MentionSuggestionRow({
    required this.suggestion,
    required this.highlighted,
    required this.onHover,
    required this.onTap,
  });

  final ComposerMentionSuggestion suggestion;
  final bool highlighted;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.codexColors;
    final l10n = AppLocalizations.of(context);
    final isFile = suggestion.kind == ComposerMentionKind.file;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: Material(
        color: highlighted ? colors.primarySoft : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(CodexMRadii.sm),
                    ),
                    child: Icon(
                      isFile
                          ? Icons.insert_drive_file_outlined
                          : Icons.account_tree_outlined,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          suggestion.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: colors.textStrong,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          suggestion.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  CodexStatusChip(
                    label: isFile
                        ? l10n.sessionComposerMentionFile
                        : l10n.sessionComposerMentionCommit,
                    tone: CodexStatusTone.neutral,
                    compact: true,
                    icon: isFile
                        ? Icons.insert_drive_file_outlined
                        : Icons.commit_outlined,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionStateRow extends StatelessWidget {
  const _SuggestionStateRow({
    super.key,
    required this.icon,
    required this.text,
    this.loading = false,
  });

  final IconData icon;
  final String text;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.codexColors;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          if (loading)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            )
          else
            Icon(icon, size: 18, color: colors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
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

class _MeasureSize extends StatefulWidget {
  const _MeasureSize({required this.child, required this.onChange});

  final Widget child;
  final ValueChanged<Size> onChange;

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  Size? _oldSize;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final size = context.size;
      if (size == null || size == _oldSize) {
        return;
      }
      _oldSize = size;
      widget.onChange(size);
    });
    return widget.child;
  }
}
