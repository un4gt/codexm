import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
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
import 'app_services.dart';
import 'theme/app_theme.dart';

class CodexmFlutterApp extends StatefulWidget {
  const CodexmFlutterApp({super.key, this.services});

  final CodexmAppServices? services;

  @override
  State<CodexmFlutterApp> createState() => _CodexmFlutterAppState();
}

class _CodexmFlutterAppState extends State<CodexmFlutterApp> {
  late final CodexmAppServices _services;
  late final CodexSettingsStore _settingsStore;

  Locale? _locale;
  CodexSettings _settings = const CodexSettings();

  @override
  void initState() {
    super.initState();
    _services = widget.services ?? CodexmAppServices.create();
    _settingsStore = _services.settingsStore;
    unawaited(_loadLocalePreference());
  }

  Future<void> _loadLocalePreference() async {
    try {
      final settings = await _settingsStore.getSettings();
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
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

  void _handleSettingsChanged(CodexSettings settings) {
    setState(() {
      _settings = settings;
      _locale = CodexLocalePreference.toLocale(settings.appLocalePreference);
    });
  }

  @override
  Widget build(BuildContext context) {
    final useDynamicPalette =
        CodexThemePaletteSource.normalize(_settings.themePaletteSource) ==
        CodexThemePaletteSource.dynamic;
    final useCustomAccent =
        CodexThemePaletteSource.normalize(_settings.themePaletteSource) ==
        CodexThemePaletteSource.customAccent;
    final accentColor = useCustomAccent && _settings.accentColorValue != null
        ? Color(_settings.accentColorValue!)
        : null;

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        return MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          themeAnimationDuration: const Duration(milliseconds: 240),
          themeAnimationCurve: Curves.easeOutCubic,
          themeMode: codexThemeModeFromPreference(
            _settings.themeModePreference,
          ),
          theme: buildLightAppTheme(
            dynamicColorScheme: useDynamicPalette ? lightDynamic : null,
            accentColor: accentColor,
            lightCodeThemePreference: _settings.lightCodeThemePreference,
            darkCodeThemePreference: _settings.darkCodeThemePreference,
          ),
          darkTheme: buildDarkAppTheme(
            dynamicColorScheme: useDynamicPalette ? darkDynamic : null,
            accentColor: accentColor,
            lightCodeThemePreference: _settings.lightCodeThemePreference,
            darkCodeThemePreference: _settings.darkCodeThemePreference,
          ),
          locale: _locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: _AppShell(
            services: _services,
            onLocalePreferenceChanged: _handleLocalePreferenceChanged,
            onSettingsChanged: _handleSettingsChanged,
          ),
        );
      },
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell({
    required this.services,
    required this.onLocalePreferenceChanged,
    required this.onSettingsChanged,
  });

  final CodexmAppServices services;
  final ValueChanged<Locale?> onLocalePreferenceChanged;
  final ValueChanged<CodexSettings> onSettingsChanged;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> with WidgetsBindingObserver {
  late final WorkspaceStore _workspaceStore;
  final _updateStartupChecker = AppUpdateStartupChecker();

  int _selectedIndex = 0;
  Workspace? _activeWorkspace;
  Session? _selectedSession;
  bool _sessionDetailVisible = false;
  bool _workspaceSessionsVisible = false;
  SessionActivity? _sessionActivity;
  bool _startupUpdateCheckTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _workspaceStore = widget.services.workspaceStore;
    _loadContext();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeCheckForUpdates();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _maybeCheckForUpdates();
    }
  }

  void _maybeCheckForUpdates() {
    if (_startupUpdateCheckTriggered || !mounted) {
      return;
    }
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    if (lifecycleState != null && lifecycleState != AppLifecycleState.resumed) {
      return;
    }
    _startupUpdateCheckTriggered = true;
    unawaited(_updateStartupChecker.checkOnLaunch(context));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      PopScope(
        canPop: !_workspaceSessionsVisible,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop && _workspaceSessionsVisible && !_sessionDetailVisible) {
            setState(() {
              _workspaceSessionsVisible = false;
            });
          }
        },
        child: IndexedStack(
          index: _workspaceSessionsVisible ? 1 : 0,
          children: [
            WorkspacesPage(
              activeWorkspaceId: _activeWorkspace?.id,
              lockedWorkspaceId: _sessionActivity?.workspaceId,
              onActiveWorkspaceChanged: _handleWorkspaceChanged,
              onOpenSessionsRequested: (workspace) {
                setState(() {
                  _activeWorkspace = workspace;
                  _selectedSession = null;
                  _workspaceSessionsVisible = true;
                });
              },
            ),
            SessionsPage(
              turnCoordinator: widget.services.turnCoordinator,
              isActive: _selectedIndex == 0 && _workspaceSessionsVisible,
              activeWorkspaceId: _activeWorkspace?.id,
              selectedSessionId: _selectedSession?.id,
              onActiveWorkspaceChanged: _handleWorkspaceChanged,
              onSessionSelected: _handleSessionChanged,
              onOpenWorkspacesRequested: () {
                setState(() {
                  _workspaceSessionsVisible = false;
                  _sessionDetailVisible = false;
                });
              },
              onOpenSettingsRequested: () {
                setState(() {
                  _selectedIndex = 2;
                });
              },
              onDetailVisibilityChanged: (visible) {
                if (_sessionDetailVisible == visible) {
                  return;
                }
                setState(() {
                  _sessionDetailVisible = visible;
                });
              },
              onActivityChanged: (activity) {
                if (_sessionActivity?.workspaceId == activity?.workspaceId &&
                    _sessionActivity?.sessionId == activity?.sessionId) {
                  return;
                }
                setState(() {
                  _sessionActivity = activity;
                });
              },
            ),
          ],
        ),
      ),
      const McpPage(),
      SettingsPage(
        lanAccessController: widget.services.lanAccessController,
        isActive: _selectedIndex == 2,
        onLocalePreferenceChanged: widget.onLocalePreferenceChanged,
        onSettingsChanged: widget.onSettingsChanged,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final layout = context.adaptiveLayoutInfo;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final destinations = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.folder_outlined),
        selectedIcon: const Icon(Icons.folder),
        label: l10n.navWorkspaces,
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
        child: layout.useBottomNavigation
            ? bodyContent
            : Row(
                children: [
                  NavigationRail(
                    selectedIndex: _selectedIndex,
                    onDestinationSelected: (index) {
                      setState(() {
                        if (index == 0 && _selectedIndex == 0) {
                          _workspaceSessionsVisible = false;
                          _sessionDetailVisible = false;
                        }
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
      bottomNavigationBar:
          layout.useBottomNavigation &&
              !(_selectedIndex == 0 && _sessionDetailVisible)
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
                          if (index == 0 && _selectedIndex == 0) {
                            _workspaceSessionsVisible = false;
                            _sessionDetailVisible = false;
                          }
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
