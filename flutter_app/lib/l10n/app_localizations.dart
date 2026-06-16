import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'CodexM'**
  String get appTitle;

  /// No description provided for @navWorkspaces.
  ///
  /// In en, this message translates to:
  /// **'Workspaces'**
  String get navWorkspaces;

  /// No description provided for @navSessions.
  ///
  /// In en, this message translates to:
  /// **'Sessions'**
  String get navSessions;

  /// No description provided for @navMcpSkills.
  ///
  /// In en, this message translates to:
  /// **'MCP & Skills'**
  String get navMcpSkills;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @settingsPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsPageTitle;

  /// No description provided for @settingsKicker.
  ///
  /// In en, this message translates to:
  /// **'Preferences and connection'**
  String get settingsKicker;

  /// No description provided for @settingsRefreshModelsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh model list'**
  String get settingsRefreshModelsTooltip;

  /// No description provided for @settingsStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings status'**
  String get settingsStatusTitle;

  /// No description provided for @settingsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load settings: {error}'**
  String settingsLoadFailed(String error);

  /// No description provided for @settingsSavingPreferences.
  ///
  /// In en, this message translates to:
  /// **'Saving preferences...'**
  String get settingsSavingPreferences;

  /// No description provided for @settingsActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String settingsActionFailed(String error);

  /// No description provided for @settingsSystemSection.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsSystemSection;

  /// No description provided for @settingsAppUpdates.
  ///
  /// In en, this message translates to:
  /// **'App updates'**
  String get settingsAppUpdates;

  /// No description provided for @settingsLanguageTitle.
  ///
  /// In en, this message translates to:
  /// **'App language'**
  String get settingsLanguageTitle;

  /// No description provided for @settingsLanguageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingsLanguageSystem;

  /// No description provided for @settingsLanguageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get settingsLanguageEnglish;

  /// No description provided for @settingsLanguageChineseSimplified.
  ///
  /// In en, this message translates to:
  /// **'Simplified Chinese'**
  String get settingsLanguageChineseSimplified;

  /// No description provided for @settingsLanguageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Language preference updated.'**
  String get settingsLanguageUpdated;

  /// No description provided for @settingsConnectionSection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get settingsConnectionSection;

  /// No description provided for @settingsDefaultValue.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get settingsDefaultValue;

  /// No description provided for @settingsHide.
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get settingsHide;

  /// No description provided for @settingsShow.
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get settingsShow;

  /// No description provided for @settingsBaseUrlOptional.
  ///
  /// In en, this message translates to:
  /// **'Base URL (optional)'**
  String get settingsBaseUrlOptional;

  /// No description provided for @settingsSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get settingsSave;

  /// No description provided for @settingsDefaultModel.
  ///
  /// In en, this message translates to:
  /// **'Default model'**
  String get settingsDefaultModel;

  /// No description provided for @settingsChooseModel.
  ///
  /// In en, this message translates to:
  /// **'Choose model'**
  String get settingsChooseModel;

  /// No description provided for @settingsModelsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No available models returned.'**
  String get settingsModelsEmpty;

  /// No description provided for @settingsModelsRefreshed.
  ///
  /// In en, this message translates to:
  /// **'Model list refreshed.'**
  String get settingsModelsRefreshed;

  /// No description provided for @settingsModelsFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch model list: {error}'**
  String settingsModelsFetchFailed(String error);

  /// No description provided for @settingsConnectionSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving connection settings...'**
  String get settingsConnectionSaving;

  /// No description provided for @settingsConnectionCleared.
  ///
  /// In en, this message translates to:
  /// **'API key and service URL cleared.'**
  String get settingsConnectionCleared;

  /// No description provided for @settingsConnectionBaseSavedKeyCleared.
  ///
  /// In en, this message translates to:
  /// **'Service URL saved and API key cleared.'**
  String get settingsConnectionBaseSavedKeyCleared;

  /// No description provided for @settingsConnectionKeySavedBaseCleared.
  ///
  /// In en, this message translates to:
  /// **'API key saved and service URL cleared.'**
  String get settingsConnectionKeySavedBaseCleared;

  /// No description provided for @settingsConnectionSaved.
  ///
  /// In en, this message translates to:
  /// **'API key and service URL saved.'**
  String get settingsConnectionSaved;

  /// No description provided for @settingsConnectionSavedModelsEmpty.
  ///
  /// In en, this message translates to:
  /// **'{status} No available models returned.'**
  String settingsConnectionSavedModelsEmpty(String status);

  /// No description provided for @settingsConnectionSavedModelsRefreshed.
  ///
  /// In en, this message translates to:
  /// **'{status} Model list refreshed.'**
  String settingsConnectionSavedModelsRefreshed(String status);

  /// No description provided for @settingsConnectionSavedModelsFetchFailed.
  ///
  /// In en, this message translates to:
  /// **'{status} Failed to fetch model list: {error}'**
  String settingsConnectionSavedModelsFetchFailed(String status, String error);

  /// No description provided for @settingsModelUpdated.
  ///
  /// In en, this message translates to:
  /// **'Model updated to: {model}'**
  String settingsModelUpdated(String model);

  /// No description provided for @settingsAdvancedConfig.
  ///
  /// In en, this message translates to:
  /// **'Advanced config'**
  String get settingsAdvancedConfig;

  /// No description provided for @settingsEffectivePreview.
  ///
  /// In en, this message translates to:
  /// **'Effective preview'**
  String get settingsEffectivePreview;

  /// No description provided for @settingsNoPreviewContent.
  ///
  /// In en, this message translates to:
  /// **'# No preview content'**
  String get settingsNoPreviewContent;

  /// No description provided for @settingsExtraConfig.
  ///
  /// In en, this message translates to:
  /// **'Extra config'**
  String get settingsExtraConfig;

  /// No description provided for @settingsExtraConfigItems.
  ///
  /// In en, this message translates to:
  /// **'Extra config entries'**
  String get settingsExtraConfigItems;

  /// No description provided for @settingsExtraConfigHelp.
  ///
  /// In en, this message translates to:
  /// **'Extra config is inserted after generated top-level keys and before sections. Do not repeat connection, model, features, or MCP server settings here.'**
  String get settingsExtraConfigHelp;

  /// No description provided for @settingsSaveContent.
  ///
  /// In en, this message translates to:
  /// **'Save content'**
  String get settingsSaveContent;

  /// No description provided for @settingsClearContent.
  ///
  /// In en, this message translates to:
  /// **'Clear content'**
  String get settingsClearContent;

  /// No description provided for @settingsExtraConfigSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String settingsExtraConfigSaveFailed(String error);

  /// No description provided for @settingsExtraConfigSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving extra config...'**
  String get settingsExtraConfigSaving;

  /// No description provided for @settingsExtraConfigClearedRuntime.
  ///
  /// In en, this message translates to:
  /// **'Extra config cleared. Only generated content is used now.'**
  String get settingsExtraConfigClearedRuntime;

  /// No description provided for @settingsExtraConfigSaved.
  ///
  /// In en, this message translates to:
  /// **'Extra config saved.'**
  String get settingsExtraConfigSaved;

  /// No description provided for @settingsExtraConfigAlreadyBlank.
  ///
  /// In en, this message translates to:
  /// **'Extra config is already blank.'**
  String get settingsExtraConfigAlreadyBlank;

  /// No description provided for @settingsExtraConfigClearing.
  ///
  /// In en, this message translates to:
  /// **'Clearing extra config...'**
  String get settingsExtraConfigClearing;

  /// No description provided for @settingsExtraConfigCleared.
  ///
  /// In en, this message translates to:
  /// **'Extra config cleared.'**
  String get settingsExtraConfigCleared;

  /// No description provided for @settingsAppearanceSection.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearanceSection;

  /// No description provided for @settingsThemeModeTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get settingsThemeModeTitle;

  /// No description provided for @settingsThemeModeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get settingsThemeModeSystem;

  /// No description provided for @settingsThemeModeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeModeLight;

  /// No description provided for @settingsThemeModeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeModeDark;

  /// No description provided for @settingsPaletteTitle.
  ///
  /// In en, this message translates to:
  /// **'Palette source'**
  String get settingsPaletteTitle;

  /// No description provided for @settingsPaletteFixed.
  ///
  /// In en, this message translates to:
  /// **'CodexM fixed palette'**
  String get settingsPaletteFixed;

  /// No description provided for @settingsPaletteDynamic.
  ///
  /// In en, this message translates to:
  /// **'Material You'**
  String get settingsPaletteDynamic;

  /// No description provided for @settingsPaletteCustomAccent.
  ///
  /// In en, this message translates to:
  /// **'Custom accent'**
  String get settingsPaletteCustomAccent;

  /// No description provided for @settingsAccentColor.
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get settingsAccentColor;

  /// No description provided for @settingsLightCodeTheme.
  ///
  /// In en, this message translates to:
  /// **'Light code theme'**
  String get settingsLightCodeTheme;

  /// No description provided for @settingsDarkCodeTheme.
  ///
  /// In en, this message translates to:
  /// **'Dark code theme'**
  String get settingsDarkCodeTheme;

  /// No description provided for @settingsCodeThemeVscodeLight.
  ///
  /// In en, this message translates to:
  /// **'VSCode Light'**
  String get settingsCodeThemeVscodeLight;

  /// No description provided for @settingsCodeThemeGithubLight.
  ///
  /// In en, this message translates to:
  /// **'GitHub Light'**
  String get settingsCodeThemeGithubLight;

  /// No description provided for @settingsCodeThemeVscodeDarkPlus.
  ///
  /// In en, this message translates to:
  /// **'VSCode Dark+'**
  String get settingsCodeThemeVscodeDarkPlus;

  /// No description provided for @settingsCodeThemeDracula.
  ///
  /// In en, this message translates to:
  /// **'Dracula'**
  String get settingsCodeThemeDracula;

  /// No description provided for @settingsCodeThemeOneDarkPro.
  ///
  /// In en, this message translates to:
  /// **'One Dark Pro'**
  String get settingsCodeThemeOneDarkPro;

  /// No description provided for @settingsAppearanceUpdated.
  ///
  /// In en, this message translates to:
  /// **'Appearance preference updated.'**
  String get settingsAppearanceUpdated;

  /// No description provided for @settingsInteractionPreferences.
  ///
  /// In en, this message translates to:
  /// **'Interaction preferences'**
  String get settingsInteractionPreferences;

  /// No description provided for @settingsShowReasoning.
  ///
  /// In en, this message translates to:
  /// **'Show reasoning'**
  String get settingsShowReasoning;

  /// No description provided for @settingsShowReasoningOn.
  ///
  /// In en, this message translates to:
  /// **'Reasoning display enabled.'**
  String get settingsShowReasoningOn;

  /// No description provided for @settingsShowReasoningOff.
  ///
  /// In en, this message translates to:
  /// **'Reasoning display disabled.'**
  String get settingsShowReasoningOff;

  /// No description provided for @settingsRunLogs.
  ///
  /// In en, this message translates to:
  /// **'Runtime logs'**
  String get settingsRunLogs;

  /// No description provided for @settingsRunLogsOn.
  ///
  /// In en, this message translates to:
  /// **'Runtime logs enabled.'**
  String get settingsRunLogsOn;

  /// No description provided for @settingsRunLogsOff.
  ///
  /// In en, this message translates to:
  /// **'Runtime logs disabled.'**
  String get settingsRunLogsOff;

  /// No description provided for @settingsLogRetentionDays.
  ///
  /// In en, this message translates to:
  /// **'Log retention: {days} days'**
  String settingsLogRetentionDays(int days);

  /// No description provided for @settingsLogRetentionUpdated.
  ///
  /// In en, this message translates to:
  /// **'Log retention updated.'**
  String get settingsLogRetentionUpdated;

  /// No description provided for @settingsSyncing.
  ///
  /// In en, this message translates to:
  /// **'Syncing settings'**
  String get settingsSyncing;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hans':
            return AppLocalizationsZhHans();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
