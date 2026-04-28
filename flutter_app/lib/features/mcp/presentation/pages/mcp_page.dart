import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/adaptive_breakpoints.dart';
import '../../../../shared/widgets/stitch_ui.dart';
import '../../../codex/application/codex_skills_store.dart';
import '../../application/managed_mcp_installer.dart';
import '../../application/mcp_models.dart';
import '../../application/mcp_runnable.dart';
import '../../application/mcp_store.dart';
import '../../../settings/application/codex_settings_store.dart';

part 'mcp_page_sections.dart';
part 'mcp_page_actions.dart';

class McpPage extends StatefulWidget {
  const McpPage({super.key});

  @override
  State<McpPage> createState() => _McpPageState();
}

class _McpPageState extends State<McpPage> {
  final _mcpStore = McpStore();
  final _settingsStore = CodexSettingsStore();
  final _skillsStore = CodexSkillsStore();
  final _runnableChecker = const McpRunnableChecker();
  final _installer = ManagedMcpInstaller();
  final _uuid = const Uuid();

  late final TextEditingController _skillNameController;
  late final TextEditingController _skillContentController;
  List<McpServer> _servers = const <McpServer>[];
  Set<String> _enabledGlobalServerIds = const <String>{};
  Map<String, bool> _runnableById = const <String, bool>{};
  Map<String, bool> _installedById = const <String, bool>{};
  Map<String, String> _managedExecPathById = const <String, String>{};
  String? _installsRootPath;
  String? _skillsDirPath;
  List<String> _installedSkills = const <String>[];
  String _status = '正在加载 MCP 与全局技能...';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _skillNameController = TextEditingController();
    _skillContentController = TextEditingController();
    _refresh();
  }

  @override
  void dispose() {
    _skillNameController.dispose();
    _skillContentController.dispose();
    super.dispose();
  }

  Future<void> _refresh({String? status}) async {
    try {
      final servers = await _mcpStore.listServers();
      final settings = await _settingsStore.getSettings();
      final skills = await _skillsStore.listInstalledSkills();
      final skillsDir = await _skillsStore.skillsDir();
      final runnable = <String, bool>{};
      final installed = <String, bool>{};
      final execPaths = <String, String>{};
      final knownIds = servers.map((server) => server.id).toSet();
      for (final server in servers) {
        runnable[server.id] = await _runnableChecker.isProbablyRunnable(server);
        installed[server.id] = await _installer.isManagedInstalled(server.id);
        execPaths[server.id] = await _installer.managedExecPath(server.id);
      }

      final installsRootPath = await _installer.installsRootPath();
      final enabledGlobalServerIds = settings.enabledGlobalMcpServerIds
          .where(knownIds.contains)
          .toSet();
      if (!mounted) {
        return;
      }

      setState(() {
        _servers = servers;
        _enabledGlobalServerIds = enabledGlobalServerIds;
        _runnableById = runnable;
        _installedById = installed;
        _managedExecPathById = execPaths;
        _installsRootPath = installsRootPath;
        _installedSkills = skills;
        _skillsDirPath = skillsDir.path;
        _status =
            status ??
            (servers.isEmpty && skills.isEmpty
                ? '还没有扩展服务和全局技能。'
                : '已加载 ${servers.length} 个扩展服务、${skills.length} 项全局技能，已全局启用 ${enabledGlobalServerIds.length} 个服务。');
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = '读取失败：$error';
      });
    }
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
      await _refresh(status: successStatus);
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

  Future<void> _setServerEnabled(McpServer server, bool enabled) async {
    await _runAction(enabled ? '正在全局启用扩展服务...' : '正在全局停用扩展服务...', () async {
      final settings = await _settingsStore.getSettings();
      final next = <String>[
        for (final id in settings.enabledGlobalMcpServerIds)
          if (id != server.id) id,
        if (enabled) server.id,
      ];
      await _settingsStore.saveSettings(
        settings.copyWith(
          enabledGlobalMcpServerIds: _settingsStore
              .normalizeEnabledGlobalMcpServerIds(next),
        ),
      );
      return enabled ? '已全局启用扩展服务：${server.name}' : '已全局停用扩展服务：${server.name}';
    });
  }

  Future<void> _refreshSkills() {
    return _runAction('正在刷新全局技能...', () async => '已刷新全局技能。');
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
    final urlCount = _servers
        .where((server) => server.transport == 'url')
        .length;
    final localCount = _servers
        .where((server) => server.transport == 'stdio')
        .length;
    final enabledCount = _enabledGlobalServerIds.length;

    return StitchPageScaffold(
      pageTitle: 'MCP & Skills',
      brandIcon: Icons.memory_outlined,
      kickerText: '全局作用域',
      topActions: [
        IconButton.filledTonal(
          onPressed: _busy ? null : _addServer,
          tooltip: '添加服务',
          icon: const Icon(Icons.add),
        ),
        IconButton.filledTonal(
          onPressed: _busy ? null : () => _refresh(),
          tooltip: '刷新状态',
          icon: const Icon(Icons.refresh_outlined),
        ),
      ],
      children: [
        StitchInfoBanner(
          icon: Icons.info_outline,
          title: '当前状态',
          subtitle: _status,
        ),
        StitchInfoBanner(
          icon: Icons.inventory_2_outlined,
          title: '托管安装目录',
          subtitle: _installsRootPath ?? '尚未准备',
        ),
        _McpMetricsCard(
          urlCount: urlCount,
          localCount: localCount,
          enabledCount: enabledCount,
        ),
        _ServerListCard(
          servers: _servers,
          busy: _busy,
          runnableById: _runnableById,
          installedById: _installedById,
          managedExecPathById: _managedExecPathById,
          enabledGlobalServerIds: _enabledGlobalServerIds,
          onEditServer: _editServer,
          onDeleteServer: _deleteServer,
          onSetServerEnabled: _setServerEnabled,
          onInstallManagedServer: _installManagedServer,
          onUninstallManagedServer: _uninstallManagedServer,
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
        if (_busy)
          const StitchInfoBanner(
            icon: Icons.sync,
            title: '正在同步 MCP 与技能',
            subtitle: '完成后会自动刷新服务状态与技能列表。',
          ),
      ],
    );
  }
}
