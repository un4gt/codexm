import 'dart:async';

import 'package:flutter/material.dart';

import '../features/mcp/presentation/pages/mcp_page.dart';
import '../features/sessions/application/session_models.dart';
import '../features/sessions/presentation/pages/sessions_page.dart';
import '../features/settings/application/codex_settings_store.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../features/update/application/app_update_startup_checker.dart';
import '../features/workspaces/application/workspace_models.dart';
import '../features/workspaces/application/workspace_store.dart';
import '../features/workspaces/presentation/pages/workspaces_page.dart';
import '../l10n/app_localizations.dart';
import '../shared/widgets/adaptive_breakpoints.dart';
import 'theme/app_theme.dart';

class CodexmFlutterApp extends StatefulWidget {
  const CodexmFlutterApp({super.key});

  @override
  State<CodexmFlutterApp> createState() => _CodexmFlutterAppState();
}

class _CodexmFlutterAppState extends State<CodexmFlutterApp> {
  final _settingsStore = CodexSettingsStore();

  Locale? _locale;

  @override
  void initState() {
    super.initState();
    unawaited(_loadLocalePreference());
  }

  Future<void> _loadLocalePreference() async {
    try {
      final settings = await _settingsStore.getSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _locale = CodexLocalePreference.toLocale(settings.appLocalePreference);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _locale = null;
      });
    }
  }

  void _handleLocalePreferenceChanged(Locale? locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _AppShell(
        onLocalePreferenceChanged: _handleLocalePreferenceChanged,
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell({required this.onLocalePreferenceChanged});

  final ValueChanged<Locale?> onLocalePreferenceChanged;

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
      SettingsPage(onLocalePreferenceChanged: widget.onLocalePreferenceChanged),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final isCompact = context.adaptiveWidthClass.isCompact;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.folder_outlined),
        selectedIcon: const Icon(Icons.folder),
        label: l10n.navWorkspaces,
      ),
      NavigationDestination(
        icon: const Icon(Icons.chat_bubble_outline),
        selectedIcon: const Icon(Icons.chat_bubble),
        label: l10n.navSessions,
      ),
      NavigationDestination(
        icon: const Icon(Icons.extension_outlined),
        selectedIcon: const Icon(Icons.extension),
        label: l10n.navMcpSkills,
      ),
      NavigationDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: l10n.navSettings,
      ),
    ];
    final railDestinations = <NavigationRailDestination>[
      NavigationRailDestination(
        icon: const Icon(Icons.folder_outlined),
        selectedIcon: const Icon(Icons.folder),
        label: Text(l10n.navWorkspaces),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.chat_bubble_outline),
        selectedIcon: const Icon(Icons.chat_bubble),
        label: Text(l10n.navSessions),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.extension_outlined),
        selectedIcon: const Icon(Icons.extension),
        label: Text(l10n.navMcpSkills),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.settings_outlined),
        selectedIcon: const Icon(Icons.settings),
        label: Text(l10n.navSettings),
      ),
    ];

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
                    destinations: railDestinations,
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
                      destinations: destinations,
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
