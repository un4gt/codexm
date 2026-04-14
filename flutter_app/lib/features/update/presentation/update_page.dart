import 'package:codexm_native/codexm_native.dart';
import 'package:flutter/material.dart';

import '../../../../shared/widgets/feature_scaffold.dart';
import '../../../../shared/widgets/stitch_ui.dart';
import '../../../sessions/presentation/widgets/simple_markdown_view.dart';
import '../../settings/application/codex_settings_store.dart';
import '../application/app_update_models.dart';
import '../application/app_update_service.dart';
import 'app_update_dialogs.dart';

class UpdatePage extends StatefulWidget {
  const UpdatePage({
    super.key,
    AppUpdateService? updateService,
    CodexSettingsStore? settingsStore,
  }) : _updateService = updateService,
       _settingsStore = settingsStore;

  final AppUpdateService? _updateService;
  final CodexSettingsStore? _settingsStore;

  @override
  State<UpdatePage> createState() => _UpdatePageState();
}

class _UpdatePageState extends State<UpdatePage> {
  late final AppUpdateService _updateService;
  late final CodexSettingsStore _settingsStore;

  var _currentApp = const AppUpdateAppInfo(
    packageName: '',
    versionName: '未知',
    versionCode: 0,
  );
  CodexSettings _settings = const CodexSettings();
  AppUpdateRelease? _latestRelease;
  AppDownloadedApk? _downloadedApk;
  int? _lastCheckedAt;
  String _status = '正在读取更新信息...';
  bool _snapshotLoaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _updateService = widget._updateService ?? AppUpdateService();
    _settingsStore = widget._settingsStore ?? CodexSettingsStore();
    _loadSnapshot();
  }

  bool get _updateAvailable {
    final latestRelease = _latestRelease;
    if (latestRelease == null) {
      return false;
    }
    return _updateService.hasUpdate(
      currentVersion: _currentApp.versionName,
      remoteVersion: latestRelease.version,
    );
  }

  Future<void> _loadSnapshot({String? status}) async {
    try {
      final settings = await _settingsStore.getSettings();
      final currentApp = await _updateService.getCurrentAppInfo();
      final state = await _updateService.getState();
      final latestRelease = state.latestRelease;
      final downloadedApk = latestRelease == null
          ? null
          : await _updateService.downloadedApkForRelease(latestRelease);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _currentApp = currentApp;
        _latestRelease = latestRelease;
        _downloadedApk = downloadedApk;
        _lastCheckedAt = state.lastCheckedAt;
        _snapshotLoaded = true;
        _status = status ?? _defaultStatus(latestRelease, currentApp.versionName);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _snapshotLoaded = true;
        _status = '读取更新信息失败：$error';
      });
    }
  }

  String _defaultStatus(AppUpdateRelease? release, String currentVersion) {
    if (release == null) {
      return '尚未检查更新。';
    }
    if (_updateService.hasUpdate(
      currentVersion: currentVersion,
      remoteVersion: release.version,
    )) {
      return '发现新版本 v${release.version}。';
    }
    return '当前已是最新版本。';
  }

  Future<void> _setAutoCheckOnLaunch(bool value) async {
    if (_busy || !_snapshotLoaded) {
      return;
    }
    setState(() {
      _busy = true;
      _status = '正在保存更新设置...';
    });
    try {
      final saved = await _settingsStore.updateSettings(
        (current) => current.copyWith(updateCheckOnLaunch: value),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = saved;
        _status = value ? '已开启启动时检测更新。' : '已关闭启动时检测更新。';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = '保存更新设置失败：$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _checkForUpdates() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _status = '正在检查更新...';
    });
    try {
      final result = await _updateService.checkForUpdate();
      await _loadSnapshot(
        status: result.updateAvailable
            ? '发现新版本 v${result.latestRelease.version}。'
            : '当前已是最新版本。',
      );
      if (!mounted) {
        return;
      }
      if (result.updateAvailable) {
        final downloadedApk = await _updateService.downloadedApkForRelease(
          result.latestRelease,
        );
        if (!mounted) {
          return;
        }
        final action = await showAppUpdateAvailableDialog(
          context: context,
          result: result,
          actionLabel: downloadedApk == null ? '立即更新' : '继续安装',
        );
        if (!mounted || action == null) {
          return;
        }
        switch (action) {
          case AppUpdateAvailableAction.openReleasePage:
            setState(() {
              _status = '正在打开发布页...';
            });
            await _updateService.openReleasePage(result.latestRelease.releaseUrl);
            if (!mounted) {
              return;
            }
            setState(() {
              _status = '已打开发布页。';
            });
            break;
          case AppUpdateAvailableAction.update:
            final status = await startAppUpdateFlow(
              context: context,
              updateService: _updateService,
              release: result.latestRelease,
            );
            if (mounted) {
              await _loadSnapshot(status: status);
            }
            break;
        }
      } else {
        await showAppUpdateNoUpdateDialog(
          context: context,
          currentVersion: result.currentApp.versionName,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = '检查更新失败：$error';
        });
        await showAppUpdateErrorDialog(context: context, error: error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _installLatestRelease() async {
    final latestRelease = _latestRelease;
    if (latestRelease == null || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _status = '正在准备安装更新...';
    });
    try {
      final status = await startAppUpdateFlow(
        context: context,
        updateService: _updateService,
        release: latestRelease,
      );
      await _loadSnapshot(status: status);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = '安装更新失败：$error';
      });
      await showAppUpdateErrorDialog(context: context, error: error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _openReleasePage() async {
    final latestRelease = _latestRelease;
    if (latestRelease == null || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _status = '正在打开发布页...';
    });
    try {
      await _updateService.openReleasePage(latestRelease.releaseUrl);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = '已打开发布页。';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = '打开发布页失败：$error';
      });
      await showAppUpdateErrorDialog(context: context, error: error);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final latestRelease = _latestRelease;
    final releaseNotes = latestRelease?.releaseNotes.trim() ?? '';
    final controlsEnabled = _snapshotLoaded && !_busy;
    return FeatureScaffold(
      title: '应用更新',
      description: '默认会在启动时检查新版本；这里也可以随时手动检查并安装最新发布包。',
      appBar: AppBar(title: const Text('更新')),
      children: [
        StitchInfoBanner(
          icon: Icons.info_outline,
          title: '更新状态',
          subtitle: _status,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('版本信息', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                _KeyValueRow(label: '当前版本', value: 'v${_currentApp.versionName}'),
                _KeyValueRow(
                  label: '最新已知版本',
                  value: latestRelease == null ? '尚未检查' : 'v${latestRelease.version}',
                ),
                _KeyValueRow(
                  label: '上次检查',
                  value: _formatTimestamp(_lastCheckedAt),
                ),
                if (_downloadedApk != null)
                  _KeyValueRow(
                    label: '已下载更新包',
                    value: _downloadedApk!.fileName,
                  ),
              ],
            ),
          ),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('检查方式', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('启动应用时检测更新'),
                  subtitle: const Text('默认开启，启动后会在后台检查是否有新版本。'),
                  value: _settings.updateCheckOnLaunch,
                  onChanged: controlsEnabled
                      ? (value) => _setAutoCheckOnLaunch(value)
                      : null,
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: controlsEnabled ? _checkForUpdates : null,
                    icon: const Icon(Icons.refresh_outlined),
                    label: const Text('检查更新'),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (latestRelease != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _updateAvailable ? '发现新版本' : '最近检查结果',
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      if (_updateAvailable)
                        Chip(
                          label: const Text('可更新'),
                          avatar: const Icon(Icons.auto_awesome, size: 18),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _KeyValueRow(label: '目标版本', value: 'v${latestRelease.version}'),
                  _KeyValueRow(
                    label: '发布时间',
                    value: latestRelease.publishedAt?.replaceFirst('T', ' ').split('.').first ?? '未知',
                  ),
                  _KeyValueRow(
                    label: '安装方式',
                    value: latestRelease.asset == null
                        ? '前往发布页下载'
                        : '应用内下载安装',
                  ),
                  if (latestRelease.asset != null)
                    _KeyValueRow(
                      label: '更新包',
                      value:
                          '${latestRelease.asset!.name} · ${_formatBytes(latestRelease.asset!.size)}',
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (_updateAvailable)
                        FilledButton.icon(
                          onPressed: controlsEnabled ? _installLatestRelease : null,
                          icon: Icon(
                            _downloadedApk == null
                                ? Icons.download_outlined
                                : Icons.install_mobile_outlined,
                          ),
                          label: Text(_downloadedApk == null ? '立即更新' : '继续安装'),
                        ),
                      OutlinedButton.icon(
                        onPressed: controlsEnabled ? _openReleasePage : null,
                        icon: const Icon(Icons.open_in_new_outlined),
                        label: const Text('查看发布页'),
                      ),
                    ],
                  ),
                  if (releaseNotes.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      '版本说明',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.outlineVariant.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SimpleMarkdownView(content: releaseNotes),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  String _formatTimestamp(int? timestamp) {
    if (timestamp == null || timestamp <= 0) {
      return '尚未检查';
    }
    final dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final month = dateTime.month.toString().padLeft(2, '0');
    final day = dateTime.day.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '${dateTime.year}-$month-$day $hour:$minute';
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) {
      return '未知大小';
    }
    const kilo = 1024;
    const mega = kilo * 1024;
    if (bytes >= mega) {
      return '${(bytes / mega).toStringAsFixed(1)} MB';
    }
    return '${(bytes / kilo).toStringAsFixed(1)} KB';
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
