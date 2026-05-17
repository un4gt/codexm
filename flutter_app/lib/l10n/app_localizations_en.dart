// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'CodexM';

  @override
  String get navWorkspaces => 'Workspaces';

  @override
  String get navSessions => 'Sessions';

  @override
  String get navMcpSkills => 'MCP & Skills';

  @override
  String get navSettings => 'Settings';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonCopiedToClipboard => 'Copied to clipboard.';

  @override
  String get commonExpand => 'Expand';

  @override
  String get commonCollapse => 'Collapse';

  @override
  String get statusRunning => 'Running';

  @override
  String get statusCompleted => 'Done';

  @override
  String get statusFailed => 'Failed';

  @override
  String get statusDeclined => 'Declined';

  @override
  String get statusWaiting => 'Waiting';

  @override
  String get sessionComposerMentionLoading => 'Searching files and commits...';

  @override
  String get sessionComposerMentionEmpty => 'No matching files or commits.';

  @override
  String get sessionComposerMentionFile => 'File';

  @override
  String get sessionComposerMentionCommit => 'Commit';

  @override
  String get settingsPageTitle => 'Settings';

  @override
  String get settingsKicker => 'Preferences and connection';

  @override
  String get settingsRefreshModelsTooltip => 'Refresh model list';

  @override
  String get settingsStatusTitle => 'Settings status';

  @override
  String settingsLoadFailed(String error) {
    return 'Failed to load settings: $error';
  }

  @override
  String get settingsSavingPreferences => 'Saving preferences...';

  @override
  String settingsActionFailed(String error) {
    return 'Action failed: $error';
  }

  @override
  String get settingsSystemSection => 'System';

  @override
  String get settingsAppUpdates => 'App updates';

  @override
  String get settingsLanguageTitle => 'App language';

  @override
  String get settingsLanguageSystem => 'Follow system';

  @override
  String get settingsLanguageEnglish => 'English';

  @override
  String get settingsLanguageChineseSimplified => 'Simplified Chinese';

  @override
  String get settingsLanguageUpdated => 'Language preference updated.';

  @override
  String get settingsConnectionSection => 'Connection';

  @override
  String get settingsDefaultValue => 'Default';

  @override
  String get settingsHide => 'Hide';

  @override
  String get settingsShow => 'Show';

  @override
  String get settingsBaseUrlOptional => 'Base URL (optional)';

  @override
  String get settingsSave => 'Save';

  @override
  String get settingsDefaultModel => 'Default model';

  @override
  String get settingsChooseModel => 'Choose model';

  @override
  String get settingsModelsEmpty => 'No available models returned.';

  @override
  String get settingsModelsRefreshed => 'Model list refreshed.';

  @override
  String settingsModelsFetchFailed(String error) {
    return 'Failed to fetch model list: $error';
  }

  @override
  String get settingsConnectionSaving => 'Saving connection settings...';

  @override
  String get settingsConnectionCleared => 'API key and service URL cleared.';

  @override
  String get settingsConnectionBaseSavedKeyCleared =>
      'Service URL saved and API key cleared.';

  @override
  String get settingsConnectionKeySavedBaseCleared =>
      'API key saved and service URL cleared.';

  @override
  String get settingsConnectionSaved => 'API key and service URL saved.';

  @override
  String settingsConnectionSavedModelsEmpty(String status) {
    return '$status No available models returned.';
  }

  @override
  String settingsConnectionSavedModelsRefreshed(String status) {
    return '$status Model list refreshed.';
  }

  @override
  String settingsConnectionSavedModelsFetchFailed(String status, String error) {
    return '$status Failed to fetch model list: $error';
  }

  @override
  String settingsModelUpdated(String model) {
    return 'Model updated to: $model';
  }

  @override
  String get settingsAdvancedConfig => 'Advanced config';

  @override
  String get settingsEffectivePreview => 'Effective preview';

  @override
  String get settingsNoPreviewContent => '# No preview content';

  @override
  String get settingsExtraConfig => 'Extra config';

  @override
  String get settingsExtraConfigItems => 'Extra config entries';

  @override
  String get settingsExtraConfigHelp =>
      'Extra config is inserted after generated top-level keys and before sections. Do not repeat connection, model, features, or MCP server settings here.';

  @override
  String get settingsSaveContent => 'Save content';

  @override
  String get settingsClearContent => 'Clear content';

  @override
  String settingsExtraConfigSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get settingsExtraConfigSaving => 'Saving extra config...';

  @override
  String get settingsExtraConfigClearedRuntime =>
      'Extra config cleared. Only generated content is used now.';

  @override
  String get settingsExtraConfigSaved => 'Extra config saved.';

  @override
  String get settingsExtraConfigAlreadyBlank =>
      'Extra config is already blank.';

  @override
  String get settingsExtraConfigClearing => 'Clearing extra config...';

  @override
  String get settingsExtraConfigCleared => 'Extra config cleared.';

  @override
  String get settingsInteractionPreferences => 'Interaction preferences';

  @override
  String get settingsShowReasoning => 'Show reasoning';

  @override
  String get settingsShowReasoningOn => 'Reasoning display enabled.';

  @override
  String get settingsShowReasoningOff => 'Reasoning display disabled.';

  @override
  String get settingsRunLogs => 'Runtime logs';

  @override
  String get settingsRunLogsOn => 'Runtime logs enabled.';

  @override
  String get settingsRunLogsOff => 'Runtime logs disabled.';

  @override
  String settingsLogRetentionDays(int days) {
    return 'Log retention: $days days';
  }

  @override
  String get settingsLogRetentionUpdated => 'Log retention updated.';

  @override
  String get settingsSyncing => 'Syncing settings';
}
