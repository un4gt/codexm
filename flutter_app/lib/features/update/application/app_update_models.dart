import 'package:codexm_native/codexm_native.dart';

class AppUpdateAsset {
  const AppUpdateAsset({
    this.id,
    required this.name,
    required this.downloadUrl,
    required this.size,
    required this.abi,
    this.updatedAt,
  });

  final int? id;
  final String name;
  final String downloadUrl;
  final int size;
  final String abi;
  final String? updatedAt;

  String get cacheKey {
    return <String>[
      if (id != null && id! > 0) 'id:$id',
      'name:$name',
      'url:$downloadUrl',
      'size:$size',
      'abi:$abi',
      if (updatedAt?.trim().isNotEmpty == true) 'updatedAt:$updatedAt',
    ].join('|');
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'downloadUrl': downloadUrl,
      'size': size,
      'abi': abi,
      'updatedAt': updatedAt,
    };
  }

  factory AppUpdateAsset.fromMap(Map<String, Object?> map) {
    return AppUpdateAsset(
      id: (map['id'] as num?)?.toInt(),
      name: map['name']?.toString() ?? '',
      downloadUrl: map['downloadUrl']?.toString() ?? '',
      size: (map['size'] as num?)?.toInt() ?? 0,
      abi: map['abi']?.toString() ?? '',
      updatedAt: map['updatedAt']?.toString(),
    );
  }
}

class AppUpdateRelease {
  const AppUpdateRelease({
    required this.version,
    required this.releaseUrl,
    required this.releaseNotes,
    this.publishedAt,
    this.asset,
  });

  final String version;
  final String releaseUrl;
  final String releaseNotes;
  final String? publishedAt;
  final AppUpdateAsset? asset;

  Map<String, Object?> toMap() {
    return {
      'version': version,
      'releaseUrl': releaseUrl,
      'releaseNotes': releaseNotes,
      'publishedAt': publishedAt,
      'asset': asset?.toMap(),
    };
  }

  factory AppUpdateRelease.fromMap(Map<String, Object?> map) {
    final rawAsset = map['asset'];
    return AppUpdateRelease(
      version: map['version']?.toString() ?? '',
      releaseUrl: map['releaseUrl']?.toString() ?? '',
      releaseNotes: map['releaseNotes']?.toString() ?? '',
      publishedAt: map['publishedAt']?.toString(),
      asset: rawAsset is Map
          ? AppUpdateAsset.fromMap(Map<String, Object?>.from(rawAsset))
          : null,
    );
  }
}

class AppDownloadedApk {
  const AppDownloadedApk({
    required this.version,
    required this.fileName,
    required this.filePath,
    required this.downloadedAt,
    required this.assetKey,
  });

  final String version;
  final String fileName;
  final String filePath;
  final int downloadedAt;
  final String assetKey;

  Map<String, Object?> toMap() {
    return {
      'version': version,
      'fileName': fileName,
      'filePath': filePath,
      'downloadedAt': downloadedAt,
      'assetKey': assetKey,
    };
  }

  factory AppDownloadedApk.fromMap(Map<String, Object?> map) {
    return AppDownloadedApk(
      version: map['version']?.toString() ?? '',
      fileName: map['fileName']?.toString() ?? '',
      filePath: map['filePath']?.toString() ?? '',
      downloadedAt: (map['downloadedAt'] as num?)?.toInt() ?? 0,
      assetKey: map['assetKey']?.toString() ?? '',
    );
  }
}

class AppUpdateState {
  const AppUpdateState({
    this.version = 1,
    this.etag,
    this.lastCheckedAt,
    this.latestRelease,
    this.downloadedApk,
  });

  final int version;
  final String? etag;
  final int? lastCheckedAt;
  final AppUpdateRelease? latestRelease;
  final AppDownloadedApk? downloadedApk;

  AppUpdateState copyWith({
    String? etag,
    int? lastCheckedAt,
    AppUpdateRelease? latestRelease,
    AppDownloadedApk? downloadedApk,
    bool clearEtag = false,
    bool clearLatestRelease = false,
    bool clearDownloadedApk = false,
  }) {
    return AppUpdateState(
      version: 1,
      etag: clearEtag ? null : (etag ?? this.etag),
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      latestRelease: clearLatestRelease
          ? null
          : (latestRelease ?? this.latestRelease),
      downloadedApk: clearDownloadedApk
          ? null
          : (downloadedApk ?? this.downloadedApk),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'version': version,
      'etag': etag,
      'lastCheckedAt': lastCheckedAt,
      'latestRelease': latestRelease?.toMap(),
      'downloadedApk': downloadedApk?.toMap(),
    };
  }

  factory AppUpdateState.fromMap(Map<String, Object?> map) {
    final rawRelease = map['latestRelease'];
    final rawDownloadedApk = map['downloadedApk'];
    return AppUpdateState(
      version: (map['version'] as num?)?.toInt() ?? 1,
      etag: map['etag']?.toString(),
      lastCheckedAt: (map['lastCheckedAt'] as num?)?.toInt(),
      latestRelease: rawRelease is Map
          ? AppUpdateRelease.fromMap(Map<String, Object?>.from(rawRelease))
          : null,
      downloadedApk: rawDownloadedApk is Map
          ? AppDownloadedApk.fromMap(
              Map<String, Object?>.from(rawDownloadedApk),
            )
          : null,
    );
  }
}

class AppUpdateCheckResult {
  const AppUpdateCheckResult({
    required this.currentApp,
    required this.latestRelease,
    required this.updateAvailable,
    required this.reusedCachedRelease,
  });

  final AppUpdateAppInfo currentApp;
  final AppUpdateRelease latestRelease;
  final bool updateAvailable;
  final bool reusedCachedRelease;
}

class AppUpdateDownloadProgress {
  const AppUpdateDownloadProgress({
    required this.bytesReceived,
    required this.totalBytes,
  });

  final int bytesReceived;
  final int? totalBytes;

  double? get fraction {
    final total = totalBytes;
    if (total == null || total <= 0) {
      return null;
    }
    return bytesReceived / total;
  }

  int? get percent {
    final value = fraction;
    if (value == null) {
      return null;
    }
    final percent = (value * 100).round();
    if (percent < 0) {
      return 0;
    }
    if (percent > 100) {
      return 100;
    }
    return percent;
  }
}

enum AppUpdateInstallStatus {
  launched,
  permissionRequired,
}

class AppUpdateInstallResult {
  const AppUpdateInstallResult({
    required this.status,
    required this.downloadedApk,
  });

  final AppUpdateInstallStatus status;
  final AppDownloadedApk downloadedApk;
}
