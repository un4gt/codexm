import 'dart:async';

import 'package:flutter/material.dart';

import '../features/mcp/presentation/pages/mcp_page.dart';
import '../features/sessions/application/session_models.dart';
import '../features/sessions/presentation/pages/sessions_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/update/application/app_update_startup_checker.dart';
import '../features/workspaces/application/workspace_models.dart';
import '../features/workspaces/application/workspace_store.dart';
import '../features/workspaces/presentation/pages/workspaces_page.dart';
import '../shared/widgets/adaptive_breakpoints.dart';
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
  final _updateStartupChecker = AppUpdateStartupChecker();

  int _selectedIndex = 0;
  Workspace? _activeWorkspace;
  Session? _selectedSession;
  bool _startupUpdateCheckTriggered = false;

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

  static const _railDestinations = <NavigationRailDestination>[
    NavigationRailDestination(
      icon: Icon(Icons.folder_outlined),
      selectedIcon: Icon(Icons.folder),
      label: Text('工作区'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.chat_bubble_outline),
      selectedIcon: Icon(Icons.chat_bubble),
      label: Text('会话'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.extension_outlined),
      selectedIcon: Icon(Icons.extension),
      label: Text('MCP'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: Text('设置'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadContext();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_startupUpdateCheckTriggered) {
        return;
      }
      _startupUpdateCheckTriggered = true;
      unawaited(_updateStartupChecker.checkOnLaunch(context));
    });
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
    final isCompact = context.adaptiveWidthClass.isCompact;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    final bodyContent = IndexedStack(
      index: _selectedIndex,
      children: _buildPages(),
    );

    return Scaffold(
      body: ColoredBox(
        color: theme.colorScheme.surface,
        child: isCompact
            ? bodyContent
            : Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    labelType: NavigationRailLabelType.all,
                    destinations: _railDestinations,
                    backgroundColor: theme.colorScheme.surface,
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                  Expanded(child: bodyContent),
                ],
              ),
      ),
      bottomNavigationBar: isCompact
          ? DecoratedBox(
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
            )
          : null,
    );
  }
}
