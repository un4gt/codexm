import 'dart:io';

import 'package:codexm_flutter/features/codex/application/codex_skills_store.dart';
import 'package:codexm_flutter/shared/persistence/app_directory_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes, lists and deletes installed skills', () async {
    final documentsDir = await Directory.systemTemp.createTemp('codexm_docs_');
    final temporaryDir = await Directory.systemTemp.createTemp('codexm_tmp_');
    addTearDown(() async {
      if (documentsDir.existsSync()) {
        await documentsDir.delete(recursive: true);
      }
      if (temporaryDir.existsSync()) {
        await temporaryDir.delete(recursive: true);
      }
    });

    final store = CodexSkillsStore(
      appDirectoryService: AppDirectoryService(
        documentsResolver: () async => documentsDir,
        temporaryResolver: () async => temporaryDir,
      ),
    );

    final name = await store.writeSkill(
      name: r'$My Skill',
      content: '# Demo Skill',
    );
    final listed = await store.listInstalledSkills();
    final file = await store.skillFile(name);
    final content = await store.readSkill(name);

    expect(name, 'my-skill');
    expect(listed, <String>['my-skill']);
    expect(file.existsSync(), isTrue);
    expect(content, '# Demo Skill');

    await store.deleteSkill('my-skill');
    expect(await store.listInstalledSkills(), isEmpty);
  });
}
