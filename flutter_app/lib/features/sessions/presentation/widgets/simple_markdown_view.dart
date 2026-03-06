import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SimpleMarkdownView extends StatelessWidget {
  const SimpleMarkdownView({
    super.key,
    required this.content,
    this.showThinking = false,
  });

  final String content;
  final bool showThinking;

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(content);
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }

    var visibleCount = 0;
    final widgets = <Widget>[];
    for (final block in blocks) {
      if (block.type == _MarkdownBlockType.thinking && !showThinking) {
        continue;
      }
      visibleCount += 1;
      widgets.add(_MarkdownBlockView(block: block));
    }

    if (visibleCount == 0) {
      return Text(
        '这段回复只包含思考内容，当前已隐藏。',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < widgets.length; index += 1) ...[
          if (index > 0) const SizedBox(height: 12),
          widgets[index],
        ],
      ],
    );
  }
}

List<_MarkdownBlock> _parseBlocks(String content) {
  final normalized = content.replaceAll(RegExp(r'\r\n?'), '\n').trimRight();
  if (normalized.isEmpty) {
    return const <_MarkdownBlock>[];
  }

  final blocks = <_MarkdownBlock>[];
  final paragraph = <String>[];
  final quote = <String>[];
  final fenced = <String>[];
  final thinking = <String>[];

  var inFence = false;
  var fenceLanguage = '';
  var inThinkingTag = false;

  void flushParagraph() {
    if (paragraph.isEmpty) {
      return;
    }
    blocks.add(
      _MarkdownBlock(
        type: _MarkdownBlockType.paragraph,
        text: paragraph.join('\n').trim(),
      ),
    );
    paragraph.clear();
  }

  void flushQuote() {
    if (quote.isEmpty) {
      return;
    }
    blocks.add(
      _MarkdownBlock(
        type: _MarkdownBlockType.quote,
        text: quote.join('\n').trim(),
      ),
    );
    quote.clear();
  }

  void flushFence() {
    if (fenced.isEmpty) {
      return;
    }
    blocks.add(
      _MarkdownBlock(
        type: fenceLanguage == 'thinking'
            ? _MarkdownBlockType.thinking
            : _MarkdownBlockType.code,
        text: fenced.join('\n'),
        language: fenceLanguage,
      ),
    );
    fenced.clear();
    fenceLanguage = '';
  }

  void flushThinkingTag() {
    if (thinking.isEmpty) {
      return;
    }
    blocks.add(
      _MarkdownBlock(
        type: _MarkdownBlockType.thinking,
        text: thinking.join('\n').trim(),
      ),
    );
    thinking.clear();
  }

  for (final line in normalized.split('\n')) {
    final trimmed = line.trim();

    if (inFence) {
      if (trimmed.startsWith('```')) {
        flushFence();
        inFence = false;
      } else {
        fenced.add(line);
      }
      continue;
    }

    if (inThinkingTag) {
      if (trimmed == '</thinking>' || trimmed == '</think>') {
        flushThinkingTag();
        inThinkingTag = false;
      } else {
        thinking.add(line);
      }
      continue;
    }

    if (trimmed == '<thinking>' || trimmed == '<think>') {
      flushParagraph();
      flushQuote();
      inThinkingTag = true;
      continue;
    }

    if (trimmed.startsWith('```')) {
      flushParagraph();
      flushQuote();
      inFence = true;
      fenceLanguage = trimmed.substring(3).trim().toLowerCase();
      continue;
    }

    if (trimmed.startsWith('>')) {
      flushParagraph();
      quote.add(trimmed.substring(1).trimLeft());
      continue;
    }

    if (trimmed.isEmpty) {
      flushParagraph();
      flushQuote();
      continue;
    }

    paragraph.add(line);
  }

  flushParagraph();
  flushQuote();
  flushFence();
  flushThinkingTag();
  return blocks;
}

class _MarkdownBlockView extends StatelessWidget {
  const _MarkdownBlockView({required this.block});

  final _MarkdownBlock block;

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case _MarkdownBlockType.paragraph:
        return SelectableText.rich(
          TextSpan(
            children: _inlineSpans(
              context,
              block.text,
            ),
          ),
        );
      case _MarkdownBlockType.quote:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
          ),
          child: SelectableText(block.text),
        );
      case _MarkdownBlockType.code:
      case _MarkdownBlockType.thinking:
        return _CodeLikeBlockView(block: block);
    }
  }

  List<InlineSpan> _inlineSpans(BuildContext context, String text) {
    final spans = <InlineSpan>[];
    final matches = RegExp(r'`([^`]+)`').allMatches(text).toList(growable: false);
    if (matches.isEmpty) {
      return <InlineSpan>[TextSpan(text: text)];
    }

    var cursor = 0;
    final codeStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          backgroundColor: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.7),
        );

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: codeStyle,
        ),
      );
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }
}

class _CodeLikeBlockView extends StatelessWidget {
  const _CodeLikeBlockView({required this.block});

  final _MarkdownBlock block;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isThinking = block.type == _MarkdownBlockType.thinking;
    final label = isThinking
        ? '思考片段'
        : (block.language?.trim().isNotEmpty == true
              ? block.language!.trim()
              : '代码片段');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isThinking
            ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.55)
            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 4),
            child: Row(
              children: [
                Icon(
                  isThinking ? Icons.psychology_outlined : Icons.code_outlined,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  tooltip: '复制内容',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: block.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('已复制到剪贴板')),
                    );
                  },
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: SelectableText(
              block.text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: 'monospace',
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _MarkdownBlockType {
  paragraph,
  code,
  quote,
  thinking,
}

class _MarkdownBlock {
  const _MarkdownBlock({
    required this.type,
    required this.text,
    this.language,
  });

  final _MarkdownBlockType type;
  final String text;
  final String? language;
}
