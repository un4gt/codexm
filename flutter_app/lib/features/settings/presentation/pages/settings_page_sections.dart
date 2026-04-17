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
              '检查新版本、管理启动时自动检查，并在应用内下载安装最新发布包。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            StitchListItem(
              title: '应用更新',
              subtitle: '查看当前版本、检查更新并安装新版本。',
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

    final apiKeyMasked = apiKeyController.text.trim().isNotEmpty
        ? 'sk-••••••••••••••••••••••'
        : '未设置';
    final apiKeyDisplay = apiKeyVisible
        ? apiKeyController.text.trim()
        : apiKeyMasked;
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
            const StitchSectionHeader(title: '连接设置'),
            SizedBox(height: tokens.compactSpacing),
            Text(
              '填写密钥与服务地址后点击保存，再自动拉取模型列表。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: tokens.sectionSpacing),
            StitchListItem(
              title: 'API Key',
              subtitle: apiKeyDisplay,
              leading: const Icon(Icons.vpn_key_outlined),
              trailing: IconButton(
                onPressed: busy ? null : onToggleApiKeyVisible,
                tooltip: apiKeyVisible ? '隐藏' : '显示',
                icon: Icon(
                  apiKeyVisible ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
            SizedBox(height: tokens.sectionSpacing),
            TextField(
              controller: apiKeyController,
              enabled: !busy,
              obscureText: !apiKeyVisible,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
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
    required this.useRawConfigToml,
    required this.previewConfigToml,
    required this.rawConfigTomlController,
    required this.extraConfigTomlController,
    required this.warnings,
    required this.previewValidationError,
    required this.extraConfigValidationError,
    required this.rawConfigValidationError,
    required this.onSaveExtraConfigToml,
    required this.onClearExtraConfigToml,
    required this.onSaveRawConfigToml,
    required this.onRestoreGeneratedConfigToml,
  });

  final bool busy;
  final bool useRawConfigToml;
  final String previewConfigToml;
  final TextEditingController rawConfigTomlController;
  final TextEditingController extraConfigTomlController;
  final List<String> warnings;
  final String? previewValidationError;
  final String? extraConfigValidationError;
  final String? rawConfigValidationError;
  final Future<void> Function() onSaveExtraConfigToml;
  final Future<void> Function() onClearExtraConfigToml;
  final Future<void> Function() onSaveRawConfigToml;
  final Future<void> Function() onRestoreGeneratedConfigToml;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;
    final widthClass = context.adaptiveWidthClass;
    final editorMaxLines = widthClass.isCompact ? 8 : 10;
    final rawEditorMaxLines = widthClass.isCompact ? 10 : 14;
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
            StitchSectionHeader(
              title: '全局 config.toml',
              trailing: Chip(label: Text(useRawConfigToml ? '完整覆盖' : '增量补充')),
            ),
            SizedBox(height: tokens.compactSpacing),
            Text(
              '默认展示当前生效配置，并优先通过补充内容做增量修改。只有在高级场景下，才建议完整覆盖整个 config.toml。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: tokens.sectionSpacing),
            _ConfigPanel(
              title: '当前生效内容',
              description: useRawConfigToml
                  ? '这里展示当前写入 Codex 的完整覆盖内容。该区域只读，避免误改。'
                  : '这里展示当前写入 Codex 的配置预览。自动生成内容和补充内容会一起合并后写入。',
              child: _ReadonlyConfigPreview(
                content: previewConfigToml,
                maxHeight: previewMaxHeight,
              ),
            ),
            if (useRawConfigToml) ...[
              SizedBox(height: tokens.compactSpacing),
              const _ConfigNotice(
                icon: Icons.warning_amber_rounded,
                text: '当前已启用完整覆盖：不会自动注入 MCP 服务器配置。',
                tone: _ConfigNoticeTone.warning,
              ),
            ],
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
              title: '补充内容',
              description: useRawConfigToml
                  ? '保存这里的内容后，会退出完整覆盖模式，改回自动生成基础配置后再追加下面片段。'
                  : '推荐在这里补充额外字段，而不是直接改完整文件。这样更不容易因为换行或遗漏而破坏基础配置。',
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
                      labelText: '补充 TOML 片段',
                      hintText: '[sandbox]\nnetwork_access = true',
                      helperText:
                          '请保持每一行都是完整的 TOML 语句；普通字符串里不要直接回车，如需多行请使用 """ 或 \'\'\'。',
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
                        label: Text(useRawConfigToml ? '保存并切回增量模式' : '保存补充内容'),
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
            SizedBox(height: tokens.sectionSpacing),
            _ConfigPanel(
              title: '完整覆盖（高级）',
              description: '仅在你确实需要完全接管 config.toml 时使用。保存后会直接写入整份文件。',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ConfigNotice(
                    icon: useRawConfigToml
                        ? Icons.edit_note_outlined
                        : Icons.info_outline,
                    text: useRawConfigToml
                        ? '当前正在使用完整覆盖模式。恢复自动生成后，会重新回到“自动生成 + 补充内容”的组合。'
                        : '这里适合高级调试场景；日常修改建议优先使用上面的补充内容。',
                    tone: useRawConfigToml
                        ? _ConfigNoticeTone.warning
                        : _ConfigNoticeTone.info,
                  ),
                  SizedBox(height: tokens.compactSpacing),
                  TextField(
                    controller: rawConfigTomlController,
                    enabled: !busy,
                    minLines: 8,
                    maxLines: rawEditorMaxLines,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    autocorrect: false,
                    enableSuggestions: false,
                    smartDashesType: SmartDashesType.disabled,
                    smartQuotesType: SmartQuotesType.disabled,
                    decoration: const InputDecoration(
                      labelText: '完整 config.toml',
                      helperText: '高级模式下，请避免在普通字符串中直接换行；如需多行值，请使用 TOML 多行字符串。',
                    ),
                  ),
                  if (rawConfigValidationError?.trim().isNotEmpty == true) ...[
                    SizedBox(height: tokens.compactSpacing),
                    _ConfigNotice(
                      icon: Icons.error_outline,
                      text: rawConfigValidationError!,
                      tone: _ConfigNoticeTone.error,
                    ),
                  ],
                  SizedBox(height: tokens.compactSpacing),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: busy ? null : onSaveRawConfigToml,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('保存完整覆盖'),
                      ),
                      OutlinedButton.icon(
                        onPressed: busy ? null : onRestoreGeneratedConfigToml,
                        icon: const Icon(Icons.restore_outlined),
                        label: Text(useRawConfigToml ? '退出完整覆盖' : '恢复自动生成'),
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
              '这里只保留会影响日常会话体验的偏好，修改后会立即保存。',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示思考内容'),
              subtitle: const Text('会话页会显示更详细的过程片段。'),
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
              title: const Text('保留运行日志'),
              subtitle: const Text('用于保留最近运行记录，便于回看问题。'),
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
            Text('全局 Skills', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              '统一管理会话里可调用的全局技能。',
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
