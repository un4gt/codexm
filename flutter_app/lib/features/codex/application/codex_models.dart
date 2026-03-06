import '../../sessions/application/session_models.dart';
import '../../settings/application/codex_settings_store.dart';
import '../../workspaces/application/workspace_models.dart';
import '../../workspaces/application/workspace_paths.dart';

typedef CodexInputElement = Map<String, Object?>;

enum CodexTurnKind {
  turn,
  review,
  rpc,
}

enum CodexCollaborationMode {
  standard,
  plan,
}

extension CodexCollaborationModeWire on CodexCollaborationMode {
  String get wireValue => this == CodexCollaborationMode.plan ? 'plan' : 'default';
}

class CodexRpcCall {
  const CodexRpcCall({
    required this.method,
    this.params,
    this.requiresThread = false,
    this.emitText = true,
    this.title,
  });

  final String method;
  final Map<String, Object?>? params;
  final bool requiresThread;
  final bool emitText;
  final String? title;
}

enum CodexTurnEventType {
  text,
  error,
  rpcResult,
  done,
}

class CodexTurnEvent {
  const CodexTurnEvent._({
    required this.type,
    this.text,
    this.message,
    this.method,
    this.result,
  });

  const CodexTurnEvent.text(String text)
      : this._(type: CodexTurnEventType.text, text: text);

  const CodexTurnEvent.error(String message)
      : this._(type: CodexTurnEventType.error, message: message);

  const CodexTurnEvent.rpcResult({
    required String method,
    required Object? result,
  }) : this._(
          type: CodexTurnEventType.rpcResult,
          method: method,
          result: result,
        );

  const CodexTurnEvent.done()
      : this._(type: CodexTurnEventType.done);

  final CodexTurnEventType type;
  final String? text;
  final String? message;
  final String? method;
  final Object? result;
}

enum CodexStreamEventType {
  text,
  error,
  done,
}

class CodexStreamEvent {
  const CodexStreamEvent._({
    required this.type,
    this.text,
    this.message,
  });

  const CodexStreamEvent.text(String text)
      : this._(type: CodexStreamEventType.text, text: text);

  const CodexStreamEvent.error(String message)
      : this._(type: CodexStreamEventType.error, message: message);

  const CodexStreamEvent.done()
      : this._(type: CodexStreamEventType.done);

  final CodexStreamEventType type;
  final String? text;
  final String? message;
}

class CodexServerConfig {
  const CodexServerConfig({
    required this.baseUrl,
    this.apiKey,
  });

  final String baseUrl;
  final String? apiKey;
}

class CodexSlashCommand {
  const CodexSlashCommand({
    required this.command,
    required this.purpose,
    required this.when,
  });

  final String command;
  final String purpose;
  final String when;
}

class CodexRuntimeLaunchContext {
  const CodexRuntimeLaunchContext({
    required this.workspace,
    required this.session,
    required this.settings,
    required this.paths,
    required this.codexHomePath,
    required this.configTomlPath,
    required this.authJsonPath,
    required this.env,
    required this.enabledMcpServerIds,
    required this.apiKey,
    this.warnings,
  });

  final Workspace workspace;
  final Session session;
  final CodexSettings settings;
  final WorkspacePaths paths;
  final String codexHomePath;
  final String configTomlPath;
  final String authJsonPath;
  final Map<String, String> env;
  final List<String> enabledMcpServerIds;
  final String apiKey;
  final List<String>? warnings;
}
