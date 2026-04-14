import 'dart:async';

import 'package:flutter/material.dart';

import '../../sessions/presentation/widgets/simple_markdown_view.dart';
import '../application/app_update_models.dart';
import '../application/app_update_service.dart';

enum AppUpdateAvailableAction {
  openReleasePage,
  update,
}

Future<AppUpdateAvailableAction?> showAppUpdateAvailableDialog({
  required BuildContext context,
  required AppUpdateCheckResult result,
  required String actionLabel,
}) {
  final release = result.latestRelease;
  return showDialog<AppUpdateAvailableAction>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final maxHeight = MediaQuery.sizeOf(dialogContext).height * 0.28;
      return AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
        title: Row(
          children: [
            Icon(
              Icons.system_update_alt_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('发现新版本')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _VersionSummary(
                currentVersion: result.currentApp.versionName,
                latestVersion: release.version,
              ),
              if (release.asset == null) ...[
                const SizedBox(height: 12),
                Text(
                  '当前版本未匹配到可直接安装的更新包，可先查看发布页再手动安装。',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              if (release.releaseNotes.trim().isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '版本说明',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: SingleChildScrollView(
                    child: SimpleMarkdownView(content: release.releaseNotes),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('稍后'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(
                dialogContext,
              ).pop(AppUpdateAvailableAction.openReleasePage);
            },
            child: const Text('查看发布页'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(AppUpdateAvailableAction.update);
            },
            child: Text(actionLabel),
          ),
        ],
      );
    },
  );
}

Future<void> showAppUpdateNoUpdateDialog({
  required BuildContext context,
  required String currentVersion,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        icon: const Icon(
          Icons.check_circle_outline,
          color: Colors.green,
          size: 40,
        ),
        title: const Text('当前已是最新版本'),
        content: Text('当前安装版本为 v$currentVersion，没有发现更高版本。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
}

Future<void> showAppUpdateErrorDialog({
  required BuildContext context,
  required Object error,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        icon: const Icon(Icons.error_outline, color: Colors.red, size: 40),
        title: const Text('更新失败'),
        content: Text(error.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      );
    },
  );
}

Future<String?> startAppUpdateFlow({
  required BuildContext context,
  required AppUpdateService updateService,
  required AppUpdateRelease release,
}) async {
  if (release.asset == null) {
    await updateService.openReleasePage(release.releaseUrl);
    return '当前版本需要前往发布页下载，已为你打开。';
  }

  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _AppUpdateFlowDialog(
        release: release,
        updateService: updateService,
      );
    },
  );
}

class _AppUpdateFlowDialog extends StatefulWidget {
  const _AppUpdateFlowDialog({
    required this.release,
    required this.updateService,
  });

  final AppUpdateRelease release;
  final AppUpdateService updateService;

  @override
  State<_AppUpdateFlowDialog> createState() => _AppUpdateFlowDialogState();
}

class _AppUpdateFlowDialogState extends State<_AppUpdateFlowDialog> {
  _AppUpdatePhase _phase = _AppUpdatePhase.preparing;
  Object? _error;
  AppUpdateDownloadProgress? _progress;

  @override
  void initState() {
    super.initState();
    unawaited(_run());
  }

  Future<void> _run() async {
    try {
      final existing = await widget.updateService.downloadedApkForRelease(
        widget.release,
      );
      final downloadedApk =
          existing ??
          await widget.updateService.downloadRelease(
            widget.release,
            onProgress: (progress) {
              if (!mounted) {
                return;
              }
              setState(() {
                _phase = _AppUpdatePhase.downloading;
                _progress = progress;
              });
            },
          );

      if (!mounted) {
        return;
      }
      setState(() {
        _phase = _AppUpdatePhase.installing;
      });

      final installResult = await widget.updateService.installDownloadedApk(
        downloadedApk,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = installResult.status == AppUpdateInstallStatus.permissionRequired
            ? _AppUpdatePhase.permissionRequired
            : _AppUpdatePhase.completed;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = _AppUpdatePhase.error;
        _error = error;
      });
    }
  }

  Future<void> _openPermissionSettings() async {
    await widget.updateService.openUnknownSourcesSettings();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop('已打开系统设置，返回后可继续安装。');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = _progress;
    return AlertDialog(
      title: Text(_titleForPhase()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_phase == _AppUpdatePhase.downloading)
            LinearProgressIndicator(value: progress?.fraction),
          if (_phase == _AppUpdatePhase.preparing ||
              _phase == _AppUpdatePhase.installing)
            const LinearProgressIndicator(),
          if (_phase == _AppUpdatePhase.completed)
            const Icon(Icons.check_circle_outline, color: Colors.green, size: 44),
          if (_phase == _AppUpdatePhase.permissionRequired)
            const Icon(
              Icons.admin_panel_settings_outlined,
              color: Colors.orange,
              size: 44,
            ),
          if (_phase == _AppUpdatePhase.error)
            const Icon(Icons.error_outline, color: Colors.red, size: 44),
          const SizedBox(height: 16),
          Text(
            _messageForPhase(),
            style: theme.textTheme.bodyMedium,
          ),
          if (progress?.percent != null &&
              _phase == _AppUpdatePhase.downloading) ...[
            const SizedBox(height: 8),
            Text(
              '下载进度 ${progress!.percent}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: _buildActions(context),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    switch (_phase) {
      case _AppUpdatePhase.preparing:
      case _AppUpdatePhase.downloading:
      case _AppUpdatePhase.installing:
        return const <Widget>[];
      case _AppUpdatePhase.completed:
        return [
          FilledButton(
            onPressed: () => Navigator.of(context).pop('已拉起系统安装界面。'),
            child: const Text('关闭'),
          ),
        ];
      case _AppUpdatePhase.permissionRequired:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('稍后再试'),
          ),
          FilledButton(
            onPressed: _openPermissionSettings,
            child: const Text('前往设置'),
          ),
        ];
      case _AppUpdatePhase.error:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _phase = _AppUpdatePhase.preparing;
                _error = null;
                _progress = null;
              });
              unawaited(_run());
            },
            child: const Text('重试'),
          ),
        ];
    }
  }

  String _titleForPhase() {
    return switch (_phase) {
      _AppUpdatePhase.preparing => '准备更新',
      _AppUpdatePhase.downloading => '正在下载更新',
      _AppUpdatePhase.installing => '准备安装',
      _AppUpdatePhase.completed => '安装界面已打开',
      _AppUpdatePhase.permissionRequired => '需要安装权限',
      _AppUpdatePhase.error => '更新失败',
    };
  }

  String _messageForPhase() {
    return switch (_phase) {
      _AppUpdatePhase.preparing => '正在准备更新包，请稍候。',
      _AppUpdatePhase.downloading =>
        '正在下载 ${widget.release.asset?.name ?? '更新包'}。',
      _AppUpdatePhase.installing => '下载完成，正在拉起系统安装界面。',
      _AppUpdatePhase.completed => '系统安装界面已经打开，请按系统提示完成安装。',
      _AppUpdatePhase.permissionRequired =>
        '当前应用还没有安装未知应用的权限，请先到系统设置里开启后再继续安装。',
      _AppUpdatePhase.error => _error?.toString() ?? '下载或安装过程中发生了错误。',
    };
  }
}

enum _AppUpdatePhase {
  preparing,
  downloading,
  installing,
  completed,
  permissionRequired,
  error,
}

class _VersionSummary extends StatelessWidget {
  const _VersionSummary({
    required this.currentVersion,
    required this.latestVersion,
  });

  final String currentVersion;
  final String latestVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _VersionPill(
            label: '当前版本',
            value: 'v$currentVersion',
            color: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(
            Icons.arrow_forward_rounded,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: _VersionPill(
            label: '最新版本',
            value: 'v$latestVersion',
            color: theme.colorScheme.primaryContainer,
          ),
        ),
      ],
    );
  }
}

class _VersionPill extends StatelessWidget {
  const _VersionPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.labelSmall),
            const SizedBox(height: 4),
            Text(
              value,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
