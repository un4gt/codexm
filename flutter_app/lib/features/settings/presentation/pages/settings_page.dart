import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/adaptive_breakpoints.dart';
import '../../../../shared/widgets/stitch_ui.dart';
import '../../../codex/application/codex_skills_store.dart';
import '../../../mcp/application/mcp_store.dart';
import '../../application/codex_settings_store.dart';
part 'settings_page_sections.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settingsStore = CodexSettingsStore();
  final _skillsStore = CodexSkillsStore();
  final _mcpStore = McpStore();

  late final TextEditingController _skillNameController;
  late final TextEditingController _skillContentController;

  String _status = '正在加载设置...';
  CodexSettings _settings = const CodexSettings();
  bool _busy = false;
  String? _skillsDirPath;
  List<String> _installedSkills = const <String>[];
  String? _apiKeyValue;
  bool _apiKeyVisible = false;
  late final TextEditingController _baseUrlController;
  List<String> _availableModels = const <String>[];
  bool _modelsLoading = false;

  @override
  void initState() {
    super.initState();
    _skillNameController = TextEditingController();
    _skillContentController = TextEditingController();
    _baseUrlController = TextEditingController();
    _loadSnapshot();
  }

  @override
  void dispose() {
    _skillNameController.dispose();
    _skillContentController.dispose();
    _baseUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadSnapshot({String? status}) async {
    try {
      final settings = await _settingsStore.getSettings();
      final apiKey = await _settingsStore.getCodexApiKey();
      final skills = await _skillsStore.listInstalledSkills();
      final skillsDir = await _skillsStore.skillsDir();
      if (!mounted) {
        return;
      }

      _baseUrlController.text = settings.openaiBaseUrl ?? '';
      setState(() {
        _settings = settings;
        _installedSkills = skills;
        _skillsDirPath = skillsDir.path;
        _apiKeyValue = apiKey;
        _status = status ?? '已加载当前设置。';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = '读取设置失败：$error';
      });
    }
  }

  Future<void> _saveApiKeyDraft(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await _runAction('正在清除密钥...', () async {
        await _settingsStore.clearCodexApiKey();
        await _syncRuntimeConfigFiles();
        return '已清除密钥。';
      }, refreshModelsAfterSuccess: true);
      return;
    }
    await _runAction('正在保存密钥...', () async {
      await _settingsStore.saveCodexApiKey(trimmed);
      await _syncRuntimeConfigFiles();
      return '已保存密钥。';
    }, refreshModelsAfterSuccess: true);
  }

  Future<void> _saveBaseUrlDraft(String value) async {
    final trimmed = value.trim();
    await _runAction('正在保存服务地址...', () async {
      await _settingsStore.updateSettings(
        (current) =>
            current.copyWith(openaiBaseUrl: trimmed.isEmpty ? null : trimmed),
      );
      await _syncRuntimeConfigFiles();
      return trimmed.isEmpty ? '已清除服务地址。' : '已保存服务地址。';
    }, refreshModelsAfterSuccess: true);
  }

  Future<void> _syncRuntimeConfigFiles() async {
    final mcpServers = await _mcpStore.listServers();
    await _settingsStore.materializeCodexConfigFiles(mcpServers: mcpServers);
  }

  Future<void> _refreshModels({
    String? statusOnEmpty,
    String? statusOnSuccess,
    String? statusOnErrorPrefix,
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
            ? (statusOnEmpty ?? '未返回可用模型列表。')
            : (statusOnSuccess ?? '已刷新模型列表。');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = '${statusOnErrorPrefix ?? '获取模型列表失败：'}$error';
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
    await _refreshModels(
      statusOnEmpty: '$successStatus 未返回可用模型列表。',
      statusOnSuccess: '$successStatus 已刷新模型列表。',
      statusOnErrorPrefix: '$successStatus 获取模型列表失败：',
    );
  }

  Future<void> _updatePreference(
    CodexSettings Function(CodexSettings current) update, {
    required String status,
    bool syncRuntimeConfig = false,
  }) {
    return _runAction('正在保存偏好...', () async {
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
      return status;
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
      setState(() {
        _status = '执行失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _refreshSkills() {
    return _runAction('正在刷新全局 skills...', () async {
      await _skillsStore.listInstalledSkills();
      return '已刷新全局 skills。';
    });
  }

  Future<void> _loadSkillDraft(String name) {
    final normalized = _skillsStore.normalizeSkillName(name);
    if (normalized.isEmpty) {
      setState(() {
        _status = '读取失败：技能名称为空。';
      });
      return Future<void>.value();
    }

    return _runAction('正在读取全局技能...', () async {
      final content = await _skillsStore.readSkill(normalized);
      if (mounted) {
        setState(() {
          _skillNameController.text = normalized;
          _skillContentController.text = content;
        });
      }
      return '已载入全局技能：$normalized。';
    });
  }

  void _clearSkillDraft() {
    if (_busy) {
      return;
    }
    setState(() {
      _skillNameController.clear();
      _skillContentController.clear();
      _status = '已清空技能编辑草稿。';
    });
  }

  Future<void> _saveSkillDraft() {
    final normalized = _skillsStore.normalizeSkillName(
      _skillNameController.text,
    );
    final content = _skillContentController.text.trim();
    if (normalized.isEmpty) {
      setState(() {
        _status = '保存失败：请输入技能名称。';
      });
      return Future<void>.value();
    }
    if (content.isEmpty) {
      setState(() {
        _status = '保存失败：请输入技能内容。';
      });
      return Future<void>.value();
    }

    return _runAction('正在保存全局技能...', () async {
      final savedName = await _skillsStore.writeSkill(
        name: normalized,
        content: content,
      );
      if (mounted) {
        setState(() {
          _skillNameController.text = savedName;
          _skillContentController.text = content;
        });
      }
      return '已保存全局技能：$savedName。';
    });
  }

  Future<void> _confirmDeleteSkill() async {
    final normalized = _skillsStore.normalizeSkillName(
      _skillNameController.text,
    );
    if (normalized.isEmpty) {
      setState(() {
        _status = '删除失败：请先选择或填写技能名称。';
      });
      return;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除全局技能'),
          content: Text('确认删除技能「$normalized」吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (result != true) {
      return;
    }

    await _runAction('正在删除全局技能...', () async {
      await _skillsStore.deleteSkill(normalized);
      if (mounted) {
        setState(() {
          _skillNameController.clear();
          _skillContentController.clear();
        });
      }
      return '已删除全局技能：$normalized。';
    });
  }

  @override
  Widget build(BuildContext context) {
    return StitchPageScaffold(
      pageTitle: '设置',
      brandIcon: Icons.settings_outlined,
      kickerText: '偏好与连接',
      topActions: [
        IconButton.filledTonal(
          onPressed: _busy ? null : _refreshModels,
          tooltip: '刷新模型列表',
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
        StitchInfoBanner(
          icon: Icons.info_outline,
          title: '设置状态',
          subtitle: _status,
        ),
        _ConnectionSection(
          apiKeyValue: _apiKeyValue,
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
          onSaveApiKey: _saveApiKeyDraft,
          onSaveBaseUrl: _saveBaseUrlDraft,
          onSelectModel: (value) {
            if (_busy) {
              return;
            }
            _updatePreference(
              (current) => current.copyWith(model: value),
              status: '已更新模型为：$value',
              syncRuntimeConfig: true,
            );
          },
        ),
        _PreferenceSection(
          settings: _settings,
          busy: _busy,
          onUpdatePreference: _updatePreference,
        ),
        _SkillsSection(
          installedSkills: _installedSkills,
          skillsDirPath: _skillsDirPath,
          busy: _busy,
          skillNameController: _skillNameController,
          skillContentController: _skillContentController,
          onRefresh: _refreshSkills,
          onClearDraft: _clearSkillDraft,
          onLoadSkill: _loadSkillDraft,
          onSaveSkill: _saveSkillDraft,
          onDeleteSkill: _confirmDeleteSkill,
        ),
        if (_busy) const _BusySettingsCard(),
      ],
    );
  }
}
