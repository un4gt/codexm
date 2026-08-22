import 'dart:async';

import 'lan_access_models.dart';
import 'lan_access_platform.dart';
import 'lan_access_preferences_store.dart';
import 'lan_http_server.dart';
import 'lan_pairing_manager.dart';

class LanAccessController {
  LanAccessController({
    required LanAccessPreferencesStore preferencesStore,
    required LanAccessPlatform platform,
    required LanAccessHttpServer httpServer,
    required LanPairingManager pairingManager,
  }) : _preferencesStore = preferencesStore,
       _platform = platform,
       _httpServer = httpServer,
       _pairingManager = pairingManager,
       _state = const LanAccessState(
         preferences: LanAccessPreferences(),
         phase: LanAccessPhase.disabled,
       ) {
    _pairingManager.onChanged = _syncRuntimeDetails;
    _httpServer.onStateChanged = _syncRuntimeDetails;
  }

  final LanAccessPreferencesStore _preferencesStore;
  final LanAccessPlatform _platform;
  final LanAccessHttpServer _httpServer;
  final LanPairingManager _pairingManager;
  final StreamController<LanAccessState> _states =
      StreamController<LanAccessState>.broadcast(sync: true);

  LanAccessState _state;
  LanNetworkSnapshot _network = const LanNetworkSnapshot();
  StreamSubscription<LanNetworkSnapshot>? _networkSubscription;
  Timer? _pairingTimer;
  Future<void> _reconcileQueue = Future<void>.value();
  bool _initialized = false;

  LanAccessState get state => _state;

  Stream<LanAccessState> get states => _states.stream;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    final preferences = await _preferencesStore.load();
    _network = await _platform.currentNetwork();
    _setState(
      _state.copyWith(
        preferences: preferences,
        phase: preferences.enabled
            ? LanAccessPhase.starting
            : LanAccessPhase.disabled,
        clearError: true,
      ),
    );
    _networkSubscription = _platform.networkSnapshots().listen(
      (snapshot) {
        _network = snapshot;
        _enqueueReconcile();
      },
      onError: (Object error) {
        _setError('无法读取局域网状态，请重试。');
      },
    );
    _pairingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.enabled) {
        _syncRuntimeDetails();
      }
    });
    if (preferences.enabled) {
      await _platform.startForegroundService(message: '正在检查局域网连接...');
    }
    await _enqueueReconcile();
  }

  Future<bool> setEnabled(bool enabled) async {
    if (enabled == _state.enabled) {
      return true;
    }
    if (enabled) {
      final granted = await _platform.requestNotificationPermission();
      if (!granted) {
        _setError('需要通知权限才能在后台持续提供局域网访问。');
        return false;
      }
      final preferences = await _preferencesStore.save(
        _state.preferences.copyWith(enabled: true),
      );
      _setState(
        _state.copyWith(
          preferences: preferences,
          phase: LanAccessPhase.starting,
          clearError: true,
        ),
      );
      await _platform.startForegroundService(message: '正在检查局域网连接...');
      await _enqueueReconcile();
      return true;
    }

    final preferences = await _preferencesStore.save(
      _state.preferences.copyWith(enabled: false),
    );
    await _httpServer.stop();
    await _platform.stopForegroundService();
    _setState(
      LanAccessState(preferences: preferences, phase: LanAccessPhase.disabled),
    );
    return true;
  }

  Future<void> setPort(int port) async {
    if (_state.enabled) {
      throw StateError('请先关闭局域网访问，再修改端口。');
    }
    if (port < 1024 || port > 65535) {
      throw ArgumentError.value(port, 'port', '端口必须在 1024 到 65535 之间。');
    }
    final preferences = await _preferencesStore.save(
      _state.preferences.copyWith(port: port),
    );
    _setState(_state.copyWith(preferences: preferences, clearError: true));
  }

  String generatePairingCode() {
    if (!_httpServer.isRunning) {
      throw StateError('局域网服务尚未开始监听。');
    }
    final code = _pairingManager.generatePairingCode();
    _syncRuntimeDetails();
    return code;
  }

  void revokeAllBrowsers() {
    _httpServer.revokeAllBrowsers();
    _syncRuntimeDetails();
  }

  Future<void> openNotificationSettings() {
    return _platform.openNotificationSettings();
  }

  Future<void> retry() async {
    if (!_state.enabled) {
      return;
    }
    _network = await _platform.currentNetwork();
    await _enqueueReconcile();
  }

  Future<void> _enqueueReconcile() {
    final next = _reconcileQueue.then((_) => _reconcile());
    _reconcileQueue = next.catchError((_) {});
    return next;
  }

  Future<void> _reconcile() async {
    if (!_state.enabled) {
      return;
    }
    final address = _network.preferredAddress;
    if (address == null) {
      if (_httpServer.isRunning) {
        await _httpServer.stop();
      }
      _setState(
        _state.copyWith(
          phase: LanAccessPhase.waitingForNetwork,
          clearAddress: true,
          clearPairingCode: true,
          clearError: true,
        ),
      );
      await _platform.updateForegroundService(message: '等待连接 Wi-Fi 或以太网');
      return;
    }

    if (_httpServer.isRunning &&
        _httpServer.address == address &&
        _httpServer.port == _state.port) {
      _syncRuntimeDetails();
      return;
    }

    _setState(
      _state.copyWith(
        phase: LanAccessPhase.starting,
        address: address,
        clearPairingCode: true,
        clearError: true,
      ),
    );
    try {
      await _httpServer.start(address: address, port: _state.port);
      _setState(
        _state.copyWith(
          phase: LanAccessPhase.listening,
          address: address,
          clearError: true,
        ),
      );
      _syncRuntimeDetails();
      await _platform.updateForegroundService(
        message: '浏览器访问 http://$address:${_state.port}',
      );
    } catch (_) {
      await _httpServer.stop();
      _setError('无法监听端口 ${_state.port}，请关闭服务后更换端口再试。');
      await _platform.updateForegroundService(message: '局域网访问启动失败，请打开应用处理');
    }
  }

  void _syncRuntimeDetails() {
    final code = _pairingManager.pairingCode;
    _setState(
      _state.copyWith(
        pairingCode: code,
        pairingCodeExpiresAt: _pairingManager.pairingCodeExpiresAt,
        pairedBrowserCount: _pairingManager.sessionCount,
        connectedBrowserCount: _httpServer.connectedBrowserCount,
        clearPairingCode: code == null,
      ),
    );
  }

  void _setError(String message) {
    _setState(
      _state.copyWith(phase: LanAccessPhase.error, errorMessage: message),
    );
  }

  void _setState(LanAccessState state) {
    _state = state;
    if (!_states.isClosed) {
      _states.add(state);
    }
  }

  Future<void> dispose() async {
    _pairingTimer?.cancel();
    await _networkSubscription?.cancel();
    await _httpServer.dispose();
    await _states.close();
  }
}
