import 'dart:io';

import 'package:codexm_native/codexm_native.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/feature_scaffold.dart';
import '../../../codex/application/codex_skills_store.dart';
import '../../../codex/application/codex_slash_commands.dart';
import '../../../mcp/application/mcp_store.dart';
import '../../application/codex_settings_store.dart';
part 'settings_page_sections.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _native = const CodexmNative();
  final _settingsStore = CodexSettingsStore();
  final _mcpStore = McpStore();
  final _skillsStore = CodexSkillsStore();

  late final TextEditingController _modelController;
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _approvalPolicyController;
  late final TextEditingController _personalityController;
  late final TextEditingController _extraConfigController;
  late final TextEditingController _rawConfigController;
  late final TextEditingController _skillNameController;
  late final TextEditingController _skillContentController;

  String _platformVersion = '读取中...';
  String _status = '正在加载设置...';
  CodexSettings _settings = const CodexSettings();
  bool _busy = false;
  List<String> _materializedWarnings = const <String>[];
  List<String> _availableModels = const <String>[];
  bool _modelsLoading = false;
  String? _modelsError;
  String _configPreview = '';
  String? _configPreviewError;
  List<String> _configPreviewWarnings = const <String>[];
  String? _skillsDirPath;
  int _mcpServerCount = 0;
  List<String> _installedSkills = const <String>[];

  @override
  void initState() {
    super.initState();
    _modelController = TextEditingController();
    _baseUrlController = TextEditingController();
    _apiKeyController = TextEditingController();
    _approvalPolicyController = TextEditingController();
    _personalityController = TextEditingController();
    _extraConfigController = TextEditingController();
    _rawConfigController = TextEditingController();
    _skillNameController = TextEditingController();
    _skillContentController = TextEditingController();
    _loadPlatformInfo();
    _loadSnapshot();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _approvalPolicyController.dispose();
    _personalityController.dispose();
    _extraConfigController.dispose();
    _rawConfigController.dispose();
    _skillNameController.dispose();
    _skillContentController.dispose();
    super.dispose();
  }

  Future<void> _loadPlatformInfo() async {
    try {
      final version = await _native.getPlatformVersion();
      if (!mounted) {
        return;
      }
      setState(() {
        _platformVersion = version ?? '未知 Android 版本';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _platformVersion = '读取失败：$error';
      });
    }
  }

  Future<void> _loadSnapshot({String? status}) async {
    try {
      final settings = await _settingsStore.getSettings();
      final apiKey = await _settingsStore.getCodexApiKey();
      final servers = await _mcpStore.listServers();
      final skills = await _skillsStore.listInstalledSkills();
      final skillsDir = await _skillsStore.skillsDir();
      final preview = _settingsStore.previewCodexConfigToml(
        settings: settings,
        mcpServers: servers,
      );
      if (!mounted) {
        return;
      }

      _modelController.text = settings.model ?? '';
      _baseUrlController.text = settings.openaiBaseUrl ?? '';
      _apiKeyController.text = apiKey ?? '';
      _approvalPolicyController.text = settings.approvalPolicy;
      _personalityController.text = settings.personality;
      _extraConfigController.text = settings.extraConfigToml ?? '';
      _rawConfigController.text = settings.rawConfigToml ?? '';

      setState(() {
        _settings = settings;
        _mcpServerCount = servers.length;
        _installedSkills = skills;
        _skillsDirPath = skillsDir.path;
        _configPreview = preview.configToml;
        _configPreviewError = preview.validationError;
        _configPreviewWarnings = preview.warnings ?? const <String>[];
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

  CodexSettings _buildDraftSettings() {
    return _settings.copyWith(
      enabled: _settings.enabled,
      model: _trimOrNull(_modelController.text),
      openaiBaseUrl: _trimOrNull(_baseUrlController.text),
      approvalPolicy: _trimOrDefault(_approvalPolicyController.text, 'never'),
      personality: _trimOrDefault(_personalityController.text, 'none'),
      featuresMultiAgent: _settings.featuresMultiAgent,
      uiShowThinking: _settings.uiShowThinking,
      debugLogToFile: _settings.debugLogToFile,
      debugLogRetentionDays: _settings.debugLogRetentionDays,
      enabledGlobalMcpServerIds: _settings.enabledGlobalMcpServerIds,
      extraConfigToml: _trimOrNull(_extraConfigController.text),
      useRawConfigToml: _settings.useRawConfigToml,
      rawConfigToml: _trimOrNull(_rawConfigController.text),
    );
  }

  String? _validateDraftSettings(CodexSettings settings) {
    if (settings.useRawConfigToml &&
        settings.rawConfigToml?.trim().isNotEmpty == true) {
      return _settingsStore.validateCodexConfigToml(
        settings.rawConfigToml!.trim(),
        label: '完整自定义内容',
      );
    }
    if (!settings.useRawConfigToml &&
        settings.extraConfigToml?.trim().isNotEmpty == true) {
      return _settingsStore.validateExtraConfigToml(
        settings.extraConfigToml!.trim(),
      );
    }
    return null;
  }

  Future<void> _persistDraftSettings() async {
    final next = _buildDraftSettings();
    final validationError = _validateDraftSettings(next);
    if (validationError != null) {
      throw StateError(validationError);
    }

    await _settingsStore.saveSettings(next);
    final apiKey = _trimOrNull(_apiKeyController.text);
    if (apiKey == null) {
      await _settingsStore.clearCodexApiKey();
    } else {
      await _settingsStore.saveCodexApiKey(apiKey);
    }
  }

  Future<void> _refreshConfigPreview({String? status}) async {
    try {
      final servers = await _mcpStore.listServers();
      final next = _buildDraftSettings();
      final validationError = _validateDraftSettings(next);
      final preview = _settingsStore.previewCodexConfigToml(
        settings: next,
        mcpServers: servers,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _configPreview = preview.configToml;
        _configPreviewWarnings = preview.warnings ?? const <String>[];
        _configPreviewError = validationError ?? preview.validationError;
        _status = status ?? '已刷新配置预览。';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _configPreviewError = '$error';
        _status = '配置预览刷新失败：$error';
      });
    }
  }

  Future<void> _refreshAvailableModels({bool openPicker = false}) async {
    if (_modelsLoading) {
      return;
    }

    setState(() {
      _modelsLoading = true;
      _modelsError = null;
      _status = '正在获取模型列表...';
    });

    try {
      final models = await _settingsStore.fetchAvailableModels(
        draftBaseUrl: _baseUrlController.text,
        draftApiKey: _trimOrNull(_apiKeyController.text),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _availableModels = models;
        _modelsLoading = false;
        _modelsError = null;
        _status = models.isEmpty ? '已连接，但暂未返回模型列表。' : '已获取 ${models.length} 个模型。';
      });
      if (openPicker) {
        await _openModelPicker();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _availableModels = const <String>[];
        _modelsLoading = false;
        _modelsError = '$error';
        _status = '获取模型列表失败：$error';
      });
    }
  }

  Future<void> _openModelPicker() async {
    if (_availableModels.isEmpty) {
      await _refreshAvailableModels(openPicker: true);
      return;
    }

    final queryController = TextEditingController(text: _modelController.text);
    var query = _modelController.text.trim();
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final filtered = _availableModels.where((model) {
              if (query.isEmpty) {
                return true;
              }
              return model.toLowerCase().contains(query.toLowerCase());
            }).toList(growable: false);
            return AlertDialog(
              title: const Text('选择模型'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: queryController,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: '筛选',
                        hintText: '输入模型关键字',
                      ),
                      onChanged: (value) {
                        setLocalState(() {
                          query = value.trim();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: filtered.isEmpty
                          ? const Center(child: Text('没有匹配的模型。'))
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: filtered.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final model = filtered[index];
                                return ListTile(
                                  title: Text(model),
                                  trailing: model == _modelController.text.trim()
                                      ? const Icon(Icons.check_circle_outline)
                                      : null,
                                  onTap: () =>
                                      Navigator.of(dialogContext).pop(model),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
              ],
            );
          },
        );
      },
    );
    queryController.dispose();

    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _modelController.text = selected;
      _status = '已选择模型：$selected';
    });
    await _refreshConfigPreview(status: '已刷新配置预览。');
  }

  void _setDraftSettings(CodexSettings next) {
    setState(() {
      _settings = next;
    });
    _refreshConfigPreview(status: _status);
  }

  Future<void> _runAction(
    String pendingStatus,
    Future<String> Function() action,
  ) async {
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

  Future<void> _saveSettings() {
    return _runAction('正在保存设置...', () async {
      await _persistDraftSettings();
      return '设置已保存。';
    });
  }

  Future<void> _materializeCodexHome() {
    return _runAction('正在生成运行配置...', () async {
      await _persistDraftSettings();
      final servers = await _mcpStore.listServers();
      final result = await _settingsStore.materializeCodexConfigFiles(
        mcpServers: servers,
      );
      final authFileExists = File(result.authJsonPath).existsSync();

      if (!mounted) {
        return authFileExists ? '已生成并保存连接配置。' : '已生成连接配置。';
      }

      setState(() {
        _materializedWarnings = result.warnings ?? const <String>[];
      });
      return authFileExists ? '已生成并保存连接配置。' : '已生成连接配置。';
    });
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
    final normalized = _skillsStore.normalizeSkillName(_skillNameController.text);
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
    final normalized = _skillsStore.normalizeSkillName(_skillNameController.text);
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

  String? _trimOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _trimOrDefault(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: '设置',
      description: '统一维护模型、访问凭据、交互偏好与运行配置，供 Android Flutter 宿主直接复用。',
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('当前状态'),
            subtitle: Text(_status),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.android_outlined),
            title: const Text('当前平台'),
            subtitle: Text(_platformVersion),
          ),
        ),
        const _BridgeStatusCard(),
        _ConnectionSection(
          settings: _settings,
          busy: _busy,
          modelController: _modelController,
          baseUrlController: _baseUrlController,
          apiKeyController: _apiKeyController,
          approvalPolicyController: _approvalPolicyController,
          personalityController: _personalityController,
          availableModelCount: _availableModels.length,
          modelsLoading: _modelsLoading,
          modelsError: _modelsError,
          onSettingsChanged: _setDraftSettings,
          onSave: _saveSettings,
          onRefresh: _loadSnapshot,
          onRefreshModels: _refreshAvailableModels,
          onOpenModelPicker: _openModelPicker,
        ),
        _PreferenceSection(
          settings: _settings,
          busy: _busy,
          onSettingsChanged: _setDraftSettings,
        ),
        _AdvancedSection(
          settings: _settings,
          busy: _busy,
          extraConfigController: _extraConfigController,
          rawConfigController: _rawConfigController,
          onSettingsChanged: _setDraftSettings,
        ),
        _ConfigPreviewSection(
          previewText: _configPreview,
          previewError: _configPreviewError,
          previewWarnings: _configPreviewWarnings,
          busy: _busy,
          onRefreshPreview: _refreshConfigPreview,
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
        _RuntimeSummarySection(
          settings: _settings,
          apiKeySaved: _apiKeyController.text.trim().isNotEmpty,
          mcpServerCount: _mcpServerCount,
          installedSkills: _installedSkills,
          materializedWarnings: _materializedWarnings,
          busy: _busy,
          onMaterialize: _materializeCodexHome,
        ),
        if (_busy) const _BusySettingsCard(),
      ],
    );
  }
}
