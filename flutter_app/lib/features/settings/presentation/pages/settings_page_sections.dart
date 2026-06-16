part of 'settings_page.dart';

class _UpdateEntrySection extends StatelessWidget {
  const _UpdateEntrySection({
    required this.busy,
    required this.onOpenUpdatePage,
  });

  final bool busy;
  final Future<void> Function() onOpenUpdatePage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StitchSectionHeader(title: l10n.settingsSystemSection),
        const SizedBox(height: 8),
        StitchListItem(
          title: l10n.settingsAppUpdates,
          leading: const Icon(Icons.system_update_alt_outlined),
          trailing: const Icon(Icons.chevron_right),
          onTap: busy ? null : () => onOpenUpdatePage(),
        ),
      ],
    );
  }
}

class _ConnectionSection extends StatelessWidget {
  const _ConnectionSection({
    required this.apiKeyController,
    required this.apiKeyVisible,
    required this.baseUrlController,
    required this.busy,
    required this.modelsLoading,
    required this.availableModels,
    required this.selectedModel,
    required this.onToggleApiKeyVisible,
    required this.onSaveConnection,
    required this.onSelectModel,
  });

  final TextEditingController apiKeyController;
  final bool apiKeyVisible;
  final TextEditingController baseUrlController;
  final bool busy;
  final bool modelsLoading;
  final List<String> availableModels;
  final String? selectedModel;
  final VoidCallback onToggleApiKeyVisible;
  final Future<void> Function() onSaveConnection;
  final ValueChanged<String> onSelectModel;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final l10n = AppLocalizations.of(context);
    final modelValue = (selectedModel ?? '').trim().isEmpty
        ? l10n.settingsDefaultValue
        : selectedModel!.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StitchSectionHeader(title: l10n.settingsConnectionSection),
        const SizedBox(height: 12),
        TextField(
          controller: apiKeyController,
          enabled: !busy,
          obscureText: !apiKeyVisible,
          decoration: InputDecoration(
            labelText: 'API Key',
            hintText: 'sk-...',
            suffixIcon: IconButton(
              onPressed: busy ? null : onToggleApiKeyVisible,
              tooltip: apiKeyVisible ? l10n.settingsHide : l10n.settingsShow,
              icon: Icon(
                apiKeyVisible ? Icons.visibility_off : Icons.visibility,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: baseUrlController,
          enabled: !busy,
          decoration: InputDecoration(
            labelText: l10n.settingsBaseUrlOptional,
            hintText: 'https://api.openai.com/v1',
          ),
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => onSaveConnection(),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: busy ? null : onSaveConnection,
            icon: const Icon(Icons.save_outlined),
            label: Text(l10n.settingsSave),
          ),
        ),
        SizedBox(height: tokens.sectionSpacing),
        StitchListItem(
          title: l10n.settingsDefaultModel,
          subtitle: modelValue,
          leading: const Icon(Icons.auto_awesome_outlined),
          trailing: modelsLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        if (availableModels.isNotEmpty) ...[
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey<String>(selectedModel ?? ''),
            initialValue: availableModels.contains(selectedModel)
                ? selectedModel
                : null,
            decoration: InputDecoration(labelText: l10n.settingsChooseModel),
            items: [
              for (final model in availableModels)
                DropdownMenuItem<String>(value: model, child: Text(model)),
            ],
            onChanged: busy
                ? null
                : (value) {
                    if (value == null || value.trim().isEmpty) {
                      return;
                    }
                    onSelectModel(value.trim());
                  },
          ),
        ],
      ],
    );
  }
}

class _ConfigTomlSection extends StatelessWidget {
  const _ConfigTomlSection({
    required this.busy,
    required this.previewConfigToml,
    required this.extraConfigTomlController,
    required this.warnings,
    required this.previewValidationError,
    required this.extraConfigValidationError,
    required this.onSaveExtraConfigToml,
    required this.onClearExtraConfigToml,
  });

  final bool busy;
  final String previewConfigToml;
  final TextEditingController extraConfigTomlController;
  final List<String> warnings;
  final String? previewValidationError;
  final String? extraConfigValidationError;
  final Future<void> Function() onSaveExtraConfigToml;
  final Future<void> Function() onClearExtraConfigToml;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    final l10n = AppLocalizations.of(context);
    final widthClass = context.adaptiveWidthClass;
    final editorMaxLines = widthClass.isCompact ? 8 : 10;
    final previewMaxHeight = widthClass.isCompact ? 240.0 : 300.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StitchSectionHeader(title: l10n.settingsAdvancedConfig),
        const SizedBox(height: 12),
        _ConfigPanel(
          title: l10n.settingsEffectivePreview,
          child: _ReadonlyConfigPreview(
            content: previewConfigToml,
            maxHeight: previewMaxHeight,
          ),
        ),
        for (final warning in warnings) ...[
          const SizedBox(height: 8),
          _ConfigNotice(
            icon: Icons.info_outline,
            text: warning,
            tone: _ConfigNoticeTone.info,
          ),
        ],
        if (previewValidationError?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 8),
          _ConfigNotice(
            icon: Icons.error_outline,
            text: previewValidationError!,
            tone: _ConfigNoticeTone.error,
          ),
        ],
        SizedBox(height: tokens.sectionSpacing),
        _ConfigPanel(
          title: l10n.settingsExtraConfig,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: extraConfigTomlController,
                enabled: !busy,
                minLines: 4,
                maxLines: editorMaxLines,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                autocorrect: false,
                enableSuggestions: false,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                decoration: InputDecoration(
                  labelText: l10n.settingsExtraConfigItems,
                  hintText: '[sandbox]\nnetwork_access = true',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.settingsExtraConfigHelp,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (extraConfigValidationError?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 8),
                _ConfigNotice(
                  icon: Icons.error_outline,
                  text: extraConfigValidationError!,
                  tone: _ConfigNoticeTone.error,
                ),
              ],
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : onSaveExtraConfigToml,
                    icon: const Icon(Icons.save_outlined),
                    label: Text(l10n.settingsSaveContent),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onClearExtraConfigToml,
                    icon: const Icon(Icons.clear_outlined),
                    label: Text(l10n.settingsClearContent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _ConfigNoticeTone { info, warning, error }

class _ConfigPanel extends StatelessWidget {
  const _ConfigPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _ConfigNotice extends StatelessWidget {
  const _ConfigNotice({
    required this.icon,
    required this.text,
    required this.tone,
  });

  final IconData icon;
  final String text;
  final _ConfigNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final Color accentColor;
    final Color backgroundColor;

    switch (tone) {
      case _ConfigNoticeTone.info:
        accentColor = colorScheme.primary;
        backgroundColor = colorScheme.primary.withValues(alpha: 0.08);
        break;
      case _ConfigNoticeTone.warning:
        accentColor = colorScheme.tertiary;
        backgroundColor = colorScheme.tertiary.withValues(alpha: 0.12);
        break;
      case _ConfigNoticeTone.error:
        accentColor = colorScheme.error;
        backgroundColor = colorScheme.errorContainer.withValues(alpha: 0.4);
        break;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tone == _ConfigNoticeTone.error
                      ? colorScheme.onErrorContainer
                      : colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadonlyConfigPreview extends StatelessWidget {
  const _ReadonlyConfigPreview({
    required this.content,
    required this.maxHeight,
  });

  final String content;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: SelectionArea(
            child: Text(
              content.trim().isEmpty ? l10n.settingsNoPreviewContent : content,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({
    required this.settings,
    required this.busy,
    required this.onUpdatePreference,
  });

  final CodexSettings settings;
  final bool busy;
  final Future<void> Function(
    CodexSettings Function(CodexSettings current) update, {
    required String status,
  })
  onUpdatePreference;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final themeMode = CodexThemeModePreference.normalize(
      settings.themeModePreference,
    );
    final paletteSource = CodexThemePaletteSource.normalize(
      settings.themePaletteSource,
    );
    final lightCodeTheme = CodexLightCodeThemePreference.normalize(
      settings.lightCodeThemePreference,
    );
    final darkCodeTheme = CodexDarkCodeThemePreference.normalize(
      settings.darkCodeThemePreference,
    );
    final selectedAccent =
        settings.accentColorValue ?? CodexMThemePalette.lightPrimary.toARGB32();

    final themeModeLabels = <String, String>{
      CodexThemeModePreference.system: l10n.settingsThemeModeSystem,
      CodexThemeModePreference.light: l10n.settingsThemeModeLight,
      CodexThemeModePreference.dark: l10n.settingsThemeModeDark,
    };
    final paletteLabels = <String, String>{
      CodexThemePaletteSource.fixed: l10n.settingsPaletteFixed,
      CodexThemePaletteSource.dynamic: l10n.settingsPaletteDynamic,
      CodexThemePaletteSource.customAccent: l10n.settingsPaletteCustomAccent,
    };
    final lightCodeThemeLabels = <String, String>{
      CodexLightCodeThemePreference.vscodeLight:
          l10n.settingsCodeThemeVscodeLight,
      CodexLightCodeThemePreference.githubLight:
          l10n.settingsCodeThemeGithubLight,
    };
    final darkCodeThemeLabels = <String, String>{
      CodexDarkCodeThemePreference.vscodeDarkPlus:
          l10n.settingsCodeThemeVscodeDarkPlus,
      CodexDarkCodeThemePreference.dracula: l10n.settingsCodeThemeDracula,
      CodexDarkCodeThemePreference.oneDarkPro: l10n.settingsCodeThemeOneDarkPro,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StitchSectionHeader(title: l10n.settingsAppearanceSection),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: themeMode,
          decoration: InputDecoration(labelText: l10n.settingsThemeModeTitle),
          items: [
            for (final value in CodexThemeModePreference.values)
              DropdownMenuItem<String>(
                value: value,
                child: Text(themeModeLabels[value] ?? value),
              ),
          ],
          onChanged: busy
              ? null
              : (value) {
                  if (value == null || value == themeMode) {
                    return;
                  }
                  onUpdatePreference(
                    (current) => current.copyWith(themeModePreference: value),
                    status: l10n.settingsAppearanceUpdated,
                  );
                },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: paletteSource,
          decoration: InputDecoration(labelText: l10n.settingsPaletteTitle),
          items: [
            for (final value in CodexThemePaletteSource.values)
              DropdownMenuItem<String>(
                value: value,
                child: Text(paletteLabels[value] ?? value),
              ),
          ],
          onChanged: busy
              ? null
              : (value) {
                  if (value == null || value == paletteSource) {
                    return;
                  }
                  onUpdatePreference(
                    (current) => current.copyWith(themePaletteSource: value),
                    status: l10n.settingsAppearanceUpdated,
                  );
                },
        ),
        if (paletteSource == CodexThemePaletteSource.customAccent) ...[
          const SizedBox(height: 12),
          _AccentPicker(
            selectedValue: selectedAccent,
            enabled: !busy,
            onSelected: (color) {
              onUpdatePreference(
                (current) => current.copyWith(
                  themePaletteSource: CodexThemePaletteSource.customAccent,
                  accentColorValue: color.toARGB32(),
                ),
                status: l10n.settingsAppearanceUpdated,
              );
            },
          ),
        ],
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: lightCodeTheme,
          decoration: InputDecoration(labelText: l10n.settingsLightCodeTheme),
          items: [
            for (final value in CodexLightCodeThemePreference.values)
              DropdownMenuItem<String>(
                value: value,
                child: Text(lightCodeThemeLabels[value] ?? value),
              ),
          ],
          onChanged: busy
              ? null
              : (value) {
                  if (value == null || value == lightCodeTheme) {
                    return;
                  }
                  onUpdatePreference(
                    (current) =>
                        current.copyWith(lightCodeThemePreference: value),
                    status: l10n.settingsAppearanceUpdated,
                  );
                },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: darkCodeTheme,
          decoration: InputDecoration(labelText: l10n.settingsDarkCodeTheme),
          items: [
            for (final value in CodexDarkCodeThemePreference.values)
              DropdownMenuItem<String>(
                value: value,
                child: Text(darkCodeThemeLabels[value] ?? value),
              ),
          ],
          onChanged: busy
              ? null
              : (value) {
                  if (value == null || value == darkCodeTheme) {
                    return;
                  }
                  onUpdatePreference(
                    (current) =>
                        current.copyWith(darkCodeThemePreference: value),
                    status: l10n.settingsAppearanceUpdated,
                  );
                },
        ),
      ],
    );
  }
}

class _AccentPicker extends StatelessWidget {
  const _AccentPicker({
    required this.selectedValue,
    required this.enabled,
    required this.onSelected,
  });

  final int selectedValue;
  final bool enabled;
  final ValueChanged<Color> onSelected;

  static const _colors = <Color>[
    Color(0xFF4F46E5),
    Color(0xFF0891B2),
    Color(0xFF059669),
    Color(0xFFDB2777),
    Color(0xFFDC2626),
    Color(0xFF7C3AED),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.settingsAccentColor, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final color in _colors)
              Tooltip(
                message: l10n.settingsAccentColor,
                child: InkResponse(
                  onTap: enabled ? () => onSelected(color) : null,
                  radius: 24,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selectedValue == color.toARGB32()
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.outlineVariant,
                        width: selectedValue == color.toARGB32() ? 2 : 1,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PreferenceSection extends StatelessWidget {
  const _PreferenceSection({
    required this.settings,
    required this.busy,
    required this.onUpdatePreference,
    required this.onUpdateLocalePreference,
  });

  final CodexSettings settings;
  final bool busy;
  final Future<void> Function(
    CodexSettings Function(CodexSettings current) update, {
    required String status,
  })
  onUpdatePreference;
  final ValueChanged<String> onUpdateLocalePreference;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final selectedLocalePreference = CodexLocalePreference.normalize(
      settings.appLocalePreference,
    );
    final languageLabels = <String, String>{
      CodexLocalePreference.system: l10n.settingsLanguageSystem,
      CodexLocalePreference.english: l10n.settingsLanguageEnglish,
      CodexLocalePreference.simplifiedChinese:
          l10n.settingsLanguageChineseSimplified,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StitchSectionHeader(title: l10n.settingsInteractionPreferences),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: selectedLocalePreference,
          decoration: InputDecoration(labelText: l10n.settingsLanguageTitle),
          items: [
            for (final value in CodexLocalePreference.values)
              DropdownMenuItem<String>(
                value: value,
                child: Text(languageLabels[value] ?? value),
              ),
          ],
          onChanged: busy
              ? null
              : (value) {
                  if (value == null || value == selectedLocalePreference) {
                    return;
                  }
                  onUpdateLocalePreference(value);
                },
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(
            l10n.settingsShowReasoning,
            style: theme.textTheme.bodyMedium,
          ),
          value: settings.uiShowThinking,
          onChanged: busy
              ? null
              : (value) => onUpdatePreference(
                  (current) => current.copyWith(uiShowThinking: value),
                  status: value
                      ? l10n.settingsShowReasoningOn
                      : l10n.settingsShowReasoningOff,
                ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.settingsRunLogs, style: theme.textTheme.bodyMedium),
          value: settings.debugLogToFile,
          onChanged: busy
              ? null
              : (value) => onUpdatePreference(
                  (current) => current.copyWith(debugLogToFile: value),
                  status: value
                      ? l10n.settingsRunLogsOn
                      : l10n.settingsRunLogsOff,
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.settingsLogRetentionDays(settings.debugLogRetentionDays),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Text(
              '${settings.debugLogRetentionDays}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        Slider.adaptive(
          min: 1,
          max: 30,
          divisions: 29,
          value: settings.debugLogRetentionDays.clamp(1, 30).toDouble(),
          onChanged: busy
              ? null
              : (value) => onUpdatePreference(
                  (current) =>
                      current.copyWith(debugLogRetentionDays: value.round()),
                  status: l10n.settingsLogRetentionUpdated,
                ),
        ),
      ],
    );
  }
}

class _BusySettingsCard extends StatelessWidget {
  const _BusySettingsCard();

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      title: Text(AppLocalizations.of(context).settingsSyncing),
    );
  }
}
