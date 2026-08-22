enum LanAccessPhase { disabled, waitingForNetwork, starting, listening, error }

class LanAccessPreferences {
  const LanAccessPreferences({this.enabled = false, this.port = 8765});

  final bool enabled;
  final int port;

  LanAccessPreferences copyWith({bool? enabled, int? port}) {
    return LanAccessPreferences(
      enabled: enabled ?? this.enabled,
      port: port ?? this.port,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{'version': 1, 'enabled': enabled, 'port': port};
  }

  factory LanAccessPreferences.fromMap(Map<String, Object?> map) {
    final port = (map['port'] as num?)?.toInt() ?? 8765;
    return LanAccessPreferences(
      enabled: map['enabled'] as bool? ?? false,
      port: port >= 1024 && port <= 65535 ? port : 8765,
    );
  }
}

class LanNetworkSnapshot {
  const LanNetworkSnapshot({this.addresses = const <String>[]});

  final List<String> addresses;

  bool get connected => addresses.isNotEmpty;

  String? get preferredAddress => addresses.firstOrNull;

  factory LanNetworkSnapshot.fromMap(Map<Object?, Object?> map) {
    final raw = map['addresses'];
    final addresses = raw is List
        ? raw
              .map((item) => item?.toString().trim() ?? '')
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList(growable: false)
        : const <String>[];
    return LanNetworkSnapshot(addresses: addresses);
  }
}

class LanAccessState {
  const LanAccessState({
    required this.preferences,
    required this.phase,
    this.address,
    this.pairingCode,
    this.pairingCodeExpiresAt,
    this.pairedBrowserCount = 0,
    this.connectedBrowserCount = 0,
    this.errorMessage,
  });

  final LanAccessPreferences preferences;
  final LanAccessPhase phase;
  final String? address;
  final String? pairingCode;
  final int? pairingCodeExpiresAt;
  final int pairedBrowserCount;
  final int connectedBrowserCount;
  final String? errorMessage;

  bool get enabled => preferences.enabled;

  int get port => preferences.port;

  String? get url => phase == LanAccessPhase.listening && address != null
      ? 'http://$address:$port'
      : null;

  LanAccessState copyWith({
    LanAccessPreferences? preferences,
    LanAccessPhase? phase,
    String? address,
    String? pairingCode,
    int? pairingCodeExpiresAt,
    int? pairedBrowserCount,
    int? connectedBrowserCount,
    String? errorMessage,
    bool clearAddress = false,
    bool clearPairingCode = false,
    bool clearError = false,
  }) {
    return LanAccessState(
      preferences: preferences ?? this.preferences,
      phase: phase ?? this.phase,
      address: clearAddress ? null : (address ?? this.address),
      pairingCode: clearPairingCode ? null : (pairingCode ?? this.pairingCode),
      pairingCodeExpiresAt: clearPairingCode
          ? null
          : (pairingCodeExpiresAt ?? this.pairingCodeExpiresAt),
      pairedBrowserCount: pairedBrowserCount ?? this.pairedBrowserCount,
      connectedBrowserCount:
          connectedBrowserCount ?? this.connectedBrowserCount,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
