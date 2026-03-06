import 'json_rpc_client.dart';

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
    final base = error.message.trim().isEmpty ? 'JSON-RPC error' : error.message;
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

  if (lower.contains('e_codex_runtime_start') ||
      lower.contains('e_codex_runtime_send') ||
      lower.contains('nativelibrarydir') ||
      lower.contains('libcodex.so') ||
      lower.contains('codexruntime')) {
    return 'Codex 运行时未就绪：请安装发布构建后重试。';
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

String formatRuntimeNotificationError(Object? params) {
  if (params is! Map) {
    return 'Codex 运行出错。';
  }

  final error = params['error'];
  if (error is Map && error['message'] != null) {
    return error['message'].toString();
  }
  if (params['message'] != null) {
    return params['message'].toString();
  }
  return 'Codex 运行出错。';
}
