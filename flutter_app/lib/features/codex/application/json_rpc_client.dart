import 'dart:async';
import 'dart:convert';

class JsonRpcError implements Exception {
  JsonRpcError(
    this.message, {
    this.code,
    this.data,
  });

  final String message;
  final int? code;
  final Object? data;

  @override
  String toString() => message;
}

class JsonRpcNotification {
  const JsonRpcNotification({
    required this.method,
    this.params,
  });

  final String method;
  final Object? params;
}

class JsonRpcServerRequest {
  const JsonRpcServerRequest({
    required this.id,
    required this.method,
    this.params,
  });

  final int id;
  final String method;
  final Object? params;
}

typedef JsonRpcSendLine = Future<void> Function(String line);
typedef JsonRpcServerRequestHandler = FutureOr<Object?> Function(
  JsonRpcServerRequest request,
);

class JsonRpcClient {
  JsonRpcClient(this._sendLine);

  final JsonRpcSendLine _sendLine;
  final StreamController<JsonRpcNotification> _notificationsController =
      StreamController<JsonRpcNotification>.broadcast();
  final Map<int, _PendingRequest> _pending = <int, _PendingRequest>{};

  int _nextId = 1;
  JsonRpcServerRequestHandler? _serverRequestHandler;

  Stream<JsonRpcNotification> get notifications => _notificationsController.stream;

  set serverRequestHandler(JsonRpcServerRequestHandler? handler) {
    _serverRequestHandler = handler;
  }

  Future<T> request<T>(
    String method, {
    Object? params,
    int? timeoutMs,
  }) async {
    final id = _nextId++;
    final completer = Completer<T>();
    Timer? timer;

    if (timeoutMs != null && timeoutMs > 0) {
      timer = Timer(Duration(milliseconds: timeoutMs), () {
        final pending = _pending.remove(id);
        if (pending == null || pending.completer.isCompleted) {
          return;
        }
        pending.completer.completeError(
          StateError('请求超时。'),
        );
      });
    }

    _pending[id] = _PendingRequest(completer, timer);

    try {
      await _sendLine(
        jsonEncode(<String, Object?>{
          'id': id,
          'method': method,
          'params': params,
        }),
      );
    } catch (error) {
      final pending = _pending.remove(id);
      pending?.timer?.cancel();
      if (pending != null && !pending.completer.isCompleted) {
        pending.completer.completeError(_toError(error));
      }
    }

    return completer.future;
  }

  Future<void> notify(
    String method, {
    Object? params,
  }) {
    return _sendLine(
      jsonEncode(<String, Object?>{
        'method': method,
        'params': params,
      }),
    );
  }

  Future<void> handleLine(String line) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(line);
    } catch (_) {
      return;
    }

    if (decoded is! Map) {
      return;
    }

    final message = Map<Object?, Object?>.from(decoded);
    final id = message['id'];
    final method = message['method'];

    if (id != null &&
        (message.containsKey('result') || message.containsKey('error'))) {
      final requestId = _readInt(id);
      if (requestId == null) {
        return;
      }
      final pending = _pending.remove(requestId);
      if (pending == null) {
        return;
      }
      pending.timer?.cancel();

      if (message.containsKey('error') && message['error'] != null) {
        final error = message['error'];
        if (error is String) {
          pending.completer.completeError(StateError(error));
          return;
        }
        if (error is Map) {
          final map = Map<Object?, Object?>.from(error);
          pending.completer.completeError(
            JsonRpcError(
              map['message']?.toString() ?? 'JSON-RPC error',
              code: _readInt(map['code']),
              data: map['data'],
            ),
          );
          return;
        }
      }

      if (!pending.completer.isCompleted) {
        pending.completer.complete(message['result']);
      }
      return;
    }

    if (id != null && method is String) {
      final requestId = _readInt(id);
      if (requestId == null) {
        return;
      }

      try {
        final handler = _serverRequestHandler;
        if (handler == null) {
          throw StateError('Unhandled server request: $method');
        }
        final result = await handler(
          JsonRpcServerRequest(
            id: requestId,
            method: method,
            params: message['params'],
          ),
        );
        await _sendLine(
          jsonEncode(<String, Object?>{
            'id': requestId,
            'result': result,
          }),
        );
      } catch (error) {
        final err = _toError(error);
        await _sendLine(
          jsonEncode(<String, Object?>{
            'id': requestId,
            'error': <String, Object?>{
              'message': err.toString(),
            },
          }),
        );
      }
      return;
    }

    if (method is String) {
      _notificationsController.add(
        JsonRpcNotification(
          method: method,
          params: message['params'],
        ),
      );
    }
  }

  void rejectAllPending(Object error) {
    final err = _toError(error);
    for (final pending in _pending.values) {
      pending.timer?.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer.completeError(err);
      }
    }
    _pending.clear();
  }

  Future<void> close() async {
    rejectAllPending(StateError('JSON-RPC 已关闭。'));
    await _notificationsController.close();
  }

  int? _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '');
  }

  Object _toError(Object error) {
    if (error is JsonRpcError || error is Error || error is Exception) {
      return error;
    }
    return StateError(error.toString());
  }
}

class _PendingRequest {
  const _PendingRequest(this.completer, this.timer);

  final Completer<dynamic> completer;
  final Timer? timer;
}
