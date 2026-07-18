import 'dart:io';

import 'package:flutter/services.dart';

import 'session_code_workspace_service.dart';

class SessionCodeErrorDetails {
  const SessionCodeErrorDetails({
    required this.message,
    required this.debugMessage,
  });

  final String message;
  final String debugMessage;
}

SessionCodeErrorDetails mapSessionCodeError(Object error) {
  if (error is SessionCodeDirtyException) {
    return SessionCodeErrorDetails(
      message: '当前代码还有未保存改动，请先保存代码检查点后重试。',
      debugMessage: error.toString(),
    );
  }
  if (error is SessionCodeMigrationRequiredException) {
    return SessionCodeErrorDetails(
      message: '请先保存工作区基线，再使用独立会话。',
      debugMessage: error.toString(),
    );
  }
  if (error is SessionCodeIdentityRequiredException) {
    return SessionCodeErrorDetails(
      message: '请先设置 Git 提交姓名和邮箱后重试。',
      debugMessage: error.toString(),
    );
  }
  if (error is SessionCodeUnmergedException) {
    return SessionCodeErrorDetails(
      message: '该会话还有未合并代码，请先合并或归档后重试。',
      debugMessage: error.toString(),
    );
  }
  if (error is SessionCodeMergeInProgressException) {
    return SessionCodeErrorDetails(
      message: '该会话正在参与合并，请先完成或放弃合并。',
      debugMessage: error.toString(),
    );
  }

  if (error is PlatformException) {
    final message = switch (error.code) {
      'E_GIT_DIRTY' => '当前代码还有未保存改动，请先保存代码检查点后重试。',
      'E_GIT_CONFLICT' => '仍有合并冲突需要处理，请先完成或放弃合并。',
      'E_GIT_IDENTITY' => '请先设置 Git 提交姓名和邮箱后重试。',
      'E_GIT_WORKTREE' => '会话代码环境不可用，请返回会话列表后重试。',
      'E_GIT_NOT_FOUND' => '未找到会话分支或代码工作副本，请返回会话列表后重试。',
      'E_GIT_PERMISSION' => '无法访问会话代码，请重新打开工作区后重试。',
      _ => '代码操作未完成，请稍后重试。',
    };
    return SessionCodeErrorDetails(
      message: message,
      debugMessage: '${error.code}: ${error.message ?? ''}'.trim(),
    );
  }

  if (error is FileSystemException) {
    final permissionDenied =
        error.osError?.errorCode == 13 ||
        error.message.toLowerCase().contains('permission');
    return SessionCodeErrorDetails(
      message: permissionDenied
          ? '无法访问会话代码，请重新打开工作区后重试。'
          : '会话代码文件不可用，请返回会话列表后重试。',
      debugMessage: error.toString(),
    );
  }

  return SessionCodeErrorDetails(
    message: '代码操作未完成，请稍后重试。',
    debugMessage: error.toString(),
  );
}
