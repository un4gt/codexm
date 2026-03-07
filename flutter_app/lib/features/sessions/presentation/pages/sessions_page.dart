import 'dart:io';

import 'package:codexm_native/codexm_native.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/adaptive_breakpoints.dart';
import '../../../codex/application/codex_models.dart';
import '../../../codex/application/codex_session_runner.dart';
import '../../../codex/application/codex_skills_store.dart';
import '../../../codex/application/codex_slash_commands.dart';
import '../../../mcp/application/mcp_store.dart';
import '../../../settings/application/codex_settings_store.dart';
import '../../../workspaces/application/workspace_models.dart';
import '../../../workspaces/application/workspace_paths.dart';
import '../../../workspaces/application/workspace_store.dart';
import '../../application/session_composer_logic.dart';
import '../../application/session_models.dart';
import '../../application/session_store.dart';
import '../widgets/message_bubble.dart';

part 'sessions_page_actions.dart';
part 'sessions_page_panels.dart';

class SessionsPage extends StatefulWidget {
  const SessionsPage({
    super.key,
    this.activeWorkspaceId,
    this.selectedSessionId,
    this.onActiveWorkspaceChanged,
    this.onSessionSelected,
    this.onOpenWorkspacesRequested,
  });

  final WorkspaceId? activeWorkspaceId;
  final SessionId? selectedSessionId;
  final ValueChanged<Workspace?>? onActiveWorkspaceChanged;
  final ValueChanged<Session?>? onSessionSelected;
  final VoidCallback? onOpenWorkspacesRequested;

  @override
  State<SessionsPage> createState() => _SessionsPageState();
}

class _SessionsPageState extends State<SessionsPage> {
  final _native = const CodexmNative();
  final _workspaceStore = WorkspaceStore();
  final _workspaceDirectoryService = WorkspaceDirectoryService();
  final _sessionStore = SessionStore();
  final _settingsStore = CodexSettingsStore();
  final _mcpStore = McpStore();
  final _skillsStore = CodexSkillsStore();
  final _runner = CodexSessionRunner();
  final _composerController = TextEditingController();
  final _messagesScrollController = ScrollController();

  Workspace? _activeWorkspace;
  List<Session> _sessions = const <Session>[];
  SessionId? _selectedSessionId;
  List<ChatMessage> _messages = const <ChatMessage>[];
  CodexSettings _settings = const CodexSettings();
  bool _hasApiKey = false;
  bool _busy = false;
  bool _running = false;
  String _status = '正在准备会话数据...';
  String _pendingAssistantText = '';
  int _pendingStartedAt = 0;
  int _legacySessionCount = 0;
  List<String> _installedSkills = const <String>[];
  List<CodexSlashCommand> _slashSuggestions = const <CodexSlashCommand>[];
  List<ComposerMentionSuggestion> _mentionSuggestions =
      const <ComposerMentionSuggestion>[];
  List<ComposerPendingMention> _pendingMentions =
      const <ComposerPendingMention>[];
  List<String> _repoFiles = const <String>[];
  List<GitCommitSummary> _recentCommits = const <GitCommitSummary>[];
  Map<String, String> _commitDetails = const <String, String>{};
  bool _mentionLoading = false;
  String? _activeMentionQuery;

  @override
  void initState() {
    super.initState();
    _composerController.addListener(_handleComposerChanged);
    _refresh();
  }

  @override
  void dispose() {
    _composerController.removeListener(_handleComposerChanged);
    _composerController.dispose();
    _messagesScrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SessionsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activeWorkspaceId != widget.activeWorkspaceId ||
        oldWidget.selectedSessionId != widget.selectedSessionId) {
      _refresh(status: '已同步当前会话上下文。');
    }
  }

  Future<void> _refresh({String? status}) async {
    final previousWorkspaceId = _activeWorkspace?.id;
    final workspace = await _loadActiveWorkspace();
    final settings = await _settingsStore.getSettings();
    final apiKey = await _settingsStore.getCodexApiKey();
    final skills = await _skillsStore.listInstalledSkills();

    if (workspace == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _activeWorkspace = null;
        _sessions = const <Session>[];
        _selectedSessionId = null;
        _messages = const <ChatMessage>[];
        _settings = settings;
        _hasApiKey = apiKey?.trim().isNotEmpty == true;
        _installedSkills = skills;
        _legacySessionCount = 0;
        _pendingMentions = const <ComposerPendingMention>[];
        _slashSuggestions = const <CodexSlashCommand>[];
        _mentionSuggestions = const <ComposerMentionSuggestion>[];
        _repoFiles = const <String>[];
        _recentCommits = const <GitCommitSummary>[];
        _commitDetails = const <String, String>{};
        _status = status ?? '请先创建并激活工作区，然后再开始对话。';
      });
      widget.onActiveWorkspaceChanged?.call(null);
      widget.onSessionSelected?.call(null);
      return;
    }

    final primary = await _sessionStore.ensurePrimarySession(
      workspace.id,
      title: '主会话',
    );
    final sessions = await _sessionStore.listSessions(workspace.id);
    final preferredSessionId =
        widget.selectedSessionId ??
        (workspace.id == previousWorkspaceId ? _selectedSessionId : null) ??
        primary.id;
    final selectedSessionId = sessions.any(
      (session) => session.id == preferredSessionId,
    )
        ? preferredSessionId
        : primary.id;
    final messages = await _sessionStore.listMessages(
      workspace.id,
      selectedSessionId,
    );
    final workspaceChanged = previousWorkspaceId != workspace.id;
    final legacySessionCount = sessions.length > 1 ? sessions.length - 1 : 0;

    if (!mounted) {
      return;
    }

    setState(() {
      _activeWorkspace = workspace;
      _sessions = sessions;
      _selectedSessionId = selectedSessionId;
      _messages = messages;
      _settings = settings;
      _hasApiKey = apiKey?.trim().isNotEmpty == true;
      _installedSkills = skills;
      _legacySessionCount = legacySessionCount;
      if (workspaceChanged) {
        _pendingMentions = const <ComposerPendingMention>[];
        _slashSuggestions = const <CodexSlashCommand>[];
        _mentionSuggestions = const <ComposerMentionSuggestion>[];
        _repoFiles = const <String>[];
        _recentCommits = const <GitCommitSummary>[];
        _commitDetails = const <String, String>{};
        _activeMentionQuery = null;
      }
      _status = status ??
          (legacySessionCount > 0
              ? '检测到 $legacySessionCount 个历史会话，已自动继续最近主会话。'
              : '已恢复当前工作区的主会话。');
    });

    widget.onActiveWorkspaceChanged?.call(workspace);
    widget.onSessionSelected?.call(
      _findSessionById(sessions, selectedSessionId) ?? primary,
    );
    _handleComposerChanged();
    _scrollToBottom();
  }

  Future<Workspace?> _loadActiveWorkspace() async {
    final requestedId = widget.activeWorkspaceId;
    if (requestedId != null && requestedId.isNotEmpty) {
      return _workspaceStore.getWorkspace(requestedId);
    }
    return _workspaceStore.getActiveWorkspace();
  }

  Session? get _selectedSession {
    return _findSessionById(_sessions, _selectedSessionId);
  }

  Session? _findSessionById(List<Session> sessions, SessionId? sessionId) {
    if (sessionId == null) {
      return null;
    }
    for (final session in sessions) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  void _updateView(VoidCallback change) {
    if (!mounted) {
      return;
    }
    setState(change);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesScrollController.hasClients) {
        return;
      }
      _messagesScrollController.animateTo(
        _messagesScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleComposerChanged() {
    final input = _composerController.text;
    final slashSuggestions = filterSlashCommands(input);
    final mentionQuery = extractMentionToken(input);

    if (mounted) {
      setState(() {
        _slashSuggestions = slashSuggestions;
      });
    }
    _refreshMentionSuggestions(mentionQuery);
  }

  Future<void> _refreshMentionSuggestions(String? query) async {
    final workspace = _activeWorkspace;
    if (workspace == null || query == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _activeMentionQuery = null;
        _mentionLoading = false;
        _mentionSuggestions = const <ComposerMentionSuggestion>[];
      });
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _activeMentionQuery = query;
      _mentionLoading = true;
    });

    var repoFiles = _repoFiles;
    if (repoFiles.isEmpty) {
      repoFiles = await _loadRepoFiles(workspace);
    }
    var commits = _recentCommits;
    if (commits.isEmpty) {
      commits = await _loadRecentCommits(workspace);
    }

    if (!mounted ||
        _activeWorkspace?.id != workspace.id ||
        _activeMentionQuery != query) {
      return;
    }

    final suggestions = filterMentionSuggestions(
      input: _composerController.text,
      repoFiles: repoFiles,
      commits: commits,
    );

    setState(() {
      _repoFiles = repoFiles;
      _recentCommits = commits;
      _mentionLoading = false;
      _mentionSuggestions = suggestions;
    });
  }

  Future<List<String>> _loadRepoFiles(Workspace workspace) async {
    try {
      final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
      if (!paths.repoDir.existsSync()) {
        return const <String>[];
      }
      final out = <String>[];
      await for (final entity
          in paths.repoDir.list(recursive: true, followLinks: false)) {
        if (entity is! File) {
          continue;
        }
        final relative = entity.path.substring(paths.repoDir.path.length + 1);
        if (!_shouldIncludeRepoFile(relative)) {
          continue;
        }
        out.add(relative);
        if (out.length >= 400) {
          break;
        }
      }
      out.sort((left, right) => left.compareTo(right));
      return out;
    } catch (_) {
      return const <String>[];
    }
  }

  bool _shouldIncludeRepoFile(String relativePath) {
    final normalized = relativePath.replaceAll('\\', '/');
    const ignoredPrefixes = <String>[
      '.git/',
      '.dart_tool/',
      'build/',
      'node_modules/',
      '.idea/',
      '.gradle/',
    ];
    for (final prefix in ignoredPrefixes) {
      if (normalized.startsWith(prefix)) {
        return false;
      }
    }
    return true;
  }

  Future<List<GitCommitSummary>> _loadRecentCommits(Workspace workspace) async {
    try {
      final paths = await _workspaceDirectoryService.pathsFor(workspace.id);
      if (!paths.repoDir.existsSync()) {
        return const <GitCommitSummary>[];
      }
      return _native.gitRecentCommits(
        localRepoDirUri: paths.repoDir.path,
        limit: 24,
      );
    } catch (_) {
      return const <GitCommitSummary>[];
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedSession = _selectedSession;
    final canEditComposer = !_busy && !_running && _activeWorkspace != null;
    final canSend = canEditComposer && _composerController.text.trim().isNotEmpty;
    final pagePadding = context.adaptivePagePadding;

    return SafeArea(
      child: Scaffold(
        body: Padding(
          padding: pagePadding,
          child: _activeWorkspace == null
              ? _WorkspaceEmptyState(
                  onOpenWorkspacesRequested: widget.onOpenWorkspacesRequested,
                )
              : _ChatPanel(
                  workspace: _activeWorkspace!,
                  sessions: _sessions,
                  selectedSession: selectedSession,
                  messages: _messages,
                  showThinking: _settings.uiShowThinking,
                  settingsEnabled: _settings.enabled,
                  hasApiKey: _hasApiKey,
                  running: _running,
                  status: _status,
                  pendingAssistantText: _pendingAssistantText,
                  pendingStartedAt: _pendingStartedAt,
                  scrollController: _messagesScrollController,
                  composerController: _composerController,
                  pendingMentions: _pendingMentions,
                  slashSuggestions: _slashSuggestions,
                  mentionSuggestions: _mentionSuggestions,
                  mentionLoading: _mentionLoading,
                  onSelectSlashSuggestion: _applySlashSuggestion,
                  onSelectMentionSuggestion: _applyMentionSuggestion,
                  onRemovePendingMention: _removePendingMention,
                  onSendMessage: _sendMessage,
                  onOpenSessionSwitcher: _openSessionSwitcher,
                  onCreateSession: _createSession,
                  canSend: canSend,
                  canEditComposer: canEditComposer,
                ),
        ),
      ),
    );
  }
}
