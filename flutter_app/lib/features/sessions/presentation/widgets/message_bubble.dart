import 'package:flutter/material.dart';

import '../../../../shared/widgets/adaptive_breakpoints.dart';
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
    final widthClass = context.adaptiveWidthClass;

    if (role == 'system' || role == 'error') {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: role == 'error'
                ? theme.colorScheme.errorContainer.withValues(alpha: 0.4)
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
            borderRadius: BorderRadius.circular(8),
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
      );
    }

    final spec = _messageStyle(theme, role);
    final maxBubbleWidth = switch (widthClass) {
      AdaptiveWidthClass.compact => 560.0,
      AdaptiveWidthClass.medium => 680.0,
      AdaptiveWidthClass.expanded => 760.0,
    };

    final hasStructuredParts = parts.any((part) => part.kind != 'agentText');
    if (role != 'user' && hasStructuredParts) {
      return _StructuredAssistantMessage(
        spec: spec,
        content: content,
        parts: parts,
        createdAt: createdAt,
        showThinking: showThinking,
        maxWidth: maxBubbleWidth,
        formatTime: _formatTime,
      );
    }

    final plainContent = content.trim().isNotEmpty
        ? content
        : parts
              .where((part) => part.kind == 'agentText')
              .map((part) => part.content)
              .join();

    return Align(
      alignment: spec.alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: spec.backgroundColor,
            borderRadius: BorderRadius.circular(spec.borderRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: Icon(spec.icon, size: 14, color: spec.iconColor),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      spec.label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: spec.labelColor,
                      ),
                    ),
                  ),
                  Text(
                    _formatTime(createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color:
                          spec.timeColor ?? theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              SimpleMarkdownView(
                content: plainContent,
                showThinking: showThinking,
              ),
            ],
          ),
        ),
      ),
    );
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
      );
    }
    return _MessageSpec(
      label: 'Codex',
      icon: Icons.auto_awesome_outlined,
      alignment: Alignment.centerLeft,
      backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: 14,
      iconColor: scheme.onSurfaceVariant,
      labelColor: scheme.onSurface,
      timeColor: scheme.onSurfaceVariant,
    );
  }
}

class _StructuredAssistantMessage extends StatelessWidget {
  const _StructuredAssistantMessage({
    required this.spec,
    required this.content,
    required this.parts,
    required this.createdAt,
    required this.showThinking,
    required this.maxWidth,
    required this.formatTime,
  });

  final _MessageSpec spec;
  final String content;
  final List<ChatMessagePart> parts;
  final int createdAt;
  final bool showThinking;
  final double maxWidth;
  final String Function(int millis) formatTime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    return Align(
      alignment: spec.alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 2),
                child: Row(
                  children: [
                    Icon(spec.icon, size: 14, color: spec.iconColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        spec.label,
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: spec.labelColor,
                        ),
                      ),
                    ),
                    Text(
                      formatTime(createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color:
                            spec.timeColor ??
                            theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              for (final part in visibleParts)
                _MessagePartCard(
                  key: ValueKey('${part.id}:${part.kind}'),
                  part: part,
                  showThinking: showThinking,
                ),
            ],
          ),
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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: spec.backgroundColor,
        borderRadius: BorderRadius.circular(10),
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
              SelectableText(
                content,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontFamily: 'monospace',
                  height: 1.35,
                ),
              )
            else
              SimpleMarkdownView(
                content: content,
                showThinking: widget.showThinking,
              ),
          ],
        ],
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
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.3,
        ),
        borderColor: colorScheme.outlineVariant.withValues(alpha: 0.45),
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
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: failed ? colorScheme.onErrorContainer : colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
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
    this.timeColor,
  });

  final String label;
  final IconData icon;
  final Alignment alignment;
  final Color backgroundColor;
  final double borderRadius;
  final Color iconColor;
  final Color labelColor;
  final Color? timeColor;
}
