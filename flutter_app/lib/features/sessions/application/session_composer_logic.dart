import 'package:codexm_native/codexm_native.dart';

import '../../codex/application/codex_models.dart';
import '../../codex/application/codex_slash_commands.dart';

enum ComposerMentionKind { file, commit }

class ComposerPendingMention {
  const ComposerPendingMention.file({
    required this.label,
    required this.value,
  }) : kind = ComposerMentionKind.file;

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
      .where((item) => item.command.substring(1).toLowerCase().startsWith(query))
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
  final known = installedSkills.map((item) => item.trim()).where((item) => item.isNotEmpty).toSet();
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

String buildUserFacingInput(String text, List<ComposerPendingMention> mentions) {
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
