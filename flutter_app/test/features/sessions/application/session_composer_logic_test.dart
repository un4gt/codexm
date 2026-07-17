import 'dart:io';

import 'package:codexm_flutter/features/sessions/application/session_composer_logic.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_paths.dart';
import 'package:codexm_native/codexm_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters slash suggestions only in command input stage', () {
    expect(
      filterSlashCommands('/re').any((item) => item.command == '/review'),
      isTrue,
    );
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

  test('finds slash trigger at the cursor and preserves the suffix', () {
    const value = TextEditingValue(
      text: '/rev 后续内容',
      selection: TextSelection.collapsed(offset: 4),
    );

    final trigger = findComposerTrigger(value);
    expect(trigger, isNotNull);
    expect(trigger!.kind, ComposerTriggerKind.slash);
    expect(trigger.query, 'rev');
    expect(trigger.range, const TextRange(start: 0, end: 4));

    final next = applyComposerSuggestion(value, trigger, '/review');
    expect(next.text, '/review 后续内容');
    expect(next.selection.baseOffset, 8);
  });

  test('finds and replaces a mention in the middle of input', () {
    const value = TextEditingValue(
      text: '检查 @mai 然后总结',
      selection: TextSelection.collapsed(offset: 7),
    );

    final trigger = findComposerTrigger(value);
    expect(trigger, isNotNull);
    expect(trigger!.kind, ComposerTriggerKind.mention);
    expect(trigger.query, 'mai');

    final next = applyComposerSuggestion(value, trigger, '@lib/main.dart');
    expect(next.text, '检查 @lib/main.dart 然后总结');
    expect(next.selection.baseOffset, '检查 @lib/main.dart '.length);
  });

  test(
    'adds trailing space and places the cursor after a terminal trigger',
    () {
      const value = TextEditingValue(
        text: '/sta',
        selection: TextSelection.collapsed(offset: 4),
      );
      final trigger = findComposerTrigger(value)!;

      final next = applyComposerSuggestion(value, trigger, '/status');
      expect(next.text, '/status ');
      expect(next.selection, const TextSelection.collapsed(offset: 8));
    },
  );

  test('builds user-facing input with pending mentions', () {
    final rendered =
        buildUserFacingInput('请帮我检查', const <ComposerPendingMention>[
          ComposerPendingMention.file(
            label: 'lib/main.dart',
            value: 'lib/main.dart',
          ),
          ComposerPendingMention.commit(
            label: 'abc1234 fix crash',
            value: 'abc1234567890',
          ),
        ]);

    expect(rendered, contains('@lib/main.dart'));
    expect(rendered, contains('@commit abc1234 fix crash'));
  });

  test('displays workspace paths without android private prefix', () {
    final paths = WorkspacePaths(
      id: 'ws_1',
      workspaceRoot: Directory(
        '/data/user/0/com.unsafe.codexm.flutterapp/app_flutter/workspaces/ws_1',
      ),
      repoDir: Directory(
        '/data/user/0/com.unsafe.codexm.flutterapp/app_flutter/workspaces/ws_1/repo',
      ),
      metaDir: Directory(
        '/data/user/0/com.unsafe.codexm.flutterapp/app_flutter/workspaces/ws_1/.meta',
      ),
      codexHomeDir: Directory(
        '/data/user/0/com.unsafe.codexm.flutterapp/app_flutter/workspaces/ws_1/.meta/codex',
      ),
      tmpDir: Directory(
        '/data/user/0/com.unsafe.codexm.flutterapp/cache/workspaces/ws_1/tmp',
      ),
    );

    expect(
      displayPathForWorkspace(
        paths,
        '/data/user/0/com.unsafe.codexm.flutterapp/app_flutter/workspaces/ws_1/repo/lib/main.dart',
      ),
      'lib/main.dart',
    );
    expect(
      displayPathForWorkspace(
        paths,
        'file:///data/user/0/com.unsafe.codexm.flutterapp/app_flutter/workspaces/ws_1/repo/flutter_app/lib/main.dart',
      ),
      'flutter_app/lib/main.dart',
    );
    expect(displayPathForWorkspace(paths, 'lib/local.dart'), 'lib/local.dart');
  });
}
