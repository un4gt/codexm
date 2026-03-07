import 'package:flutter/services.dart';

enum WorkspaceGitErrorType {
  authentication,
  certificate,
  repositoryNotFound,
  localDirectoryConflict,
  network,
  unknown,
}

class WorkspaceGitErrorDetails {
  const WorkspaceGitErrorDetails({
    required this.type,
    required this.message,
    required this.debugMessage,
  });

  final WorkspaceGitErrorType type;
  final String message;
  final String debugMessage;
}

WorkspaceGitErrorDetails mapWorkspaceGitError(Object error) {
  final rawMessage = switch (error) {
    PlatformException exception => exception.message ?? exception.code,
    _ => error.toString(),
  }.trim();
  final lower = rawMessage.toLowerCase();

  if (_matchesAny(lower, const [
    'authentication',
    'credentials',
    'auth',
    'unauthorized',
    'forbidden',
    'could not authenticate',
  ])) {
    return WorkspaceGitErrorDetails(
      type: WorkspaceGitErrorType.authentication,
      message: '连接失败：认证信息无效，或当前仓库没有访问权限。',
      debugMessage: rawMessage,
    );
  }

  if (_matchesAny(lower, const [
    'certificate',
    'ssl',
    'tls',
    'schannel',
    'server certificate',
  ])) {
    return WorkspaceGitErrorDetails(
      type: WorkspaceGitErrorType.certificate,
      message: '连接失败：证书校验未通过。若是内网或自签名仓库，请确认安全设置。',
      debugMessage: rawMessage,
    );
  }

  if (_matchesAny(lower, const [
    'repository not found',
    'not found',
    'does not exist',
    'unable to find',
  ])) {
    return WorkspaceGitErrorDetails(
      type: WorkspaceGitErrorType.repositoryNotFound,
      message: '连接失败：找不到该仓库，请检查仓库地址是否正确。',
      debugMessage: rawMessage,
    );
  }

  if (_matchesAny(lower, const [
    'not empty',
    'already exists',
    'exists and is not an empty directory',
  ])) {
    return WorkspaceGitErrorDetails(
      type: WorkspaceGitErrorType.localDirectoryConflict,
      message: '本地目录不可用：目标目录已存在内容，请更换工作区或清理后重试。',
      debugMessage: rawMessage,
    );
  }

  if (_matchesAny(lower, const [
    'network',
    'dns',
    'resolve host',
    'timeout',
    'connection',
    'could not connect',
  ])) {
    return WorkspaceGitErrorDetails(
      type: WorkspaceGitErrorType.network,
      message: '连接失败：网络不可达或远端暂时无响应，请稍后再试。',
      debugMessage: rawMessage,
    );
  }

  return WorkspaceGitErrorDetails(
    type: WorkspaceGitErrorType.unknown,
    message: '执行失败：${rawMessage.isEmpty ? '出现未知错误。' : rawMessage}',
    debugMessage: rawMessage,
  );
}

bool _matchesAny(String value, List<String> patterns) {
  for (final pattern in patterns) {
    if (value.contains(pattern)) {
      return true;
    }
  }
  return false;
}
