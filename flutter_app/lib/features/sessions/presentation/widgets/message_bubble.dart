import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/session_models.dart';
import 'simple_markdown_view.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.showThinking,
    this.parts = const <ChatMessagePart>[],
  });

  final String role;
  final String content;
  final int createdAt;
  final bool showThinking;
  final List<ChatMessagePart> parts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (role == 'system' || role == 'error') {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: _ChatWidthRow(
          alignment: Alignment.center,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: role == 'error'
                  ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                  : theme.colorScheme.surfaceContainerHighest.withValues(
                      alpha: 0.3,
                    ),
              borderRadius: BorderRadius.circular(context.appTokens.cardRadius),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  role == 'error' ? Icons.error_outline : Icons.info_outline,
                  size: 16,
                  color: role == 'error'
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: SimpleMarkdownView(
                    content: content,
                    showThinking: false,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final spec = _messageStyle(theme, role);
    final hasStructuredParts = parts.any((part) => part.kind != 'agentText');
    final plainContent = content.trim().isNotEmpty
        ? content
        : parts
              .where((part) => part.kind == 'agentText')
              .map((part) => part.content)
              .join();

    if (role != 'user' && hasStructuredParts) {
      return _StructuredAssistantMessage(
        cardKey: _cardKeyFor(key),
        spec: spec,
        content: content,
        parts: parts,
        createdAt: createdAt,
        showThinking: showThinking,
        formatTime: _formatTime,
      );
    }

    return _ChatWidthRow(
      alignment: spec.alignment,
      child: _MessageCard(
        key: _cardKeyFor(key),
        spec: spec,
        createdAt: createdAt,
        formatTime: _formatTime,
        onLongPress: () => _copyMessage(context, plainContent),
        child: SimpleMarkdownView(
          content: plainContent,
          showThinking: showThinking,
          textAlign: role == 'user' ? TextAlign.right : TextAlign.left,
        ),
      ),
    );
  }

  Key? _cardKeyFor(Key? sourceKey) {
    if (sourceKey is ValueKey<String>) {
      return ValueKey<String>('${sourceKey.value}-card');
    }
    return null;
  }

  Future<void> _copyMessage(BuildContext context, String value) async {
    final text = value.trim();
    if (text.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
  }

  String _formatTime(int millis) {
    if (millis <= 0) {
      return '--:--';
    }
    final value = DateTime.fromMillisecondsSinceEpoch(millis);
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  _MessageSpec _messageStyle(ThemeData theme, String role) {
    final scheme = theme.colorScheme;
    if (role == 'user') {
      return _MessageSpec(
        label: '你',
        icon: Icons.person_outline,
        alignment: Alignment.centerRight,
        backgroundColor: scheme.primaryContainer.withValues(alpha: 0.92),
        borderRadius: 16,
        iconColor: scheme.primary,
        labelColor: scheme.onPrimaryContainer,
        timeColor: scheme.onPrimaryContainer.withValues(alpha: 0.72),
        avatarBackground: scheme.primary,
        avatarForeground: scheme.onPrimary,
      );
    }
    return _MessageSpec(
      label: 'CodexM',
      icon: Icons.auto_awesome_outlined,
      alignment: Alignment.centerLeft,
      backgroundColor: scheme.surfaceContainerLow,
      borderRadius: 16,
      iconColor: scheme.primary,
      labelColor: scheme.onSurface,
      timeColor: scheme.onSurfaceVariant,
      avatarBackground: scheme.secondaryContainer,
      avatarForeground: scheme.onSecondaryContainer,
    );
  }
}

class _ChatWidthRow extends StatelessWidget {
  const _ChatWidthRow({required this.alignment, required this.child});

  final Alignment alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final gutter = width * tokens.chatHorizontalGutterFactor;
        final bubbleWidth = width * tokens.chatMessageWidthFactor;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter, vertical: 6),
          child: Align(
            alignment: alignment,
            child: SizedBox(width: bubbleWidth, child: child),
          ),
        );
      },
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    super.key,
    required this.spec,
    required this.createdAt,
    required this.formatTime,
    required this.child,
    this.onLongPress,
  });

  final _MessageSpec spec;
  final int createdAt;
  final String Function(int millis) formatTime;
  final Widget child;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isUser = spec.alignment == Alignment.centerRight;

    final header = Row(
      children: [
        if (!isUser) ...[_MessageAvatar(spec: spec), const SizedBox(width: 8)],
        Expanded(
          child: Text(
            spec.label,
            textAlign: isUser ? TextAlign.right : TextAlign.left,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: spec.labelColor,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          formatTime(createdAt),
          style: theme.textTheme.labelSmall?.copyWith(
            color: spec.timeColor ?? theme.colorScheme.onSurfaceVariant,
          ),
        ),
        if (isUser) ...[const SizedBox(width: 8), _MessageAvatar(spec: spec)],
      ],
    );

    return Material(
      color: spec.backgroundColor,
      elevation: context.appTokens.elevationLow,
      shadowColor: theme.colorScheme.shadow.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(spec.borderRadius),
      child: InkWell(
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(spec.borderRadius),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [header, const SizedBox(height: 8), child],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageAvatar extends StatelessWidget {
  const _MessageAvatar({required this.spec});

  final _MessageSpec spec;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 14,
      backgroundColor: spec.avatarBackground,
      foregroundColor: spec.avatarForeground,
      child: Icon(spec.icon, size: 16),
    );
  }
}

class _StructuredAssistantMessage extends StatelessWidget {
  const _StructuredAssistantMessage({
    required this.cardKey,
    required this.spec,
    required this.content,
    required this.parts,
    required this.createdAt,
    required this.showThinking,
    required this.formatTime,
  });

  final Key? cardKey;
  final _MessageSpec spec;
  final String content;
  final List<ChatMessagePart> parts;
  final int createdAt;
  final bool showThinking;
  final String Function(int millis) formatTime;

  @override
  Widget build(BuildContext context) {
    final hasOrderedText = parts.any(
      (part) => part.kind == 'agentText' && part.content.trim().isNotEmpty,
    );
    final visibleParts = [
      if (!hasOrderedText && content.trim().isNotEmpty)
        ChatMessagePart(
          id: 'assistant-text',
          kind: 'agentText',
          title: '回复',
          content: content,
          status: 'completed',
        ),
      ...parts.where(
        (part) => part.content.trim().isNotEmpty || part.status != null,
      ),
    ];

    return _ChatWidthRow(
      alignment: spec.alignment,
      child: _MessageCard(
        key: cardKey,
        spec: spec,
        createdAt: createdAt,
        formatTime: formatTime,
        onLongPress: () {
          final text = visibleParts.map((part) => part.content).join('\n');
          Clipboard.setData(ClipboardData(text: text.trim()));
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < visibleParts.length; index += 1) ...[
              if (index > 0) const SizedBox(height: 8),
              _MessagePartCard(
                key: ValueKey(
                  '${visibleParts[index].id}:${visibleParts[index].kind}',
                ),
                part: visibleParts[index],
                showThinking: showThinking,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessagePartCard extends StatefulWidget {
  const _MessagePartCard({
    super.key,
    required this.part,
    required this.showThinking,
  });

  final ChatMessagePart part;
  final bool showThinking;

  @override
  State<_MessagePartCard> createState() => _MessagePartCardState();
}

class _MessagePartCardState extends State<_MessagePartCard> {
  late bool _expanded;

  ChatMessagePart get part => widget.part;

  bool get _isCollapsible =>
      (part.kind == 'command' || part.kind == 'toolCall') &&
      part.content.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _expanded = !_isCollapsible || part.status == 'inProgress';
  }

  @override
  void didUpdateWidget(covariant _MessagePartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isCollapsible) {
      _expanded = true;
      return;
    }
    if (oldWidget.part.status != 'inProgress' && part.status == 'inProgress') {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spec = _partSpec(colorScheme, part.kind);
    final content = part.content.trimRight();
    final summary = _summaryFor(content);
    final showContent = content.isNotEmpty && (!_isCollapsible || _expanded);

    return Material(
      color: spec.backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: spec.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _isCollapsible
                  ? () {
                      setState(() {
                        _expanded = !_expanded;
                      });
                    }
                  : null,
              borderRadius: BorderRadius.circular(8),
              child: Semantics(
                button: _isCollapsible,
                label: _isCollapsible
                    ? (_expanded ? '折叠${part.title}' : '展开${part.title}')
                    : null,
                child: Padding(
                  padding: EdgeInsets.only(bottom: _isCollapsible ? 2 : 0),
                  child: Row(
                    children: [
                      Icon(spec.icon, size: 16, color: spec.iconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          part.title,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (part.status != null)
                        _PartStatusChip(status: part.status!),
                      if (_isCollapsible) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: _expanded ? '折叠内容' : '展开内容',
                          child: Icon(
                            _expanded ? Icons.expand_less : Icons.expand_more,
                            size: 20,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (_isCollapsible && !_expanded && summary.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontFamily: _usesMonospace(part.kind) ? 'monospace' : null,
                  height: 1.35,
                ),
              ),
            ],
            if (showContent) ...[
              const SizedBox(height: 8),
              if (_usesMonospace(part.kind))
                SimpleCodeBlock(
                  content: content,
                  language: part.kind == 'command' ? 'shell' : 'diff',
                )
              else
                SimpleMarkdownView(
                  content: content,
                  showThinking: widget.showThinking,
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _summaryFor(String content) {
    return content
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  }

  bool _usesMonospace(String kind) {
    return kind == 'command' || kind == 'fileChange';
  }

  _PartVisualSpec _partSpec(ColorScheme colorScheme, String kind) {
    return switch (kind) {
      'reasoning' => _PartVisualSpec(
        icon: Icons.lightbulb_outline,
        iconColor: colorScheme.tertiary,
        backgroundColor: colorScheme.tertiaryContainer.withValues(alpha: 0.22),
        borderColor: colorScheme.tertiary.withValues(alpha: 0.22),
      ),
      'command' => _PartVisualSpec(
        icon: Icons.terminal,
        iconColor: colorScheme.primary,
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.18),
        borderColor: colorScheme.primary.withValues(alpha: 0.2),
      ),
      'toolCall' => _PartVisualSpec(
        icon: Icons.build_circle_outlined,
        iconColor: colorScheme.primary,
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.16),
        borderColor: colorScheme.primary.withValues(alpha: 0.2),
      ),
      'fileChange' => _PartVisualSpec(
        icon: Icons.description_outlined,
        iconColor: colorScheme.secondary,
        backgroundColor: colorScheme.secondaryContainer.withValues(alpha: 0.18),
        borderColor: colorScheme.secondary.withValues(alpha: 0.22),
      ),
      'plan' => _PartVisualSpec(
        icon: Icons.checklist_outlined,
        iconColor: colorScheme.primary,
        backgroundColor: colorScheme.surfaceContainerHigh.withValues(
          alpha: 0.8,
        ),
        borderColor: colorScheme.outlineVariant,
      ),
      'agentText' => _PartVisualSpec(
        icon: Icons.chat_bubble_outline,
        iconColor: colorScheme.onSurfaceVariant,
        backgroundColor: Colors.transparent,
        borderColor: Colors.transparent,
      ),
      _ => _PartVisualSpec(
        icon: Icons.build_outlined,
        iconColor: colorScheme.onSurfaceVariant,
        backgroundColor: colorScheme.surfaceContainerHigh.withValues(
          alpha: 0.6,
        ),
        borderColor: colorScheme.outlineVariant,
      ),
    };
  }
}

class _PartStatusChip extends StatelessWidget {
  const _PartStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final normalized = status.trim();
    final failed = normalized == 'failed';
    final inProgress = normalized == 'inProgress';
    final label = switch (normalized) {
      'inProgress' => '进行中',
      'completed' => '完成',
      'failed' => '失败',
      'declined' => '已拒绝',
      _ => normalized,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: failed
            ? colorScheme.errorContainer.withValues(alpha: 0.65)
            : inProgress
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (inProgress) ...[
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.6,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: failed
                  ? colorScheme.onErrorContainer
                  : colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PartVisualSpec {
  const _PartVisualSpec({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
}

class _MessageSpec {
  const _MessageSpec({
    required this.label,
    required this.icon,
    required this.alignment,
    required this.backgroundColor,
    required this.borderRadius,
    required this.iconColor,
    required this.labelColor,
    required this.avatarBackground,
    required this.avatarForeground,
    this.timeColor,
  });

  final String label;
  final IconData icon;
  final Alignment alignment;
  final Color backgroundColor;
  final double borderRadius;
  final Color iconColor;
  final Color labelColor;
  final Color avatarBackground;
  final Color avatarForeground;
  final Color? timeColor;
}
