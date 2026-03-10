import 'package:uuid/uuid.dart';
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../shared/widgets/stitch_ui.dart';
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
  final _runnableChecker = const McpRunnableChecker();
  final _installer = ManagedMcpInstaller();
  final _uuid = const Uuid();

  List<McpServer> _servers = const <McpServer>[];
  Set<String> _enabledGlobalServerIds = const <String>{};
  Map<String, bool> _runnableById = const <String, bool>{};
  Map<String, bool> _installedById = const <String, bool>{};
  Map<String, String> _managedExecPathById = const <String, String>{};
  String? _installsRootPath;
  String _status = '正在加载扩展服务列表...';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh({String? status}) async {
    try {
      final servers = await _mcpStore.listServers();
      final settings = await _settingsStore.getSettings();
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
        _status =
            status ??
            (servers.isEmpty
                ? '还没有扩展服务。'
                : '已加载 ${servers.length} 个扩展服务，已全局启用 ${enabledGlobalServerIds.length} 个。');
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
        if (_busy)
          const StitchInfoBanner(
            icon: Icons.sync,
            title: '正在同步扩展服务',
            subtitle: '完成后会自动刷新可运行性与安装摘要。',
          ),
      ],
    );
  }
}
