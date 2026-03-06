import 'dart:io';

import '../../../shared/persistence/app_directory_service.dart';

class CodexSkillsStore {
  CodexSkillsStore({
    AppDirectoryService? appDirectoryService,
  }) : _appDirectoryService = appDirectoryService ?? AppDirectoryService();

  final AppDirectoryService _appDirectoryService;

  Future<Directory> skillsDir() async {
    final codexHomeDir = await _appDirectoryService.codexHomeDir();
    final dir = Directory('${codexHomeDir.path}/skills');
    await dir.create(recursive: true);
    return dir;
  }

  String normalizeSkillName(String raw) {
    final trimmed = raw.trim().replaceFirst(RegExp(r'^\$+'), '').trim().toLowerCase();
    final cleaned = trimmed
        .replaceAll(RegExp(r'[^a-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^[-_]+|[-_]+$'), '');
    return cleaned;
  }

  Future<File> skillFile(String name) async {
    final normalized = normalizeSkillName(name);
    if (normalized.isEmpty) {
      throw StateError('名称为空。');
    }
    final dir = await skillsDir();
    return File('${dir.path}/$normalized/SKILL.md');
  }

  Future<List<String>> listInstalledSkills() async {
    final dir = await skillsDir();
    final out = <String>[];
    await for (final entity in dir.list()) {
      if (entity is! Directory) {
        continue;
      }
      final file = File('${entity.path}/SKILL.md');
      if (!file.existsSync()) {
        continue;
      }
      final segments = entity.uri.pathSegments.where((segment) => segment.isNotEmpty).toList();
      if (segments.isEmpty) {
        continue;
      }
      out.add(normalizeSkillName(segments.last));
    }
    out.sort((left, right) => left.compareTo(right));
    return out;
  }

  Future<String> readSkill(String name) async {
    final normalized = normalizeSkillName(name);
    if (normalized.isEmpty) {
      throw StateError('名称为空。');
    }
    final file = await skillFile(normalized);
    if (!file.existsSync()) {
      throw StateError('技能不存在：$normalized');
    }
    final content = await file.readAsString();
    return content.trimRight();
  }

  Future<String> writeSkill({
    required String name,
    required String content,
  }) async {
    final normalized = normalizeSkillName(name);
    final trimmed = content.trim();
    if (normalized.isEmpty) {
      throw StateError('名称为空。');
    }
    if (trimmed.isEmpty) {
      throw StateError('内容为空。');
    }
    final file = await skillFile(normalized);
    await file.parent.create(recursive: true);
    await file.writeAsString('$trimmed\n');
    return normalized;
  }

  Future<void> deleteSkill(String name) async {
    final normalized = normalizeSkillName(name);
    if (normalized.isEmpty) {
      return;
    }
    final dir = await skillsDir();
    final skillDir = Directory('${dir.path}/$normalized');
    if (skillDir.existsSync()) {
      await skillDir.delete(recursive: true);
    }
  }
}
