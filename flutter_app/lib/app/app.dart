import 'package:flutter/material.dart';

import '../features/mcp/presentation/pages/mcp_page.dart';
import '../features/sessions/application/session_models.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/sessions/presentation/pages/sessions_page.dart';
import '../features/workspaces/application/workspace_models.dart';
import '../features/workspaces/application/workspace_store.dart';
import '../features/workspaces/presentation/pages/workspaces_page.dart';
import 'theme/app_theme.dart';

class CodexmFlutterApp extends StatelessWidget {
  const CodexmFlutterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CodexM Flutter',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const _AppShell(),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  final _workspaceStore = WorkspaceStore();

  int _selectedIndex = 0;
  Workspace? _activeWorkspace;
  Session? _selectedSession;
  bool _loadingContext = true;

  static const _destinations = <NavigationDestination>[
    NavigationDestination(icon: Icon(Icons.folder_outlined), selectedIcon: Icon(Icons.folder), label: '工作区'),
    NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: '会话'),
    NavigationDestination(icon: Icon(Icons.extension_outlined), selectedIcon: Icon(Icons.extension), label: 'MCP'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: '设置'),
  ];

  @override
  void initState() {
    super.initState();
    _loadContext();
  }

  Future<void> _loadContext() async {
    final workspace = await _workspaceStore.getActiveWorkspace();
    if (!mounted) {
      return;
    }
    setState(() {
      _activeWorkspace = workspace;
      _loadingContext = false;
    });
  }

  void _handleWorkspaceChanged(Workspace? workspace) {
    setState(() {
      if (_activeWorkspace?.id != workspace?.id) {
        _selectedSession = null;
      }
      _activeWorkspace = workspace;
      _loadingContext = false;
    });
  }

  void _handleSessionChanged(Session? session) {
    setState(() {
      _selectedSession = session;
    });
  }

  List<Widget> _buildPages() {
    return <Widget>[
      WorkspacesPage(
        activeWorkspaceId: _activeWorkspace?.id,
        onActiveWorkspaceChanged: _handleWorkspaceChanged,
        onOpenSessionsRequested: () {
          setState(() {
            _selectedIndex = 1;
          });
        },
      ),
      SessionsPage(
        activeWorkspaceId: _activeWorkspace?.id,
        selectedSessionId: _selectedSession?.id,
        onActiveWorkspaceChanged: _handleWorkspaceChanged,
        onSessionSelected: _handleSessionChanged,
        onOpenWorkspacesRequested: () {
          setState(() {
            _selectedIndex = 0;
          });
        },
        onOpenSettingsRequested: () {
          setState(() {
            _selectedIndex = 3;
          });
        },
      ),
      const McpPage(),
      const SettingsPage(),
    ];
  }

  Widget _buildContextBar(BuildContext context) {
    final theme = Theme.of(context);
    if (_loadingContext) {
      return LinearProgressIndicator(
        minHeight: 2,
        color: theme.colorScheme.primary,
      );
    }
    if (_activeWorkspace == null) {
      return const SizedBox.shrink();
    }

    final subtitle = _selectedSession == null
        ? _activeWorkspace!.localPath
        : '${_activeWorkspace!.name} · ${_selectedSession!.title}';

    return Material(
      color: theme.colorScheme.surface,
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.folder_special_outlined),
        title: Text(_activeWorkspace!.name),
        subtitle: Text(
          subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: TextButton(
          onPressed: () {
            setState(() {
              _selectedIndex = _selectedSession == null ? 0 : 1;
            });
          },
          child: Text(_selectedSession == null ? '查看工作区' : '回到会话'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _buildPages()),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildContextBar(context),
          NavigationBar(
            selectedIndex: _selectedIndex,
            destinations: _destinations,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
          ),
        ],
      ),
    );
  }
}
