import 'dart:convert';
import 'dart:math';

class LanPairingException implements Exception {
  const LanPairingException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class LanBrowserSession {
  const LanBrowserSession({
    required this.token,
    required this.csrfToken,
    required this.createdAt,
  });

  final String token;
  final String csrfToken;
  final int createdAt;
}

class LanPairingManager {
  LanPairingManager({
    Random? random,
    DateTime Function()? now,
    this.pairingLifetime = const Duration(minutes: 5),
  }) : _random = random ?? Random.secure(),
       _now = now ?? DateTime.now;

  final Random _random;
  final DateTime Function() _now;
  final Duration pairingLifetime;
  final Map<String, LanBrowserSession> _sessions =
      <String, LanBrowserSession>{};
  final Map<String, List<int>> _attemptsByAddress = <String, List<int>>{};

  String? _pairingCode;
  int? _pairingCodeExpiresAt;

  void Function()? onChanged;

  String? get pairingCode {
    _clearExpiredCode();
    return _pairingCode;
  }

  int? get pairingCodeExpiresAt {
    _clearExpiredCode();
    return _pairingCodeExpiresAt;
  }

  int get sessionCount => _sessions.length;

  String generatePairingCode() {
    _pairingCode = _random.nextInt(1000000).toString().padLeft(6, '0');
    _pairingCodeExpiresAt = _now().add(pairingLifetime).millisecondsSinceEpoch;
    onChanged?.call();
    return _pairingCode!;
  }

  String ensurePairingCode() => pairingCode ?? generatePairingCode();

  LanBrowserSession pair({
    required String code,
    required String remoteAddress,
  }) {
    _recordAttempt(remoteAddress);
    final expected = pairingCode;
    if (expected == null) {
      throw const LanPairingException('pairing_expired', '配对码已过期，请在手机上重新生成。');
    }
    if (!_constantTimeEquals(expected, code.trim())) {
      throw const LanPairingException('pairing_invalid', '配对码不正确。');
    }

    final session = LanBrowserSession(
      token: _randomToken(32),
      csrfToken: _randomToken(24),
      createdAt: _now().millisecondsSinceEpoch,
    );
    _sessions[session.token] = session;
    _pairingCode = null;
    _pairingCodeExpiresAt = null;
    onChanged?.call();
    return session;
  }

  LanBrowserSession? findSession(String? token) {
    if (token == null || token.isEmpty) {
      return null;
    }
    return _sessions[token];
  }

  void revoke(String? token) {
    if (token != null && _sessions.remove(token) != null) {
      onChanged?.call();
    }
  }

  void revokeAll() {
    final changed =
        _sessions.isNotEmpty ||
        _pairingCode != null ||
        _attemptsByAddress.isNotEmpty;
    _sessions.clear();
    _attemptsByAddress.clear();
    _pairingCode = null;
    _pairingCodeExpiresAt = null;
    if (changed) {
      onChanged?.call();
    }
  }

  void _recordAttempt(String remoteAddress) {
    final nowMs = _now().millisecondsSinceEpoch;
    final cutoff = nowMs - const Duration(minutes: 1).inMilliseconds;
    final attempts = _attemptsByAddress.putIfAbsent(
      remoteAddress,
      () => <int>[],
    )..removeWhere((value) => value < cutoff);
    if (attempts.length >= 5) {
      throw const LanPairingException('pairing_rate_limited', '尝试次数过多，请稍后再试。');
    }
    attempts.add(nowMs);
  }

  void _clearExpiredCode() {
    final expiresAt = _pairingCodeExpiresAt;
    if (expiresAt != null && expiresAt <= _now().millisecondsSinceEpoch) {
      _pairingCode = null;
      _pairingCodeExpiresAt = null;
      onChanged?.call();
    }
  }

  String _randomToken(int length) {
    final bytes = List<int>.generate(length, (_) => _random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  bool _constantTimeEquals(String left, String right) {
    var difference = left.length ^ right.length;
    final length = max(left.length, right.length);
    for (var index = 0; index < length; index += 1) {
      final leftUnit = index < left.length ? left.codeUnitAt(index) : 0;
      final rightUnit = index < right.length ? right.codeUnitAt(index) : 0;
      difference |= leftUnit ^ rightUnit;
    }
    return difference == 0;
  }
}
