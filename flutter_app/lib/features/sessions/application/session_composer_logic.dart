import 'package:codexm_native/codexm_native.dart';
import 'package:flutter/services.dart';

import '../../codex/application/codex_models.dart';
import '../../codex/application/codex_slash_commands.dart';
import '../../codex/application/runtime_path_mapper.dart';
import '../../workspaces/application/workspace_paths.dart';

enum ComposerMentionKind { file, commit }

enum ComposerTriggerKind { slash, mention }

class ComposerTrigger {
  const ComposerTrigger({
    required this.kind,
    required this.query,
    required this.range,
  });

  final ComposerTriggerKind kind;
  final String query;
  final TextRange range;
}

class ComposerPendingMention {
  const ComposerPendingMention.file({required this.label, required this.value})
    : kind = ComposerMentionKind.file;

  const ComposerPendingMention.commit({
    required this.label,
    required this.value,
  }) : kind = ComposerMentionKind.commit;

  final ComposerMentionKind kind;
  final String label;
  final String value;
}

class ComposerMentionSuggestion {
  const ComposerMentionSuggestion({
    required this.kind,
    required this.label,
    required this.value,
    required this.description,
  });

  final ComposerMentionKind kind;
  final String label;
  final String value;
  final String description;
}

ComposerTrigger? findComposerTrigger(TextEditingValue value) {
  final selection = value.selection;
  if (!selection.isValid || !selection.isCollapsed) {
    return null;
  }
  final text = value.text;
  final cursor = selection.extentOffset;
  if (cursor < 0 || cursor > text.length) {
    return null;
  }
  final beforeCursor = text.substring(0, cursor);
  final match = RegExp(r'(^|\s)([/@])([^\s/@]*)$').firstMatch(beforeCursor);
  if (match == null) {
    return null;
  }

  final prefixLength = (match.group(1) ?? '').length;
  final start = match.start + prefixLength;
  final marker = match.group(2);
  if (marker == '/') {
    final firstContent = text.indexOf(RegExp(r'\S'));
    if (firstContent != start) {
      return null;
    }
  }

  var end = cursor;
  while (end < text.length && !RegExp(r'[\s/@]').hasMatch(text[end])) {
    end += 1;
  }
  return ComposerTrigger(
    kind: marker == '/'
        ? ComposerTriggerKind.slash
        : ComposerTriggerKind.mention,
    query: match.group(3) ?? '',
    range: TextRange(start: start, end: end),
  );
}

TextEditingValue applyComposerSuggestion(
  TextEditingValue value,
  ComposerTrigger trigger,
  String replacement,
) {
  final text = value.text;
  final safeStart = trigger.range.start.clamp(0, text.length);
  final safeEnd = trigger.range.end.clamp(safeStart, text.length);
  final prefix = text.substring(0, safeStart);
  final suffix = text.substring(safeEnd);
  final hasLeadingWhitespace =
      suffix.isNotEmpty && RegExp(r'\s').hasMatch(suffix[0]);
  final inserted = hasLeadingWhitespace ? replacement : '$replacement ';
  final next = '$prefix$inserted$suffix';
  final cursor =
      prefix.length + inserted.length + (hasLeadingWhitespace ? 1 : 0);
  return TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: cursor.clamp(0, next.length)),
  );
}

TextEditingValue removeComposerTrigger(
  TextEditingValue value,
  ComposerTrigger trigger,
) {
  final text = value.text;
  final safeStart = trigger.range.start.clamp(0, text.length);
  final safeEnd = trigger.range.end.clamp(safeStart, text.length);
  final prefix = text.substring(0, safeStart).trimRight();
  final suffix = text.substring(safeEnd);
  final next = '$prefix$suffix';
  return TextEditingValue(
    text: next,
    selection: TextSelection.collapsed(offset: prefix.length),
  );
}

String? extractSlashToken(String input) {
  final trimmed = input.trimLeft();
  if (!trimmed.startsWith('/')) {
    return null;
  }
  if (RegExp(r'\s').hasMatch(trimmed)) {
    return null;
  }
  return trimmed;
}

String? extractMentionToken(String input) {
  final match = RegExp(r'(^|\s)@([^\s@]*)$').firstMatch(input);
  if (match == null) {
    return null;
  }
  return match.group(2) ?? '';
}

String replaceActiveSlashToken(String input, String command) {
  final leadingWhitespace = RegExp(r'^\s*').firstMatch(input)?.group(0) ?? '';
  final trimmed = input.substring(leadingWhitespace.length);
  if (!trimmed.startsWith('/')) {
    return '$leadingWhitespace$command ';
  }
  final firstWhitespace = trimmed.indexOf(RegExp(r'\s'));
  if (firstWhitespace == -1) {
    return '$leadingWhitespace$command ';
  }
  return '$leadingWhitespace$command${trimmed.substring(firstWhitespace)}';
}

String clearActiveMentionToken(String input) {
  final match = RegExp(r'(^|\s)@([^\s@]*)$').firstMatch(input);
  if (match == null) {
    return input;
  }
  final prefixLength = (match.group(1) ?? '').length;
  final start = match.start + prefixLength;
  return input.substring(0, start).trimRight();
}

List<CodexSlashCommand> filterSlashCommands(String input) {
  final token = extractSlashToken(input);
  if (token == null) {
    return const <CodexSlashCommand>[];
  }
  final query = token.substring(1).toLowerCase();
  if (query.isEmpty) {
    return visibleCodexSlashCommands;
  }
  return visibleCodexSlashCommands
      .where(
        (item) => item.command.substring(1).toLowerCase().startsWith(query),
      )
      .toList(growable: false);
}

List<CodexSlashCommand> filterSlashCommandsForQuery(String query) {
  final normalized = query.trim().toLowerCase();
  if (normalized.isEmpty) {
    return visibleCodexSlashCommands;
  }
  return visibleCodexSlashCommands
      .where(
        (item) =>
            item.command.substring(1).toLowerCase().startsWith(normalized),
      )
      .toList(growable: false);
}

List<ComposerMentionSuggestion> filterMentionSuggestions({
  required String input,
  required Iterable<String> repoFiles,
  required Iterable<GitCommitSummary> commits,
  int limit = 12,
}) {
  final token = extractMentionToken(input);
  if (token == null) {
    return const <ComposerMentionSuggestion>[];
  }
  final query = token.trim().toLowerCase();

  final suggestions = <ComposerMentionSuggestion>[];

  final fileMatches = repoFiles.where((path) {
    if (query.isEmpty) {
      return true;
    }
    return path.toLowerCase().contains(query);
  });
  for (final path in fileMatches.take(limit)) {
    suggestions.add(
      ComposerMentionSuggestion(
        kind: ComposerMentionKind.file,
        label: path,
        value: path,
        description: '文件',
      ),
    );
  }

  final remaining = limit - suggestions.length;
  if (remaining <= 0) {
    return suggestions;
  }

  final commitMatches = commits.where((commit) {
    if (query.isEmpty) {
      return true;
    }
    final haystack =
        '${commit.hash} ${commit.shortHash} ${commit.title} ${commit.authorName}'
            .toLowerCase();
    return haystack.contains(query);
  });
  for (final commit in commitMatches.take(remaining)) {
    suggestions.add(
      ComposerMentionSuggestion(
        kind: ComposerMentionKind.commit,
        label: '${commit.shortHash} ${commit.title}'.trim(),
        value: commit.hash,
        description: commit.authorName.trim().isEmpty
            ? '提交'
            : '提交 · ${commit.authorName}',
      ),
    );
  }

  return suggestions;
}

List<String> extractSkillNames(String text, Iterable<String> installedSkills) {
  final known = installedSkills
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet();
  if (known.isEmpty) {
    return const <String>[];
  }
  final tokens = RegExp(r'\B\$([A-Za-z0-9_-]{2,})\b')
      .allMatches(text)
      .map((match) => (match.group(1) ?? '').trim())
      .where(known.contains)
      .toSet();
  return tokens.toList(growable: false);
}

String buildUserFacingInput(
  String text,
  List<ComposerPendingMention> mentions,
) {
  if (mentions.isEmpty) {
    return text.trim();
  }
  final buffer = StringBuffer(text.trim());
  buffer.write('\n\n');
  for (final mention in mentions) {
    if (mention.kind == ComposerMentionKind.file) {
      buffer.writeln('@${mention.label}');
    } else {
      buffer.writeln('@commit ${mention.label}');
    }
  }
  return buffer.toString().trimRight();
}

String displayPathForWorkspace(
  WorkspacePaths paths,
  String rawPath, {
  String? workspaceRepoDir,
}) {
  final hasFileScheme = rawPath.trim().startsWith('file://');
  final value = rawPath.trim().replaceFirst(RegExp(r'^file://'), '');
  if (value.isEmpty) {
    return value;
  }

  final mapper = RuntimePathMapper(
    workspaceRepoDir: workspaceRepoDir ?? paths.repoDir.path,
    codexHomeDir: paths.codexHomeDir.path,
    tmpDir: paths.tmpDir.path,
  );
  final mapped = mapper.realToVirtual(value);
  if (mapped == RuntimePathMapper.workspaceAlias) {
    return RuntimePathMapper.workspaceAlias;
  }
  if (mapped.startsWith('${RuntimePathMapper.workspaceAlias}/')) {
    return mapped.substring(RuntimePathMapper.workspaceAlias.length + 1);
  }
  if (!hasFileScheme && !value.startsWith('/')) {
    return value;
  }
  return mapped;
}
