import 'package:flutter/material.dart';

import '../../../../shared/widgets/feature_scaffold.dart';
import '../../../../shared/widgets/adaptive_breakpoints.dart';
import '../../../codex/application/codex_skills_store.dart';
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

  late final TextEditingController _apiKeyController;
  late final TextEditingController _skillNameController;
  late final TextEditingController _skillContentController;

  String _status = '正在加载设置...';
  CodexSettings _settings = const CodexSettings();
  bool _busy = false;
  String? _skillsDirPath;
  List<String> _installedSkills = const <String>[];

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController();
    _skillNameController = TextEditingController();
    _skillContentController = TextEditingController();
    _loadSnapshot();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _skillNameController.dispose();
    _skillContentController.dispose();
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

      _apiKeyController.text = apiKey ?? '';
      setState(() {
        _settings = settings;
        _installedSkills = skills;
        _skillsDirPath = skillsDir.path;
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

  Future<void> _updatePreference(
    CodexSettings Function(CodexSettings current) update, {
      required String status,
  }) {
    return _runAction('正在保存偏好...', () async {
      final next = update(_settings);
      final saved = await _settingsStore.saveSettings(next);
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

  @override
  Widget build(BuildContext context) {
    return FeatureScaffold(
      title: '设置',
      description: '这里仅保留真正会影响日常使用体验的设置，避免把运行时和开发配置直接暴露到主界面。',
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: const Text('设置状态'),
            subtitle: Text(_status),
          ),
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
