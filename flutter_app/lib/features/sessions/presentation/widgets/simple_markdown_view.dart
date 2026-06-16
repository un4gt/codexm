import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_highlight/flutter_highlight.dart';
import 'package:flutter_highlight/themes/atom-one-dark.dart';
import 'package:flutter_highlight/themes/dracula.dart';
import 'package:flutter_highlight/themes/github.dart';
import 'package:flutter_highlight/themes/vs.dart';
import 'package:flutter_highlight/themes/vs2015.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../settings/application/codex_settings_store.dart';

class SimpleMarkdownView extends StatelessWidget {
  const SimpleMarkdownView({
    super.key,
    required this.content,
    this.showThinking = false,
    this.textAlign = TextAlign.left,
  });

  final String content;
  final bool showThinking;
  final TextAlign textAlign;

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
      widgets.add(_MarkdownBlockView(block: block, textAlign: textAlign));
    }

    if (visibleCount == 0) {
      return Text(
        '这段回复只包含思考内容，当前已隐藏。',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
  final listItems = <String>[];
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

  void flushList() {
    if (listItems.isEmpty) {
      return;
    }
    blocks.add(
      _MarkdownBlock(
        type: _MarkdownBlockType.unorderedList,
        text: '',
        items: List<String>.from(listItems),
      ),
    );
    listItems.clear();
  }

  void flushFence() {
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
      flushList();
      inThinkingTag = true;
      continue;
    }

    if (trimmed.startsWith('```')) {
      flushParagraph();
      flushQuote();
      flushList();
      inFence = true;
      fenceLanguage = trimmed.substring(3).trim().toLowerCase();
      continue;
    }

    if (trimmed.startsWith('>')) {
      flushParagraph();
      flushList();
      quote.add(trimmed.substring(1).trimLeft());
      continue;
    }

    if (trimmed.isEmpty) {
      flushParagraph();
      flushQuote();
      flushList();
      continue;
    }

    final unorderedMatch = RegExp(r'^\s*[-*+]\s+(.+)$').firstMatch(line);
    if (unorderedMatch != null) {
      flushParagraph();
      flushQuote();
      listItems.add(unorderedMatch.group(1)!.trimRight());
      continue;
    }

    if (listItems.isNotEmpty && line.startsWith(RegExp(r'\s'))) {
      listItems[listItems.length - 1] = '${listItems.last}\n${line.trimLeft()}';
      continue;
    }

    flushList();
    paragraph.add(line);
  }

  flushParagraph();
  flushQuote();
  flushList();
  if (inFence) {
    flushFence();
  }
  flushThinkingTag();
  return blocks;
}

class _MarkdownBlockView extends StatelessWidget {
  const _MarkdownBlockView({required this.block, required this.textAlign});

  final _MarkdownBlock block;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    switch (block.type) {
      case _MarkdownBlockType.paragraph:
        return SelectableText.rich(
          TextSpan(children: _inlineSpans(context, block.text)),
          textAlign: textAlign,
        );
      case _MarkdownBlockType.quote:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 3,
              ),
            ),
          ),
          child: SelectableText(block.text, textAlign: textAlign),
        );
      case _MarkdownBlockType.unorderedList:
        final items = block.items.isNotEmpty
            ? block.items
            : block.text.split('\n');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < items.length; index += 1) ...[
              if (index > 0) const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 18,
                    child: Text(
                      '•',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    child: SelectableText.rich(
                      TextSpan(children: _inlineSpans(context, items[index])),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      case _MarkdownBlockType.code:
      case _MarkdownBlockType.thinking:
        return SimpleCodeBlock(
          content: block.text,
          language: block.type == _MarkdownBlockType.thinking
              ? 'thinking'
              : block.language,
          thinking: block.type == _MarkdownBlockType.thinking,
        );
    }
  }

  List<InlineSpan> _inlineSpans(BuildContext context, String text) {
    final spans = <InlineSpan>[];
    final matches = RegExp(
      r'`([^`]+)`',
    ).allMatches(text).toList(growable: false);
    if (matches.isEmpty) {
      return <InlineSpan>[TextSpan(text: text)];
    }

    var cursor = 0;
    final theme = Theme.of(context);
    final codeStyle = theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      backgroundColor: context.appTokens.codeBackground,
      color: theme.colorScheme.onSurface,
      height: 1.35,
    );

    for (final match in matches) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      spans.add(TextSpan(text: match.group(1), style: codeStyle));
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }
}

class SimpleCodeBlock extends StatelessWidget {
  const SimpleCodeBlock({
    super.key,
    required this.content,
    this.language,
    this.thinking = false,
  });

  final String content;
  final String? language;
  final bool thinking;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = context.appTokens;
    final label = thinking
        ? '思考片段'
        : (language?.trim().isNotEmpty == true ? language!.trim() : '代码片段');
    final normalizedLanguage = _normalizeHighlightLanguage(language);
    final highlightTheme = _highlightThemeFor(theme.brightness, tokens);
    highlightTheme['root'] = (highlightTheme['root'] ?? const TextStyle())
        .copyWith(
          backgroundColor: Colors.transparent,
          color: theme.colorScheme.onSurface,
          fontFamily: 'monospace',
          fontSize: theme.textTheme.bodyMedium?.fontSize,
          height: 1.45,
        );

    return Container(
      key: const ValueKey('simple-code-block'),
      width: double.infinity,
      decoration: BoxDecoration(
        color: thinking
            ? theme.colorScheme.secondaryContainer.withValues(alpha: 0.55)
            : tokens.codeBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: theme.brightness == Brightness.dark ? 0.18 : 0.38,
            ),
            padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
            child: Row(
              children: [
                Icon(
                  thinking ? Icons.psychology_outlined : Icons.code_outlined,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                IconButton(
                  tooltip: '复制内容',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
                  },
                  icon: const Icon(Icons.copy_all_outlined, size: 18),
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: tokens.codePadding,
            child: normalizedLanguage == null
                ? SelectableText(
                    content,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.45,
                      color: theme.colorScheme.onSurface,
                    ),
                  )
                : HighlightView(
                    content,
                    language: normalizedLanguage,
                    theme: highlightTheme,
                    padding: EdgeInsets.zero,
                    textStyle: theme.textTheme.bodyMedium?.copyWith(
                      fontFamily: 'monospace',
                      height: 1.45,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String? _normalizeHighlightLanguage(String? raw) {
    final language = raw?.trim().toLowerCase();
    if (language == null || language.isEmpty || language == '代码片段') {
      return null;
    }
    return switch (language) {
      'sh' || 'bash' || 'shell' => 'bash',
      'js' || 'javascript' => 'javascript',
      'ts' || 'typescript' => 'typescript',
      'py' || 'python' => 'python',
      'dart' => 'dart',
      'json' => 'json',
      'yaml' || 'yml' => 'yaml',
      'diff' => 'diff',
      'html' => 'xml',
      'xml' => 'xml',
      'css' => 'css',
      'java' => 'java',
      'kt' || 'kotlin' => 'kotlin',
      'thinking' => null,
      _ => null,
    };
  }

  Map<String, TextStyle> _highlightThemeFor(
    Brightness brightness,
    AppThemeTokens tokens,
  ) {
    final source = brightness == Brightness.dark
        ? switch (CodexDarkCodeThemePreference.normalize(
            tokens.darkCodeThemePreference,
          )) {
            CodexDarkCodeThemePreference.dracula => draculaTheme,
            CodexDarkCodeThemePreference.oneDarkPro => atomOneDarkTheme,
            _ => vs2015Theme,
          }
        : switch (CodexLightCodeThemePreference.normalize(
            tokens.lightCodeThemePreference,
          )) {
            CodexLightCodeThemePreference.githubLight => githubTheme,
            _ => vsTheme,
          };
    return Map<String, TextStyle>.from(source);
  }
}

enum _MarkdownBlockType { paragraph, code, quote, unorderedList, thinking }

class _MarkdownBlock {
  const _MarkdownBlock({
    required this.type,
    required this.text,
    this.language,
    this.items = const <String>[],
  });

  final _MarkdownBlockType type;
  final String text;
  final String? language;
  final List<String> items;
}
