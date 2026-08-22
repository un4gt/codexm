import 'dart:io';

import 'package:codexm_flutter/features/lan_access/application/lan_access_controller.dart';
import 'package:codexm_flutter/features/lan_access/application/lan_access_models.dart';
import 'package:codexm_flutter/features/lan_access/application/lan_access_platform.dart';
import 'package:codexm_flutter/features/lan_access/application/lan_access_preferences_store.dart';
import 'package:codexm_flutter/features/lan_access/application/lan_http_server.dart';
import 'package:codexm_flutter/features/lan_access/application/lan_pairing_manager.dart';
import 'package:codexm_flutter/features/lan_access/presentation/lan_access_settings_section.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows disabled state and allows port editing', (tester) async {
    final fixture = await _LanWidgetFixture.create();
    addTearDown(fixture.dispose);

    await _pumpSection(tester, fixture.controller);

    expect(find.text('已关闭'), findsOneWidget);
    expect(find.text('HTTP 连接未加密，请仅在你信任的局域网中使用。'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    await _disposeFixture(tester, fixture);
  });

  testWidgets('shows listening address and one-time pairing code', (
    tester,
  ) async {
    final fixture = await _LanWidgetFixture.create(
      preferences: const LanAccessPreferences(enabled: true),
      network: const LanNetworkSnapshot(addresses: <String>['192.168.20.7']),
    );
    addTearDown(fixture.dispose);

    await _pumpSection(tester, fixture.controller);

    expect(find.text('已在局域网中运行'), findsOneWidget);
    expect(find.text('http://192.168.20.7:8765'), findsOneWidget);
    expect(find.text(fixture.pairingManager.pairingCode!), findsOneWidget);
    expect(find.textContaining('秒后失效'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    await _disposeFixture(tester, fixture);
  });

  testWidgets('shows retry and notification actions after listener failure', (
    tester,
  ) async {
    final fixture = await _LanWidgetFixture.create(
      preferences: const LanAccessPreferences(enabled: true),
      network: const LanNetworkSnapshot(addresses: <String>['192.168.20.7']),
      failToStart: true,
    );
    addTearDown(fixture.dispose);

    await _pumpSection(tester, fixture.controller);

    expect(find.text('无法监听端口 8765，请关闭服务后更换端口再试。'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '重试'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, '通知设置'), findsOneWidget);
    expect(fixture.httpServer.startAttempts, 1);

    await tester.tap(find.widgetWithText(OutlinedButton, '重试'));
    await tester.pump();
    expect(fixture.httpServer.startAttempts, 2);

    await tester.ensureVisible(find.widgetWithText(OutlinedButton, '通知设置'));
    await tester.tap(find.widgetWithText(OutlinedButton, '通知设置'));
    await tester.pump();
    expect(fixture.platform.openSettingsCalls, 1);
    await _disposeFixture(tester, fixture);
  });

  testWidgets(
    'keeps access disabled and exposes settings when permission denied',
    (tester) async {
      final fixture = await _LanWidgetFixture.create(permissionGranted: false);
      addTearDown(fixture.dispose);

      await _pumpSection(tester, fixture.controller);
      await tester.tap(find.text('允许浏览器访问'));
      await tester.pumpAndSettle();

      expect(find.text('需要通知权限才能在后台持续提供局域网访问。'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, '通知设置'), findsOneWidget);
      expect(fixture.preferencesStore.preferences.enabled, isFalse);
      expect(fixture.platform.startCalls, 0);

      await tester.ensureVisible(find.widgetWithText(OutlinedButton, '通知设置'));
      await tester.tap(find.widgetWithText(OutlinedButton, '通知设置'));
      await tester.pump();
      expect(fixture.platform.openSettingsCalls, 1);
      await _disposeFixture(tester, fixture);
    },
  );
}

Future<void> _pumpSection(WidgetTester tester, LanAccessController controller) {
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const <Locale>[Locale('zh')],
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: LanAccessSettingsSection(controller: controller),
        ),
      ),
    ),
  );
}

Future<void> _disposeFixture(
  WidgetTester tester,
  _LanWidgetFixture fixture,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.runAsync(fixture.dispose);
  await tester.pump();
}

class _LanWidgetFixture {
  _LanWidgetFixture({
    required this.controller,
    required this.preferencesStore,
    required this.platform,
    required this.pairingManager,
    required this.httpServer,
  });

  final LanAccessController controller;
  final _FakePreferencesStore preferencesStore;
  final _FakeLanAccessPlatform platform;
  final LanPairingManager pairingManager;
  final _FakeLanHttpServer httpServer;
  bool _disposed = false;

  static Future<_LanWidgetFixture> create({
    LanAccessPreferences preferences = const LanAccessPreferences(),
    LanNetworkSnapshot network = const LanNetworkSnapshot(),
    bool permissionGranted = true,
    bool failToStart = false,
  }) async {
    final preferencesStore = _FakePreferencesStore(preferences);
    final platform = _FakeLanAccessPlatform(
      network: network,
      permissionGranted: permissionGranted,
    );
    final pairingManager = LanPairingManager();
    final httpServer = _FakeLanHttpServer(
      pairingManager,
      failToStart: failToStart,
    );
    final controller = LanAccessController(
      preferencesStore: preferencesStore,
      platform: platform,
      httpServer: httpServer,
      pairingManager: pairingManager,
    );
    await controller.initialize();
    return _LanWidgetFixture(
      controller: controller,
      preferencesStore: preferencesStore,
      platform: platform,
      pairingManager: pairingManager,
      httpServer: httpServer,
    );
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await controller.dispose();
    await platform.dispose();
  }
}

class _FakePreferencesStore extends LanAccessPreferencesStore {
  _FakePreferencesStore(this.preferences);

  LanAccessPreferences preferences;

  @override
  Future<LanAccessPreferences> load() async => preferences;

  @override
  Future<LanAccessPreferences> save(LanAccessPreferences value) async {
    preferences = value;
    return value;
  }
}

class _FakeLanAccessPlatform implements LanAccessPlatform {
  _FakeLanAccessPlatform({
    required this.network,
    required this.permissionGranted,
  });

  LanNetworkSnapshot network;
  bool permissionGranted;
  int startCalls = 0;
  int openSettingsCalls = 0;

  @override
  Future<LanNetworkSnapshot> currentNetwork() async => network;

  @override
  Stream<LanNetworkSnapshot> networkSnapshots() =>
      const Stream<LanNetworkSnapshot>.empty();

  @override
  Future<bool> requestNotificationPermission() async => permissionGranted;

  @override
  Future<void> openNotificationSettings() async {
    openSettingsCalls += 1;
  }

  @override
  Future<void> startForegroundService({required String message}) async {
    startCalls += 1;
  }

  @override
  Future<void> updateForegroundService({required String message}) async {}

  @override
  Future<void> stopForegroundService() async {}

  Future<void> dispose() async {}
}

class _FakeLanHttpServer implements LanAccessHttpServer {
  _FakeLanHttpServer(this.pairingManager, {required this.failToStart});

  final LanPairingManager pairingManager;
  final bool failToStart;
  bool running = false;
  String? currentAddress;
  int? currentPort;
  int startAttempts = 0;

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
    startAttempts += 1;
    if (failToStart) throw const SocketException('test listener failure');
    running = true;
    currentAddress = address;
    currentPort = port;
    pairingManager.ensurePairingCode();
    onStateChanged?.call();
  }

  @override
  Future<void> stop() {
    running = false;
    currentAddress = null;
    currentPort = null;
    pairingManager.revokeAll();
    onStateChanged?.call();
    return SynchronousFuture<void>(null);
  }

  @override
  void revokeAllBrowsers() {
    pairingManager.revokeAll();
    onStateChanged?.call();
  }

  @override
  Future<void> dispose() => stop();
}
