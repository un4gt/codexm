import 'package:flutter/material.dart';

import '../../../../shared/widgets/adaptive_breakpoints.dart';
import 'simple_markdown_view.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.role,
    required this.content,
    required this.createdAt,
    required this.showThinking,
    this.isStreaming = false,
  });

  final String role;
  final String content;
  final int createdAt;
  final bool showThinking;
  final bool isStreaming;

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
                    child: isStreaming
                        ? CircularProgressIndicator(
                            strokeWidth: 2,
                            color: spec.iconColor,
                          )
                        : Icon(spec.icon, size: 14, color: spec.iconColor),
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
              SimpleMarkdownView(content: content, showThinking: showThinking),
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
