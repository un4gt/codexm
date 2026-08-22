import '../features/codex/application/codex_launch_context_service.dart';
import '../features/codex/application/codex_session_runner.dart';
import '../features/codex/application/session_turn_coordinator.dart';
import '../features/lan_access/application/lan_access_controller.dart';
import '../features/lan_access/application/lan_access_platform.dart';
import '../features/lan_access/application/lan_access_preferences_store.dart';
import '../features/lan_access/application/lan_http_server.dart';
import '../features/lan_access/application/lan_pairing_manager.dart';
import '../features/mcp/application/mcp_store.dart';
import '../features/sessions/application/session_code_workspace_service.dart';
import '../features/sessions/application/session_store.dart';
import '../features/settings/application/codex_settings_store.dart';
import '../features/workspaces/application/workspace_paths.dart';
import '../features/workspaces/application/workspace_store.dart';
import '../shared/persistence/app_directory_service.dart';

class CodexmAppServices {
  CodexmAppServices._({
    required this.settingsStore,
    required this.workspaceStore,
    required this.sessionStore,
    required this.turnCoordinator,
    required this.lanAccessController,
  });

  final CodexSettingsStore settingsStore;
  final WorkspaceStore workspaceStore;
  final SessionStore sessionStore;
  final SessionTurnCoordinator turnCoordinator;
  final LanAccessController lanAccessController;

  static CodexmAppServices create() {
    final appDirectories = AppDirectoryService();
    final workspaceDirectories = WorkspaceDirectoryService(
      appDirectoryService: appDirectories,
    );
    final settingsStore = CodexSettingsStore(
      appDirectoryService: appDirectories,
    );
    final workspaceStore = WorkspaceStore(
      appDirectoryService: appDirectories,
      workspaceDirectoryService: workspaceDirectories,
    );
    final sessionStore = SessionStore(
      workspaceDirectoryService: workspaceDirectories,
    );
    final mcpStore = McpStore(appDirectoryService: appDirectories);
    final codeWorkspaceService = SessionCodeWorkspaceService(
      workspaceStore: workspaceStore,
      workspaceDirectoryService: workspaceDirectories,
      sessionStore: sessionStore,
    );
    final launchContextService = CodexLaunchContextService(
      workspaceDirectoryService: workspaceDirectories,
      sessionStore: sessionStore,
      settingsStore: settingsStore,
      mcpStore: mcpStore,
    );
    final runner = CodexSessionRunner(
      launchContextService: launchContextService,
      sessionStore: sessionStore,
    );
    final turnCoordinator = SessionTurnCoordinator(
      workspaceStore: workspaceStore,
      sessionStore: sessionStore,
      codeWorkspaceService: codeWorkspaceService,
      settingsStore: settingsStore,
      runner: runner,
    );
    final pairingManager = LanPairingManager();
    final httpServer = LanHttpServer(
      workspaceStore: workspaceStore,
      sessionStore: sessionStore,
      settingsStore: settingsStore,
      turnCoordinator: turnCoordinator,
      pairingManager: pairingManager,
    );
    final lanAccessController = LanAccessController(
      preferencesStore: LanAccessPreferencesStore(
        appDirectoryService: appDirectories,
      ),
      platform: MethodChannelLanAccessPlatform(),
      httpServer: httpServer,
      pairingManager: pairingManager,
    );
    return CodexmAppServices._(
      settingsStore: settingsStore,
      workspaceStore: workspaceStore,
      sessionStore: sessionStore,
      turnCoordinator: turnCoordinator,
      lanAccessController: lanAccessController,
    );
  }

  Future<void> initialize() => lanAccessController.initialize();
}
