import 'codex_models.dart';

class RuntimePathMapper {
  RuntimePathMapper({
    required String workspaceRepoDir,
    required String codexHomeDir,
    required String tmpDir,
    String? runtimeBinDir,
  }) : _aliases = _buildAliases(
         workspaceRepoDir: workspaceRepoDir,
         codexHomeDir: codexHomeDir,
         tmpDir: tmpDir,
         runtimeBinDir: runtimeBinDir,
       );

  factory RuntimePathMapper.fromLaunchContext(
    CodexRuntimeLaunchContext launchContext,
  ) {
    return RuntimePathMapper(
      workspaceRepoDir: launchContext.paths.repoDir.path,
      codexHomeDir: launchContext.paths.codexHomeDir.path,
      tmpDir: launchContext.paths.tmpDir.path,
    );
  }

  static const workspaceAlias = '/workspace';
  static const codexHomeAlias = '/home/codex';
  static const tmpAlias = '/tmp/codex';
  static const runtimeBinAlias = '/runtime/bin';

  static final _androidRuntimeBinPattern = RegExp(
    r'/(?:data/user/\d+|data/data)/[^/\s:,"\)\]\}]+/files/codexm/bin/[^/\s:,"\)\]\}]+',
  );

  final List<_PathAlias> _aliases;

  String realToVirtual(String input) {
    var output = input;
    for (final alias in _aliases) {
      output = _replacePathPrefix(
        output,
        realPrefix: alias.realPath,
        virtualPrefix: alias.virtualPath,
      );
    }
    return output.replaceAll(_androidRuntimeBinPattern, runtimeBinAlias);
  }

  String virtualToReal(String input) {
    var output = input;
    for (final alias in _aliases) {
      output = _replacePathPrefix(
        output,
        realPrefix: alias.virtualPath,
        virtualPrefix: alias.realPath,
      );
    }
    return output;
  }

  CodexTurnEvent sanitizeEvent(CodexTurnEvent event) {
    switch (event.type) {
      case CodexTurnEventType.text:
        return CodexTurnEvent.text(realToVirtual(event.text ?? ''));
      case CodexTurnEventType.messagePart:
        return CodexTurnEvent.messagePart(
          id: event.partId ?? '',
          kind: event.partKind ?? 'event',
          title: realToVirtual(event.partTitle ?? ''),
          content: realToVirtual(event.partContent ?? ''),
          status: event.partStatus == null
              ? null
              : realToVirtual(event.partStatus!),
        );
      case CodexTurnEventType.status:
        return CodexTurnEvent.status(
          event.message == null ? null : realToVirtual(event.message!),
          isRetrying: event.isRetrying,
        );
      case CodexTurnEventType.error:
        return CodexTurnEvent.error(realToVirtual(event.message ?? ''));
      case CodexTurnEventType.rpcResult:
      case CodexTurnEventType.done:
        return event;
    }
  }

  static List<_PathAlias> _buildAliases({
    required String workspaceRepoDir,
    required String codexHomeDir,
    required String tmpDir,
    String? runtimeBinDir,
  }) {
    final aliases = <_PathAlias>[
      _PathAlias(_normalizePath(workspaceRepoDir), workspaceAlias),
      _PathAlias(_normalizePath(codexHomeDir), codexHomeAlias),
      _PathAlias(_normalizePath(tmpDir), tmpAlias),
      if (runtimeBinDir != null && runtimeBinDir.trim().isNotEmpty)
        _PathAlias(_normalizePath(runtimeBinDir), runtimeBinAlias),
    ].where((alias) => alias.realPath.isNotEmpty).toList();
    aliases.sort((left, right) => right.realPath.length - left.realPath.length);
    return aliases;
  }

  static String _normalizePath(String path) {
    var value = path.trim();
    while (value.length > 1 && value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }

  static String _replacePathPrefix(
    String input, {
    required String realPrefix,
    required String virtualPrefix,
  }) {
    if (realPrefix.isEmpty) {
      return input;
    }
    final pattern = RegExp(
      '${RegExp.escape(realPrefix)}(?=\$|[\\s/:,"\'\\)\\]\\}])',
    );
    return input.replaceAll(pattern, virtualPrefix);
  }
}

class _PathAlias {
  const _PathAlias(this.realPath, this.virtualPath);

  final String realPath;
  final String virtualPath;
}
