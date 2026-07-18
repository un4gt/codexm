import 'package:codexm_flutter/features/sessions/application/session_code_error_mapper.dart';
import 'package:codexm_flutter/features/sessions/application/session_code_workspace_service.dart';
import 'package:codexm_native/codexm_native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps dirty sessions to checkpoint guidance', () {
    final details = mapSessionCodeError(
      const SessionCodeDirtyException(
        GitStatus(
          staged: <String>[],
          unstaged: <String>['lib/main.dart'],
          untracked: <String>[],
        ),
      ),
    );

    expect(details.message, contains('保存代码检查点'));
    expect(details.message, isNot(contains('lib/main.dart')));
  });

  test('maps stable native worktree errors without leaking native details', () {
    final details = mapSessionCodeError(
      PlatformException(
        code: 'E_GIT_WORKTREE',
        message: '/data/user/0/app/worktrees/session is invalid',
      ),
    );

    expect(details.message, contains('会话代码环境不可用'));
    expect(details.message, isNot(contains('/data/user')));
    expect(details.debugMessage, contains('/data/user'));
  });

  test('uses product-safe copy for unknown native errors', () {
    final details = mapSessionCodeError(
      PlatformException(
        code: 'E_GIT_BRIDGE',
        message: 'raw libgit2 diagnostic',
      ),
    );

    expect(details.message, '代码操作未完成，请稍后重试。');
    expect(details.message, isNot(contains('libgit2')));
  });

  test('blocks deletion while a session participates in an active merge', () {
    final details = mapSessionCodeError(
      const SessionCodeMergeInProgressException(),
    );

    expect(details.message, contains('先完成或放弃合并'));
  });
}
