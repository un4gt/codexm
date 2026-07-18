import 'dart:io';
import 'dart:convert';

import 'package:codexm_flutter/app/theme/app_theme.dart';
import 'package:codexm_flutter/features/workspaces/presentation/pages/workspaces_page.dart';
import 'package:codexm_flutter/features/workspaces/application/workspace_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
  const secureStorageChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  late Directory documentsDir;
  late Directory temporaryDir;

  setUp(() async {
    documentsDir = await Directory.systemTemp.createTemp('codexm_docs_');
    temporaryDir = await Directory.systemTemp.createTemp('codexm_tmp_');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
          switch (call.method) {
            case 'getApplicationDocumentsDirectory':
              return documentsDir.path;
            case 'getTemporaryDirectory':
              return temporaryDir.path;
            default:
              return null;
          }
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async {
          switch (call.method) {
            case 'read':
              return null;
            case 'write':
            case 'delete':
              return null;
            default:
              return null;
          }
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
    if (documentsDir.existsSync()) {
      await documentsDir.delete(recursive: true);
    }
    if (temporaryDir.existsSync()) {
      await temporaryDir.delete(recursive: true);
    }
  });

  testWidgets('shows empty workspace guidance and grouped add actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildAppTheme(), home: const WorkspacesPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有工作区'), findsOneWidget);
    expect(find.text('工作区'), findsAtLeastNWidgets(1));
    expect(find.byTooltip('添加工作区'), findsOneWidget);

    await tester.tap(find.byTooltip('添加工作区'));
    await tester.pumpAndSettle();

    expect(find.text('新建空白工作区'), findsOneWidget);
    expect(find.text('克隆 Git 仓库'), findsOneWidget);
  });

  testWidgets('opens the workspace-scoped session flow from a workspace row', (
    WidgetTester tester,
  ) async {
    final workspacesDir = Directory('${documentsDir.path}/workspaces');
    final indexDir = Directory('${workspacesDir.path}/.index');
    await tester.runAsync(() async {
      await indexDir.create(recursive: true);
      await File('${indexDir.path}/workspaces.json').writeAsString(
        jsonEncode({
          'version': 2,
          'workspaces': [
            {
              'id': 'workspace-1',
              'name': '测试工作区',
              'createdAt': 1,
              'localPath': '${workspacesDir.path}/workspace-1/',
              'integrationBranch': 'main',
              'sessionGitVersion': 1,
            },
          ],
        }),
      );
    });
    Workspace? opened;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: WorkspacesPage(
          onOpenSessionsRequested: (workspace) => opened = workspace,
        ),
      ),
    );
    for (var i = 0; i < 100 && find.text('测试工作区').evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.tap(find.text('测试工作区'));
    for (var i = 0; i < 100 && opened == null; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    expect(opened?.id, 'workspace-1');
    expect(find.text('测试工作区'), findsOneWidget);
  });
}
