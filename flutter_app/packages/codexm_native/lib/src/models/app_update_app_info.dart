class AppUpdateAppInfo {
  const AppUpdateAppInfo({
    required this.packageName,
    required this.versionName,
    required this.versionCode,
  });

  final String packageName;
  final String versionName;
  final int versionCode;

  factory AppUpdateAppInfo.fromMap(Map<Object?, Object?> map) {
    return AppUpdateAppInfo(
      packageName: map['packageName']?.toString() ?? '',
      versionName: map['versionName']?.toString() ?? '',
      versionCode: (map['versionCode'] as num?)?.toInt() ?? 0,
    );
  }
}
