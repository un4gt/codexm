import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/adaptive_breakpoints.dart';
import '../../../../shared/widgets/stitch_ui.dart';
import '../../../mcp/application/mcp_models.dart';
import '../../../mcp/application/mcp_store.dart';
import '../../../update/presentation/update_page.dart';
import '../../application/codex_settings_store.dart';
part 'settings_page_sections.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    this.onLocalePreferenceChanged,
    this.onSettingsChanged,
  });

  final ValueChanged<Locale?>? onLocalePreferenceChanged;
  final ValueChanged<CodexSettings>? onSettingsChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settingsStore = CodexSettingsStore();
  final _mcpStore = McpStore();

  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _extraConfigTomlController;

  String _status = '';
  CodexSettings _settings = const CodexSettings();
  bool _busy = false;
  String? _apiKeyValue;
  bool _apiKeyVisible = false;
  List<String> _availableModels = const <String>[];
  bool _modelsLoading = false;
  String _configPreviewToml = '';
  List<String> _configWarnings = const <String>[];
  String? _configPreviewValidationError;
  String? _extraConfigValidationError;
  List<McpServer> _mcpServers = const <McpServer>[];
  bool _suspendConfigDraftListeners = false;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _baseUrlController = TextEditingController();
    _extraConfigTomlController = TextEditingController();
    _baseUrlController.addListener(_handleConfigDraftChanged);
    _extraConfigTomlController.addListener(_handleConfigDraftChanged);
    _loadSnapshot();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _extraConfigTomlController.dispose();
    super.dispose();
  }

  Future<void> _loadSnapshot({String? status}) async {
    try {
      final settings = await _settingsStore.getSettings();
      final apiKey = await _settingsStore.getCodexApiKey();
      final mcpServers = await _mcpStore.listServers();
      final preview = _settingsStore.previewCodexConfigToml(
        settings: settings,
        mcpServers: mcpServers,
        enabledMcpServerIds: settings.enabledGlobalMcpServerIds,
      );
      if (!mounted) {
        return;
      }

      _apiKeyController.text = apiKey?.trim() ?? '';
      _suspendConfigDraftListeners = true;
      _baseUrlController.text = settings.openaiBaseUrl ?? '';
      _extraConfigTomlController.text =
          settings.extraConfigToml?.trimRight() ?? '';
      _suspendConfigDraftListeners = false;
      setState(() {
        _settings = settings;
        _mcpServers = mcpServers;
        _apiKeyValue = apiKey;
        _configPreviewToml = preview.configToml.trimRight();
        _configWarnings = preview.warnings ?? const <String>[];
        _configPreviewValidationError = preview.validationError;
        _extraConfigValidationError = null;
        _status = status ?? '';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _status = l10n.settingsLoadFailed(error.toString());
      });
    }
  }

  void _handleConfigDraftChanged() {
    if (!mounted || _suspendConfigDraftListeners) {
      return;
    }
    final normalizedExtra = _extraConfigTomlController.text
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .trim();
    final draftSettings = _settings.copyWith(
      openaiBaseUrl: _baseUrlController.text.trim().isEmpty
          ? null
          : _baseUrlController.text.trim(),
      clearOpenaiBaseUrl: _baseUrlController.text.trim().isEmpty,
      extraConfigToml: normalizedExtra.isEmpty ? '' : '$normalizedExtra\n',
    );
    final preview = _settingsStore.previewCodexConfigToml(
      settings: draftSettings,
      mcpServers: _mcpServers,
      enabledMcpServerIds: draftSettings.enabledGlobalMcpServerIds,
    );
    final extraValidationError = _settingsStore.validateExtraConfigToml(
      normalizedExtra,
    );
    setState(() {
      _configPreviewToml = preview.configToml.trimRight();
      _configWarnings = preview.warnings ?? const <String>[];
      _configPreviewValidationError = preview.validationError;
      _extraConfigValidationError = extraValidationError;
    });
  }

  Future<void> _saveConnectionDrafts() async {
    final apiKey = _apiKeyController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    final l10n = AppLocalizations.of(context);
    await _runAction(l10n.settingsConnectionSaving, () async {
      if (apiKey.isEmpty) {
        await _settingsStore.clearCodexApiKey();
      } else {
        await _settingsStore.saveCodexApiKey(apiKey);
      }
      await _settingsStore.updateSettings(
        (current) => current.copyWith(
          openaiBaseUrl: baseUrl.isEmpty ? null : baseUrl,
          clearOpenaiBaseUrl: baseUrl.isEmpty,
        ),
      );
      await _syncRuntimeConfigFiles();
      if (apiKey.isEmpty && baseUrl.isEmpty) {
        return l10n.settingsConnectionCleared;
      }
      if (apiKey.isEmpty) {
        return l10n.settingsConnectionBaseSavedKeyCleared;
      }
      if (baseUrl.isEmpty) {
        return l10n.settingsConnectionKeySavedBaseCleared;
      }
      return l10n.settingsConnectionSaved;
    }, refreshModelsAfterSuccess: true);
  }

  Future<void> _syncRuntimeConfigFiles() async {
    final mcpServers = await _mcpStore.listServers();
    await _settingsStore.materializeCodexConfigFiles(mcpServers: mcpServers);
  }

  Future<void> _saveExtraConfigTomlDraft() async {
    final normalized = _extraConfigTomlController.text
        .replaceAll(RegExp(r'\r\n?'), '\n')
        .trim();
    final validationError = _settingsStore.validateExtraConfigToml(normalized);
    if (validationError != null) {
      final l10n = AppLocalizations.of(context);
      setState(() {
        _extraConfigValidationError = validationError;
        _status = l10n.settingsExtraConfigSaveFailed(validationError);
      });
      return;
    }

    final l10n = AppLocalizations.of(context);
    await _runAction(l10n.settingsExtraConfigSaving, () async {
      await _settingsStore.updateSettings(
        (current) => current.copyWith(
          extraConfigToml: normalized.isEmpty ? '' : '$normalized\n',
        ),
      );
      await _syncRuntimeConfigFiles();
      if (normalized.isEmpty) {
        return l10n.settingsExtraConfigClearedRuntime;
      }
      return l10n.settingsExtraConfigSaved;
    });
  }

  Future<void> _clearExtraConfigTomlDraft() async {
    final l10n = AppLocalizations.of(context);
    if ((_settings.extraConfigToml?.trim().isEmpty ?? true) &&
        _extraConfigTomlController.text.trim().isEmpty) {
      setState(() {
        _extraConfigValidationError = null;
        _status = l10n.settingsExtraConfigAlreadyBlank;
      });
      return;
    }

    await _runAction(l10n.settingsExtraConfigClearing, () async {
      await _settingsStore.updateSettings(
        (current) => current.copyWith(extraConfigToml: ''),
      );
      await _syncRuntimeConfigFiles();
      return l10n.settingsExtraConfigCleared;
    });
  }

  Future<void> _refreshModels({
    String? statusOnEmpty,
    String? statusOnSuccess,
    String Function(String error)? statusOnError,
  }) async {
    if (_modelsLoading) {
      return;
    }
    setState(() {
      _modelsLoading = true;
    });
    try {
      final models = await _settingsStore.fetchAvailableModels(
        draftBaseUrl: _baseUrlController.text,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _availableModels = models;
        _status = models.isEmpty
            ? (statusOnEmpty ??
                  AppLocalizations.of(context).settingsModelsEmpty)
            : (statusOnSuccess ??
                  AppLocalizations.of(context).settingsModelsRefreshed);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      final errorText = error.toString();
      setState(() {
        _status =
            statusOnError?.call(errorText) ??
            l10n.settingsModelsFetchFailed(errorText);
      });
    } finally {
      if (mounted) {
        setState(() {
          _modelsLoading = false;
        });
      }
    }
  }

  Future<void> _refreshModelsAfterConnectionSaved(String successStatus) async {
    final hasApiKey = (_apiKeyValue ?? '').trim().isNotEmpty;
    if (!hasApiKey) {
      if (!mounted) {
        return;
      }
      setState(() {
        _availableModels = const <String>[];
        _status = successStatus;
      });
      return;
    }
    final l10n = AppLocalizations.of(context);
    await _refreshModels(
      statusOnEmpty: l10n.settingsConnectionSavedModelsEmpty(successStatus),
      statusOnSuccess: l10n.settingsConnectionSavedModelsRefreshed(
        successStatus,
      ),
      statusOnError: (error) =>
          l10n.settingsConnectionSavedModelsFetchFailed(successStatus, error),
    );
  }

  Future<void> _updatePreference(
    CodexSettings Function(CodexSettings current) update, {
    required String status,
    bool syncRuntimeConfig = false,
  }) {
    return _runAction(
      AppLocalizations.of(context).settingsSavingPreferences,
      () async {
        final next = update(_settings);
        final saved = await _settingsStore.saveSettings(next);
        if (syncRuntimeConfig) {
          await _syncRuntimeConfigFiles();
        }
        if (mounted) {
          setState(() {
            _settings = saved;
          });
        }
        widget.onSettingsChanged?.call(saved);
        return status;
      },
    );
  }

  Future<void> _updateLocalePreference(String value) {
    final l10n = AppLocalizations.of(context);
    return _runAction(l10n.settingsSavingPreferences, () async {
      final saved = await _settingsStore.updateSettings(
        (current) => current.copyWith(appLocalePreference: value),
      );
      widget.onLocalePreferenceChanged?.call(
        CodexLocalePreference.toLocale(saved.appLocalePreference),
      );
      widget.onSettingsChanged?.call(saved);
      if (mounted) {
        setState(() {
          _settings = saved;
        });
      }
      return l10n.settingsLanguageUpdated;
    });
  }

  Future<void> _runAction(
    String pendingStatus,
    Future<String> Function() action, {
    bool refreshModelsAfterSuccess = false,
  }) async {
    if (_busy) {
      return;
    }

    setState(() {
      _busy = true;
      _status = pendingStatus;
    });

    try {
      final successStatus = await action();
      await _loadSnapshot(status: successStatus);
      if (refreshModelsAfterSuccess) {
        await _refreshModelsAfterConnectionSaved(successStatus);
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() {
        _status = l10n.settingsActionFailed(error.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _openUpdatePage() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const UpdatePage()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return StitchPageScaffold(
      pageTitle: l10n.settingsPageTitle,
      brandIcon: Icons.settings_outlined,
      kickerText: l10n.settingsKicker,
      topActions: [
        IconButton.filledTonal(
          onPressed: _busy ? null : _refreshModels,
          tooltip: l10n.settingsRefreshModelsTooltip,
          icon: _modelsLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh_outlined),
        ),
      ],
      children: [
        if (_status.trim().isNotEmpty)
          StitchInfoBanner(
            icon: Icons.info_outline,
            title: l10n.settingsStatusTitle,
            subtitle: _status,
          ),
        _UpdateEntrySection(busy: _busy, onOpenUpdatePage: _openUpdatePage),
        _ConnectionSection(
          apiKeyController: _apiKeyController,
          apiKeyVisible: _apiKeyVisible,
          baseUrlController: _baseUrlController,
          busy: _busy,
          modelsLoading: _modelsLoading,
          availableModels: _availableModels,
          selectedModel: _settings.model,
          onToggleApiKeyVisible: () {
            if (_busy) {
              return;
            }
            setState(() {
              _apiKeyVisible = !_apiKeyVisible;
            });
          },
          onSaveConnection: _saveConnectionDrafts,
          onSelectModel: (value) {
            if (_busy) {
              return;
            }
            _updatePreference(
              (current) => current.copyWith(model: value),
              status: l10n.settingsModelUpdated(value),
              syncRuntimeConfig: true,
            );
          },
        ),
        _ConfigTomlSection(
          busy: _busy,
          previewConfigToml: _configPreviewToml,
          extraConfigTomlController: _extraConfigTomlController,
          warnings: _configWarnings,
          previewValidationError: _configPreviewValidationError,
          extraConfigValidationError: _extraConfigValidationError,
          onSaveExtraConfigToml: _saveExtraConfigTomlDraft,
          onClearExtraConfigToml: _clearExtraConfigTomlDraft,
        ),
        _AppearanceSection(
          settings: _settings,
          busy: _busy,
          onUpdatePreference: _updatePreference,
        ),
        _PreferenceSection(
          settings: _settings,
          busy: _busy,
          onUpdatePreference: _updatePreference,
          onUpdateLocalePreference: _updateLocalePreference,
        ),
        if (_busy) const _BusySettingsCard(),
      ],
    );
  }
}
