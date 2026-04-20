import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/adaptive_breakpoints.dart';
import '../../../../shared/widgets/stitch_ui.dart';
import '../../../codex/application/codex_skills_store.dart';
import '../../../mcp/application/mcp_store.dart';
import '../../../update/presentation/update_page.dart';
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
  late final TextEditingController _apiKeyController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _extraConfigTomlController;

  String _status = '正在加载设置...';
  CodexSettings _settings = const CodexSettings();
  bool _busy = false;
  String? _skillsDirPath;
  List<String> _installedSkills = const <String>[];
  String? _apiKeyValue;
  bool _apiKeyVisible = false;
  List<String> _availableModels = const <String>[];
  bool _modelsLoading = false;
  String _configPreviewToml = '';
  List<String> _configWarnings = const <String>[];
  String? _configPreviewValidationError;
  String? _extraConfigValidationError;

  @override
  void initState() {
    super.initState();
    _skillNameController = TextEditingController();
    _skillContentController = TextEditingController();
    _apiKeyController = TextEditingController();
    _baseUrlController = TextEditingController();
    _extraConfigTomlController = TextEditingController();
    _extraConfigTomlController.addListener(() {
      if (!mounted || _extraConfigValidationError == null) {
        return;
      }
      setState(() {
        _extraConfigValidationError = null;
      });
    });
    _loadSnapshot();
  }

  @override
  void dispose() {
    _skillNameController.dispose();
    _skillContentController.dispose();
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _extraConfigTomlController.dispose();
    super.dispose();
  }

  Future<void> _loadSnapshot({String? status}) async {
    try {
      final settings = await _settingsStore.getSettings();
      final apiKey = await _settingsStore.getCodexApiKey();
      final skills = await _skillsStore.listInstalledSkills();
      final skillsDir = await _skillsStore.skillsDir();
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
      _baseUrlController.text = settings.openaiBaseUrl ?? '';
      _extraConfigTomlController.text =
          settings.extraConfigToml?.trimRight() ?? '';
      setState(() {
        _settings = settings;
        _installedSkills = skills;
        _skillsDirPath = skillsDir.path;
        _apiKeyValue = apiKey;
        _configPreviewToml = preview.configToml.trimRight();
        _configWarnings = preview.warnings ?? const <String>[];
        _configPreviewValidationError = preview.validationError;
        _extraConfigValidationError = null;
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

  Future<void> _saveConnectionDrafts() async {
    final apiKey = _apiKeyController.text.trim();
    final baseUrl = _baseUrlController.text.trim();
    await _runAction('正在保存连接设置...', () async {
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
        return '已清除密钥和服务地址。';
      }
      if (apiKey.isEmpty) {
        return '已保存服务地址，并清除密钥。';
      }
      if (baseUrl.isEmpty) {
        return '已保存密钥，并清除服务地址。';
      }
      return '已保存密钥和服务地址。';
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
      setState(() {
        _extraConfigValidationError = validationError;
        _status = '保存失败：$validationError';
      });
      return;
    }

    await _runAction('正在保存补充配置...', () async {
      await _settingsStore.updateSettings(
        (current) => current.copyWith(
          extraConfigToml: normalized.isEmpty ? '' : '$normalized\n',
        ),
      );
      await _syncRuntimeConfigFiles();
      if (normalized.isEmpty) {
        return '已清空补充配置，当前仅使用自动生成内容。';
      }
      return '已保存补充配置。';
    });
  }

  Future<void> _clearExtraConfigTomlDraft() async {
    if ((_settings.extraConfigToml?.trim().isEmpty ?? true) &&
        _extraConfigTomlController.text.trim().isEmpty) {
      setState(() {
        _extraConfigValidationError = null;
        _status = '补充配置已是空白。';
      });
      return;
    }

    await _runAction('正在清空补充配置...', () async {
      await _settingsStore.updateSettings(
        (current) => current.copyWith(extraConfigToml: ''),
      );
      await _syncRuntimeConfigFiles();
      return '已清空补充配置。';
    });
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

  Future<void> _openUpdatePage() async {
    await Navigator.of(
      context,
    ).push<void>(MaterialPageRoute<void>(builder: (_) => const UpdatePage()));
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
              status: '已更新模型为：$value',
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
