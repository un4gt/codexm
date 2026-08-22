import 'dart:math';

import 'package:codexm_flutter/features/lan_access/application/lan_pairing_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'pairing code is single-use and creates an in-memory browser session',
    () {
      var now = DateTime.utc(2026, 8, 21, 12);
      final manager = LanPairingManager(random: Random(42), now: () => now);

      final code = manager.generatePairingCode();
      expect(code, hasLength(6));
      expect(code, matches(RegExp(r'^\d{6}$')));

      final session = manager.pair(code: code, remoteAddress: '192.168.1.5');
      expect(session.token.length, greaterThan(30));
      expect(session.csrfToken.length, greaterThan(20));
      expect(manager.findSession(session.token), same(session));
      expect(manager.pairingCode, isNull);
      expect(manager.sessionCount, 1);

      expect(
        () => manager.pair(code: code, remoteAddress: '192.168.1.5'),
        throwsA(
          isA<LanPairingException>().having(
            (error) => error.code,
            'code',
            'pairing_expired',
          ),
        ),
      );

      now = now.add(const Duration(minutes: 1));
      manager.revoke(session.token);
      expect(manager.sessionCount, 0);
    },
  );

  test('expires pairing codes after five minutes', () {
    var now = DateTime.utc(2026, 8, 21, 12);
    final manager = LanPairingManager(random: Random(7), now: () => now);

    manager.generatePairingCode();
    now = now.add(const Duration(minutes: 5, milliseconds: 1));

    expect(manager.pairingCode, isNull);
    expect(manager.pairingCodeExpiresAt, isNull);
  });

  test('rate-limits pairing attempts by remote address', () {
    final manager = LanPairingManager(random: Random(9));
    manager.generatePairingCode();

    for (var attempt = 0; attempt < 5; attempt += 1) {
      expect(
        () => manager.pair(code: '000000', remoteAddress: '192.168.1.9'),
        throwsA(isA<LanPairingException>()),
      );
    }

    expect(
      () => manager.pair(code: '000000', remoteAddress: '192.168.1.9'),
      throwsA(
        isA<LanPairingException>().having(
          (error) => error.code,
          'code',
          'pairing_rate_limited',
        ),
      ),
    );
  });
}
