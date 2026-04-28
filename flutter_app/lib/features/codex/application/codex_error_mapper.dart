import 'json_rpc_client.dart';

class RuntimeNotificationError {
  const RuntimeNotificationError({
    required this.message,
    required this.willRetry,
    this.codexErrorInfo,
    this.additionalDetails,
  });

  final String message;
  final bool willRetry;
  final Object? codexErrorInfo;
  final String? additionalDetails;

  bool get retryLimitReached {
    final info = codexErrorInfo;
    if (info is Map) {
      return info.containsKey('responseTooManyFailedAttempts') ||
          info.containsKey('response_too_many_failed_attempts');
    }
    final haystack = [
      message,
      additionalDetails ?? '',
      info?.toString() ?? '',
    ].join('\n').toLowerCase();
    return haystack.contains('responsetoomanyfailedattempts') ||
        haystack.contains('response too many failed attempts') ||
        haystack.contains('retry limit') ||
        haystack.contains('max retry');
  }
}

bool isMissingThreadState(Object error) {
  final message = error.toString();
  String details = '';
  if (error is JsonRpcError &&
      error.data is Map &&
      (error.data as Map)['details'] != null) {
    details = (error.data as Map)['details'].toString();
  }

  final haystack = '$message\n$details'.toLowerCase();
  return haystack.contains('no rollout found for thread id') ||
      haystack.contains('no thread found with id');
}

String formatRpcErrorForLog(Object error) {
  if (error is JsonRpcError) {
    final base = error.message.trim().isEmpty
        ? 'JSON-RPC error'
        : error.message;
    if (error.data is Map) {
      final details = (error.data as Map)['details']?.toString().trim() ?? '';
      if (details.isNotEmpty &&
          !base.toLowerCase().contains(details.toLowerCase())) {
        return '$base\n$details';
      }
    }
    return base;
  }
  return error.toString();
}

String formatRpcErrorForUser(Object error) {
  final message = error.toString();
  final lower = message.toLowerCase();

  if (message.contains('请求超时') || message.contains('发送请求超时')) {
    return '连接超时：请检查网络与「设置」中的服务器地址/密钥是否正确。';
  }

  final runtimeBridgeError =
      lower.contains('e_codex_runtime_start') ||
      lower.contains('e_codex_runtime_send');
  final missingRuntimeBinaries =
      lower.contains('未能从 nativelibrarydir 解析 codex 运行时可执行文件') ||
      lower.contains('missing: libcodex.so') ||
      lower.contains('missing: libcodex_exec.so') ||
      lower.contains('missing: librg.so') ||
      lower.contains('codexruntime 缺少依赖库');
  final runtimePermissionError =
      lower.contains('permission denied') || lower.contains('无法执行可执行文件');
  final runtimeStartupExit =
      lower.contains('codexruntime 启动后立即退出') ||
      lower.contains('runtime not running');

  if (runtimeBridgeError ||
      missingRuntimeBinaries ||
      runtimePermissionError ||
      runtimeStartupExit) {
    if (missingRuntimeBinaries) {
      return '当前安装包缺少 Codex 运行组件，请安装包含运行时的最新安装包后重试。';
    }
    if (runtimePermissionError) {
      return 'Codex 运行组件权限异常，请重装应用后重试。';
    }
    if (runtimeStartupExit) {
      return 'Codex 启动失败：请检查「设置 > 连接」中的 API Key / Base URL 后重试。';
    }
    return 'Codex 启动失败，请稍后重试。';
  }

  if (message.contains('CollaborationMode') ||
      message.contains('CollabrationMode') ||
      (message.contains('Invalid request') &&
          message.contains('expected struct')) ||
      (message.contains('invalid type') &&
          message.contains('expected struct'))) {
    return '服务返回了协议校验错误：请更新应用与 Codex 运行时后重试。';
  }

  if (error is JsonRpcError) {
    return error.message.trim().isEmpty ? '服务返回错误。' : error.message;
  }

  return message.trim().isEmpty ? '发生未知错误。' : message;
}

RuntimeNotificationError parseRuntimeNotificationError(Object? params) {
  if (params is! Map) {
    return const RuntimeNotificationError(
      message: 'Codex 运行出错。',
      willRetry: false,
    );
  }

  final error = params['error'];
  final willRetry = params['willRetry'] == true || params['will_retry'] == true;
  String? additionalDetails;
  if (error is Map && error['message'] != null) {
    final rawAdditional =
        error['additionalDetails'] ?? error['additional_details'];
    additionalDetails = rawAdditional?.toString();
    return RuntimeNotificationError(
      message: error['message'].toString(),
      willRetry: willRetry,
      codexErrorInfo: error['codexErrorInfo'] ?? error['codex_error_info'],
      additionalDetails: additionalDetails,
    );
  }
  if (params['message'] != null) {
    return RuntimeNotificationError(
      message: params['message'].toString(),
      willRetry: willRetry,
    );
  }
  return RuntimeNotificationError(message: 'Codex 运行出错。', willRetry: willRetry);
}

String formatRuntimeNotificationError(Object? params) {
  final error = parseRuntimeNotificationError(params);
  if (error.retryLimitReached) {
    return '重连失败：已达到重试上限，请检查网络后重试。';
  }
  return error.message.trim().isEmpty ? 'Codex 运行出错。' : error.message;
}
