import 'dart:convert';

/// Builds and interprets the minimal JSON-RPC messages used by the Android smoke flow.
class CodexSmokeRpc {
  int _nextRequestId = 1;

  /// Returns the next request id for a JSON-RPC call.
  int nextRequestId() => _nextRequestId++;

  /// Builds the runtime `initialize` request.
  String buildInitializeRequest(int requestId) {
    return jsonEncode({
      'jsonrpc': '2.0',
      'id': requestId,
      'method': 'initialize',
      'params': {
        'clientInfo': {
          'name': 'codexm_flutter_smoke',
          'title': 'CodexM Flutter Smoke',
          'version': '0.0.7',
        },
        'capabilities': {'experimentalApi': true},
      },
    });
  }

  /// Builds the `initialized` notification sent after initialize succeeds.
  String buildInitializedNotification() {
    return jsonEncode({
      'jsonrpc': '2.0',
      'method': 'initialized',
      'params': <String, Object?>{},
    });
  }

  /// Builds the `thread/start` request used by the smoke page.
  String buildThreadStartRequest({
    required int requestId,
    required String cwd,
    String approvalPolicy = 'never',
  }) {
    return jsonEncode({
      'jsonrpc': '2.0',
      'id': requestId,
      'method': 'thread/start',
      'params': {
        'cwd': cwd,
        'approvalPolicy': approvalPolicy,
        'personality': 'none',
      },
    });
  }

  /// Builds the `turn/start` request used to verify the first assistant message.
  String buildTurnStartRequest({
    required int requestId,
    required String threadId,
    required String cwd,
    required String prompt,
    String approvalPolicy = 'never',
  }) {
    return jsonEncode({
      'jsonrpc': '2.0',
      'id': requestId,
      'method': 'turn/start',
      'params': {
        'threadId': threadId,
        'cwd': cwd,
        'approvalPolicy': approvalPolicy,
        'input': [
          {'type': 'text', 'text': prompt},
        ],
      },
    });
  }

  /// Attempts to decode a runtime stdout line as JSON-RPC.
  Map<String, Object?>? tryDecodeMessage(String line) {
    try {
      final value = jsonDecode(line);
      if (value is Map) {
        return value.map(
          (key, value) => MapEntry(key.toString(), value),
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Returns whether the given message is the matching initialize response.
  bool isInitializeResponse(Map<String, Object?> message, int requestId) {
    return message['id'] == requestId && message.containsKey('result');
  }

  /// Returns whether the given message indicates a turn finished.
  bool isTurnCompleted(Map<String, Object?> message) {
    return message['method'] == 'turn/completed';
  }

  /// Extracts a thread id from a `thread/start` response.
  String? extractThreadId(Map<String, Object?> message) {
    final result = message['result'];
    if (result is Map) {
      final thread = result['thread'];
      if (thread is Map) {
        return thread['id']?.toString();
      }
    }
    return null;
  }

  /// Extracts streamed assistant text from runtime notifications.
  String? extractAssistantDelta(Map<String, Object?> message) {
    final method = message['method']?.toString();
    if (method == 'item/agentMessage/delta' || (method?.endsWith('/outputDelta') ?? false)) {
      final params = message['params'];
      if (params is Map) {
        final delta = params['delta'];
        if (delta is String) {
          return delta;
        }
        if (delta is Map) {
          return delta['text']?.toString();
        }
      }
    }
    return null;
  }

  /// Extracts a runtime error message from a JSON-RPC notification if present.
  String? extractErrorMessage(Map<String, Object?> message) {
    if (message['method'] != 'error') {
      return null;
    }
    final params = message['params'];
    if (params is Map) {
      final error = params['error'];
      if (error is Map && error['message'] != null) {
        return error['message'].toString();
      }
      if (params['message'] != null) {
        return params['message'].toString();
      }
    }
    return '运行时返回错误';
  }
}
