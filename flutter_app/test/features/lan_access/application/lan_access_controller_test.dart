import 'dart:async';

import 'package:codexm_flutter/features/lan_access/application/lan_access_controller.dart';
import 'package:codexm_flutter/features/lan_access/application/lan_access_models.dart';
import 'package:codexm_flutter/features/lan_access/application/lan_access_platform.dart';
import 'package:codexm_flutter/features/lan_access/application/lan_access_preferences_store.dart';
import 'package:codexm_flutter/features/lan_access/application/lan_http_server.dart';
import 'package:codexm_flutter/features/lan_access/application/lan_pairing_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('restores enabled access and follows LAN address changes', () async {
    final fixture = await _ControllerFixture.create(
      preferences: const LanAccessPreferences(enabled: true),
    );
    addTearDown(fixture.dispose);

    expect(fixture.controller.state.phase, LanAccessPhase.waitingForNetwork);
    expect(fixture.platform.startMessages, ['正在检查局域网连接...']);
    expect(fixture.platform.updateMessages.last, '等待连接 Wi-Fi 或以太网');

    final firstListening = fixture.controller.states.firstWhere(
      (state) =>
          state.phase == LanAccessPhase.listening &&
          state.address == '192.168.1.20',
    );
    fixture.platform.emit(
      const LanNetworkSnapshot(addresses: <String>['192.168.1.20']),
    );
    expect((await firstListening).url, 'http://192.168.1.20:8765');
    expect(fixture.server.starts, [('192.168.1.20', 8765)]);
    expect(fixture.pairingManager.pairingCode, isNotNull);

    final rebound = fixture.controller.states.firstWhere(
      (state) =>
          state.phase == LanAccessPhase.listening &&
          state.address == '192.168.1.21',
    );
    fixture.platform.emit(
      const LanNetworkSnapshot(addresses: <String>['192.168.1.21']),
    );
    await rebound;
    expect(fixture.server.starts.last, ('192.168.1.21', 8765));
    expect(fixture.server.stopCalls, 2);

    final disconnected = fixture.controller.states.firstWhere(
      (state) => state.phase == LanAccessPhase.waitingForNetwork,
    );
    fixture.platform.emit(const LanNetworkSnapshot());
    await disconnected;
    expect(fixture.server.running, isFalse);
    expect(fixture.pairingManager.sessionCount, 0);
    expect(fixture.pairingManager.pairingCode, isNull);
  });

  test('handles notification denial and locks port while enabled', () async {
    final fixture = await _ControllerFixture.create(permissionGranted: false);
    addTearDown(fixture.dispose);

    expect(await fixture.controller.setEnabled(true), isFalse);
    expect(fixture.controller.state.enabled, isFalse);
    expect(fixture.controller.state.phase, LanAccessPhase.error);
    expect(fixture.store.saveCalls, 0);
    expect(fixture.platform.startMessages, isEmpty);

    await fixture.controller.setPort(9123);
    expect(fixture.controller.state.port, 9123);
    expect(() => fixture.controller.setPort(80), throwsA(isA<ArgumentError>()));

    fixture.platform.permissionGranted = true;
    fixture.platform.emit(
      const LanNetworkSnapshot(addresses: <String>['10.0.0.8']),
    );
    expect(await fixture.controller.setEnabled(true), isTrue);
    expect(fixture.controller.state.phase, LanAccessPhase.listening);
    expect(() => fixture.controller.setPort(9444), throwsA(isA<StateError>()));

    expect(await fixture.controller.setEnabled(false), isTrue);
    expect(fixture.controller.state.phase, LanAccessPhase.disabled);
    expect(fixture.platform.stopCalls, 1);
  });
}

class _ControllerFixture {
  const _ControllerFixture({
    required this.controller,
    required this.store,
    required this.platform,
    required this.server,
    required this.pairingManager,
  });

  final LanAccessController controller;
  final _MemoryPreferencesStore store;
  final _ControllerPlatform platform;
  final _ControllerServer server;
  final LanPairingManager pairingManager;

  static Future<_ControllerFixture> create({
    LanAccessPreferences preferences = const LanAccessPreferences(),
    LanNetworkSnapshot network = const LanNetworkSnapshot(),
    bool permissionGranted = true,
  }) async {
    final store = _MemoryPreferencesStore(preferences);
    final platform = _ControllerPlatform(
      network: network,
      permissionGranted: permissionGranted,
    );
    final pairingManager = LanPairingManager();
    final server = _ControllerServer(pairingManager);
    final controller = LanAccessController(
      preferencesStore: store,
      platform: platform,
      httpServer: server,
      pairingManager: pairingManager,
    );
    await controller.initialize();
    return _ControllerFixture(
      controller: controller,
      store: store,
      platform: platform,
      server: server,
      pairingManager: pairingManager,
    );
  }

  Future<void> dispose() async {
    await controller.dispose();
    await platform.dispose();
  }
}

class _MemoryPreferencesStore extends LanAccessPreferencesStore {
  _MemoryPreferencesStore(this.preferences);

  LanAccessPreferences preferences;
  int saveCalls = 0;

  @override
  Future<LanAccessPreferences> load() async => preferences;

  @override
  Future<LanAccessPreferences> save(LanAccessPreferences value) async {
    saveCalls += 1;
    preferences = value;
    return value;
  }
}

class _ControllerPlatform implements LanAccessPlatform {
  _ControllerPlatform({required this.network, required this.permissionGranted});

  final StreamController<LanNetworkSnapshot> _snapshots =
      StreamController<LanNetworkSnapshot>.broadcast(sync: true);
  LanNetworkSnapshot network;
  bool permissionGranted;
  final List<String> startMessages = <String>[];
  final List<String> updateMessages = <String>[];
  int stopCalls = 0;

  void emit(LanNetworkSnapshot value) {
    network = value;
    _snapshots.add(value);
  }

  @override
  Future<LanNetworkSnapshot> currentNetwork() async => network;

  @override
  Stream<LanNetworkSnapshot> networkSnapshots() => _snapshots.stream;

  @override
  Future<bool> requestNotificationPermission() async => permissionGranted;

  @override
  Future<void> openNotificationSettings() async {}

  @override
  Future<void> startForegroundService({required String message}) async {
    startMessages.add(message);
  }

  @override
  Future<void> updateForegroundService({required String message}) async {
    updateMessages.add(message);
  }

  @override
  Future<void> stopForegroundService() async {
    stopCalls += 1;
  }

  Future<void> dispose() => _snapshots.close();
}

class _ControllerServer implements LanAccessHttpServer {
  _ControllerServer(this.pairingManager);

  final LanPairingManager pairingManager;
  final List<(String, int)> starts = <(String, int)>[];
  bool running = false;
  String? currentAddress;
  int? currentPort;
  int stopCalls = 0;

  @override
  void Function()? onStateChanged;

  @override
  bool get isRunning => running;

  @override
  String? get address => currentAddress;

  @override
  int? get port => currentPort;

  @override
  int get connectedBrowserCount => 0;

  @override
  Future<void> start({required String address, required int port}) async {
    await stop();
    starts.add((address, port));
    running = true;
    currentAddress = address;
    currentPort = port;
    pairingManager.ensurePairingCode();
    onStateChanged?.call();
  }

  @override
  Future<void> stop() async {
    stopCalls += 1;
    running = false;
    currentAddress = null;
    currentPort = null;
    pairingManager.revokeAll();
    onStateChanged?.call();
  }

  @override
  void revokeAllBrowsers() {
    pairingManager.revokeAll();
    onStateChanged?.call();
  }

  @override
  Future<void> dispose() => stop();
}
