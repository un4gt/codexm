part of 'settings_page.dart';

class _ConnectionSection extends StatelessWidget {
  const _ConnectionSection({
    required this.apiKeyValue,
    required this.apiKeyVisible,
    required this.baseUrlController,
    required this.busy,
    required this.modelsLoading,
    required this.availableModels,
    required this.selectedModel,
    required this.onToggleApiKeyVisible,
    required this.onSaveApiKey,
    required this.onSaveBaseUrl,
    required this.onSelectModel,
  });

  final String? apiKeyValue;
  final bool apiKeyVisible;
  final TextEditingController baseUrlController;
  final bool busy;
  final bool modelsLoading;
  final List<String> availableModels;
  final String? selectedModel;
  final VoidCallback onToggleApiKeyVisible;
  final ValueChanged<String> onSaveApiKey;
  final ValueChanged<String> onSaveBaseUrl;
  final ValueChanged<String> onSelectModel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;

    final apiKeyMasked = (apiKeyValue ?? '').trim().isNotEmpty
        ? 'sk-••••••••••••••••••••••'
        : '未设置';
    final apiKeyDisplay = apiKeyVisible
        ? ((apiKeyValue ?? '').trim().isEmpty ? '' : apiKeyValue!.trim())
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
              '密钥与服务地址会用于生成运行时配置；修改后会立即写入本地。',
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
            SizedBox(height: tokens.compactSpacing),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final controller = TextEditingController(
                        text: apiKeyValue ?? '',
                      );
                      final result = await showDialog<String>(
                        context: context,
                        builder: (dialogContext) {
                          return AlertDialog(
                            title: const Text('设置 API Key'),
                            content: TextField(
                              controller: controller,
                              autofocus: true,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'API Key',
                                hintText: 'sk-...',
                              ),
                              onSubmitted: (value) {
                                Navigator.of(dialogContext).pop(value.trim());
                              },
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: const Text('取消'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(
                                  dialogContext,
                                ).pop(controller.text.trim()),
                                child: const Text('保存'),
                              ),
                            ],
                          );
                        },
                      );
                      controller.dispose();
                      if (result == null) {
                        return;
                      }
                      onSaveApiKey(result);
                    },
              icon: const Icon(Icons.edit_outlined),
              label: Text((apiKeyValue ?? '').trim().isEmpty ? '设置密钥' : '更新密钥'),
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
              onSubmitted: (value) => onSaveBaseUrl(value),
            ),
            SizedBox(height: tokens.compactSpacing),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: busy
                    ? null
                    : () => onSaveBaseUrl(baseUrlController.text),
                icon: const Icon(Icons.save_outlined),
                label: const Text('保存地址'),
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
