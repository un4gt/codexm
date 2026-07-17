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
        content: content,
        parts: parts,
        showThinking: showThinking,
      );
    }

    if (role == 'user') {
      return _ChatWidthRow(
        alignment: Alignment.centerRight,
        widthFactor: context.appTokens.chatMessageWidthFactor,
        child: Material(
          key: _cardKeyFor(key),
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onLongPress: () => _copyMessage(context, plainContent),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: SimpleMarkdownView(
                content: plainContent,
                showThinking: false,
                textAlign: TextAlign.left,
              ),
            ),
          ),
        ),
      );
    }

    return _ChatWidthRow(
      alignment: Alignment.centerLeft,
      child: KeyedSubtree(
        key: _cardKeyFor(key),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: () => _copyMessage(context, plainContent),
            child: SimpleMarkdownView(
              content: plainContent,
              showThinking: showThinking,
              textAlign: TextAlign.left,
            ),
          ),
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
}

class _ChatWidthRow extends StatelessWidget {
  const _ChatWidthRow({
    required this.alignment,
    required this.child,
    this.widthFactor = 1,
  });

  final Alignment alignment;
  final Widget child;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    final tokens = context.appTokens;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final gutter = width * tokens.chatHorizontalGutterFactor;
        final availableWidth = width - gutter * 2;
        final bubbleWidth = availableWidth * widthFactor;
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

class _StructuredAssistantMessage extends StatelessWidget {
  const _StructuredAssistantMessage({
    required this.cardKey,
    required this.content,
    required this.parts,
    required this.showThinking,
  });

  final Key? cardKey;
  final String content;
  final List<ChatMessagePart> parts;
  final bool showThinking;

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
        (part) =>
            (part.kind != 'reasoning' || showThinking) &&
            (part.content.trim().isNotEmpty || part.status != null),
      ),
    ];

    return _ChatWidthRow(
      alignment: Alignment.centerLeft,
      child: KeyedSubtree(
        key: cardKey,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
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
                for (
                  var index = 0;
                  index < visibleParts.length;
                  index += 1
                ) ...[
                  if (index > 0) const SizedBox(height: 10),
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
    if (part.kind == 'agentText') {
      return SimpleMarkdownView(
        content: part.content,
        showThinking: widget.showThinking,
      );
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final spec = _partSpec(colorScheme, part.kind);
    final content = part.content.trimRight();
    final summary = _summaryFor(content);
    final showContent = content.isNotEmpty && (!_isCollapsible || _expanded);

    return Material(
      color: spec.backgroundColor,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
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
