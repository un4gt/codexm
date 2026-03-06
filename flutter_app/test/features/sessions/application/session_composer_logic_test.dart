import 'package:codexm_flutter/features/sessions/application/session_composer_logic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:codexm_native/codexm_native.dart';

void main() {
  test('filters slash suggestions only in command input stage', () {
    expect(filterSlashCommands('/re').any((item) => item.command == '/review'), isTrue);
    expect(filterSlashCommands('/review repo').isEmpty, isTrue);
    expect(filterSlashCommands('plain text').isEmpty, isTrue);
  });

  test('filters mention suggestions across files and commits', () {
    final suggestions = filterMentionSuggestions(
      input: '请检查 @api',
      repoFiles: const <String>[
        'lib/api/client.dart',
        'lib/features/sessions/presentation/pages/sessions_page.dart',
      ],
      commits: const <GitCommitSummary>[
        GitCommitSummary(
          hash: 'abcdef1234567890',
          shortHash: 'abcdef1',
          title: 'api: tighten auth flow',
          authorName: 'Codex',
          committedAt: 1,
        ),
      ],
    );

    expect(
      suggestions.any(
        (item) =>
            item.kind == ComposerMentionKind.file &&
            item.value == 'lib/api/client.dart',
      ),
      isTrue,
    );
    expect(
      suggestions.any(
        (item) =>
            item.kind == ComposerMentionKind.commit &&
            item.value == 'abcdef1234567890',
      ),
      isTrue,
    );
  });

  test('builds user-facing input with pending mentions', () {
    final rendered = buildUserFacingInput(
      '请帮我检查',
      const <ComposerPendingMention>[
        ComposerPendingMention.file(label: 'lib/main.dart', value: 'lib/main.dart'),
        ComposerPendingMention.commit(
          label: 'abc1234 fix crash',
          value: 'abc1234567890',
        ),
      ],
    );

    expect(rendered, contains('@lib/main.dart'));
    expect(rendered, contains('@commit abc1234 fix crash'));
  });
}
