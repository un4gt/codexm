import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../shared/widgets/stitch_ui.dart';
import '../application/lan_access_controller.dart';
import '../application/lan_access_models.dart';

class LanAccessSettingsSection extends StatefulWidget {
  const LanAccessSettingsSection({super.key, required this.controller});

  final LanAccessController controller;

  @override
  State<LanAccessSettingsSection> createState() =>
      _LanAccessSettingsSectionState();
}

class _LanAccessSettingsSectionState extends State<LanAccessSettingsSection> {
  late LanAccessState _state;
  late final TextEditingController _portController;
  StreamSubscription<LanAccessState>? _subscription;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _state = widget.controller.state;
    _portController = TextEditingController(text: '${_state.port}');
    _subscription = widget.controller.states.listen((state) {
      if (!mounted) return;
      setState(() {
        _state = state;
        if (!_state.enabled && !_portController.selection.isValid) {
          _portController.text = '${state.port}';
        }
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _portController.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.controller.setEnabled(enabled);
    } catch (_) {
      _showStatus(_strings.enableFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _savePort() async {
    final value = int.tryParse(_portController.text.trim());
    if (value == null) {
      _showStatus(_strings.invalidPort);
      return;
    }
    try {
      await widget.controller.setPort(value);
      _showStatus(_strings.portSaved);
    } catch (error) {
      _showStatus(error.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _copy(String value, String success) async {
    await Clipboard.setData(ClipboardData(text: value));
    _showStatus(success);
  }

  void _showStatus(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  _LanStrings get _strings => _LanStrings.of(context);

  String _phaseText(_LanStrings strings) {
    return switch (_state.phase) {
      LanAccessPhase.disabled => strings.disabled,
      LanAccessPhase.waitingForNetwork => strings.waitingForNetwork,
      LanAccessPhase.starting => strings.starting,
      LanAccessPhase.listening => strings.listening,
      LanAccessPhase.error => _state.errorMessage ?? strings.failed,
    };
  }

  @override
  Widget build(BuildContext context) {
    final strings = _strings;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final url = _state.url;
    final code = _state.pairingCode;
    final expiresAt = _state.pairingCodeExpiresAt;
    final secondsLeft = expiresAt == null
        ? null
        : ((expiresAt - DateTime.now().millisecondsSinceEpoch) / 1000)
              .ceil()
              .clamp(0, 300);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StitchSectionHeader(title: strings.title),
        SwitchListTile.adaptive(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          title: Text(strings.allowBrowser),
          subtitle: Text(_phaseText(strings)),
          secondary: const Icon(Icons.lan_outlined),
          value: _state.enabled,
          onChanged: _busy ? null : _toggle,
        ),
        const Divider(height: 24),
        TextField(
          controller: _portController,
          enabled: !_state.enabled && !_busy,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(5),
          ],
          decoration: InputDecoration(
            labelText: strings.port,
            helperText: strings.portRange,
            suffixIcon: IconButton(
              tooltip: strings.savePort,
              onPressed: _state.enabled || _busy ? null : _savePort,
              icon: const Icon(Icons.save_outlined),
            ),
          ),
          onSubmitted: (_) => _savePort(),
        ),
        if (_state.enabled) ...[
          const SizedBox(height: 20),
          if (url != null)
            _LanValueRow(
              label: strings.address,
              value: url,
              tooltip: strings.copyAddress,
              icon: Icons.copy_outlined,
              onPressed: () => _copy(url, strings.addressCopied),
            ),
          if (code != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.42,
                ),
                border: Border.all(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.pairingCode,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          code,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0,
                          ),
                        ),
                        if (secondsLeft != null)
                          Text(
                            strings.expiresIn(secondsLeft),
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: strings.copyCode,
                    onPressed: () => _copy(code, strings.codeCopied),
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  IconButton(
                    tooltip: strings.regenerate,
                    onPressed: widget.controller.generatePairingCode,
                    icon: const Icon(Icons.refresh_outlined),
                  ),
                ],
              ),
            ),
          ] else if (_state.phase == LanAccessPhase.listening) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.controller.generatePairingCode,
              icon: const Icon(Icons.add_link_outlined),
              label: Text(strings.addBrowser),
            ),
          ],
          if (_state.pairedBrowserCount > 0 ||
              _state.connectedBrowserCount > 0) ...[
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              leading: const Icon(Icons.devices_outlined),
              title: Text(
                strings.browserCount(
                  _state.connectedBrowserCount,
                  _state.pairedBrowserCount,
                ),
              ),
              trailing: TextButton(
                onPressed: widget.controller.revokeAllBrowsers,
                child: Text(strings.disconnectAll),
              ),
            ),
          ],
        ],
        if (_state.phase == LanAccessPhase.error) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              if (_state.enabled) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.controller.retry,
                    icon: const Icon(Icons.refresh_outlined),
                    label: Text(strings.retry),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.controller.openNotificationSettings,
                  icon: const Icon(Icons.notifications_outlined),
                  label: Text(strings.notificationSettings),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.shield_outlined,
              size: 20,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                strings.securityWarning,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LanValueRow extends StatelessWidget {
  const _LanValueRow({
    required this.label,
    required this.value,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final String value;
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.textTheme.labelMedium),
              const SizedBox(height: 4),
              SelectableText(value, style: theme.textTheme.bodyLarge),
            ],
          ),
        ),
        IconButton(tooltip: tooltip, onPressed: onPressed, icon: Icon(icon)),
      ],
    );
  }
}

class _LanStrings {
  const _LanStrings({required this.english});

  final bool english;

  static _LanStrings of(BuildContext context) => _LanStrings(
    english: Localizations.localeOf(context).languageCode == 'en',
  );

  String get title => english ? 'Local network access' : '局域网访问';
  String get allowBrowser => english ? 'Allow browser access' : '允许浏览器访问';
  String get disabled => english ? 'Off' : '已关闭';
  String get waitingForNetwork =>
      english ? 'Waiting for a local network' : '等待连接局域网';
  String get starting => english ? 'Starting...' : '正在启动...';
  String get listening =>
      english ? 'Available on the local network' : '已在局域网中运行';
  String get failed => english ? 'Unable to start' : '启动失败';
  String get port => english ? 'Listening port' : '监听端口';
  String get portRange => english
      ? '1024-65535; change while access is off'
      : '范围 1024-65535；关闭服务后可修改';
  String get savePort => english ? 'Save port' : '保存端口';
  String get address => english ? 'Browser address' : '浏览器地址';
  String get copyAddress => english ? 'Copy address' : '复制地址';
  String get addressCopied => english ? 'Address copied.' : '地址已复制。';
  String get pairingCode => english ? 'One-time pairing code' : '一次性配对码';
  String get copyCode => english ? 'Copy pairing code' : '复制配对码';
  String get codeCopied => english ? 'Pairing code copied.' : '配对码已复制。';
  String get regenerate => english ? 'Generate a new code' : '重新生成配对码';
  String get addBrowser => english ? 'Pair another browser' : '添加浏览器';
  String get disconnectAll => english ? 'Disconnect all' : '全部断开';
  String get retry => english ? 'Retry' : '重试';
  String get notificationSettings => english ? 'Notification settings' : '通知设置';
  String get securityWarning => english
      ? 'HTTP traffic is not encrypted. Use this only on a local network you trust.'
      : 'HTTP 连接未加密，请仅在你信任的局域网中使用。';
  String get enableFailed =>
      english ? 'Unable to change local access.' : '无法更改局域网访问状态。';
  String get invalidPort => english ? 'Enter a valid port.' : '请输入有效端口。';
  String get portSaved => english ? 'Port saved.' : '端口已保存。';

  String expiresIn(int seconds) =>
      english ? 'Expires in ${seconds}s' : '$seconds 秒后失效';

  String browserCount(int connected, int paired) => english
      ? '$connected connected, $paired paired'
      : '$connected 个在线，$paired 个已配对';
}
