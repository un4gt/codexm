import 'dart:async';

class AsyncQueue<T> {
  final List<T> _items = <T>[];
  final List<void Function(T?)> _waiters = <void Function(T?)>[];
  bool _closed = false;

  bool get isClosed => _closed;

  void push(T value) {
    if (_closed) {
      return;
    }
    if (_waiters.isNotEmpty) {
      final waiter = _waiters.removeAt(0);
      waiter(value);
      return;
    }
    _items.add(value);
  }

  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    while (_waiters.isNotEmpty) {
      final waiter = _waiters.removeAt(0);
      waiter(null);
    }
  }

  Future<T?> shift([int? timeoutMs]) async {
    if (_items.isNotEmpty) {
      return _items.removeAt(0);
    }
    if (_closed) {
      return null;
    }

    if (timeoutMs == null || timeoutMs <= 0) {
      final completer = Completer<T?>();
      _waiters.add((value) {
        if (!completer.isCompleted) {
          completer.complete(value);
        }
      });
      return completer.future;
    }

    final completer = Completer<T?>();
    late void Function(T?) waiter;
    Timer? timer;

    waiter = (value) {
      timer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(value);
      }
    };

    timer = Timer(Duration(milliseconds: timeoutMs), () {
      _waiters.remove(waiter);
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });

    _waiters.add(waiter);
    return completer.future;
  }
}
