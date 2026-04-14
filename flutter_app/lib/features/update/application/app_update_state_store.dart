import 'dart:convert';
import 'dart:io';

import '../../../shared/persistence/app_directory_service.dart';
import 'app_update_models.dart';

class AppUpdateStateStore {
  AppUpdateStateStore({
    AppDirectoryService? appDirectoryService,
  }) : _appDirectoryService = appDirectoryService ?? AppDirectoryService();

  final AppDirectoryService _appDirectoryService;

  Future<AppUpdateState> getState() async {
    final file = await _stateFile();
    if (!file.existsSync()) {
      return const AppUpdateState();
    }
    final parsed = jsonDecode(await file.readAsString());
    if (parsed is! Map) {
      return const AppUpdateState();
    }
    return AppUpdateState.fromMap(Map<String, Object?>.from(parsed));
  }

  Future<AppUpdateState> saveState(AppUpdateState state) async {
    final file = await _stateFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(state.toMap()),
    );
    return state;
  }

  Future<AppUpdateState> updateState(
    AppUpdateState Function(AppUpdateState current) update,
  ) async {
    final current = await getState();
    final next = update(current);
    return saveState(next);
  }

  Future<File> _stateFile() async {
    final dir = await _appDirectoryService.settingsDir();
    return File('${dir.path}/update_state.json');
  }
}
