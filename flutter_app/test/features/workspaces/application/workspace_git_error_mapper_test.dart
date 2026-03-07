import 'package:codexm_flutter/features/workspaces/application/workspace_git_error_mapper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps authentication failures', () {
    final details = mapWorkspaceGitError(
      PlatformException(
        code: 'E_GIT_BRIDGE',
        message: 'authentication failed',
      ),
    );

    expect(details.type, WorkspaceGitErrorType.authentication);
    expect(details.message, contains('认证信息无效'));
  });

  test('maps certificate failures', () {
    final details = mapWorkspaceGitError(
      PlatformException(
        code: 'E_GIT_BRIDGE',
        message: 'server certificate verification failed',
      ),
    );

    expect(details.type, WorkspaceGitErrorType.certificate);
    expect(details.message, contains('证书校验未通过'));
  });

  test('maps local directory conflict failures', () {
    final details = mapWorkspaceGitError(
      Exception('destination path already exists and is not an empty directory'),
    );

    expect(details.type, WorkspaceGitErrorType.localDirectoryConflict);
    expect(details.message, contains('本地目录不可用'));
  });
}
