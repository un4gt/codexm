import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/adaptive_breakpoints.dart';
import '../../../../shared/widgets/app_ui.dart';
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

class _McpPageState extends State<McpPage> with SingleTickerProviderStateMixin {
  final _mcpStore = McpStore();
  final _settingsStore = CodexSettingsStore();
  final _skillsStore = CodexSkillsStore();
  final _runnableChecker = const McpRunnableChecker();
  final _installer = ManagedMcpInstaller();
  final _uuid = const Uuid();

  late final TextEditingController _skillNameController;
  late final TextEditingController _skillContentController;
  late final TabController _tabController;
  List<McpServer> _servers = const <McpServer>[];
  Set<String> _enabledGlobalServerIds = const <String>{};
  Map<String, bool> _runnableById = const <String, bool>{};
  Map<String, bool> _installedById = const <String, bool>{};
  List<String> _installedSkills = const <String>[];
  bool _showSkillEditor = false;
  String _status = '正在加载 MCP 与全局技能...';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _skillNameController = TextEditingController();
    _skillContentController = TextEditingController();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
    _refresh();
  }

  void _handleTabChanged() {
    if (!_tabController.indexIsChanging && mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _skillNameController.dispose();
    _skillContentController.dispose();
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    super.dispose();
  }

  Future<void> _refresh({String? status}) async {
    try {
      final servers = await _mcpStore.listServers();
      final settings = await _settingsStore.getSettings();
      final skills = await _skillsStore.listInstalledSkills();
      final runnable = <String, bool>{};
      final installed = <String, bool>{};
      final knownIds = servers.map((server) => server.id).toSet();
      for (final server in servers) {
        runnable[server.id] = await _runnableChecker.isProbablyRunnable(server);
        installed[server.id] = await _installer.isManagedInstalled(server.id);
      }

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
        _installedSkills = skills;
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
          _showSkillEditor = true;
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
      _showSkillEditor = true;
      _status = '已清空技能编辑草稿。';
    });
  }

  void _closeSkillEditor() {
    if (_busy) {
      return;
    }
    setState(() {
      _showSkillEditor = false;
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
          _showSkillEditor = false;
        });
      }
      return '已删除全局技能：$normalized。';
    });
  }

  @override
  Widget build(BuildContext context) {
    final showError = _status.contains('失败');
    return AppPageScaffold(
      title: 'MCP 与技能',
      actions: [
        IconButton(
          onPressed: _busy
              ? null
              : () {
                  if (_tabController.index == 0) {
                    _addServer();
                  } else {
                    _clearSkillDraft();
                  }
                },
          tooltip: _tabController.index == 0 ? '添加服务' : '新建技能',
          icon: const Icon(Icons.add),
        ),
        IconButton(
          onPressed: _busy ? null : () => _refresh(),
          tooltip: '刷新',
          icon: const Icon(Icons.refresh_outlined),
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(text: '服务'),
          Tab(text: '技能'),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (showError)
            AppStatusNotice(message: _status, tone: AppNoticeTone.error),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      _ServerListCard(
                        servers: _servers,
                        busy: _busy,
                        runnableById: _runnableById,
                        installedById: _installedById,
                        enabledGlobalServerIds: _enabledGlobalServerIds,
                        onEditServer: _editServer,
                        onDeleteServer: _deleteServer,
                        onSetServerEnabled: _setServerEnabled,
                        onInstallManagedServer: _installManagedServer,
                        onUninstallManagedServer: _uninstallManagedServer,
                      ),
                    ],
                  ),
                ),
                ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  children: [
                    _SkillsSection(
                      installedSkills: _installedSkills,
                      busy: _busy,
                      showEditor: _showSkillEditor,
                      skillNameController: _skillNameController,
                      skillContentController: _skillContentController,
                      onBack: _closeSkillEditor,
                      onLoadSkill: _loadSkillDraft,
                      onSaveSkill: _saveSkillDraft,
                      onDeleteSkill: _confirmDeleteSkill,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
