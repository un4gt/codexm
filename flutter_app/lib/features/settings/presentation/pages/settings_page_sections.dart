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
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('更新', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '检查并安装。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            StitchListItem(
              title: '应用更新',
              subtitle: '管理版本。',
              leading: const Icon(Icons.system_update_alt_outlined),
              trailing: const Icon(Icons.chevron_right),
              onTap: busy ? null : () => onOpenUpdatePage(),
            ),
          ],
        ),
      ),
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
    final theme = Theme.of(context);
    final tokens = context.appTokens;

    final modelValue = (selectedModel ?? '').trim().isEmpty
        ? '默认'
        : selectedModel!.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StitchSectionHeader(title: '连接'),
            SizedBox(height: tokens.compactSpacing),
            Text(
              '配置服务密钥与地址。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: tokens.sectionSpacing),
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
            SizedBox(height: tokens.sectionSpacing),
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
            SizedBox(height: tokens.compactSpacing),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onSaveConnection,
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存'),
              ),
            ),
            SizedBox(height: tokens.sectionSpacing),
            StitchListItem(
              title: '当前模型',
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
              SizedBox(height: tokens.compactSpacing),
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
        ),
      ),
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
    final theme = Theme.of(context);
    final tokens = context.appTokens;
    final widthClass = context.adaptiveWidthClass;
    final editorMaxLines = widthClass.isCompact ? 8 : 10;
    final previewMaxHeight = widthClass.isCompact ? 240.0 : 300.0;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(tokens.cardRadius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const StitchSectionHeader(title: '高级配置'),
            SizedBox(height: tokens.compactSpacing),
            Text(
              '可在此配置额外参数，保存后合并生效。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: tokens.sectionSpacing),
            _ConfigPanel(
              title: '生效预览',
              description: '当前将写入的完整配置内容。',
              child: _ReadonlyConfigPreview(
                content: previewConfigToml,
                maxHeight: previewMaxHeight,
              ),
            ),
            for (final warning in warnings) ...[
              SizedBox(height: tokens.compactSpacing),
              _ConfigNotice(
                icon: Icons.info_outline,
                text: warning,
                tone: _ConfigNoticeTone.info,
              ),
            ],
            if (previewValidationError?.trim().isNotEmpty == true) ...[
              SizedBox(height: tokens.compactSpacing),
              _ConfigNotice(
                icon: Icons.error_outline,
                text: previewValidationError!,
                tone: _ConfigNoticeTone.error,
              ),
            ],
            SizedBox(height: tokens.sectionSpacing),
            _ConfigPanel(
              title: '附加配置',
              description: '在此补充其他字段。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: extraConfigTomlController,
                    enabled: !busy,
                    minLines: 6,
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
                  if (extraConfigValidationError?.trim().isNotEmpty ==
                      true) ...[
                    SizedBox(height: tokens.compactSpacing),
                    _ConfigNotice(
                      icon: Icons.error_outline,
                      text: extraConfigValidationError!,
                      tone: _ConfigNoticeTone.error,
                    ),
                  ],
                  SizedBox(height: tokens.compactSpacing),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : onSaveExtraConfigToml,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('保存补充内容'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : onClearExtraConfigToml,
                        icon: const Icon(Icons.clear_outlined),
                        label: const Text('清空补充内容'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ConfigNoticeTone { info, warning, error }

class _ConfigPanel extends StatelessWidget {
  const _ConfigPanel({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(tokens.inputRadius),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.75),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: tokens.compactSpacing),
            child,
          ],
        ),
      ),
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
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
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.75),
        ),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('交互偏好', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '管理会话过程偏好。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示推理过程'),
              subtitle: const Text('在消息流中呈现完整推导步骤。'),
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
              title: const Text('运行日志'),
              subtitle: const Text('保存本地日志便于回看。'),
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
                    style: theme.textTheme.titleSmall,
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
                      (current) => current.copyWith(
                        debugLogRetentionDays: value.round(),
                      ),
                      status: '已更新日志保留天数。',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({
    required this.installedSkills,
    required this.skillsDirPath,
    required this.busy,
    required this.skillNameController,
    required this.skillContentController,
    required this.onRefresh,
    required this.onClearDraft,
    required this.onLoadSkill,
    required this.onSaveSkill,
    required this.onDeleteSkill,
  });

  final List<String> installedSkills;
  final String? skillsDirPath;
  final bool busy;
  final TextEditingController skillNameController;
  final TextEditingController skillContentController;
  final Future<void> Function() onRefresh;
  final VoidCallback onClearDraft;
  final Future<void> Function(String name) onLoadSkill;
  final Future<void> Function() onSaveSkill;
  final Future<void> Function() onDeleteSkill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('全局技能', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '管理自定义操作。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (skillsDirPath?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                '当前目录：$skillsDirPath',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : onRefresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('刷新列表'),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : onClearDraft,
                  icon: const Icon(Icons.clear),
                  label: const Text('清空编辑'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '已安装 ${installedSkills.length} 项',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            if (installedSkills.isEmpty)
              const _SettingsHint(
                icon: Icons.extension_off_outlined,
                title: '还没有全局技能',
                description: '新建后即可在会话里直接调用。',
              )
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < installedSkills.length;
                      index++
                    ) ...[
                      ListTile(
                        leading: const Icon(Icons.extension_outlined),
                        title: Text('\$${installedSkills[index]}'),
                        subtitle: const Text('点击载入到编辑区'),
                        trailing: const Icon(Icons.chevron_right),
                        enabled: !busy,
                        onTap: busy
                            ? null
                            : () => onLoadSkill(installedSkills[index]),
                      ),
                      if (index < installedSkills.length - 1)
                        Divider(
                          height: 1,
                          color: theme.colorScheme.outlineVariant,
                        ),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: skillNameController,
              enabled: !busy,
              decoration: const InputDecoration(
                labelText: '技能名称',
                hintText: '例如 ui-ux-pro-max',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: skillContentController,
              enabled: !busy,
              minLines: 6,
              maxLines: 12,
              decoration: const InputDecoration(
                labelText: '技能内容',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final widthClass = context.adaptiveWidthClassOf(
                  constraints.maxWidth,
                );
                final compact = widthClass.isCompact;
                final actions = <Widget>[
                  FilledButton.icon(
                    onPressed: busy ? null : onSaveSkill,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('保存技能'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : onDeleteSkill,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('删除技能'),
                  ),
                ];
                return compact
                    ? Column(
                        children: [
                          for (final action in actions) ...[
                            SizedBox(width: double.infinity, child: action),
                            if (action != actions.last)
                              const SizedBox(height: 12),
                          ],
                        ],
                      )
                    : Row(
                        children: [
                          for (final action in actions) ...[
                            Expanded(child: action),
                            if (action != actions.last)
                              const SizedBox(width: 12),
                          ],
                        ],
                      );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsHint extends StatelessWidget {
  const _SettingsHint({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusySettingsCard extends StatelessWidget {
  const _BusySettingsCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('正在同步设置'),
        subtitle: Text('完成后会自动刷新当前内容。'),
      ),
    );
  }
}
