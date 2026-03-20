import 'package:flutter/material.dart';

import '../features/mcp/presentation/pages/mcp_page.dart';
import '../features/sessions/application/session_models.dart';
import '../features/sessions/presentation/pages/sessions_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
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

  static const _destinations = <NavigationDestination>[
    NavigationDestination(
      icon: Icon(Icons.folder_outlined),
      selectedIcon: Icon(Icons.folder),
      label: '工作区',
    ),
    NavigationDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat_bubble),
      label: '会话',
    ),
    NavigationDestination(
      icon: Icon(Icons.extension_outlined),
      selectedIcon: Icon(Icons.extension),
      label: 'MCP',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: '设置',
    ),
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
    });
  }

  void _handleWorkspaceChanged(Workspace? workspace) {
    setState(() {
      if (_activeWorkspace?.id != workspace?.id) {
        _selectedSession = null;
      }
      _activeWorkspace = workspace;
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
      ),
      const McpPage(),
      const SettingsPage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: ColoredBox(
        color: theme.colorScheme.surface,
        child: IndexedStack(index: _selectedIndex, children: _buildPages()),
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              NavigationBar(
                selectedIndex: _selectedIndex,
                destinations: _destinations,
                onDestinationSelected: (index) {
                  setState(() {
                    _selectedIndex = index;
                  });
                },
              ),
              if (bottomPadding == 0) const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
