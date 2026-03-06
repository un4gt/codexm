import 'package:codexm_flutter/features/codex/application/codex_slash_commands.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('finds known slash command from input', () {
    final command = findCodexSlashCommand('/review 当前改动');

    expect(command?.command, '/review');
    expect(command?.purpose, contains('评审'));
  });

  test('returns null for unknown input', () {
    expect(findCodexSlashCommand('普通消息'), isNull);
    expect(findCodexSlashCommand('/unknown'), isNull);
  });
}
