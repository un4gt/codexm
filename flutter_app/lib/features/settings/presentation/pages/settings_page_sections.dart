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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StitchSectionHeader(title: '系统'),
        const SizedBox(height: 8),
        StitchListItem(
          title: '应用更新',
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
    final modelValue = (selectedModel ?? '').trim().isEmpty
        ? '默认'
        : selectedModel!.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StitchSectionHeader(title: '连接'),
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
              tooltip: apiKeyVisible ? '隐藏' : '显示',
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
          decoration: const InputDecoration(
            labelText: 'Base URL（可选）',
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
            label: const Text('保存'),
          ),
        ),
        SizedBox(height: tokens.sectionSpacing),
        StitchListItem(
          title: '默认模型',
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
            decoration: const InputDecoration(labelText: '选择模型'),
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
    final widthClass = context.adaptiveWidthClass;
    final editorMaxLines = widthClass.isCompact ? 8 : 10;
    final previewMaxHeight = widthClass.isCompact ? 240.0 : 300.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StitchSectionHeader(title: '高级配置'),
        const SizedBox(height: 12),
        _ConfigPanel(
          title: '生效预览',
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
          title: '附加配置',
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
                decoration: const InputDecoration(
                  labelText: '附加配置项',
                  hintText: '[sandbox]\nnetwork_access = true',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '附加配置会插入到自动生成的顶层键之后、各分组之前。不要在这里重复填写连接、模型、features 或 MCP 服务器。',
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
                    label: const Text('保存内容'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onClearExtraConfigToml,
                    icon: const Icon(Icons.clear_outlined),
                    label: const Text('清空内容'),
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
              content.trim().isEmpty ? '# 暂无可预览内容' : content,
              style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreferenceSection extends StatelessWidget {
  const _PreferenceSection({
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const StitchSectionHeader(title: '交互偏好'),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text('显示推理过程', style: theme.textTheme.bodyMedium),
          value: settings.uiShowThinking,
          onChanged: busy
              ? null
              : (value) => onUpdatePreference(
                  (current) => current.copyWith(uiShowThinking: value),
                  status: value ? '已开启思考内容展示。' : '已关闭思考内容展示。',
                ),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text('运行日志', style: theme.textTheme.bodyMedium),
          value: settings.debugLogToFile,
          onChanged: busy
              ? null
              : (value) => onUpdatePreference(
                  (current) => current.copyWith(debugLogToFile: value),
                  status: value ? '已开启运行日志。' : '已关闭运行日志。',
                ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                '日志保留天数：${settings.debugLogRetentionDays} 天',
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
                  status: '已更新日志保留天数。',
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
    return const ListTile(
      leading: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      title: Text('正在同步设置'),
    );
  }
}
