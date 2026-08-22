import 'dart:convert';
import 'dart:io';

import '../../../shared/persistence/app_directory_service.dart';
import 'lan_access_models.dart';

class LanAccessPreferencesStore {
  LanAccessPreferencesStore({AppDirectoryService? appDirectoryService})
    : _appDirectoryService = appDirectoryService ?? AppDirectoryService();

  final AppDirectoryService _appDirectoryService;

  Future<LanAccessPreferences> load() async {
    final file = await _file();
    if (!file.existsSync()) {
      return const LanAccessPreferences();
    }
    try {
      final parsed = jsonDecode(await file.readAsString());
      if (parsed is Map) {
        return LanAccessPreferences.fromMap(Map<String, Object?>.from(parsed));
      }
    } catch (_) {
      // Invalid preferences fall back to a disabled listener.
    }
    return const LanAccessPreferences();
  }

  Future<LanAccessPreferences> save(LanAccessPreferences preferences) async {
    if (preferences.port < 1024 || preferences.port > 65535) {
      throw ArgumentError.value(
        preferences.port,
        'port',
        '端口必须在 1024 到 65535 之间。',
      );
    }
    final file = await _file();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(preferences.toMap()),
      flush: true,
    );
    return preferences;
  }

  Future<File> _file() async {
    final dir = await _appDirectoryService.settingsDir();
    return File('${dir.path}/lan_access.json');
  }
}
