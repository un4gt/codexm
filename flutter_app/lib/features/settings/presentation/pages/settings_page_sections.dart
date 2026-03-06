part of 'settings_page.dart';

class _BridgeStatusCard extends StatelessWidget {
  const _BridgeStatusCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: ListTile(
        leading: Icon(Icons.memory_outlined),
        title: Text('运行桥接状态'),
        subtitle: Text(
          'Android 运行时与 Git 桥接已接入 Flutter 宿主；MCP 与 skills 统一按全局配置管理。',
        ),
      ),
    );
  }
}

class _ConnectionSection extends StatelessWidget {
  const _ConnectionSection({
    required this.settings,
    required this.busy,
    required this.modelController,
    required this.baseUrlController,
    required this.apiKeyController,
    required this.approvalPolicyController,
    required this.personalityController,
    required this.availableModelCount,
    required this.modelsLoading,
    required this.modelsError,
    required this.onSettingsChanged,
    required this.onSave,
    required this.onRefresh,
    required this.onRefreshModels,
    required this.onOpenModelPicker,
  });

  final CodexSettings settings;
  final bool busy;
  final TextEditingController modelController;
  final TextEditingController baseUrlController;
  final TextEditingController apiKeyController;
  final TextEditingController approvalPolicyController;
  final TextEditingController personalityController;
  final int availableModelCount;
  final bool modelsLoading;
  final String? modelsError;
  final ValueChanged<CodexSettings> onSettingsChanged;
  final VoidCallback onSave;
  final Future<void> Function({String? status}) onRefresh;
  final Future<void> Function({bool openPicker}) onRefreshModels;
  final Future<void> Function() onOpenModelPicker;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('连接与模型', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用 Codex'),
              subtitle: const Text('关闭后会保留本地数据，但不会在会话页发起运行。'),
              value: settings.enabled,
              onChanged: busy
                  ? null
                  : (value) =>
                        onSettingsChanged(settings.copyWith(enabled: value)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: modelController,
              enabled: !busy,
              decoration: const InputDecoration(labelText: '模型名称'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: busy || modelsLoading
                      ? null
                      : () => onRefreshModels(openPicker: false),
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: Text(modelsLoading ? '获取中...' : '获取模型'),
                ),
                FilledButton.tonalIcon(
                  onPressed: busy || modelsLoading ? null : onOpenModelPicker,
                  icon: const Icon(Icons.list_alt_outlined),
                  label: const Text('从列表选择'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              availableModelCount > 0
                  ? '已缓存 $availableModelCount 个模型，可直接从列表选择。'
                  : '填写地址与密钥后，可直接拉取模型列表。',
              style: theme.textTheme.bodySmall,
            ),
            if (modelsError?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(
                modelsError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: baseUrlController,
              enabled: !busy,
              decoration: const InputDecoration(labelText: '服务地址'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: apiKeyController,
              enabled: !busy,
              obscureText: true,
              decoration: const InputDecoration(labelText: '访问令牌'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: approvalPolicyController,
              enabled: !busy,
              decoration: const InputDecoration(labelText: '审批策略'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: personalityController,
              enabled: !busy,
              decoration: const InputDecoration(labelText: '回复风格'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: busy ? null : onSave,
                  child: const Text('保存设置'),
                ),
                OutlinedButton(
                  onPressed: busy ? null : () => onRefresh(),
                  child: const Text('刷新'),
                ),
              ],
            ),
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
    required this.onSettingsChanged,
  });

  final CodexSettings settings;
  final bool busy;
  final ValueChanged<CodexSettings> onSettingsChanged;

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
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用多代理特性'),
              subtitle: const Text('用于后续多代理编排与运行能力验证。'),
              value: settings.featuresMultiAgent,
              onChanged: busy
                  ? null
                  : (value) => onSettingsChanged(
                      settings.copyWith(featuresMultiAgent: value),
                    ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('显示思考内容'),
              subtitle: const Text('会话页会据此决定是否展示思考片段。'),
              value: settings.uiShowThinking,
              onChanged: busy
                  ? null
                  : (value) => onSettingsChanged(
                      settings.copyWith(uiShowThinking: value),
                    ),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('保留运行日志'),
              subtitle: const Text('开启后，会话页会显示最近一段运行日志。'),
              value: settings.debugLogToFile,
              onChanged: busy
                  ? null
                  : (value) => onSettingsChanged(
                      settings.copyWith(debugLogToFile: value),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              '日志保留天数：${settings.debugLogRetentionDays}',
              style: theme.textTheme.titleSmall,
            ),
            Slider.adaptive(
              min: 1,
              max: 30,
              divisions: 29,
              value: settings.debugLogRetentionDays.clamp(1, 30).toDouble(),
              onChanged: busy
                  ? null
                  : (value) => onSettingsChanged(
                      settings.copyWith(debugLogRetentionDays: value.round()),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.settings,
    required this.busy,
    required this.extraConfigController,
    required this.rawConfigController,
    required this.onSettingsChanged,
  });

  final CodexSettings settings;
  final bool busy;
  final TextEditingController extraConfigController;
  final TextEditingController rawConfigController;
  final ValueChanged<CodexSettings> onSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('高级配置', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('使用完整自定义内容'),
              subtitle: const Text('开启后，将直接使用下方完整内容，并跳过自动拼接。'),
              value: settings.useRawConfigToml,
              onChanged: busy
                  ? null
                  : (value) => onSettingsChanged(
                      settings.copyWith(useRawConfigToml: value),
                    ),
            ),
            const SizedBox(height: 12),
            if (!settings.useRawConfigToml)
              TextField(
                controller: extraConfigController,
                enabled: !busy,
                minLines: 4,
                maxLines: 8,
                decoration: const InputDecoration(labelText: '附加配置片段'),
              ),
            if (settings.useRawConfigToml)
              TextField(
                controller: rawConfigController,
                enabled: !busy,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(labelText: '完整自定义内容'),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConfigPreviewSection extends StatelessWidget {
  const _ConfigPreviewSection({
    required this.previewText,
    required this.previewError,
    required this.previewWarnings,
    required this.busy,
    required this.onRefreshPreview,
  });

  final String previewText;
  final String? previewError;
  final List<String> previewWarnings;
  final bool busy;
  final Future<void> Function({String? status}) onRefreshPreview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('运行配置预览', style: theme.textTheme.titleMedium),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => onRefreshPreview(),
                  icon: const Icon(Icons.refresh_outlined),
                  label: const Text('刷新预览'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('保存前可先在这里确认最终会写入运行目录的配置内容。'),
            if (previewError?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Text(
                previewError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (previewWarnings.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('提醒', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final warning in previewWarnings) Text('• $warning'),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.55,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                previewText.trim().isEmpty ? '当前还没有可预览的内容。' : previewText,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                ),
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
            const Text('统一管理全局扩展；在会话中输入 \$技能名 即可启用对应能力。'),
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
            const SizedBox(height: 12),
            Text('已安装：${installedSkills.length} 项'),
            if (skillsDirPath?.trim().isNotEmpty == true)
              Text('全局目录：$skillsDirPath'),
            const SizedBox(height: 12),
            if (installedSkills.isEmpty)
              const Text('还没有全局 skills。')
            else
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    for (var index = 0; index < installedSkills.length; index++) ...[
                      ListTile(
                        leading: const Icon(Icons.extension_outlined),
                        title: Text('\$${installedSkills[index]}'),
                        subtitle: const Text('点击载入到编辑区'),
                        trailing: const Icon(Icons.edit_outlined),
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
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
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
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuntimeSummarySection extends StatelessWidget {
  const _RuntimeSummarySection({
    required this.settings,
    required this.apiKeySaved,
    required this.mcpServerCount,
    required this.installedSkills,
    required this.skillsDirPath,
    required this.materializedHomeDir,
    required this.materializedAuthPresent,
    required this.materializedWarnings,
    required this.busy,
    required this.onMaterialize,
  });

  final CodexSettings settings;
  final bool apiKeySaved;
  final int mcpServerCount;
  final List<String> installedSkills;
  final String? skillsDirPath;
  final String? materializedHomeDir;
  final bool materializedAuthPresent;
  final List<String> materializedWarnings;
  final bool busy;
  final VoidCallback onMaterialize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('运行摘要', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              '模型：${settings.model?.trim().isNotEmpty == true ? settings.model : '未设置'}',
            ),
            Text(
              '服务地址：${settings.openaiBaseUrl?.trim().isNotEmpty == true ? settings.openaiBaseUrl : '未设置'}',
            ),
            Text('访问令牌：${apiKeySaved ? '已保存' : '未保存'}'),
            Text('审批策略：${settings.approvalPolicy}'),
            Text('回复风格：${settings.personality}'),
            Text('已配置扩展服务：$mcpServerCount 个'),
            Text('全局启用 MCP：${settings.enabledGlobalMcpServerIds.length} 项'),
            Text('内置快捷能力：${codexSlashCommands.length} 项'),
            Text('Skills 作用域：全局'),
            Text('已安装全局扩展：${installedSkills.length} 项'),
            if (skillsDirPath?.trim().isNotEmpty == true)
              Text('Skills 目录：$skillsDirPath'),
            if (installedSkills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final skill in installedSkills) Chip(label: Text(skill)),
                ],
              ),
            ],
            if (materializedHomeDir != null) ...[
              const SizedBox(height: 8),
              Text('运行目录：$materializedHomeDir'),
              Text('认证信息：${materializedAuthPresent ? '已生成' : '未生成'}'),
            ],
            if (materializedWarnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('提醒', style: theme.textTheme.titleSmall),
              const SizedBox(height: 6),
              for (final warning in materializedWarnings) Text('• $warning'),
            ],
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: busy ? null : onMaterialize,
              child: const Text('生成运行配置'),
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
        subtitle: Text('完成后会自动刷新摘要。'),
      ),
    );
  }
}
