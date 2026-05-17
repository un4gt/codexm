import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/adaptive_breakpoints.dart';
import '../../../../shared/widgets/codex_ui.dart';
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
    final colors = context.codexColors;
    final widthClass = context.adaptiveWidthClass;

    if (role == 'system' || role == 'error') {
      return Align(
        alignment: Alignment.center,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: role == 'error' ? colors.errorSoft : colors.surfaceMuted,
            borderRadius: BorderRadius.circular(CodexMRadii.pill),
            border: Border.all(
              color: role == 'error' ? colors.errorSoft : colors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                role == 'error' ? Icons.error_outline : Icons.info_outline,
                size: 16,
                color: role == 'error' ? colors.error : colors.textMuted,
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
      AdaptiveWidthClass.compact => 520.0,
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
            border: role == 'user' ? null : Border.all(color: colors.divider),
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
    final colors = theme.extension<CodexMColors>() ?? CodexMColors.light;
    if (role == 'user') {
      return _MessageSpec(
        label: '你',
        icon: Icons.person_outline,
        alignment: Alignment.centerRight,
        backgroundColor: colors.primarySoft,
        borderRadius: CodexMRadii.lg,
        iconColor: colors.primary,
        labelColor: colors.textStrong,
        timeColor: colors.textMuted,
      );
    }
    return _MessageSpec(
      label: 'Codex',
      icon: Icons.auto_awesome_outlined,
      alignment: Alignment.centerLeft,
      backgroundColor: colors.surface,
      borderRadius: CodexMRadii.lg,
      iconColor: colors.textMuted,
      labelColor: colors.textStrong,
      timeColor: colors.textMuted,
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
                TimelinePartCard(
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

class TimelinePartCard extends StatefulWidget {
  const TimelinePartCard({
    super.key,
    required this.part,
    required this.showThinking,
  });

  final ChatMessagePart part;
  final bool showThinking;

  @override
  State<TimelinePartCard> createState() => _TimelinePartCardState();
}

class _TimelinePartCardState extends State<TimelinePartCard> {
  late bool _expanded;

  ChatMessagePart get part => widget.part;

  bool get _isCollapsible {
    if (part.content.trim().isEmpty) {
      return false;
    }
    return part.kind == 'command' ||
        part.kind == 'toolCall' ||
        part.kind == 'reasoning' ||
        part.kind == 'plan' ||
        part.kind == 'fileChange';
  }

  @override
  void initState() {
    super.initState();
    _expanded = _defaultExpanded(part);
  }

  @override
  void didUpdateWidget(covariant TimelinePartCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isCollapsible) {
      _expanded = true;
      return;
    }
    if (!_isRunning(oldWidget.part.status) && _isRunning(part.status)) {
      _expanded = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.codexColors;
    final l10n = AppLocalizations.of(context);
    final spec = _partSpec(context, part.kind);
    final content = part.content.trimRight();
    final summary = _summaryFor(content);
    final showContent = content.isNotEmpty && (!_isCollapsible || _expanded);
    final isTextPart = part.kind == 'agentText';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: spec.backgroundColor,
        borderRadius: BorderRadius.circular(CodexMRadii.md),
        border: Border.all(color: spec.borderColor),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: spec.lineColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(CodexMRadii.md),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(isTextPart ? 12 : 10, 10, 12, 12),
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
                      borderRadius: BorderRadius.circular(CodexMRadii.sm),
                      child: Semantics(
                        button: _isCollapsible,
                        label: _isCollapsible
                            ? (_expanded
                                  ? '${l10n.commonCollapse}${part.title}'
                                  : '${l10n.commonExpand}${part.title}')
                            : null,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: _isCollapsible ? 2 : 0,
                          ),
                          child: Row(
                            children: [
                              Icon(spec.icon, size: 17, color: spec.iconColor),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  part.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: colors.textStrong,
                                  ),
                                ),
                              ),
                              if (part.status != null)
                                _PartStatusChip(status: part.status!),
                              if (_isCollapsible) ...[
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: _expanded
                                      ? l10n.commonCollapse
                                      : l10n.commonExpand,
                                  child: Icon(
                                    _expanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                    size: 22,
                                    color: colors.textMuted,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                          fontFamily: _usesMonospace(part.kind)
                              ? 'monospace'
                              : null,
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (showContent) ...[
                      const SizedBox(height: 8),
                      if (_usesMonospace(part.kind))
                        CodexCodeBlock(content: content, maxHeight: 240)
                      else
                        SimpleMarkdownView(
                          content: content,
                          showThinking: widget.showThinking,
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _defaultExpanded(ChatMessagePart part) {
    if (!_isCollapsible) {
      return true;
    }
    if (_isRunning(part.status) || _isFailed(part.status)) {
      return true;
    }
    if (part.kind == 'reasoning') {
      return false;
    }
    if (part.kind == 'command' || part.kind == 'toolCall') {
      return false;
    }
    if (part.kind == 'plan') {
      return false;
    }
    return true;
  }

  String _summaryFor(String content) {
    return content
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '');
  }

  bool _usesMonospace(String kind) {
    return kind == 'command' || kind == 'toolCall' || kind == 'fileChange';
  }

  bool _isRunning(String? status) {
    final value = status?.trim();
    return value == 'inProgress' || value == 'running';
  }

  bool _isFailed(String? status) {
    final value = status?.trim();
    return value == 'failed' || value == 'error';
  }

  _PartVisualSpec _partSpec(BuildContext context, String kind) {
    final colors = context.codexColors;
    return switch (kind) {
      'reasoning' => _PartVisualSpec(
        icon: Icons.lightbulb_outline,
        iconColor: colors.warning,
        lineColor: colors.warning,
        backgroundColor: colors.warningSoft.withValues(alpha: 0.42),
        borderColor: colors.warning.withValues(alpha: 0.18),
      ),
      'command' => _PartVisualSpec(
        icon: Icons.terminal,
        iconColor: colors.primary,
        lineColor: colors.primary,
        backgroundColor: colors.surface,
        borderColor: colors.divider,
      ),
      'toolCall' => _PartVisualSpec(
        icon: Icons.build_circle_outlined,
        iconColor: colors.primary,
        lineColor: colors.info,
        backgroundColor: colors.surface,
        borderColor: colors.divider,
      ),
      'fileChange' => _PartVisualSpec(
        icon: Icons.description_outlined,
        iconColor: colors.success,
        lineColor: colors.success,
        backgroundColor: colors.surface,
        borderColor: colors.divider,
      ),
      'plan' => _PartVisualSpec(
        icon: Icons.checklist_outlined,
        iconColor: colors.primary,
        lineColor: colors.primaryMuted,
        backgroundColor: colors.surfaceMuted,
        borderColor: colors.divider,
      ),
      'agentText' => _PartVisualSpec(
        icon: Icons.chat_bubble_outline,
        iconColor: colors.textMuted,
        lineColor: colors.divider,
        backgroundColor: colors.surface,
        borderColor: colors.divider,
      ),
      _ => _PartVisualSpec(
        icon: Icons.build_outlined,
        iconColor: colors.textMuted,
        lineColor: colors.textSubtle,
        backgroundColor: colors.surfaceMuted,
        borderColor: colors.divider,
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
    final l10n = AppLocalizations.of(context);
    final normalized = status.trim();
    final failed = normalized == 'failed' || normalized == 'error';
    final inProgress = normalized == 'inProgress' || normalized == 'running';
    final label = switch (normalized) {
      'inProgress' => l10n.statusRunning,
      'running' => l10n.statusRunning,
      'completed' => l10n.statusCompleted,
      'failed' => l10n.statusFailed,
      'error' => l10n.statusFailed,
      'declined' => l10n.statusDeclined,
      'waiting' => l10n.statusWaiting,
      _ => normalized,
    };

    return DefaultTextStyle.merge(
      style: theme.textTheme.labelSmall,
      child: CodexStatusChip(
        label: label,
        compact: true,
        tone: failed
            ? CodexStatusTone.error
            : inProgress
            ? CodexStatusTone.running
            : normalized == 'declined' || normalized == 'waiting'
            ? CodexStatusTone.warning
            : normalized == 'completed'
            ? CodexStatusTone.success
            : CodexStatusTone.neutral,
      ),
    );
  }
}

class _PartVisualSpec {
  const _PartVisualSpec({
    required this.icon,
    required this.iconColor,
    required this.lineColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color lineColor;
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
