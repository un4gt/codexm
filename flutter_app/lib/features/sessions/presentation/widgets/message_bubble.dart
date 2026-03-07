import 'package:flutter/material.dart';

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
    final spec = _messageStyle(theme, role);
    final maxBubbleWidth = MediaQuery.sizeOf(context).width >= 700 ? 720.0 : 560.0;

    return Align(
      alignment: spec.alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxBubbleWidth),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: spec.backgroundColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: spec.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(spec.icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      spec.label,
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                  Text(
                    _formatTime(createdAt),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SimpleMarkdownView(
                content: content,
                showThinking: showThinking,
              ),
              if (isStreaming) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '正在生成回复',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ],
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
    if (role == 'user') {
      return _MessageSpec(
        label: '你',
        icon: Icons.person_outline,
        alignment: Alignment.centerRight,
        backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.92),
        borderColor: theme.colorScheme.primary.withValues(alpha: 0.25),
      );
    }
    if (role == 'system' || role == 'error') {
      return _MessageSpec(
        label: '系统',
        icon: Icons.info_outline,
        alignment: Alignment.centerLeft,
        backgroundColor: theme.colorScheme.errorContainer.withValues(alpha: 0.72),
        borderColor: theme.colorScheme.error.withValues(alpha: 0.18),
      );
    }
    return _MessageSpec(
      label: 'Codex',
      icon: Icons.auto_awesome_outlined,
      alignment: Alignment.centerLeft,
      backgroundColor:
          theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
      borderColor: theme.colorScheme.outlineVariant,
    );
  }
}

class _MessageSpec {
  const _MessageSpec({
    required this.label,
    required this.icon,
    required this.alignment,
    required this.backgroundColor,
    required this.borderColor,
  });

  final String label;
  final IconData icon;
  final Alignment alignment;
  final Color backgroundColor;
  final Color borderColor;
}
