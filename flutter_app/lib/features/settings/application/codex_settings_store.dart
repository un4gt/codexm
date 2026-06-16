import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import '../../../shared/persistence/app_directory_service.dart';
import '../../mcp/application/mcp_models.dart';
import 'auth_store.dart';
import 'auth_types.dart';

class CodexLocalePreference {
  const CodexLocalePreference._();

  static const system = 'system';
  static const english = 'en';
  static const simplifiedChinese = 'zh_Hans';

  static const values = <String>[system, english, simplifiedChinese];

  static String normalize(String? value) {
    final normalized = value?.trim();
    if (normalized == english || normalized == simplifiedChinese) {
      return normalized!;
    }
    return system;
  }

  static Locale? toLocale(String? value) {
    switch (normalize(value)) {
      case english:
        return const Locale('en');
      case simplifiedChinese:
        return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');
      case system:
        return null;
    }
    return null;
  }
}

class CodexThemeModePreference {
  const CodexThemeModePreference._();

  static const system = 'system';
  static const light = 'light';
  static const dark = 'dark';

  static const values = <String>[system, light, dark];

  static String normalize(String? value) {
    final normalized = value?.trim();
    if (normalized == light || normalized == dark) {
      return normalized!;
    }
    return system;
  }
}

class CodexThemePaletteSource {
  const CodexThemePaletteSource._();

  static const fixed = 'fixed';
  static const dynamic = 'dynamic';
  static const customAccent = 'customAccent';

  static const values = <String>[fixed, dynamic, customAccent];

  static String normalize(String? value) {
    final normalized = value?.trim();
    if (normalized == dynamic || normalized == customAccent) {
      return normalized!;
    }
    return fixed;
  }
}

class CodexLightCodeThemePreference {
  const CodexLightCodeThemePreference._();

  static const vscodeLight = 'vscodeLight';
  static const githubLight = 'githubLight';

  static const values = <String>[vscodeLight, githubLight];

  static String normalize(String? value) {
    final normalized = value?.trim();
    if (normalized == githubLight) {
      return normalized!;
    }
    return vscodeLight;
  }
}

class CodexDarkCodeThemePreference {
  const CodexDarkCodeThemePreference._();

  static const vscodeDarkPlus = 'vscodeDarkPlus';
  static const dracula = 'dracula';
  static const oneDarkPro = 'oneDarkPro';

  static const values = <String>[vscodeDarkPlus, dracula, oneDarkPro];

  static String normalize(String? value) {
    final normalized = value?.trim();
    if (normalized == dracula || normalized == oneDarkPro) {
      return normalized!;
    }
    return vscodeDarkPlus;
  }
}

class CodexSettings {
  const CodexSettings({
    this.version = 1,
    this.enabled = true,
    this.authRef,
    this.model,
    this.openaiBaseUrl,
    this.approvalPolicy = 'never',
    this.personality = 'none',
    this.featuresMultiAgent = false,
    this.uiShowThinking = false,
    this.debugLogToFile = false,
    this.debugLogRetentionDays = 7,
    this.updateCheckOnLaunch = true,
    this.appLocalePreference = CodexLocalePreference.system,
    this.themeModePreference = CodexThemeModePreference.system,
    this.themePaletteSource = CodexThemePaletteSource.fixed,
    this.accentColorValue,
    this.lightCodeThemePreference = CodexLightCodeThemePreference.vscodeLight,
    this.darkCodeThemePreference = CodexDarkCodeThemePreference.vscodeDarkPlus,
    this.enabledGlobalMcpServerIds = const <String>[],
    this.extraConfigToml,
  });

  final int version;
  final bool enabled;
  final AuthRef? authRef;
  final String? model;
  final String? openaiBaseUrl;
  final String approvalPolicy;
  final String personality;
  final bool featuresMultiAgent;
  final bool uiShowThinking;
  final bool debugLogToFile;
  final int debugLogRetentionDays;
  final bool updateCheckOnLaunch;
  final String appLocalePreference;
  final String themeModePreference;
  final String themePaletteSource;
  final int? accentColorValue;
  final String lightCodeThemePreference;
  final String darkCodeThemePreference;
  final List<String> enabledGlobalMcpServerIds;
  final String? extraConfigToml;

  CodexSettings copyWith({
    bool? enabled,
    AuthRef? authRef,
    String? model,
    String? openaiBaseUrl,
    String? approvalPolicy,
    String? personality,
    bool? featuresMultiAgent,
    bool? uiShowThinking,
    bool? debugLogToFile,
    int? debugLogRetentionDays,
    bool? updateCheckOnLaunch,
    String? appLocalePreference,
    String? themeModePreference,
    String? themePaletteSource,
    int? accentColorValue,
    String? lightCodeThemePreference,
    String? darkCodeThemePreference,
    List<String>? enabledGlobalMcpServerIds,
    String? extraConfigToml,
    bool clearAuthRef = false,
    bool clearOpenaiBaseUrl = false,
    bool clearAccentColorValue = false,
  }) {
    return CodexSettings(
      version: 1,
      enabled: enabled ?? this.enabled,
      authRef: clearAuthRef ? null : (authRef ?? this.authRef),
      model: model ?? this.model,
      openaiBaseUrl: clearOpenaiBaseUrl
          ? null
          : (openaiBaseUrl ?? this.openaiBaseUrl),
      approvalPolicy: approvalPolicy ?? this.approvalPolicy,
      personality: personality ?? this.personality,
      featuresMultiAgent: featuresMultiAgent ?? this.featuresMultiAgent,
      uiShowThinking: uiShowThinking ?? this.uiShowThinking,
      debugLogToFile: debugLogToFile ?? this.debugLogToFile,
      debugLogRetentionDays:
          debugLogRetentionDays ?? this.debugLogRetentionDays,
      updateCheckOnLaunch: updateCheckOnLaunch ?? this.updateCheckOnLaunch,
      appLocalePreference: CodexLocalePreference.normalize(
        appLocalePreference ?? this.appLocalePreference,
      ),
      themeModePreference: CodexThemeModePreference.normalize(
        themeModePreference ?? this.themeModePreference,
      ),
      themePaletteSource: CodexThemePaletteSource.normalize(
        themePaletteSource ?? this.themePaletteSource,
      ),
      accentColorValue: clearAccentColorValue
          ? null
          : (accentColorValue ?? this.accentColorValue),
      lightCodeThemePreference: CodexLightCodeThemePreference.normalize(
        lightCodeThemePreference ?? this.lightCodeThemePreference,
      ),
      darkCodeThemePreference: CodexDarkCodeThemePreference.normalize(
        darkCodeThemePreference ?? this.darkCodeThemePreference,
      ),
      enabledGlobalMcpServerIds:
          enabledGlobalMcpServerIds ?? this.enabledGlobalMcpServerIds,
      extraConfigToml: extraConfigToml ?? this.extraConfigToml,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'version': version,
      'enabled': enabled,
      'authRef': authRef,
      'model': model,
      'openaiBaseUrl': openaiBaseUrl,
      'approvalPolicy': approvalPolicy,
      'personality': personality,
      'featuresMultiAgent': featuresMultiAgent,
      'uiShowThinking': uiShowThinking,
      'debugLogToFile': debugLogToFile,
      'debugLogRetentionDays': debugLogRetentionDays,
      'updateCheckOnLaunch': updateCheckOnLaunch,
      'appLocalePreference': appLocalePreference,
      'themeModePreference': themeModePreference,
      'themePaletteSource': themePaletteSource,
      'accentColorValue': accentColorValue,
      'lightCodeThemePreference': lightCodeThemePreference,
      'darkCodeThemePreference': darkCodeThemePreference,
      'enabledGlobalMcpServerIds': enabledGlobalMcpServerIds,
      'extraConfigToml': extraConfigToml,
    };
  }

  factory CodexSettings.fromMap(Map<String, Object?> map) {
    return CodexSettings(
      version: (map['version'] as num?)?.toInt() ?? 1,
      enabled: map['enabled'] as bool? ?? true,
      authRef: map['authRef']?.toString(),
      model: map['model']?.toString(),
      openaiBaseUrl: map['openaiBaseUrl']?.toString(),
      approvalPolicy: map['approvalPolicy']?.toString() ?? 'never',
      personality: map['personality']?.toString() ?? 'none',
      featuresMultiAgent: map['featuresMultiAgent'] as bool? ?? false,
      uiShowThinking: map['uiShowThinking'] as bool? ?? false,
      debugLogToFile: map['debugLogToFile'] as bool? ?? false,
      debugLogRetentionDays:
          (map['debugLogRetentionDays'] as num?)?.toInt() ?? 7,
      updateCheckOnLaunch: map['updateCheckOnLaunch'] as bool? ?? true,
      appLocalePreference: CodexLocalePreference.normalize(
        map['appLocalePreference']?.toString(),
      ),
      themeModePreference: CodexThemeModePreference.normalize(
        map['themeModePreference']?.toString(),
      ),
      themePaletteSource: CodexThemePaletteSource.normalize(
        map['themePaletteSource']?.toString(),
      ),
      accentColorValue: _normalizeArgbColorValue(map['accentColorValue']),
      lightCodeThemePreference: CodexLightCodeThemePreference.normalize(
        map['lightCodeThemePreference']?.toString(),
      ),
      darkCodeThemePreference: CodexDarkCodeThemePreference.normalize(
        map['darkCodeThemePreference']?.toString(),
      ),
      enabledGlobalMcpServerIds: _normalizeStringList(
        map['enabledGlobalMcpServerIds'],
      ),
      extraConfigToml: map['extraConfigToml']?.toString(),
    );
  }
}

class CodexSettingsStore {
  CodexSettingsStore({
    AppDirectoryService? appDirectoryService,
    AuthStore? authStore,
  }) : _appDirectoryService = appDirectoryService ?? AppDirectoryService(),
       _authStore = authStore ?? AuthStore();

  final AppDirectoryService _appDirectoryService;
  final AuthStore _authStore;

  List<String> normalizeEnabledGlobalMcpServerIds(Iterable<String> rawIds) {
    return _normalizeStringList(rawIds.toList(growable: false));
  }

  Future<CodexSettings> getSettings() async {
    final file = await _settingsFile();
    if (!file.existsSync()) {
      return const CodexSettings();
    }
    final parsed = jsonDecode(await file.readAsString());
    if (parsed is! Map) {
      return const CodexSettings();
    }
    return CodexSettings.fromMap(Map<String, Object?>.from(parsed));
  }

  Future<CodexSettings> saveSettings(CodexSettings settings) async {
    final normalized = settings.copyWith(
      enabledGlobalMcpServerIds: normalizeEnabledGlobalMcpServerIds(
        settings.enabledGlobalMcpServerIds,
      ),
    );
    final file = await _settingsFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(normalized.toMap()),
    );
    return normalized;
  }

  Future<CodexSettings> updateSettings(
    CodexSettings Function(CodexSettings current) update,
  ) async {
    final current = await getSettings();
    final next = update(current);
    return saveSettings(next);
  }

  Future<String?> getCodexApiKey() async {
    final settings = await getSettings();
    final authRef = settings.authRef;
    if (authRef == null || authRef.isEmpty) {
      return null;
    }
    final auth = await _authStore.loadAuth(authRef);
    return auth?['token']?.toString();
  }

  Future<CodexSettings> saveCodexApiKey(String apiKey) async {
    final ref = await _authStore.saveAuth(
      CodexProviderAuth(token: apiKey).toMap(),
    );
    return updateSettings((current) => current.copyWith(authRef: ref));
  }

  Future<CodexSettings> clearCodexApiKey() async {
    final current = await getSettings();
    final authRef = current.authRef;
    if (authRef != null && authRef.isNotEmpty) {
      await _authStore.deleteAuth(authRef);
    }
    return updateSettings((settings) => settings.copyWith(clearAuthRef: true));
  }

  Future<
    ({
      CodexSettings settings,
      String codexHomePath,
      String configTomlPath,
      String configToml,
      String authJsonPath,
      List<String>? warnings,
    })
  >
  materializeCodexConfigFiles({
    List<McpServer>? mcpServers,
    List<String>? enabledMcpServerIds,
  }) async {
    final settings = await getSettings();
    final effectiveEnabledMcpServerIds =
        enabledMcpServerIds ?? settings.enabledGlobalMcpServerIds;
    final codexHomeDir = await _appDirectoryService.codexHomeDir();
    final config = _composeStoredConfigToml(
      settings,
      mcpServers: mcpServers,
      enabledMcpServerIds: effectiveEnabledMcpServerIds,
    );
    final validationError = validateCodexConfigToml(config.cfg);
    if (validationError != null) {
      throw StateError(validationError);
    }
    final configFile = File('${codexHomeDir.path}/config.toml');
    await configFile.writeAsString(config.cfg);

    final authFile = File('${codexHomeDir.path}/auth.json');
    final apiKey = await getCodexApiKey();
    if (apiKey?.trim().isNotEmpty == true) {
      await authFile.writeAsString(generateCodexAuthJson(apiKey!.trim()));
    } else if (authFile.existsSync()) {
      await authFile.delete();
    }

    return (
      settings: settings,
      codexHomePath: codexHomeDir.path,
      configTomlPath: configFile.path,
      configToml: config.cfg,
      authJsonPath: authFile.path,
      warnings: config.warnings,
    );
  }

  String normalizeOpenaiBaseUrlForCodex(String input) {
    final raw = input.trim();
    if (raw.isEmpty) {
      return '';
    }
    var base = raw.replaceAll(RegExp(r'/+$'), '');
    if (base.endsWith('/models')) {
      base = base.substring(0, base.length - '/models'.length);
    }
    if (!base.endsWith('/v1')) {
      base = '$base/v1';
    }
    return base;
  }

  String resolveModelsListUrl(String? rawBaseUrl) {
    final raw = (rawBaseUrl ?? '').trim();
    final baseInput = raw.isEmpty ? 'https://api.openai.com/v1' : raw;
    final base = baseInput.replaceAll(RegExp(r'/+$'), '');
    if (raw.isNotEmpty &&
        !(base.startsWith('http://') || base.startsWith('https://'))) {
      throw StateError('服务器地址格式不正确（需以 http:// 或 https:// 开头）。');
    }
    if (base.endsWith('/models')) {
      return base;
    }
    if (base.endsWith('/v1')) {
      return '$base/models';
    }
    return '$base/v1/models';
  }

  Future<List<String>> fetchAvailableModels({
    String? draftBaseUrl,
    String? draftApiKey,
    HttpClient? httpClient,
  }) async {
    final apiKey = (draftApiKey ?? '').trim().isNotEmpty
        ? draftApiKey!.trim()
        : await getCodexApiKey();
    if (apiKey == null || apiKey.isEmpty) {
      throw StateError('请先设置密钥。');
    }

    final client = httpClient ?? HttpClient();
    final shouldCloseClient = httpClient == null;

    try {
      final uri = Uri.parse(resolveModelsListUrl(draftBaseUrl));
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $apiKey');
      final response = await request.close();
      final body = await response.transform(const Utf8Decoder()).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('无法获取模型列表：请检查服务器地址与密钥（HTTP ${response.statusCode}）。');
      }

      final parsed = jsonDecode(body);
      if (parsed is! Map) {
        return const <String>[];
      }
      final data = parsed['data'];
      if (data is! List) {
        return const <String>[];
      }
      final ids = <String>{};
      for (final item in data) {
        if (item is Map && item['id'] is String) {
          final id = (item['id'] as String).trim();
          if (id.isNotEmpty) {
            ids.add(id);
          }
        }
      }
      final out = ids.toList(growable: false)
        ..sort((left, right) => left.compareTo(right));
      return out;
    } on SocketException {
      throw StateError('无法连接到服务地址，请检查地址、网络连接或 DNS 配置。');
    } on HandshakeException {
      throw StateError('连接已建立，但证书校验失败；请检查 HTTPS 证书配置。');
    } finally {
      if (shouldCloseClient) {
        client.close(force: true);
      }
    }
  }

  String generateCodexConfigToml(CodexSettings settings) {
    final lines = <String>['# 由 CodexM 自动生成', '# 如需自定义，请在 Flutter 迁移设置中编辑', ''];
    if (settings.model?.trim().isNotEmpty == true) {
      lines.add('model = ${jsonEncode(settings.model!.trim())}');
    }
    lines.add('approval_policy = ${jsonEncode(settings.approvalPolicy)}');
    lines.add('model_provider = ${jsonEncode('openai')}');
    lines.add('sandbox_mode = ${jsonEncode('danger-full-access')}');
    lines.add('cli_auth_credentials_store = ${jsonEncode('file')}');

    final baseUrl = settings.openaiBaseUrl?.trim() ?? '';
    if (baseUrl.isNotEmpty) {
      final normalized = normalizeOpenaiBaseUrlForCodex(baseUrl);
      if (normalized.isNotEmpty) {
        lines.add('openai_base_url = ${jsonEncode(normalized)}');
      }
    }

    if (settings.featuresMultiAgent) {
      lines.add('');
      lines.add('[features]');
      lines.add('multi_agent = true');
    }

    lines.add('');
    return '${lines.join('\n')}\n';
  }

  String generateCodexAuthJson(String apiKey) {
    return '${const JsonEncoder.withIndent('  ').convert({'auth_mode': 'apikey', 'OPENAI_API_KEY': apiKey})}\n';
  }

  ({String configToml, List<String>? warnings, String? validationError})
  previewCodexConfigToml({
    required CodexSettings settings,
    List<McpServer>? mcpServers,
    List<String>? enabledMcpServerIds,
  }) {
    final composed = _composeStoredConfigToml(
      settings,
      mcpServers: mcpServers,
      enabledMcpServerIds:
          enabledMcpServerIds ?? settings.enabledGlobalMcpServerIds,
    );
    return (
      configToml: composed.cfg,
      warnings: composed.warnings,
      validationError: validateCodexConfigToml(composed.cfg),
    );
  }

  String? validateCodexConfigToml(String content, {String label = '配置'}) {
    return _validateTomlLikeText(content, label: label);
  }

  String? validateExtraConfigToml(String content) {
    final trimmed = content.replaceAll(RegExp(r'\r\n?'), '\n').trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final baseError = _validateTomlLikeText(trimmed, label: '补充内容');
    if (baseError != null) {
      return baseError;
    }

    final lines = trimmed.split('\n');
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final tableName = _tomlTableName(line);
      if (tableName == 'mcp_servers' || tableName.startsWith('mcp_servers.')) {
        return '服务器配置请在 MCP 页面管理，这里不要重复填写。';
      }
      final keyName = _tomlAssignmentKey(line);
      if (keyName == 'model' ||
          keyName == 'approval_policy' ||
          keyName == 'model_provider' ||
          keyName == 'sandbox_mode' ||
          keyName == 'cli_auth_credentials_store' ||
          keyName == 'openai_base_url' ||
          tableName == 'model_providers' ||
          tableName.startsWith('model_providers.') ||
          tableName == 'features') {
        return '这部分内容和上方表单重复，请直接修改对应设置项。';
      }
    }
    return null;
  }

  Future<File> _settingsFile() async {
    final dir = await _appDirectoryService.settingsDir();
    return File('${dir.path}/codex.json');
  }

  _ComposedToml _composeStoredConfigToml(
    CodexSettings settings, {
    List<McpServer>? mcpServers,
    List<String>? enabledMcpServerIds,
  }) {
    var cfg = _mergeToml(
      generateCodexConfigToml(settings),
      settings.extraConfigToml,
    );

    final enabled = (enabledMcpServerIds ?? const <String>[])
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    if (enabled.isNotEmpty && (mcpServers?.isNotEmpty ?? false)) {
      final snippet = _generateMcpServersToml(
        mcpServers!.where((server) => enabled.contains(server.id)).toList(),
      );
      if (snippet.trim().isNotEmpty) {
        cfg = '${cfg.trimRight()}\n\n${snippet.trim()}\n';
      }
    }

    return _ComposedToml(
      cfg: cfg.endsWith('\n') ? cfg : '$cfg\n',
      warnings: null,
    );
  }

  String _mergeToml(String baseToml, String? extraToml) {
    final base = baseToml.replaceAll(RegExp(r'\r\n?'), '\n').trimRight();
    final extra = (extraToml ?? '').replaceAll(RegExp(r'\r\n?'), '\n').trim();
    if (extra.isEmpty) {
      return '$base\n';
    }
    const extraHeader = '# 附加配置（由设置页插入）';
    final lines = base.split('\n');
    final firstTableIndex = lines.indexWhere((rawLine) {
      final line = rawLine.trim();
      return line.startsWith('[') && line.endsWith(']');
    });
    final extraBlock = '$extraHeader\n$extra';
    if (firstTableIndex == -1) {
      return '$base\n\n$extraBlock\n';
    }

    final head = lines.take(firstTableIndex).join('\n').trimRight();
    final tail = lines.skip(firstTableIndex).join('\n').trim();
    return '$head\n\n$extraBlock\n\n$tail\n';
  }

  String _generateMcpServersToml(List<McpServer> servers) {
    if (servers.isEmpty) {
      return '';
    }
    final lines = <String>['# MCP servers（由 CodexM 按全局配置注入）'];
    for (final server in servers.where(
      (server) => server.configKey.trim().isNotEmpty,
    )) {
      lines.add('');
      lines.add('[mcp_servers.${server.configKey.trim()}]');
      if (server.transport == 'url' && server.url?.trim().isNotEmpty == true) {
        lines.add('url = ${jsonEncode(server.url!.trim())}');
      } else if (server.command?.trim().isNotEmpty == true) {
        lines.add('command = ${jsonEncode(server.command!.trim())}');
        if (server.args != null && server.args!.isNotEmpty) {
          lines.add('args = ${jsonEncode(server.args)}');
        }
      }
    }
    return '${lines.join('\n')}\n';
  }
}

String _tomlAssignmentKey(String line) {
  final equalsIndex = line.indexOf('=');
  if (equalsIndex <= 0) {
    return '';
  }
  final key = line.substring(0, equalsIndex).trim();
  return _isTomlKey(key) ? key : '';
}

String _tomlTableName(String line) {
  if (!(line.startsWith('[') && line.endsWith(']'))) {
    return '';
  }
  return line.substring(1, line.length - 1).trim();
}

List<String> _normalizeStringList(Object? raw) {
  final items = raw is List ? raw : const <Object?>[];
  final seen = <String>{};
  final out = <String>[];
  for (final item in items) {
    final value = item?.toString().trim() ?? '';
    if (value.isEmpty || seen.contains(value)) {
      continue;
    }
    seen.add(value);
    out.add(value);
  }
  return out;
}

int? _normalizeArgbColorValue(Object? raw) {
  final value = raw is num ? raw.toInt() : int.tryParse(raw?.toString() ?? '');
  if (value == null || value < 0 || value > 0xFFFFFFFF) {
    return null;
  }
  if ((value & 0xFF000000) == 0) {
    return value | 0xFF000000;
  }
  return value;
}

class _ComposedToml {
  const _ComposedToml({required this.cfg, required this.warnings});

  final String cfg;
  final List<String>? warnings;
}

String? _validateTomlLikeText(String content, {required String label}) {
  final normalized = content.replaceAll(RegExp(r'\r\n?'), '\n').trim();
  if (normalized.isEmpty) {
    return '$label不能为空。';
  }

  final definedKeys = <String>{};
  final definedTables = <String>{};
  var currentTable = '';
  _PendingTomlValue? pendingValue;
  final lines = normalized.split('\n');

  for (var index = 0; index < lines.length; index++) {
    final rawLine = lines[index].trim();
    if (pendingValue != null) {
      final continuation = _scanTomlValue(
        rawLine,
        initialState: pendingValue.state,
      );
      if (continuation.error != null) {
        return '$label第 ${index + 1} 行有格式问题：${continuation.error}';
      }
      if (continuation.isComplete) {
        pendingValue = null;
      } else {
        pendingValue = _PendingTomlValue(
          startLine: pendingValue.startLine,
          state: continuation.state,
        );
      }
      continue;
    }

    if (rawLine.isEmpty || rawLine.startsWith('#')) {
      continue;
    }

    if (rawLine.startsWith('[')) {
      if (!rawLine.endsWith(']')) {
        return '$label第 ${index + 1} 行有格式问题：分组标题没有正确结束。';
      }
      final tableName = rawLine.substring(1, rawLine.length - 1).trim();
      if (tableName.isEmpty) {
        return '$label第 ${index + 1} 行有格式问题：分组名称为空。';
      }
      final segments = tableName.split('.');
      for (final segment in segments) {
        if (!_isTomlKey(segment)) {
          return '$label第 ${index + 1} 行有格式问题：分组名称不合法。';
        }
      }
      if (!definedTables.add(tableName)) {
        return '$label第 ${index + 1} 行有格式问题：分组重复定义。';
      }
      currentTable = tableName;
      continue;
    }

    final equalsIndex = rawLine.indexOf('=');
    if (equalsIndex <= 0 || equalsIndex == rawLine.length - 1) {
      return '$label第 ${index + 1} 行有格式问题：这一行缺少“=”号。';
    }
    final key = rawLine.substring(0, equalsIndex).trim();
    final value = rawLine.substring(equalsIndex + 1).trim();
    if (!_isTomlKey(key)) {
      return '$label第 ${index + 1} 行有格式问题：键名不合法。';
    }
    if (value.isEmpty) {
      return '$label第 ${index + 1} 行有格式问题：值不能为空。';
    }

    final valueState = _scanTomlValue(value);
    if (valueState.error != null) {
      return '$label第 ${index + 1} 行有格式问题：${valueState.error}';
    }

    final fullKey = currentTable.isEmpty ? key : '$currentTable.$key';
    if (!definedKeys.add(fullKey)) {
      return '$label第 ${index + 1} 行有格式问题：键重复定义。';
    }

    if (!valueState.isComplete) {
      pendingValue = _PendingTomlValue(
        startLine: index + 1,
        state: valueState.state,
      );
    }
  }

  if (pendingValue != null) {
    return '$label第 ${pendingValue.startLine} 行有格式问题：值没有正确结束。';
  }

  return null;
}

class _PendingTomlValue {
  const _PendingTomlValue({required this.startLine, required this.state});

  final int startLine;
  final _TomlValueState state;
}

class _TomlValueState {
  const _TomlValueState({
    this.inBasicString = false,
    this.inLiteralString = false,
    this.inMultilineBasicString = false,
    this.inMultilineLiteralString = false,
    this.arrayDepth = 0,
    this.inlineTableDepth = 0,
  });

  final bool inBasicString;
  final bool inLiteralString;
  final bool inMultilineBasicString;
  final bool inMultilineLiteralString;
  final int arrayDepth;
  final int inlineTableDepth;

  bool get isComplete =>
      !inBasicString &&
      !inLiteralString &&
      !inMultilineBasicString &&
      !inMultilineLiteralString &&
      arrayDepth == 0 &&
      inlineTableDepth == 0;

  _TomlValueState copyWith({
    bool? inBasicString,
    bool? inLiteralString,
    bool? inMultilineBasicString,
    bool? inMultilineLiteralString,
    int? arrayDepth,
    int? inlineTableDepth,
  }) {
    return _TomlValueState(
      inBasicString: inBasicString ?? this.inBasicString,
      inLiteralString: inLiteralString ?? this.inLiteralString,
      inMultilineBasicString:
          inMultilineBasicString ?? this.inMultilineBasicString,
      inMultilineLiteralString:
          inMultilineLiteralString ?? this.inMultilineLiteralString,
      arrayDepth: arrayDepth ?? this.arrayDepth,
      inlineTableDepth: inlineTableDepth ?? this.inlineTableDepth,
    );
  }
}

class _TomlValueScanResult {
  const _TomlValueScanResult({
    required this.state,
    required this.isComplete,
    this.error,
  });

  final _TomlValueState state;
  final bool isComplete;
  final String? error;
}

_TomlValueScanResult _scanTomlValue(
  String value, {
  _TomlValueState initialState = const _TomlValueState(),
}) {
  var state = initialState;

  for (var index = 0; index < value.length; index++) {
    if (state.inMultilineBasicString) {
      final closingIndex = value.indexOf('"""', index);
      if (closingIndex == -1) {
        return _TomlValueScanResult(state: state, isComplete: false);
      }
      state = state.copyWith(inMultilineBasicString: false);
      index = closingIndex + 2;
      continue;
    }
    if (state.inMultilineLiteralString) {
      final closingIndex = value.indexOf("'''", index);
      if (closingIndex == -1) {
        return _TomlValueScanResult(state: state, isComplete: false);
      }
      state = state.copyWith(inMultilineLiteralString: false);
      index = closingIndex + 2;
      continue;
    }

    final char = value[index];
    if (state.inBasicString) {
      if (char == r'\') {
        index++;
        continue;
      }
      if (char == '"') {
        state = state.copyWith(inBasicString: false);
      }
      continue;
    }
    if (state.inLiteralString) {
      if (char == "'") {
        state = state.copyWith(inLiteralString: false);
      }
      continue;
    }

    if (char == '#') {
      break;
    }
    if (value.startsWith('"""', index)) {
      state = state.copyWith(inMultilineBasicString: true);
      index += 2;
      continue;
    }
    if (value.startsWith("'''", index)) {
      state = state.copyWith(inMultilineLiteralString: true);
      index += 2;
      continue;
    }
    if (char == '"') {
      state = state.copyWith(inBasicString: true);
      continue;
    }
    if (char == "'") {
      state = state.copyWith(inLiteralString: true);
      continue;
    }
    if (char == '[') {
      state = state.copyWith(arrayDepth: state.arrayDepth + 1);
      continue;
    }
    if (char == ']') {
      if (state.arrayDepth == 0) {
        return _TomlValueScanResult(
          state: state,
          isComplete: false,
          error: '数组结束位置不正确。',
        );
      }
      state = state.copyWith(arrayDepth: state.arrayDepth - 1);
      continue;
    }
    if (char == '{') {
      state = state.copyWith(inlineTableDepth: state.inlineTableDepth + 1);
      continue;
    }
    if (char == '}') {
      if (state.inlineTableDepth == 0) {
        return _TomlValueScanResult(
          state: state,
          isComplete: false,
          error: '内联表结束位置不正确。',
        );
      }
      state = state.copyWith(inlineTableDepth: state.inlineTableDepth - 1);
    }
  }

  if (state.inBasicString || state.inLiteralString) {
    return _TomlValueScanResult(
      state: state,
      isComplete: false,
      error: '普通字符串不能直接换行，请改用 TOML 多行字符串。',
    );
  }

  return _TomlValueScanResult(state: state, isComplete: state.isComplete);
}

bool _isTomlKey(String value) {
  return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(value);
}
